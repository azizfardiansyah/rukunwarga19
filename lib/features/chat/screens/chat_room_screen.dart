import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/chat_service.dart';
import '../../../core/services/pocketbase_service.dart';
import '../../../core/utils/error_classifier.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/models/chat_model.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/chat_providers.dart';

enum _RoomMenuAction { toggleSearch, media, pin, manageMembers, editAvatar }

class ChatRoomScreen extends ConsumerStatefulWidget {
  const ChatRoomScreen({super.key, required this.conversationId});

  final String conversationId;

  @override
  ConsumerState<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends ConsumerState<ChatRoomScreen> {
  final _messageCtrl = TextEditingController();
  final _roomSearchCtrl = TextEditingController();
  final _scrollController = ScrollController();
  late final ChatService _chatService;
  late final String _currentUserId;

  ChatMessagesData? _data;
  bool _isLoading = true;
  bool _isSending = false;
  bool _isSearchMode = false;
  bool _isTypingStateActive = false;
  bool _isDisposed = false;
  bool _isFetchingMessages = false;
  bool _queuedSilentRefresh = false;
  PlatformFile? _selectedAttachment;
  MessageModel? _replyingTo;
  MessageModel? _editingMessage;
  Timer? _presenceTimer;
  Timer? _refreshDebounce;
  Timer? _typingStopTimer;
  Future<void> Function()? _unsubscribeMessages;
  Future<void> Function()? _unsubscribeConversation;
  Future<void> Function()? _unsubscribeMembers;

  @override
  void initState() {
    super.initState();
    _chatService = ref.read(chatServiceProvider);
    _currentUserId = ref.read(authProvider).user?.id ?? '';
    final cached = _chatService.getCachedMessages(widget.conversationId);
    if (cached != null) {
      _data = cached;
      _isLoading = false;
    }
    _messageCtrl.addListener(_handleComposerChanged);
    _roomSearchCtrl.addListener(_handleRoomSearchChanged);
    _loadMessages(silent: cached != null);
    _bindRealtime();
    _presenceTimer = Timer.periodic(
      const Duration(seconds: 25),
      (_) => _touchPresence(),
    );
    WidgetsBinding.instance.addPostFrameCallback((_) {
      _touchPresence();
    });
  }

  Future<void> _bindRealtime() async {
    await _disposeRealtime();
    _unsubscribeMessages = await pb
        .collection(AppConstants.colMessages)
        .subscribe('*', (event) {
          final record = event.record;
          if (record == null ||
              record.getStringValue('conversation') != widget.conversationId) {
            return;
          }
          _scheduleRefresh();
        }, filter: 'conversation = "${widget.conversationId}"');
    _unsubscribeConversation = await pb
        .collection(AppConstants.colConversations)
        .subscribe(widget.conversationId, (_) => _scheduleRefresh());
    try {
      _unsubscribeMembers = await pb
          .collection(AppConstants.colConversationMembers)
          .subscribe(
            '*',
            _handleMemberRealtimeEvent,
            filter: 'conversation = "${widget.conversationId}"',
          );
    } catch (_) {
      _unsubscribeMembers = null;
    }
  }

  void _handleMemberRealtimeEvent(dynamic event) {
    final record = event.record;
    if (record == null ||
        record.getStringValue('conversation') != widget.conversationId) {
      return;
    }
    if (record.getStringValue('user') == _currentUserId) {
      return;
    }
    final action = '${event.action ?? ''}'.toLowerCase();
    if (action == 'delete') {
      _scheduleRefresh();
      return;
    }
    if (_applyParticipantRealtimeUpdate(record)) {
      return;
    }
    _scheduleRefresh();
  }

  bool _applyParticipantRealtimeUpdate(dynamic record) {
    final current = _data;
    if (current == null || !mounted || _isDisposed) {
      return false;
    }
    final userId = record.getStringValue('user');
    if (userId.isEmpty) {
      return false;
    }
    final index = current.participants.indexWhere(
      (participant) => participant.userId == userId,
    );
    if (index < 0) {
      return false;
    }

    final existing = current.participants[index];
    final nextLastSeenAt =
        _readRecordDateTime(record, 'last_seen_at') ?? existing.lastSeenAt;
    final nextTypingAt = record.data.containsKey('typing_at')
        ? _readRecordDateTime(record, 'typing_at')
        : existing.typingAt;
    final hasChanged =
        existing.lastSeenAt?.millisecondsSinceEpoch !=
            nextLastSeenAt?.millisecondsSinceEpoch ||
        existing.typingAt?.millisecondsSinceEpoch !=
            nextTypingAt?.millisecondsSinceEpoch;
    if (!hasChanged) {
      return true;
    }

    final participants = List<ChatParticipantModel>.from(current.participants);
    participants[index] = ChatParticipantModel(
      userId: existing.userId,
      displayName: existing.displayName,
      avatarUrl: existing.avatarUrl,
      lastSeenAt: nextLastSeenAt,
      typingAt: nextTypingAt,
      isCurrentUser: existing.isCurrentUser,
    );
    final nextData = ChatMessagesData(
      conversation: current.conversation,
      messages: current.messages,
      participants: participants,
    );
    setState(() {
      _data = nextData;
    });
    _chatService.cacheMessagesData(nextData);
    return true;
  }

  DateTime? _readRecordDateTime(dynamic record, String field) {
    final raw = record.data[field];
    final value = raw?.toString().trim() ?? '';
    if (value.isEmpty) {
      return null;
    }
    return DateTime.tryParse(value);
  }

  void _scheduleRefresh() {
    if (_isDisposed) {
      return;
    }
    _refreshDebounce?.cancel();
    _refreshDebounce = Timer(const Duration(milliseconds: 450), () {
      if (mounted && !_isDisposed) {
        _loadMessages(silent: true);
      }
    });
  }

  Future<void> _disposeRealtime() async {
    await _unsubscribeMessages?.call();
    await _unsubscribeConversation?.call();
    await _unsubscribeMembers?.call();
    _unsubscribeMessages = null;
    _unsubscribeConversation = null;
    _unsubscribeMembers = null;
  }

  Future<void> _loadMessages({bool silent = false}) async {
    if (_isDisposed) {
      return;
    }
    if (_isFetchingMessages) {
      _queuedSilentRefresh = _queuedSilentRefresh || silent;
      return;
    }
    _isFetchingMessages = true;
    if (!silent && mounted && !_isDisposed && _data == null) {
      setState(() => _isLoading = true);
    }

    try {
      final previous = _data;
      final result = await _chatService.getMessages(widget.conversationId);
      if (!mounted || _isDisposed) {
        return;
      }

      final previousSignature = _messagesSignature(previous);
      final nextSignature = _messagesSignature(result);
      final shouldScroll = _shouldAutoScroll(previous, result);
      final shouldUpdateUi =
          previous == null || previousSignature != nextSignature || _isLoading;

      if (shouldUpdateUi) {
        setState(() {
          _data = result;
          _isLoading = false;
          if (_replyingTo != null) {
            final match = result.messages.where(
              (item) => item.id == _replyingTo!.id,
            );
            _replyingTo = match.isEmpty ? null : match.first;
          }
          if (_editingMessage != null) {
            final match = result.messages.where(
              (item) => item.id == _editingMessage!.id,
            );
            _editingMessage = match.isEmpty ? null : match.first;
          }
        });
        _chatService.cacheMessagesData(result);
        if (shouldScroll) {
          _scrollToBottom();
        }
      } else if (_isLoading) {
        setState(() => _isLoading = false);
      }
    } catch (error) {
      if (!mounted || _isDisposed) {
        return;
      }
      setState(() => _isLoading = false);
      if (!silent) {
        ErrorClassifier.showErrorSnackBar(context, error);
      }
    } finally {
      _isFetchingMessages = false;
      if (_queuedSilentRefresh && mounted && !_isDisposed) {
        _queuedSilentRefresh = false;
        unawaited(_loadMessages(silent: true));
      }
    }
  }

  Future<void> _pickAttachment() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: false,
        withData: true,
      );
      if (!mounted || result == null || result.files.isEmpty) {
        return;
      }

      setState(() {
        _selectedAttachment = result.files.single;
      });
    } catch (error) {
      if (mounted) {
        ErrorClassifier.showErrorSnackBar(context, error);
      }
    }
  }

  void _appendMessage(MessageModel message) {
    if (!mounted) {
      return;
    }
    final current = _data;
    if (current == null) {
      return;
    }
    setState(() {
      _data = ChatMessagesData(
        conversation: current.conversation,
        messages: [...current.messages, message],
        participants: current.participants,
      );
    });
    if (_data != null) {
      _chatService.cacheMessagesData(_data!);
    }
    _scrollToBottom();
  }

  String _messagesSignature(ChatMessagesData? data) {
    if (data == null) {
      return '';
    }
    final messageSignature = data.messages
        .map(
          (message) =>
              '${message.id}:${message.editedAt?.millisecondsSinceEpoch ?? 0}:'
              '${message.deliveryStatus ?? ''}:${message.deliveredCount}:'
              '${message.readCount}:${message.isPinned ? 1 : 0}:'
              '${message.isStarred ? 1 : 0}:${message.isDeleted ? 1 : 0}:'
              '${message.reactions.map((item) => '${item.emoji}${item.count}${item.reactedByMe ? 1 : 0}').join(',')}',
        )
        .join('|');
    final participantSignature = data.participants
        .map(
          (participant) =>
              '${participant.userId}:${participant.lastSeenAt?.millisecondsSinceEpoch ?? 0}:'
              '${participant.typingAt?.millisecondsSinceEpoch ?? 0}',
        )
        .join('|');
    return '${data.conversation.id}:${data.conversation.name}:'
        '${data.conversation.lastMessageAt?.millisecondsSinceEpoch ?? 0}:'
        '${data.messages.length}:$messageSignature:$participantSignature';
  }

  bool _shouldAutoScroll(ChatMessagesData? previous, ChatMessagesData next) {
    if (previous == null) {
      return true;
    }
    if (next.messages.length > previous.messages.length) {
      return true;
    }
    final previousLastId = previous.messages.isEmpty
        ? ''
        : previous.messages.last.id;
    final nextLastId = next.messages.isEmpty ? '' : next.messages.last.id;
    return previousLastId.isNotEmpty && previousLastId != nextLastId;
  }

  void _handleRoomSearchChanged() {
    if (mounted && !_isDisposed) {
      setState(() {});
    }
  }

  void _handleComposerChanged() {
    if (_isDisposed) {
      return;
    }
    final trimmed = _messageCtrl.text.trim();
    if (trimmed.isEmpty) {
      if (_isTypingStateActive) {
        _isTypingStateActive = false;
        unawaited(
          _chatService.setTypingState(
            conversationId: widget.conversationId,
            isTyping: false,
          ),
        );
      }
      _typingStopTimer?.cancel();
    } else {
      if (!_isTypingStateActive) {
        _isTypingStateActive = true;
        unawaited(
          _chatService.setTypingState(
            conversationId: widget.conversationId,
            isTyping: true,
          ),
        );
      }
      _typingStopTimer?.cancel();
      _typingStopTimer = Timer(const Duration(seconds: 3), () {
        if (_isDisposed) {
          return;
        }
        _isTypingStateActive = false;
        unawaited(
          _chatService.setTypingState(
            conversationId: widget.conversationId,
            isTyping: false,
          ),
        );
      });
    }

    if (mounted && !_isDisposed) {
      setState(() {});
    }
  }

  Future<void> _touchPresence() async {
    if (_isDisposed) {
      return;
    }
    try {
      await _chatService.touchPresence(widget.conversationId);
    } catch (_) {}
  }

  Future<void> _showComposerActions() async {
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
          child: Wrap(
            runSpacing: 6,
            children: [
              _MessageActionTile(
                icon: Icons.attach_file_rounded,
                label: 'Lampiran',
                onTap: () {
                  Navigator.pop(sheetContext);
                  _pickAttachment();
                },
              ),
              _MessageActionTile(
                icon: Icons.poll_rounded,
                label: 'Polling',
                onTap: () {
                  Navigator.pop(sheetContext);
                  _showPollComposer();
                },
              ),
              _MessageActionTile(
                icon: Icons.mic_rounded,
                label: 'Voice Note',
                onTap: () {
                  Navigator.pop(sheetContext);
                  _pickVoiceNote();
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _pickVoiceNote() async {
    try {
      final result = await FilePicker.platform.pickFiles(
        allowMultiple: false,
        withData: true,
        type: FileType.custom,
        allowedExtensions: const ['aac', 'm4a', 'mp3', 'wav', 'ogg', 'webm'],
      );
      if (!mounted || result == null || result.files.isEmpty) {
        return;
      }

      final durationController = TextEditingController(text: '30');
      final durationSeconds = await showDialog<int>(
        context: context,
        builder: (dialogContext) => AlertDialog(
          title: const Text('Kirim Voice Note'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                result.files.single.name,
                style: AppTheme.bodyMedium.copyWith(
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: durationController,
                keyboardType: TextInputType.number,
                inputFormatters: [FilteringTextInputFormatter.digitsOnly],
                decoration: const InputDecoration(
                  labelText: 'Durasi (detik)',
                  hintText: 'Contoh: 30',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(null),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(
                dialogContext,
              ).pop(int.tryParse(durationController.text.trim()) ?? 0),
              child: const Text('Kirim'),
            ),
          ],
        ),
      );

      if (!mounted || durationSeconds == null) {
        return;
      }

      setState(() => _isSending = true);
      final message = await ref
          .read(chatServiceProvider)
          .sendVoiceMessage(
            conversationId: widget.conversationId,
            audioFile: result.files.single,
            durationSeconds: durationSeconds,
            replyToId: _replyingTo?.id,
          );
      _appendMessage(message);
      if (mounted) {
        setState(() => _replyingTo = null);
      }
      await Future<void>.delayed(const Duration(milliseconds: 140));
      await _loadMessages(silent: true);
    } catch (error) {
      if (mounted) {
        ErrorClassifier.showErrorSnackBar(context, error);
      }
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  Future<void> _showPollComposer() async {
    final titleController = TextEditingController();
    final optionControllers = <TextEditingController>[
      TextEditingController(),
      TextEditingController(),
    ];
    var allowMultipleChoice = false;
    var allowAnonymousVote = false;
    var isSubmitting = false;

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) {
          Future<void> submit() async {
            final options = optionControllers
                .map((controller) => controller.text.trim())
                .where((item) => item.isNotEmpty)
                .toList(growable: false);
            if (titleController.text.trim().isEmpty || options.length < 2) {
              ErrorClassifier.showErrorSnackBar(
                context,
                const FormatException(
                  'Judul polling dan minimal 2 opsi wajib diisi.',
                ),
              );
              return;
            }

            setSheetState(() => isSubmitting = true);
            try {
              final message = await ref
                  .read(chatServiceProvider)
                  .createPoll(
                    conversationId: widget.conversationId,
                    title: titleController.text.trim(),
                    options: options,
                    allowMultipleChoice: allowMultipleChoice,
                    allowAnonymousVote: allowAnonymousVote,
                  );
              if (!mounted || !sheetContext.mounted) {
                return;
              }
              Navigator.of(sheetContext).pop();
              _appendMessage(message);
              await Future<void>.delayed(const Duration(milliseconds: 140));
              await _loadMessages(silent: true);
            } catch (error) {
              if (mounted) {
                ErrorClassifier.showErrorSnackBar(context, error);
              }
            } finally {
              if (sheetContext.mounted) {
                setSheetState(() => isSubmitting = false);
              }
            }
          }

          return Padding(
            padding: EdgeInsets.only(
              left: 16,
              right: 16,
              top: 8,
              bottom: MediaQuery.of(sheetContext).viewInsets.bottom + 16,
            ),
            child: SingleChildScrollView(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text('Buat Polling', style: AppTheme.heading3),
                  const SizedBox(height: 12),
                  TextField(
                    controller: titleController,
                    decoration: const InputDecoration(
                      labelText: 'Pertanyaan / Judul',
                    ),
                  ),
                  const SizedBox(height: 12),
                  for (
                    var index = 0;
                    index < optionControllers.length;
                    index++
                  ) ...[
                    TextField(
                      controller: optionControllers[index],
                      decoration: InputDecoration(
                        labelText: 'Opsi ${index + 1}',
                      ),
                    ),
                    const SizedBox(height: 10),
                  ],
                  Row(
                    children: [
                      TextButton.icon(
                        onPressed: optionControllers.length >= 6
                            ? null
                            : () => setSheetState(
                                () => optionControllers.add(
                                  TextEditingController(),
                                ),
                              ),
                        icon: const Icon(Icons.add_rounded),
                        label: const Text('Tambah Opsi'),
                      ),
                      const Spacer(),
                      Text(
                        '${optionControllers.length}/6 opsi',
                        style: AppTheme.caption,
                      ),
                    ],
                  ),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    value: allowMultipleChoice,
                    onChanged: (value) =>
                        setSheetState(() => allowMultipleChoice = value),
                    title: const Text('Izinkan multi-pilihan'),
                  ),
                  SwitchListTile.adaptive(
                    contentPadding: EdgeInsets.zero,
                    value: allowAnonymousVote,
                    onChanged: (value) =>
                        setSheetState(() => allowAnonymousVote = value),
                    title: const Text('Sembunyikan identitas voter'),
                  ),
                  const SizedBox(height: 8),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: isSubmitting ? null : submit,
                      child: isSubmitting
                          ? const SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(strokeWidth: 2),
                            )
                          : const Text('Kirim Polling'),
                    ),
                  ),
                ],
              ),
            ),
          );
        },
      ),
    );

    titleController.dispose();
    for (final controller in optionControllers) {
      controller.dispose();
    }
  }

  Future<void> _votePoll(MessageModel message, List<String> optionIds) async {
    final pollId = message.poll?.id ?? message.pollId;
    if ((pollId ?? '').isEmpty) {
      return;
    }
    try {
      await ref
          .read(chatServiceProvider)
          .votePoll(pollId: pollId!, optionIds: optionIds);
      await _loadMessages(silent: true);
    } catch (error) {
      if (mounted) {
        ErrorClassifier.showErrorSnackBar(context, error);
      }
    }
  }

  Future<void> _sendMessage() async {
    final text = _messageCtrl.text.trim();
    if (_isSending) {
      return;
    }
    if (_editingMessage != null && text.isEmpty) {
      ErrorClassifier.showErrorSnackBar(
        context,
        const FormatException('Isi pesan edit tidak boleh kosong.'),
      );
      return;
    }
    if (_editingMessage == null &&
        text.isEmpty &&
        _selectedAttachment == null) {
      return;
    }

    setState(() => _isSending = true);
    try {
      final service = ref.read(chatServiceProvider);
      if (_editingMessage != null) {
        await service.editMessage(messageId: _editingMessage!.id, text: text);
        _messageCtrl.clear();
        if (mounted) {
          setState(() => _editingMessage = null);
        }
      } else {
        final sentMessage = await service.sendMessage(
          conversationId: widget.conversationId,
          text: text,
          attachment: _selectedAttachment,
          replyToId: _replyingTo?.id,
        );
        _messageCtrl.clear();
        if (mounted && _data != null) {
          setState(() {
            _selectedAttachment = null;
            _replyingTo = null;
          });
          _appendMessage(sentMessage);
        } else if (mounted) {
          setState(() {
            _selectedAttachment = null;
            _replyingTo = null;
          });
        }
      }
      _isTypingStateActive = false;
      unawaited(
        service.setTypingState(
          conversationId: widget.conversationId,
          isTyping: false,
        ),
      );
      await Future<void>.delayed(const Duration(milliseconds: 140));
      await _loadMessages(silent: true);
    } catch (error) {
      if (mounted) {
        ErrorClassifier.showErrorSnackBar(context, error);
      }
    } finally {
      if (mounted) {
        setState(() => _isSending = false);
      }
    }
  }

  Future<void> _openAttachment(MessageModel message) async {
    final url = message.attachmentUrl;
    if (url == null || url.isEmpty) {
      return;
    }

    final uri = Uri.tryParse(url);
    if (uri == null) {
      return;
    }

    final launched = await launchUrl(uri, mode: LaunchMode.externalApplication);
    if (!launched && mounted) {
      ErrorClassifier.showErrorSnackBar(
        context,
        const FormatException('Lampiran tidak dapat dibuka.'),
      );
    }
  }

  Future<void> _forwardMessage(MessageModel message) async {
    final bootstrap = await ref.read(chatBootstrapProvider.future);
    final options = [
      ...bootstrap.inbox,
      ...bootstrap.groups,
    ].where((item) => item.id != widget.conversationId).toList(growable: false);
    if (!mounted) {
      return;
    }
    if (options.isEmpty) {
      ErrorClassifier.showErrorSnackBar(
        context,
        const FormatException('Belum ada percakapan tujuan untuk forward.'),
      );
      return;
    }

    final target = await showModalBottomSheet<ConversationModel>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Teruskan Pesan', style: AppTheme.heading3),
              const SizedBox(height: 12),
              SizedBox(
                height: 320,
                child: ListView.separated(
                  itemCount: options.length,
                  separatorBuilder: (_, _) => const Divider(height: 1),
                  itemBuilder: (context, index) {
                    final item = options[index];
                    return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      leading: CircleAvatar(
                        radius: 18,
                        backgroundColor: item.isPrivate
                            ? AppTheme.accentColor.withValues(alpha: 0.16)
                            : AppTheme.primaryColor.withValues(alpha: 0.10),
                        child: Icon(
                          item.isPrivate
                              ? Icons.support_agent_rounded
                              : item.isGroupRt
                              ? Icons.groups_rounded
                              : Icons.hub_rounded,
                          color: item.isPrivate
                              ? AppTheme.accentColor
                              : AppTheme.primaryColor,
                          size: 18,
                        ),
                      ),
                      title: Text(item.name, style: AppTheme.bodyMedium),
                      subtitle: Text(
                        item.subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTheme.caption,
                      ),
                      onTap: () => Navigator.pop(context, item),
                    );
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (!mounted || target == null) {
      return;
    }

    try {
      await ref
          .read(chatServiceProvider)
          .forwardMessage(
            messageId: message.id,
            targetConversationId: target.id,
          );
      ref.read(chatRefreshTickProvider.notifier).bump();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Pesan diteruskan ke ${target.name}')),
        );
      }
    } catch (error) {
      if (mounted) {
        ErrorClassifier.showErrorSnackBar(context, error);
      }
    }
  }

  Future<void> _showMessageActions(MessageModel message) async {
    final auth = ref.read(authProvider);
    await showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
          child: Wrap(
            runSpacing: 6,
            children: [
              if (!message.isDeleted)
                Padding(
                  padding: const EdgeInsets.only(bottom: 6),
                  child: Wrap(
                    spacing: 8,
                    runSpacing: 8,
                    children: [
                      for (final emoji in _quickReactionEmojis)
                        _QuickReactionChip(
                          emoji: emoji,
                          selected: message.reactions.any(
                            (item) => item.emoji == emoji && item.reactedByMe,
                          ),
                          onTap: () async {
                            Navigator.pop(context);
                            await _toggleReaction(message, emoji);
                          },
                        ),
                    ],
                  ),
                ),
              if (!message.isDeleted)
                _MessageActionTile(
                  icon: Icons.reply_rounded,
                  label: 'Balas',
                  onTap: () {
                    Navigator.pop(context);
                    setState(() {
                      _editingMessage = null;
                      _replyingTo = message;
                    });
                  },
                ),
              if (!message.isDeleted)
                _MessageActionTile(
                  icon: Icons.add_reaction_outlined,
                  label: 'Reaksi',
                  onTap: () async {
                    Navigator.pop(context);
                    await _showReactionPicker(message);
                  },
                ),
              _MessageActionTile(
                icon: Icons.forward_rounded,
                label: 'Teruskan',
                onTap: () {
                  Navigator.pop(context);
                  _forwardMessage(message);
                },
              ),
              _MessageActionTile(
                icon: Icons.copy_all_rounded,
                label: 'Salin',
                onTap: () async {
                  Navigator.pop(context);
                  await Clipboard.setData(
                    ClipboardData(
                      text: message.text.isNotEmpty
                          ? message.text
                          : (message.attachmentUrl ?? ''),
                    ),
                  );
                  if (mounted) {
                    ScaffoldMessenger.of(this.context).showSnackBar(
                      const SnackBar(content: Text('Konten pesan disalin')),
                    );
                  }
                },
              ),
              _MessageActionTile(
                icon: message.isStarred
                    ? Icons.star_rounded
                    : Icons.star_outline_rounded,
                label: message.isStarred ? 'Hapus bintang' : 'Beri bintang',
                onTap: () async {
                  Navigator.pop(context);
                  await _runMessageAction(() async {
                    await ref
                        .read(chatServiceProvider)
                        .toggleMessageStar(message.id);
                  });
                },
              ),
              if (!message.isDeleted &&
                  message.isMine &&
                  auth.user != null &&
                  message.messageType != AppConstants.msgTypePoll &&
                  !message.isVoice)
                _MessageActionTile(
                  icon: Icons.edit_outlined,
                  label: 'Edit pesan',
                  onTap: () {
                    Navigator.pop(context);
                    _startEditingMessage(message);
                  },
                ),
              _MessageActionTile(
                icon: message.isPinned
                    ? Icons.push_pin_rounded
                    : Icons.push_pin_outlined,
                label: message.isPinned ? 'Lepas Pin Pesan' : 'Pin Pesan',
                onTap: () async {
                  Navigator.pop(context);
                  if (message.isPinned) {
                    await _runMessageAction(() async {
                      await ref
                          .read(chatServiceProvider)
                          .setMessagePin(
                            messageId: message.id,
                            isPinned: false,
                          );
                    });
                    return;
                  }

                  final duration = await _showMessagePinDurationDialog();
                  if (!mounted || duration == null) {
                    return;
                  }

                  await _runMessageAction(() async {
                    await ref
                        .read(chatServiceProvider)
                        .setMessagePin(
                          messageId: message.id,
                          isPinned: true,
                          duration: duration,
                        );
                  });
                },
              ),
              if (message.isMine || auth.isSysadmin)
                _MessageActionTile(
                  icon: Icons.delete_outline_rounded,
                  label: 'Hapus',
                  isDestructive: true,
                  onTap: () async {
                    Navigator.pop(context);
                    await _runMessageAction(() async {
                      await ref
                          .read(chatServiceProvider)
                          .deleteMessage(message.id);
                    });
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _runMessageAction(Future<void> Function() action) async {
    try {
      await action();
      await _loadMessages(silent: true);
      ref.read(chatRefreshTickProvider.notifier).bump();
    } catch (error) {
      if (mounted) {
        ErrorClassifier.showErrorSnackBar(context, error);
      }
    }
  }

  void _startEditingMessage(MessageModel message) {
    _messageCtrl.value = TextEditingValue(
      text: message.text,
      selection: TextSelection.collapsed(offset: message.text.length),
    );
    setState(() {
      _editingMessage = message;
      _replyingTo = null;
      _selectedAttachment = null;
    });
  }

  Future<void> _showReactionPicker(MessageModel message) {
    return showModalBottomSheet<void>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
          child: Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              for (final emoji in _reactionPickerEmojis)
                _QuickReactionChip(
                  emoji: emoji,
                  selected: message.reactions.any(
                    (item) => item.emoji == emoji && item.reactedByMe,
                  ),
                  onTap: () async {
                    Navigator.pop(sheetContext);
                    await _toggleReaction(message, emoji);
                  },
                ),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _toggleReaction(MessageModel message, String emoji) async {
    await _runMessageAction(() async {
      await ref
          .read(chatServiceProvider)
          .toggleMessageReaction(messageId: message.id, emoji: emoji);
    });
  }

  void _toggleSearchMode() {
    setState(() {
      _isSearchMode = !_isSearchMode;
      if (!_isSearchMode) {
        _roomSearchCtrl.clear();
      }
    });
  }

  Future<void> _showConversationMediaSheet() async {
    final messages = _data?.messages ?? const <MessageModel>[];
    final media = messages
        .where(
          (item) =>
              item.hasAttachment &&
              _isImageFileName(item.attachmentName ?? '') &&
              (item.attachmentUrl ?? '').isNotEmpty,
        )
        .toList(growable: false);
    final documents = messages
        .where(
          (item) =>
              item.hasAttachment &&
              !_isImageFileName(item.attachmentName ?? ''),
        )
        .toList(growable: false);
    final links = _extractConversationLinks(messages);

    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (sheetContext) => SafeArea(
        child: DefaultTabController(
          length: 3,
          child: SizedBox(
            height: MediaQuery.of(sheetContext).size.height * 0.78,
            child: Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(16, 4, 16, 10),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          'Media, Dokumen, dan Link',
                          style: AppTheme.heading3,
                        ),
                      ),
                      Text('${messages.length} pesan', style: AppTheme.caption),
                    ],
                  ),
                ),
                const TabBar(
                  tabs: [
                    Tab(text: 'Media'),
                    Tab(text: 'Dokumen'),
                    Tab(text: 'Link'),
                  ],
                ),
                Expanded(
                  child: TabBarView(
                    children: [
                      _ConversationMediaTab(
                        messages: media,
                        onOpenMessageAttachment: _openAttachment,
                      ),
                      _ConversationDocumentTab(
                        messages: documents,
                        onOpenMessageAttachment: _openAttachment,
                      ),
                      _ConversationLinkTab(links: links),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  List<_ConversationLinkEntry> _extractConversationLinks(
    List<MessageModel> messages,
  ) {
    final entries = <_ConversationLinkEntry>[];
    final seen = <String>{};
    for (final message in messages) {
      for (final match in _urlRegex.allMatches(message.text)) {
        final url = message.text.substring(match.start, match.end);
        final normalized = url.trim();
        if (normalized.isEmpty || !seen.add('${message.id}::$normalized')) {
          continue;
        }
        entries.add(_ConversationLinkEntry(message: message, url: normalized));
      }
    }
    return entries;
  }

  Future<Duration?> _showMessagePinDurationDialog() {
    final options = _messagePinDurationOptions;
    var selected = options[1];

    return showDialog<Duration>(
      context: context,
      builder: (dialogContext) => StatefulBuilder(
        builder: (context, setState) => AlertDialog(
          title: const Text('Pilih durasi pin pesan'),
          contentPadding: const EdgeInsets.fromLTRB(24, 18, 24, 8),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Pin bisa dilepas kapan saja.',
                style: AppTheme.bodyMedium.copyWith(
                  color: AppTheme.textSecondary,
                ),
              ),
              const SizedBox(height: 14),
              RadioGroup<_MessagePinDurationOption>(
                groupValue: selected,
                onChanged: (value) {
                  if (value == null) {
                    return;
                  }
                  setState(() => selected = value);
                },
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    for (final option in options)
                      RadioListTile<_MessagePinDurationOption>(
                        value: option,
                        contentPadding: EdgeInsets.zero,
                        dense: true,
                        title: Text(option.label),
                        activeColor: AppTheme.accentColor,
                      ),
                  ],
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(dialogContext).pop(),
              child: const Text('Batal'),
            ),
            FilledButton(
              onPressed: () =>
                  Navigator.of(dialogContext).pop(selected.duration),
              child: const Text('Pin'),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _toggleConversationPin() async {
    final conversation = _data?.conversation;
    if (conversation == null) {
      return;
    }

    try {
      await ref
          .read(chatServiceProvider)
          .setConversationPreference(
            conversationId: conversation.id,
            isPinned: !conversation.isPinned,
          );
      await _loadMessages(silent: true);
      ref.invalidate(chatBootstrapProvider);
      await ref.read(chatBootstrapProvider.future);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            conversation.isPinned
                ? 'Pin chat dilepas'
                : 'Chat dipin ke posisi teratas',
          ),
        ),
      );
    } catch (error) {
      if (mounted) {
        ErrorClassifier.showErrorSnackBar(context, error);
      }
    }
  }

  Future<void> _handleRoomMenuAction(_RoomMenuAction action) async {
    switch (action) {
      case _RoomMenuAction.toggleSearch:
        _toggleSearchMode();
        return;
      case _RoomMenuAction.media:
        await _showConversationMediaSheet();
        return;
      case _RoomMenuAction.pin:
        await _toggleConversationPin();
        return;
      case _RoomMenuAction.manageMembers:
        await _showOrgUnitMemberManager();
        return;
      case _RoomMenuAction.editAvatar:
        await _showConversationAvatarEditor();
        return;
    }
  }

  Future<void> _refreshConversationShell() async {
    await _loadMessages(silent: true);
    ref.read(chatRefreshTickProvider.notifier).bump();
    ref.invalidate(chatBootstrapProvider);
    try {
      await ref.read(chatBootstrapProvider.future);
    } catch (_) {}
  }

  Future<void> _showOrgUnitMemberManager() async {
    final conversation = _data?.conversation;
    if (conversation == null) {
      return;
    }

    try {
      final service = ref.read(chatServiceProvider);
      final options = await service.getOrgUnitConversationMemberOptions(
        conversation.id,
      );
      if (!mounted) {
        return;
      }
      final selectedUserIds = {
        ...options.where((item) => item.isSelected).map((item) => item.userId),
      };
      final result = await showModalBottomSheet<List<String>>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (sheetContext) => StatefulBuilder(
          builder: (sheetContext, setSheetState) => SafeArea(
            child: Padding(
              padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Kelola Anggota Grup', style: AppTheme.heading3),
                  const SizedBox(height: 8),
                  Text(
                    'Tambahkan akun yang masuk area yuridiksi grup ini. Pengurus unit tetap diprioritaskan.',
                    style: AppTheme.bodySmall.copyWith(
                      color: AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    height: MediaQuery.of(sheetContext).size.height * 0.6,
                    child: ListView.separated(
                      itemCount: options.length,
                      separatorBuilder: (_, _) => const Divider(height: 1),
                      itemBuilder: (context, index) {
                        final option = options[index];
                        final isChecked = selectedUserIds.contains(
                          option.userId,
                        );
                        final isEnabled =
                            !option.isLocked &&
                            (option.isEligible || option.isSelected);
                        return CheckboxListTile(
                          value: isChecked,
                          onChanged: !isEnabled
                              ? null
                              : (value) {
                                  setSheetState(() {
                                    if (value == true) {
                                      selectedUserIds.add(option.userId);
                                    } else {
                                      selectedUserIds.remove(option.userId);
                                    }
                                  });
                                },
                          contentPadding: EdgeInsets.zero,
                          secondary: CircleAvatar(
                            radius: 20,
                            backgroundColor: AppTheme.primaryColor.withValues(
                              alpha: 0.12,
                            ),
                            backgroundImage:
                                (option.avatarUrl ?? '').trim().isNotEmpty
                                ? NetworkImage(option.avatarUrl!)
                                : null,
                            child: (option.avatarUrl ?? '').trim().isEmpty
                                ? Text(
                                    Formatters.inisial(option.displayName),
                                    style: AppTheme.caption.copyWith(
                                      fontWeight: FontWeight.w700,
                                      color: AppTheme.primaryColor,
                                    ),
                                  )
                                : null,
                          ),
                          title: Text(
                            option.displayName,
                            style: AppTheme.bodyMedium.copyWith(
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                          subtitle: Text(
                            option.subtitle,
                            style: AppTheme.caption.copyWith(
                              color: option.isEligible
                                  ? AppTheme.textSecondary
                                  : AppTheme.warningColor,
                            ),
                          ),
                        );
                      },
                    ),
                  ),
                  const SizedBox(height: 14),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => Navigator.of(
                        sheetContext,
                      ).pop(selectedUserIds.toList(growable: false)),
                      child: const Text('Simpan Anggota'),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      );
      if (!mounted || result == null) {
        return;
      }

      await service.updateOrgUnitConversationMembers(
        conversationId: conversation.id,
        userIds: result,
      );
      await _refreshConversationShell();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Anggota grup berhasil diperbarui')),
      );
    } catch (error) {
      if (mounted) {
        ErrorClassifier.showErrorSnackBar(context, error);
      }
    }
  }

  Future<void> _showConversationAvatarEditor() async {
    final conversation = _data?.conversation;
    if (conversation == null || conversation.isPrivate) {
      return;
    }

    try {
      PlatformFile? selectedAvatar;
      var removeAvatar = false;
      final result = await showModalBottomSheet<_ConversationAvatarEditResult>(
        context: context,
        isScrollControlled: true,
        showDragHandle: true,
        builder: (sheetContext) => StatefulBuilder(
          builder: (sheetContext, setSheetState) {
            final hasExistingAvatar =
                (conversation.avatarUrl ?? '').trim().isNotEmpty &&
                !removeAvatar &&
                selectedAvatar == null;
            final hasPendingChange = selectedAvatar != null || removeAvatar;
            Future<void> pickAvatar() async {
              try {
                final picked = await FilePicker.platform.pickFiles(
                  allowMultiple: false,
                  withData: true,
                  type: FileType.custom,
                  allowedExtensions: const ['jpg', 'jpeg', 'png', 'webp'],
                );
                if (picked == null || picked.files.isEmpty) {
                  return;
                }
                setSheetState(() {
                  selectedAvatar = picked.files.single;
                  removeAvatar = false;
                });
              } catch (error) {
                if (mounted) {
                  ErrorClassifier.showErrorSnackBar(context, error);
                }
              }
            }

            return SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Edit Avatar Grup', style: AppTheme.heading3),
                    const SizedBox(height: 8),
                    Text(
                      'Gunakan gambar persegi agar avatar tampil rapi di daftar chat.',
                      style: AppTheme.bodySmall.copyWith(
                        color: AppTheme.textSecondary,
                      ),
                    ),
                    const SizedBox(height: 18),
                    Center(
                      child: _ConversationAvatarPreview(
                        label: conversation.name,
                        imageUrl: hasExistingAvatar
                            ? conversation.avatarUrl
                            : null,
                        bytes: selectedAvatar?.bytes,
                        size: 88,
                      ),
                    ),
                    const SizedBox(height: 18),
                    SizedBox(
                      width: double.infinity,
                      child: OutlinedButton.icon(
                        onPressed: pickAvatar,
                        icon: const Icon(Icons.photo_camera_back_outlined),
                        label: Text(
                          selectedAvatar == null
                              ? 'Pilih Avatar'
                              : 'Ganti Avatar',
                        ),
                      ),
                    ),
                    if (selectedAvatar != null ||
                        (conversation.avatarUrl ?? '').trim().isNotEmpty)
                      SizedBox(
                        width: double.infinity,
                        child: TextButton.icon(
                          onPressed: () {
                            setSheetState(() {
                              selectedAvatar = null;
                              removeAvatar = (conversation.avatarUrl ?? '')
                                  .trim()
                                  .isNotEmpty;
                            });
                          },
                          icon: const Icon(Icons.delete_outline_rounded),
                          label: Text(
                            (conversation.avatarUrl ?? '').trim().isNotEmpty
                                ? 'Hapus Avatar Saat Ini'
                                : 'Kosongkan Pilihan',
                          ),
                        ),
                      ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      child: FilledButton(
                        onPressed: !hasPendingChange
                            ? null
                            : () => Navigator.of(sheetContext).pop(
                                _ConversationAvatarEditResult(
                                  avatar: selectedAvatar,
                                  removeAvatar: removeAvatar,
                                ),
                              ),
                        child: Text(
                          removeAvatar && selectedAvatar == null
                              ? 'Hapus Avatar'
                              : 'Simpan Avatar',
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            );
          },
        ),
      );
      if (!mounted || result == null) {
        return;
      }

      await ref
          .read(chatServiceProvider)
          .updateConversationAvatar(
            conversationId: conversation.id,
            avatar: result.avatar,
            removeAvatar: result.removeAvatar,
          );
      await _refreshConversationShell();
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Avatar grup berhasil diperbarui')),
      );
    } catch (error) {
      if (mounted) {
        ErrorClassifier.showErrorSnackBar(context, error);
      }
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_isDisposed || !_scrollController.hasClients) {
        return;
      }
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 220),
          curve: Curves.easeOut,
        );
      }
    });
  }

  @override
  void dispose() {
    _isDisposed = true;
    _messageCtrl.removeListener(_handleComposerChanged);
    _roomSearchCtrl.removeListener(_handleRoomSearchChanged);
    _presenceTimer?.cancel();
    _refreshDebounce?.cancel();
    _typingStopTimer?.cancel();
    unawaited(
      _chatService.setTypingState(
        conversationId: widget.conversationId,
        isTyping: false,
      ),
    );
    unawaited(_disposeRealtime());
    _roomSearchCtrl.dispose();
    _messageCtrl.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final conversation = _data?.conversation;
    final visibleMessages = _visibleMessages;
    final pinnedMessages = _pinnedMessages;
    final activePinnedMessage = pinnedMessages.isEmpty
        ? null
        : pinnedMessages.first;
    final showParticipantAvatars =
        conversation != null && !conversation.isPrivate;
    final roomAvatarUrl = _resolveRoomAvatarUrl(conversation);
    final roomHeaderBadgeLabel = _conversationHeaderBadgeLabel(conversation);

    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: false,
        toolbarHeight: 84,
        backgroundColor: Colors.transparent,
        shadowColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        titleSpacing: 0,
        flexibleSpace: Container(
          decoration: BoxDecoration(
            gradient: AppTheme.headerGradientFor(context),
            borderRadius: const BorderRadius.vertical(
              bottom: Radius.circular(28),
            ),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withValues(
                  alpha: AppTheme.isDark(context) ? 0.18 : 0.12,
                ),
                blurRadius: 18,
                offset: const Offset(0, 8),
              ),
            ],
          ),
        ),
        title: Row(
          children: [
            const SizedBox(width: 4),
            IconButton(
              tooltip: 'Kembali',
              onPressed: () => Navigator.of(context).maybePop(),
              icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
            ),
            if (conversation != null) ...[
              _RoomConversationAvatar(
                conversation: conversation,
                imageUrlOverride: roomAvatarUrl,
              ),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    conversation?.name ?? 'Chat',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTheme.bodyLarge.copyWith(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (conversation != null)
                    Text(
                      _conversationHeaderSubtitle(conversation),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTheme.caption.copyWith(
                        color: Colors.white.withValues(alpha: 0.82),
                      ),
                    ),
                ],
              ),
            ),
          ],
        ),
        actions: [
          if (conversation != null && roomHeaderBadgeLabel.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(right: 6),
              child: Center(
                child: _MessageSubscriptionBadge(
                  label: roomHeaderBadgeLabel,
                  planCode: conversation.participantPlanCode,
                  systemRole: conversation.participantSystemRole,
                ),
              ),
            ),
          if (conversation != null)
            PopupMenuButton<_RoomMenuAction>(
              tooltip: 'Opsi lainnya',
              onSelected: _handleRoomMenuAction,
              icon: const Icon(Icons.more_vert_rounded, color: Colors.white),
              itemBuilder: (context) {
                final items = <PopupMenuEntry<_RoomMenuAction>>[
                  PopupMenuItem(
                    value: _RoomMenuAction.toggleSearch,
                    child: _RoomMenuItemLabel(
                      icon: _isSearchMode
                          ? Icons.close_rounded
                          : Icons.search_rounded,
                      label: _isSearchMode ? 'Tutup pencarian' : 'Cari di chat',
                    ),
                  ),
                  const PopupMenuDivider(),
                  const PopupMenuItem(
                    value: _RoomMenuAction.media,
                    child: _RoomMenuItemLabel(
                      icon: Icons.perm_media_outlined,
                      label: 'Media, dokumen, dan link',
                    ),
                  ),
                  PopupMenuItem(
                    value: _RoomMenuAction.pin,
                    child: _RoomMenuItemLabel(
                      icon: conversation.isPinned
                          ? Icons.push_pin_rounded
                          : Icons.push_pin_outlined,
                      label: conversation.isPinned
                          ? 'Lepas pin chat'
                          : 'Pin chat',
                    ),
                  ),
                ];
                if ((conversation.orgUnitId ?? '').trim().isNotEmpty) {
                  items.add(const PopupMenuDivider());
                  items.add(
                    const PopupMenuItem(
                      value: _RoomMenuAction.manageMembers,
                      child: _RoomMenuItemLabel(
                        icon: Icons.group_add_outlined,
                        label: 'Kelola anggota grup',
                      ),
                    ),
                  );
                }
                if (!conversation.isPrivate) {
                  items.add(
                    const PopupMenuItem(
                      value: _RoomMenuAction.editAvatar,
                      child: _RoomMenuItemLabel(
                        icon: Icons.account_circle_outlined,
                        label: 'Edit avatar grup',
                      ),
                    ),
                  );
                }
                return items;
              },
            ),
          const SizedBox(width: 4),
        ],
      ),
      body: Stack(
        children: [
          Container(
            decoration: const BoxDecoration(
              gradient: LinearGradient(
                colors: [
                  AppTheme.extraLightGray,
                  AppTheme.bgWhite,
                  AppTheme.backgroundColor,
                ],
                begin: Alignment.topCenter,
                end: Alignment.bottomCenter,
              ),
            ),
          ),
          Positioned(
            top: -72,
            right: -36,
            child: Container(
              width: 180,
              height: 180,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.primaryColor.withValues(alpha: 0.06),
              ),
            ),
          ),
          Positioned(
            top: 120,
            left: -54,
            child: Container(
              width: 140,
              height: 140,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: AppTheme.accentColor.withValues(alpha: 0.05),
              ),
            ),
          ),
          Column(
            children: [
              if (_isSearchMode)
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 12, 14, 0),
                  child: _RoomSearchField(
                    controller: _roomSearchCtrl,
                    resultCount: visibleMessages.length,
                  ),
                ),
              if (activePinnedMessage != null &&
                  _roomSearchCtrl.text.trim().isEmpty)
                Padding(
                  padding: const EdgeInsets.fromLTRB(14, 10, 14, 0),
                  child: _PinnedMessageBanner(
                    message: activePinnedMessage,
                    pinnedCount: pinnedMessages.length,
                    preview: _pinnedMessagePreview(activePinnedMessage),
                  ),
                ),
              Expanded(
                child: _isLoading && _data == null
                    ? const Center(child: CircularProgressIndicator())
                    : _data == null || _data!.messages.isEmpty
                    ? Center(
                        child: AppTheme.glassContainer(
                          opacity: 0.72,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.chat_bubble_outline_rounded,
                                size: 40,
                                color: AppTheme.textSecondary,
                              ),
                              const SizedBox(height: 10),
                              Text('Belum ada pesan', style: AppTheme.heading3),
                              const SizedBox(height: 6),
                              Text(
                                'Mulai percakapan untuk mengaktifkan ruang chat ini.',
                                style: AppTheme.bodyMedium,
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      )
                    : visibleMessages.isEmpty
                    ? Center(
                        child: AppTheme.glassContainer(
                          opacity: 0.72,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Icon(
                                Icons.search_off_rounded,
                                size: 38,
                                color: AppTheme.textSecondary,
                              ),
                              const SizedBox(height: 10),
                              Text(
                                'Pesan tidak ditemukan',
                                style: AppTheme.heading3,
                              ),
                              const SizedBox(height: 6),
                              Text(
                                'Ubah kata kunci untuk melihat hasil lain di percakapan ini.',
                                style: AppTheme.bodyMedium,
                                textAlign: TextAlign.center,
                              ),
                            ],
                          ),
                        ),
                      )
                    : RefreshIndicator(
                        onRefresh: _loadMessages,
                        child: ListView.builder(
                          controller: _scrollController,
                          physics: const AlwaysScrollableScrollPhysics(),
                          padding: const EdgeInsets.fromLTRB(14, 10, 14, 14),
                          itemCount: visibleMessages.length,
                          itemBuilder: (context, index) {
                            final message = visibleMessages[index];
                            return _MessageBubble(
                              message: message,
                              roomAvatarUrl: roomAvatarUrl,
                              showPeerAvatar:
                                  showParticipantAvatars && !message.isMine,
                              showSenderContext:
                                  showParticipantAvatars && !message.isMine,
                              onOpenAttachment: message.hasAttachment
                                  ? () => _openAttachment(message)
                                  : null,
                              onShowActions: () => _showMessageActions(message),
                              onToggleReaction: (emoji) =>
                                  _toggleReaction(message, emoji),
                              onAddReaction: () => _showReactionPicker(message),
                              onVotePoll: message.isPoll
                                  ? (optionIds) => _votePoll(message, optionIds)
                                  : null,
                            );
                          },
                        ),
                      ),
              ),
              SafeArea(
                top: false,
                child: Container(
                  padding: const EdgeInsets.fromLTRB(12, 8, 12, 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.96),
                    borderRadius: const BorderRadius.vertical(
                      top: Radius.circular(24),
                    ),
                    border: Border(
                      top: BorderSide(
                        color: AppTheme.dividerColor.withValues(alpha: 0.8),
                      ),
                    ),
                    boxShadow: [
                      BoxShadow(
                        color: AppTheme.primaryColor.withValues(alpha: 0.05),
                        blurRadius: 18,
                        offset: const Offset(0, -4),
                      ),
                    ],
                  ),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      if (_replyingTo != null)
                        _ComposerHint(
                          icon: Icons.reply_rounded,
                          color: AppTheme.primaryColor,
                          title: 'Membalas ${_replyingTo!.senderName}',
                          subtitle: _replyingTo!.text.isNotEmpty
                              ? _replyingTo!.text
                              : (_replyingTo!.attachmentName ?? 'Lampiran'),
                          onClose: () => setState(() => _replyingTo = null),
                        ),
                      if (_editingMessage != null)
                        _ComposerHint(
                          icon: Icons.edit_outlined,
                          color: AppTheme.accentColor,
                          title: 'Mengedit pesan',
                          subtitle: _editingMessage!.text.isNotEmpty
                              ? _editingMessage!.text
                              : (_editingMessage!.attachmentName ?? 'Pesan'),
                          onClose: () {
                            _messageCtrl.clear();
                            setState(() => _editingMessage = null);
                          },
                        ),
                      if (_selectedAttachment != null)
                        _AttachmentDraftPreview(
                          attachment: _selectedAttachment!,
                          onClose: () =>
                              setState(() => _selectedAttachment = null),
                        ),
                      if (_mentionSuggestions.isNotEmpty)
                        _MentionSuggestionStrip(
                          participants: _mentionSuggestions,
                          onSelect: _insertMention,
                        ),
                      Row(
                        children: [
                          IconButton.filledTonal(
                            onPressed: _isSending || _editingMessage != null
                                ? null
                                : _showComposerActions,
                            style: IconButton.styleFrom(
                              backgroundColor: AppTheme.extraLightGray,
                              foregroundColor: AppTheme.primaryColor,
                              padding: const EdgeInsets.all(14),
                            ),
                            icon: const Icon(Icons.add_rounded),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: TextField(
                              controller: _messageCtrl,
                              minLines: 1,
                              maxLines: 3,
                              textInputAction: TextInputAction.send,
                              onSubmitted: (_) => _sendMessage(),
                              decoration: InputDecoration(
                                hintText: _editingMessage != null
                                    ? 'Perbarui pesan...'
                                    : _replyingTo != null
                                    ? 'Tulis balasan...'
                                    : _selectedAttachment != null
                                    ? 'Tambahkan caption...'
                                    : _canShowMentionSuggestions
                                    ? 'Tulis pesan... gunakan @ untuk mention'
                                    : 'Tulis pesan...',
                                filled: true,
                                fillColor: Colors.white,
                                border: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(20),
                                  borderSide: BorderSide(
                                    color: AppTheme.dividerColor.withValues(
                                      alpha: 0.8,
                                    ),
                                  ),
                                ),
                                enabledBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(20),
                                  borderSide: BorderSide(
                                    color: AppTheme.dividerColor.withValues(
                                      alpha: 0.8,
                                    ),
                                  ),
                                ),
                                focusedBorder: OutlineInputBorder(
                                  borderRadius: BorderRadius.circular(20),
                                  borderSide: const BorderSide(
                                    color: AppTheme.primaryColor,
                                    width: 1.2,
                                  ),
                                ),
                                contentPadding: const EdgeInsets.symmetric(
                                  horizontal: 16,
                                  vertical: 12,
                                ),
                              ),
                            ),
                          ),
                          const SizedBox(width: 8),
                          SizedBox(
                            width: 52,
                            height: 52,
                            child: FilledButton(
                              onPressed: _isSending ? null : _sendMessage,
                              style: FilledButton.styleFrom(
                                backgroundColor: AppTheme.primaryColor,
                                shape: const CircleBorder(),
                                padding: EdgeInsets.zero,
                              ),
                              child: _isSending
                                  ? const SizedBox(
                                      width: 18,
                                      height: 18,
                                      child: CircularProgressIndicator(
                                        strokeWidth: 2,
                                        color: Colors.white,
                                      ),
                                    )
                                  : Icon(
                                      _editingMessage != null
                                          ? Icons.check_rounded
                                          : Icons.send_rounded,
                                    ),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  bool get _canShowMentionSuggestions {
    final conversation = _data?.conversation;
    return conversation != null && !conversation.isPrivate;
  }

  List<MessageModel> get _visibleMessages {
    final messages = _data?.messages ?? const <MessageModel>[];
    final query = _roomSearchCtrl.text.trim().toLowerCase();
    if (query.isEmpty) {
      return messages;
    }
    return messages
        .where((message) {
          final haystack = [
            message.senderName,
            message.text,
            message.attachmentName ?? '',
            message.replySnippet ?? '',
          ].join(' ').toLowerCase();
          return haystack.contains(query);
        })
        .toList(growable: false);
  }

  List<ChatParticipantModel> get _otherParticipants =>
      (_data?.participants ?? const <ChatParticipantModel>[])
          .where((item) => !item.isCurrentUser)
          .toList(growable: false);

  String? get _activeMentionQuery {
    if (!_canShowMentionSuggestions) {
      return null;
    }
    final text = _messageCtrl.text;
    final selection = _messageCtrl.selection;
    final cursor = selection.baseOffset < 0
        ? text.length
        : selection.baseOffset;
    final prefix = text.substring(0, cursor);
    final match = RegExp(r'(?:^|\s)@([A-Za-z0-9_]*)$').firstMatch(prefix);
    return match?.group(1);
  }

  List<ChatParticipantModel> get _mentionSuggestions {
    final rawQuery = _activeMentionQuery;
    if (rawQuery == null) {
      return const <ChatParticipantModel>[];
    }
    final query = rawQuery.trim().toLowerCase();
    return _otherParticipants
        .where((participant) {
          final handle = _mentionHandleForName(
            participant.displayName,
          ).toLowerCase();
          final displayName = participant.displayName.toLowerCase();
          return query.isEmpty ||
              handle.contains(query) ||
              displayName.contains(query);
        })
        .take(5)
        .toList(growable: false);
  }

  void _insertMention(ChatParticipantModel participant) {
    final text = _messageCtrl.text;
    final selection = _messageCtrl.selection;
    final cursor = selection.baseOffset < 0
        ? text.length
        : selection.baseOffset;
    final prefix = text.substring(0, cursor);
    final suffix = text.substring(cursor);
    final match = RegExp(r'@([A-Za-z0-9_]*)$').firstMatch(prefix);
    if (match == null) {
      return;
    }

    final start = match.start;
    final replacement = '@${_mentionHandleForName(participant.displayName)} ';
    final nextText = '${prefix.substring(0, start)}$replacement$suffix';
    final nextCursor = prefix.substring(0, start).length + replacement.length;
    _messageCtrl.value = TextEditingValue(
      text: nextText,
      selection: TextSelection.collapsed(offset: nextCursor),
    );
  }

  String _conversationHeaderSubtitle(ConversationModel conversation) {
    final typingParticipants = _otherParticipants
        .where((item) => item.isTyping)
        .toList(growable: false);
    if (typingParticipants.isNotEmpty) {
      if (conversation.isPrivate) {
        return 'Sedang mengetik...';
      }
      if (typingParticipants.length == 1) {
        return '${typingParticipants.first.displayName} sedang mengetik...';
      }
      return '${typingParticipants.first.displayName} dan ${typingParticipants.length - 1} lainnya sedang mengetik...';
    }

    final onlineParticipants = _otherParticipants
        .where((item) => item.isOnline)
        .toList(growable: false);
    if (onlineParticipants.isNotEmpty) {
      return conversation.isPrivate
          ? 'Online'
          : '${onlineParticipants.length} anggota online';
    }

    final lastSeenEntries =
        _otherParticipants
            .map((item) => item.lastSeenAt)
            .whereType<DateTime>()
            .toList(growable: false)
          ..sort((left, right) => right.compareTo(left));
    if (lastSeenEntries.isNotEmpty) {
      final label = Formatters.tanggalRelatif(lastSeenEntries.first);
      return conversation.isPrivate
          ? 'Terakhir dilihat $label'
          : 'Terakhir aktif $label';
    }

    final lastSeenAt = conversation.lastMessageAt;
    if (lastSeenAt == null) {
      return 'Status kehadiran belum tersedia';
    }
    return 'Terakhir aktif ${Formatters.tanggalRelatif(lastSeenAt)}';
  }

  String _conversationHeaderBadgeLabel(ConversationModel? conversation) {
    if (conversation == null) {
      return '';
    }
    final explicit = (conversation.badgeLabel ?? '').trim();
    if (explicit.isNotEmpty) {
      return explicit;
    }
    if (!conversation.isPrivate) {
      return '';
    }
    final participantRole = AppConstants.roleFromSystemRolePlan(
      systemRole: conversation.participantSystemRole ?? '',
      planCode: conversation.participantPlanCode ?? '',
    );
    return AppConstants.roleLabel(participantRole);
  }

  String? _resolveRoomAvatarUrl(ConversationModel? conversation) {
    final explicit = (conversation?.avatarUrl ?? '').trim();
    if (explicit.isNotEmpty) {
      return explicit;
    }

    for (final message in _data?.messages ?? const <MessageModel>[]) {
      final avatarUrl = (message.senderAvatarUrl ?? '').trim();
      if (!message.isMine && avatarUrl.isNotEmpty) {
        return avatarUrl;
      }
    }
    return null;
  }

  List<MessageModel> get _pinnedMessages {
    final items =
        _data?.messages
            .where((message) => message.isPinned && !message.isDeleted)
            .toList(growable: false) ??
        const <MessageModel>[];
    final sorted = [...items];
    sorted.sort((left, right) {
      final leftTime = left.createdAt?.millisecondsSinceEpoch ?? 0;
      final rightTime = right.createdAt?.millisecondsSinceEpoch ?? 0;
      return rightTime.compareTo(leftTime);
    });
    return sorted;
  }

  String _pinnedMessagePreview(MessageModel message) {
    final text = message.text.trim();
    if (message.isPoll) {
      return text.isNotEmpty ? 'Polling: $text' : 'Polling dipin';
    }
    if (message.isVoice) {
      return 'Voice note dipin';
    }
    if (message.hasAttachment) {
      final attachmentName = (message.attachmentName ?? '').trim();
      if (text.isNotEmpty) {
        return text;
      }
      return attachmentName.isNotEmpty
          ? 'Lampiran: $attachmentName'
          : 'Lampiran dipin';
    }
    if (text.isNotEmpty) {
      return text;
    }
    return 'Pesan dipin';
  }
}

const List<_MessagePinDurationOption> _messagePinDurationOptions = [
  _MessagePinDurationOption(label: '24 jam', duration: Duration(hours: 24)),
  _MessagePinDurationOption(label: '7 hari', duration: Duration(days: 7)),
  _MessagePinDurationOption(label: '30 hari', duration: Duration(days: 30)),
];

class _MessagePinDurationOption {
  const _MessagePinDurationOption({
    required this.label,
    required this.duration,
  });

  final String label;
  final Duration duration;
}

class _ComposerHint extends StatelessWidget {
  const _ComposerHint({
    required this.icon,
    required this.color,
    required this.title,
    required this.subtitle,
    required this.onClose,
  });

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.extraLightGray,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.dividerColor.withValues(alpha: 0.7)),
      ),
      child: Row(
        children: [
          Icon(icon, color: color, size: 18),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: AppTheme.bodySmall.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                Text(
                  subtitle,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.caption,
                ),
              ],
            ),
          ),
          IconButton(onPressed: onClose, icon: const Icon(Icons.close_rounded)),
        ],
      ),
    );
  }
}

class _PinnedMessageBanner extends StatelessWidget {
  const _PinnedMessageBanner({
    required this.message,
    required this.pinnedCount,
    required this.preview,
  });

  final MessageModel message;
  final int pinnedCount;
  final String preview;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 11),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: AppTheme.dividerColor.withValues(alpha: 0.92),
        ),
        boxShadow: [
          BoxShadow(
            color: AppTheme.secondaryColor.withValues(alpha: 0.05),
            blurRadius: 14,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 4,
            height: 42,
            decoration: BoxDecoration(
              color: AppTheme.accentColor,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          const SizedBox(width: 12),
          Container(
            width: 34,
            height: 34,
            decoration: BoxDecoration(
              color: AppTheme.accentColor.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(
              Icons.push_pin_rounded,
              color: AppTheme.accentColor,
              size: 16,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        message.senderName,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTheme.bodyMedium.copyWith(
                          fontWeight: FontWeight.w800,
                          color: AppTheme.textPrimary,
                        ),
                      ),
                    ),
                    if (pinnedCount > 1)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 8,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: AppTheme.primaryColor.withValues(alpha: 0.08),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          '$pinnedCount pinned',
                          style: AppTheme.caption.copyWith(
                            color: AppTheme.primaryColor,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                  ],
                ),
                const SizedBox(height: 2),
                Text(
                  preview,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.caption.copyWith(
                    color: AppTheme.textSecondary,
                    height: 1.25,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AttachmentDraftPreview extends StatelessWidget {
  const _AttachmentDraftPreview({
    required this.attachment,
    required this.onClose,
  });

  final PlatformFile attachment;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    final isImage = _isImageFileName(attachment.name);
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: AppTheme.extraLightGray,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.dividerColor.withValues(alpha: 0.7)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (isImage && attachment.bytes != null)
            ClipRRect(
              borderRadius: BorderRadius.circular(12),
              child: Image.memory(
                attachment.bytes!,
                width: 64,
                height: 64,
                fit: BoxFit.cover,
              ),
            )
          else
            Container(
              width: 56,
              height: 56,
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: AppTheme.dividerColor),
              ),
              child: Icon(
                _fileIconForName(attachment.name),
                color: AppTheme.primaryColor,
              ),
            ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  isImage ? 'Preview lampiran gambar' : 'Lampiran siap dikirim',
                  style: AppTheme.bodySmall.copyWith(
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  attachment.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: AppTheme.bodyMedium.copyWith(
                    fontWeight: FontWeight.w600,
                  ),
                ),
                if (attachment.size > 0)
                  Text(
                    Formatters.fileSize(attachment.size),
                    style: AppTheme.caption,
                  ),
              ],
            ),
          ),
          IconButton(onPressed: onClose, icon: const Icon(Icons.close_rounded)),
        ],
      ),
    );
  }
}

class _RoomSearchField extends StatelessWidget {
  const _RoomSearchField({required this.controller, required this.resultCount});

  final TextEditingController controller;
  final int resultCount;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.96),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.dividerColor.withValues(alpha: 0.9)),
        boxShadow: [
          BoxShadow(
            color: AppTheme.secondaryColor.withValues(alpha: 0.04),
            blurRadius: 12,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.search_rounded, color: AppTheme.textSecondary),
          const SizedBox(width: 8),
          Expanded(
            child: TextField(
              controller: controller,
              decoration: const InputDecoration(
                hintText: 'Cari isi pesan, nama, atau lampiran...',
                border: InputBorder.none,
                isDense: true,
              ),
            ),
          ),
          Text(
            '$resultCount hasil',
            style: AppTheme.caption.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }
}

class _MentionSuggestionStrip extends StatelessWidget {
  const _MentionSuggestionStrip({
    required this.participants,
    required this.onSelect,
  });

  final List<ChatParticipantModel> participants;
  final ValueChanged<ChatParticipantModel> onSelect;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: AppTheme.extraLightGray,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.dividerColor.withValues(alpha: 0.7)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Mention anggota grup',
            style: AppTheme.bodySmall.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 8),
          SizedBox(
            height: 42,
            child: ListView.separated(
              scrollDirection: Axis.horizontal,
              itemCount: participants.length,
              separatorBuilder: (_, _) => const SizedBox(width: 8),
              itemBuilder: (context, index) {
                final participant = participants[index];
                return ActionChip(
                  avatar: _TinyParticipantAvatar(
                    imageUrl: participant.avatarUrl,
                    label: participant.displayName,
                  ),
                  label: Text(
                    '@${_mentionHandleForName(participant.displayName)}',
                    style: AppTheme.caption.copyWith(
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  onPressed: () => onSelect(participant),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _TinyParticipantAvatar extends StatelessWidget {
  const _TinyParticipantAvatar({required this.imageUrl, required this.label});

  final String? imageUrl;
  final String label;

  @override
  Widget build(BuildContext context) {
    final resolvedImageUrl = (imageUrl ?? '').trim();
    if (resolvedImageUrl.isEmpty) {
      return CircleAvatar(
        radius: 10,
        backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.12),
        child: Text(
          Formatters.inisial(label),
          style: AppTheme.caption.copyWith(
            fontWeight: FontWeight.w700,
            color: AppTheme.primaryColor,
            fontSize: 9,
          ),
        ),
      );
    }
    return CircleAvatar(
      radius: 10,
      backgroundImage: NetworkImage(resolvedImageUrl),
    );
  }
}

class _MessageAttachmentPreview extends StatelessWidget {
  const _MessageAttachmentPreview({
    required this.message,
    required this.isMine,
    required this.textColor,
    required this.bottomSpacing,
    this.onOpenAttachment,
  });

  final MessageModel message;
  final bool isMine;
  final Color textColor;
  final double bottomSpacing;
  final VoidCallback? onOpenAttachment;

  @override
  Widget build(BuildContext context) {
    final attachmentName = message.attachmentName ?? 'Lampiran';
    final isImage = _isImageFileName(attachmentName);

    return InkWell(
      onTap: onOpenAttachment,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: EdgeInsets.only(bottom: bottomSpacing),
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: isMine
              ? Colors.white.withValues(alpha: 0.14)
              : AppTheme.extraLightGray,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (isImage && (message.attachmentUrl ?? '').isNotEmpty)
              ClipRRect(
                borderRadius: BorderRadius.circular(12),
                child: AspectRatio(
                  aspectRatio: 16 / 10,
                  child: Image.network(
                    message.attachmentUrl!,
                    fit: BoxFit.cover,
                    errorBuilder: (context, error, stackTrace) =>
                        _FileFallbackTile(
                          attachmentName: attachmentName,
                          textColor: textColor,
                          isMine: isMine,
                        ),
                    loadingBuilder: (context, child, progress) {
                      if (progress == null) return child;
                      return Container(
                        color: Colors.black.withValues(alpha: 0.04),
                        alignment: Alignment.center,
                        child: const CircularProgressIndicator(strokeWidth: 2),
                      );
                    },
                  ),
                ),
              )
            else
              _FileFallbackTile(
                attachmentName: attachmentName,
                textColor: textColor,
                isMine: isMine,
              ),
            const SizedBox(height: 8),
            Row(
              children: [
                Icon(
                  isImage
                      ? Icons.image_outlined
                      : _fileIconForName(attachmentName),
                  size: 16,
                  color: textColor,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    attachmentName,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: AppTheme.bodySmall.copyWith(
                      color: textColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                Text(
                  'Buka',
                  style: AppTheme.caption.copyWith(
                    color: textColor.withValues(alpha: 0.88),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _FileFallbackTile extends StatelessWidget {
  const _FileFallbackTile({
    required this.attachmentName,
    required this.textColor,
    required this.isMine,
  });

  final String attachmentName;
  final Color textColor;
  final bool isMine;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 82,
      decoration: BoxDecoration(
        color: isMine
            ? Colors.white.withValues(alpha: 0.08)
            : Colors.white.withValues(alpha: 0.74),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isMine
              ? Colors.white.withValues(alpha: 0.12)
              : AppTheme.dividerColor,
        ),
      ),
      padding: const EdgeInsets.all(12),
      child: Row(
        children: [
          Container(
            width: 42,
            height: 42,
            decoration: BoxDecoration(
              color: isMine
                  ? Colors.white.withValues(alpha: 0.14)
                  : AppTheme.primaryColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(_fileIconForName(attachmentName), color: textColor),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              attachmentName,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: AppTheme.bodyMedium.copyWith(
                color: textColor,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _LinkifiedText extends StatelessWidget {
  const _LinkifiedText({required this.text, required this.style});

  final String text;
  final TextStyle style;

  @override
  Widget build(BuildContext context) {
    final matches = _linkOrMentionRegex
        .allMatches(text)
        .toList(growable: false);
    if (matches.isEmpty) {
      return Text(text, style: style);
    }

    final spans = <InlineSpan>[];
    var start = 0;
    for (final match in matches) {
      if (match.start > start) {
        spans.add(
          TextSpan(text: text.substring(start, match.start), style: style),
        );
      }
      final token = text.substring(match.start, match.end);
      final isUrl = _urlRegex.hasMatch(token);
      spans.add(
        TextSpan(
          text: token,
          style: style.copyWith(
            color: isUrl
                ? style.color == Colors.white
                      ? Colors.white
                      : AppTheme.primaryColor
                : AppTheme.errorColor,
            decoration: isUrl ? TextDecoration.underline : TextDecoration.none,
            fontWeight: FontWeight.w600,
          ),
          recognizer: isUrl
              ? (TapGestureRecognizer()
                  ..onTap = () {
                    _launchDetectedUrl(token);
                  })
              : null,
        ),
      );
      start = match.end;
    }
    if (start < text.length) {
      spans.add(TextSpan(text: text.substring(start), style: style));
    }

    return RichText(text: TextSpan(children: spans));
  }
}

class _VoiceMessageCard extends StatelessWidget {
  const _VoiceMessageCard({
    required this.message,
    required this.isMine,
    required this.textColor,
    this.onOpenAttachment,
  });

  final MessageModel message;
  final bool isMine;
  final Color textColor;
  final VoidCallback? onOpenAttachment;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onOpenAttachment,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        padding: const EdgeInsets.all(12),
        decoration: BoxDecoration(
          color: isMine
              ? Colors.white.withValues(alpha: 0.14)
              : AppTheme.extraLightGray,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Row(
          children: [
            Container(
              width: 42,
              height: 42,
              decoration: BoxDecoration(
                color: isMine
                    ? Colors.white.withValues(alpha: 0.16)
                    : AppTheme.primaryColor.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.mic_rounded, color: textColor),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Voice note',
                    style: AppTheme.bodySmall.copyWith(
                      color: textColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    _formatDuration(message.voiceDurationSeconds ?? 0),
                    style: AppTheme.caption.copyWith(
                      color: textColor.withValues(alpha: 0.86),
                    ),
                  ),
                ],
              ),
            ),
            Text(
              'Buka',
              style: AppTheme.caption.copyWith(
                color: textColor,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _PollMessageCard extends StatelessWidget {
  const _PollMessageCard({
    required this.message,
    required this.isMine,
    required this.textColor,
    this.onVote,
  });

  final MessageModel message;
  final bool isMine;
  final Color textColor;
  final Future<void> Function(List<String> optionIds)? onVote;

  @override
  Widget build(BuildContext context) {
    final poll = message.poll;
    if (poll == null) {
      return const SizedBox.shrink();
    }
    final totalVotes = poll.options.fold<int>(
      0,
      (sum, option) => sum + option.voteCount,
    );

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isMine
            ? Colors.white.withValues(alpha: 0.14)
            : AppTheme.extraLightGray,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(Icons.poll_rounded, color: textColor, size: 18),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  poll.title,
                  style: AppTheme.bodyMedium.copyWith(
                    color: textColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            poll.isOpen
                ? poll.allowMultipleChoice
                      ? 'Polling aktif - multi-pilihan'
                      : 'Polling aktif - satu pilihan'
                : 'Polling ditutup',
            style: AppTheme.caption.copyWith(
              color: textColor.withValues(alpha: 0.84),
            ),
          ),
          const SizedBox(height: 10),
          for (final option in poll.options) ...[
            _PollOptionTile(
              option: option,
              isMine: isMine,
              textColor: textColor,
              totalVotes: totalVotes,
              onTap: !poll.isOpen || onVote == null
                  ? null
                  : () => _handleVote(context, poll, option.id),
            ),
            const SizedBox(height: 8),
          ],
          Text(
            '$totalVotes suara',
            style: AppTheme.caption.copyWith(
              color: textColor.withValues(alpha: 0.84),
            ),
          ),
        ],
      ),
    );
  }

  Future<void> _handleVote(
    BuildContext context,
    ChatPollModel poll,
    String optionId,
  ) async {
    if (onVote == null) {
      return;
    }
    if (!poll.allowMultipleChoice) {
      await onVote!([optionId]);
      return;
    }

    final selected = {
      ...poll.options.where((item) => item.isSelected).map((e) => e.id),
    };
    final result = await showModalBottomSheet<List<String>>(
      context: context,
      showDragHandle: true,
      builder: (sheetContext) => StatefulBuilder(
        builder: (sheetContext, setSheetState) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 18),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('Pilih Opsi', style: AppTheme.heading3),
                const SizedBox(height: 12),
                for (final option in poll.options)
                  CheckboxListTile(
                    value: selected.contains(option.id),
                    contentPadding: EdgeInsets.zero,
                    title: Text(option.label),
                    onChanged: (value) {
                      setSheetState(() {
                        if (value == true) {
                          selected.add(option.id);
                        } else {
                          selected.remove(option.id);
                        }
                      });
                    },
                  ),
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: FilledButton(
                    onPressed: () => Navigator.of(
                      sheetContext,
                    ).pop(selected.toList(growable: false)),
                    child: const Text('Kirim Pilihan'),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );

    if (result == null || result.isEmpty) {
      return;
    }
    await onVote!(result);
  }
}

class _PollOptionTile extends StatelessWidget {
  const _PollOptionTile({
    required this.option,
    required this.isMine,
    required this.textColor,
    required this.totalVotes,
    this.onTap,
  });

  final ChatPollOptionModel option;
  final bool isMine;
  final Color textColor;
  final int totalVotes;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final progress = totalVotes == 0 ? 0.0 : option.voteCount / totalVotes;
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(12),
      child: Container(
        padding: const EdgeInsets.all(10),
        decoration: BoxDecoration(
          color: option.isSelected
              ? (isMine
                    ? Colors.white.withValues(alpha: 0.18)
                    : AppTheme.primaryColor.withValues(alpha: 0.08))
              : (isMine
                    ? Colors.white.withValues(alpha: 0.08)
                    : Colors.white.withValues(alpha: 0.78)),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: option.isSelected
                ? (isMine ? Colors.white : AppTheme.primaryColor)
                : Colors.transparent,
          ),
        ),
        child: Column(
          children: [
            Row(
              children: [
                Icon(
                  option.isSelected
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked_rounded,
                  size: 18,
                  color: textColor,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    option.label,
                    style: AppTheme.bodySmall.copyWith(
                      color: textColor,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
                Text(
                  '${option.voteCount}',
                  style: AppTheme.caption.copyWith(
                    color: textColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(999),
              child: LinearProgressIndicator(
                value: progress,
                minHeight: 6,
                backgroundColor: isMine
                    ? Colors.white.withValues(alpha: 0.12)
                    : AppTheme.extraLightGray,
                valueColor: AlwaysStoppedAnimation<Color>(
                  isMine ? Colors.white : AppTheme.primaryColor,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    required this.onShowActions,
    required this.roomAvatarUrl,
    required this.showPeerAvatar,
    required this.showSenderContext,
    this.onOpenAttachment,
    this.onToggleReaction,
    this.onAddReaction,
    this.onVotePoll,
  });

  final MessageModel message;
  final VoidCallback onShowActions;
  final String? roomAvatarUrl;
  final bool showPeerAvatar;
  final bool showSenderContext;
  final VoidCallback? onOpenAttachment;
  final ValueChanged<String>? onToggleReaction;
  final VoidCallback? onAddReaction;
  final Future<void> Function(List<String> optionIds)? onVotePoll;

  @override
  Widget build(BuildContext context) {
    final isMine = message.isMine;
    final bubbleTextColor = isMine ? Colors.white : AppTheme.textPrimary;
    final metaColor = isMine
        ? Colors.white.withValues(alpha: 0.82)
        : AppTheme.textSecondary;
    final badgeLabel = _messageBadgeLabel(message);
    final sentAtLabel = message.createdAt != null
        ? Formatters.waktu(message.createdAt!)
        : '';
    final showHeaderRow = showSenderContext && !isMine;
    final reactionLeftInset = !isMine && showPeerAvatar ? 44.0 : 0.0;
    final bubble = GestureDetector(
      onLongPress: onShowActions,
      child: Container(
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        padding: const EdgeInsets.fromLTRB(12, 10, 12, 9),
        decoration: BoxDecoration(
          color: isMine ? AppTheme.primaryColor : Colors.white,
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(18),
            topRight: const Radius.circular(18),
            bottomLeft: Radius.circular(isMine ? 18 : 6),
            bottomRight: Radius.circular(isMine ? 6 : 18),
          ),
          border: Border.all(
            color: isMine
                ? AppTheme.primaryDark.withValues(alpha: 0.35)
                : AppTheme.dividerColor.withValues(alpha: 0.9),
          ),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: isMine ? 0.08 : 0.035),
              blurRadius: 10,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (showHeaderRow) ...[
              Row(
                children: [
                  Expanded(
                    child: Text(
                      message.senderName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTheme.caption.copyWith(
                        color: AppTheme.primaryColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                  if (badgeLabel.isNotEmpty) ...[
                    const SizedBox(width: 6),
                    _MessageSubscriptionBadge(
                      label: badgeLabel,
                      planCode: message.senderPlanCode,
                      systemRole: message.senderSystemRole,
                    ),
                  ],
                  const SizedBox(width: 2),
                  GestureDetector(
                    onTap: onShowActions,
                    child: const Icon(
                      Icons.expand_more_rounded,
                      size: 16,
                      color: AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 3),
            ] else
              Align(
                alignment: Alignment.centerRight,
                child: GestureDetector(
                  onTap: onShowActions,
                  child: Icon(
                    Icons.expand_more_rounded,
                    size: 16,
                    color: isMine
                        ? Colors.white.withValues(alpha: 0.84)
                        : AppTheme.textSecondary,
                  ),
                ),
              ),
            if (message.isForwarded) ...[
              Text(
                'Diteruskan${(message.forwardedFromName ?? '').isNotEmpty ? ' dari ${message.forwardedFromName}' : ''}',
                style: AppTheme.caption.copyWith(
                  color: isMine
                      ? Colors.white.withValues(alpha: 0.82)
                      : AppTheme.textSecondary,
                  fontStyle: FontStyle.italic,
                ),
              ),
              const SizedBox(height: 4),
            ],
            if (message.hasReply)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 8,
                ),
                decoration: BoxDecoration(
                  color: isMine
                      ? Colors.white.withValues(alpha: 0.14)
                      : AppTheme.extraLightGray,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      message.replySenderName ?? 'Pesan sebelumnya',
                      style: AppTheme.caption.copyWith(
                        color: isMine ? Colors.white : AppTheme.primaryColor,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      message.replySnippet ?? 'Pesan',
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: AppTheme.caption.copyWith(
                        color: isMine
                            ? Colors.white.withValues(alpha: 0.88)
                            : AppTheme.textSecondary,
                      ),
                    ),
                  ],
                ),
              ),
            if (message.isDeleted)
              Text(
                'Pesan dihapus',
                style: AppTheme.bodyMedium.copyWith(
                  color: bubbleTextColor.withValues(alpha: 0.88),
                  fontStyle: FontStyle.italic,
                ),
              )
            else ...[
              if (message.isPoll && message.poll != null)
                _PollMessageCard(
                  message: message,
                  isMine: isMine,
                  textColor: bubbleTextColor,
                  onVote: onVotePoll,
                )
              else if (message.isVoice)
                _VoiceMessageCard(
                  message: message,
                  isMine: isMine,
                  textColor: bubbleTextColor,
                  onOpenAttachment: onOpenAttachment,
                )
              else if (message.hasAttachment)
                _MessageAttachmentPreview(
                  message: message,
                  isMine: isMine,
                  onOpenAttachment: onOpenAttachment,
                  textColor: bubbleTextColor,
                  bottomSpacing: message.text.isEmpty ? 0 : 8,
                ),
              if (message.text.isNotEmpty && !message.isPoll)
                _LinkifiedText(
                  text: message.text,
                  style: AppTheme.bodyMedium.copyWith(
                    color: bubbleTextColor,
                    height: 1.35,
                  ),
                ),
              if (!message.isDeleted &&
                  (message.isEdited ||
                      sentAtLabel.isNotEmpty ||
                      (isMine && (message.deliveryStatus ?? '').isNotEmpty) ||
                      message.isStarred ||
                      message.isPinned)) ...[
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.end,
                  children: [
                    if (message.isEdited)
                      Text(
                        'Diedit',
                        style: AppTheme.caption.copyWith(
                          color: metaColor,
                          fontStyle: FontStyle.italic,
                        ),
                      ),
                    if (message.isEdited) const SizedBox(width: 8),
                    if (sentAtLabel.isNotEmpty)
                      Text(
                        sentAtLabel,
                        style: AppTheme.caption.copyWith(color: metaColor),
                      ),
                    if (sentAtLabel.isNotEmpty &&
                        (message.isStarred ||
                            message.isPinned ||
                            (isMine &&
                                (message.deliveryStatus ?? '').isNotEmpty)))
                      const SizedBox(width: 8),
                    if (message.isStarred)
                      Icon(Icons.star_rounded, size: 14, color: metaColor),
                    if (message.isStarred &&
                        (message.isPinned ||
                            (isMine &&
                                (message.deliveryStatus ?? '').isNotEmpty)))
                      const SizedBox(width: 6),
                    if (message.isPinned)
                      Icon(Icons.push_pin_rounded, size: 14, color: metaColor),
                    if (message.isPinned &&
                        isMine &&
                        (message.deliveryStatus ?? '').isNotEmpty)
                      const SizedBox(width: 6),
                    if (isMine && (message.deliveryStatus ?? '').isNotEmpty)
                      _MessageDeliveryStatus(
                        status: message.deliveryStatus ?? 'sent',
                        color: metaColor,
                        deliveredCount: message.deliveredCount,
                        readCount: message.readCount,
                        recipientCount: message.recipientCount,
                      ),
                  ],
                ),
              ],
            ],
          ],
        ),
      ),
    );

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Padding(
        padding: const EdgeInsets.only(bottom: 8),
        child: Column(
          crossAxisAlignment: isMine
              ? CrossAxisAlignment.end
              : CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: isMine
                  ? MainAxisAlignment.end
                  : MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                if (!isMine && showPeerAvatar) ...[
                  _ChatParticipantAvatar(
                    imageUrl: message.senderAvatarUrl ?? roomAvatarUrl,
                    label: message.senderName,
                  ),
                  const SizedBox(width: 8),
                ],
                bubble,
              ],
            ),
            if (message.hasReactions)
              Padding(
                padding: EdgeInsets.only(
                  top: 4,
                  left: reactionLeftInset,
                  right: 0,
                ),
                child: Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  alignment: isMine ? WrapAlignment.end : WrapAlignment.start,
                  children: [
                    for (final reaction in message.reactions)
                      _ReactionCountChip(
                        reaction: reaction,
                        onTap: onToggleReaction == null
                            ? null
                            : () => onToggleReaction!(reaction.emoji),
                      ),
                    if (onAddReaction != null)
                      _AddReactionChip(onTap: onAddReaction!),
                  ],
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _MessageDeliveryStatus extends StatelessWidget {
  const _MessageDeliveryStatus({
    required this.status,
    required this.color,
    required this.deliveredCount,
    required this.readCount,
    required this.recipientCount,
  });

  final String status;
  final Color color;
  final int deliveredCount;
  final int readCount;
  final int recipientCount;

  @override
  Widget build(BuildContext context) {
    final safeStatus = status.trim().toLowerCase();
    IconData icon;
    String? ratioLabel;
    final iconColor = safeStatus == 'read' ? AppTheme.accentColor : color;

    switch (safeStatus) {
      case 'read':
        icon = Icons.done_all_rounded;
        ratioLabel = recipientCount > 1 ? '$readCount/$recipientCount' : null;
        break;
      case 'delivered':
        icon = Icons.done_all_rounded;
        ratioLabel = recipientCount > 1
            ? '$deliveredCount/$recipientCount'
            : null;
        break;
      default:
        icon = Icons.done_rounded;
        ratioLabel = null;
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, size: 14, color: iconColor),
        if (ratioLabel != null) ...[
          const SizedBox(width: 4),
          Text(
            ratioLabel,
            style: AppTheme.caption.copyWith(
              color: color,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ],
    );
  }
}

class _ReactionCountChip extends StatelessWidget {
  const _ReactionCountChip({required this.reaction, this.onTap});

  final MessageReactionModel reaction;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: reaction.reactedByMe
              ? AppTheme.primaryColor.withValues(alpha: 0.12)
              : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: reaction.reactedByMe
                ? AppTheme.primaryColor.withValues(alpha: 0.4)
                : AppTheme.dividerColor,
          ),
        ),
        child: Text(
          '${reaction.emoji} ${reaction.count}',
          style: AppTheme.caption.copyWith(
            fontWeight: FontWeight.w700,
            color: reaction.reactedByMe
                ? AppTheme.primaryColor
                : AppTheme.textPrimary,
          ),
        ),
      ),
    );
  }
}

class _AddReactionChip extends StatelessWidget {
  const _AddReactionChip({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
        decoration: BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: AppTheme.dividerColor),
        ),
        child: const Icon(
          Icons.add_reaction_outlined,
          size: 14,
          color: AppTheme.textSecondary,
        ),
      ),
    );
  }
}

class _QuickReactionChip extends StatelessWidget {
  const _QuickReactionChip({
    required this.emoji,
    required this.selected,
    required this.onTap,
  });

  final String emoji;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(999),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: selected
              ? AppTheme.primaryColor.withValues(alpha: 0.12)
              : Colors.white,
          borderRadius: BorderRadius.circular(999),
          border: Border.all(
            color: selected
                ? AppTheme.primaryColor.withValues(alpha: 0.4)
                : AppTheme.dividerColor,
          ),
        ),
        child: Text(emoji, style: const TextStyle(fontSize: 22)),
      ),
    );
  }
}

String _messageBadgeLabel(MessageModel message) {
  final explicit = (message.senderBadgeLabel ?? '').trim();
  if (explicit.isNotEmpty) {
    return explicit;
  }

  final systemRole = AppConstants.normalizeSystemRole(
    message.senderSystemRole ?? '',
  );
  if (systemRole == AppConstants.systemRoleSysadmin) {
    return 'Sysadmin';
  }
  if (systemRole == AppConstants.systemRoleWarga) {
    return 'Warga';
  }

  final planCode = AppConstants.normalizePlanCode(message.senderPlanCode ?? '');
  switch (planCode) {
    case AppConstants.planRwPro:
      return 'Admin RW Pro';
    case AppConstants.planRw:
      return 'Admin RW';
    case AppConstants.planRt:
      return 'Admin RT';
    default:
      return AppConstants.planCodeLabel(planCode);
  }
}

class _MessageSubscriptionBadge extends StatelessWidget {
  const _MessageSubscriptionBadge({
    required this.label,
    required this.planCode,
    required this.systemRole,
  });

  final String label;
  final String? planCode;
  final String? systemRole;

  @override
  Widget build(BuildContext context) {
    final normalizedSystemRole = AppConstants.normalizeSystemRole(
      systemRole ?? '',
    );
    final normalizedPlanCode = AppConstants.normalizePlanCode(planCode ?? '');

    Color foreground;
    List<Color> background;

    if (normalizedSystemRole == AppConstants.systemRoleSysadmin) {
      foreground = Colors.white;
      background = [AppTheme.secondaryColor, AppTheme.primaryDark];
    } else {
      switch (normalizedPlanCode) {
        case AppConstants.planRwPro:
          foreground = AppTheme.primaryDark;
          background = [AppTheme.warningColor, AppTheme.bgWhite];
          break;
        case AppConstants.planRw:
          foreground = Colors.white;
          background = [AppTheme.errorColor, AppTheme.primaryColor];
          break;
        case AppConstants.planRt:
          foreground = Colors.white;
          background = [AppTheme.textSecondary, AppTheme.secondaryColor];
          break;
        default:
          foreground = AppTheme.textSecondary;
          background = [AppTheme.bgLighter, AppTheme.bgWhite];
      }
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        gradient: LinearGradient(colors: background),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: AppTheme.caption.copyWith(
          color: foreground,
          fontWeight: FontWeight.w800,
          fontSize: 10,
        ),
      ),
    );
  }
}

class _ChatParticipantAvatar extends StatelessWidget {
  const _ChatParticipantAvatar({required this.imageUrl, required this.label});

  final String? imageUrl;
  final String label;

  @override
  Widget build(BuildContext context) {
    final safeLabel = label.trim().isEmpty ? '?' : label.trim();
    final normalizedUrl = (imageUrl ?? '').trim();
    return Container(
      width: 32,
      height: 32,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: AppTheme.dividerColor.withValues(alpha: 0.9)),
      ),
      child: ClipOval(
        child: normalizedUrl.isNotEmpty
            ? Image.network(
                normalizedUrl,
                width: 32,
                height: 32,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => _RoomAvatarFallback(
                  label: safeLabel,
                  size: 32,
                  textColor: AppTheme.primaryColor,
                  backgroundColor: AppTheme.primaryColor.withValues(
                    alpha: 0.12,
                  ),
                ),
              )
            : _RoomAvatarFallback(
                label: safeLabel,
                size: 32,
                textColor: AppTheme.primaryColor,
                backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.12),
              ),
      ),
    );
  }
}

class _RoomConversationAvatar extends StatelessWidget {
  const _RoomConversationAvatar({
    required this.conversation,
    this.imageUrlOverride,
  });

  final ConversationModel conversation;
  final String? imageUrlOverride;

  @override
  Widget build(BuildContext context) {
    final resolvedImageUrl = (imageUrlOverride ?? conversation.avatarUrl ?? '')
        .trim();

    if (conversation.isPrivate || resolvedImageUrl.isNotEmpty) {
      return Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
        ),
        child: ClipOval(
          child: resolvedImageUrl.isNotEmpty
              ? Image.network(
                  resolvedImageUrl,
                  width: 42,
                  height: 42,
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => _RoomAvatarFallback(
                    label: conversation.name,
                    size: 42,
                    textColor: Colors.white,
                    backgroundColor: Colors.white.withValues(alpha: 0.16),
                  ),
                )
              : _RoomAvatarFallback(
                  label: conversation.name,
                  size: 42,
                  textColor: Colors.white,
                  backgroundColor: Colors.white.withValues(alpha: 0.16),
                ),
        ),
      );
    }

    return Container(
      width: 42,
      height: 42,
      decoration: BoxDecoration(
        gradient: conversation.isGroupRt
            ? const LinearGradient(
                colors: [AppTheme.secondaryColor, AppTheme.primaryColor],
              )
            : const LinearGradient(
                colors: [AppTheme.accentColor, AppTheme.primaryLight],
              ),
        shape: BoxShape.circle,
      ),
      child: Icon(
        conversation.isGroupRt ? Icons.groups_rounded : Icons.hub_rounded,
        color: Colors.white,
        size: 20,
      ),
    );
  }
}

class _RoomMenuItemLabel extends StatelessWidget {
  const _RoomMenuItemLabel({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 20, color: AppTheme.textPrimary),
        const SizedBox(width: 10),
        Expanded(child: Text(label, style: AppTheme.bodyMedium)),
      ],
    );
  }
}

class _ConversationAvatarPreview extends StatelessWidget {
  const _ConversationAvatarPreview({
    required this.label,
    required this.imageUrl,
    required this.bytes,
    required this.size,
  });

  final String label;
  final String? imageUrl;
  final Uint8List? bytes;
  final double size;

  @override
  Widget build(BuildContext context) {
    final resolvedImageUrl = (imageUrl ?? '').trim();
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        border: Border.all(color: AppTheme.dividerColor),
      ),
      child: ClipOval(
        child: bytes != null
            ? Image.memory(bytes!, width: size, height: size, fit: BoxFit.cover)
            : resolvedImageUrl.isNotEmpty
            ? Image.network(
                resolvedImageUrl,
                width: size,
                height: size,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => _RoomAvatarFallback(
                  label: label,
                  size: size,
                  textColor: AppTheme.primaryColor,
                  backgroundColor: AppTheme.primaryColor.withValues(
                    alpha: 0.12,
                  ),
                ),
              )
            : _RoomAvatarFallback(
                label: label,
                size: size,
                textColor: AppTheme.primaryColor,
                backgroundColor: AppTheme.primaryColor.withValues(alpha: 0.12),
              ),
      ),
    );
  }
}

class _ConversationAvatarEditResult {
  const _ConversationAvatarEditResult({
    required this.avatar,
    required this.removeAvatar,
  });

  final PlatformFile? avatar;
  final bool removeAvatar;
}

class _RoomAvatarFallback extends StatelessWidget {
  const _RoomAvatarFallback({
    required this.label,
    required this.size,
    required this.textColor,
    required this.backgroundColor,
  });

  final String label;
  final double size;
  final Color textColor;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      color: backgroundColor,
      alignment: Alignment.center,
      child: Text(
        Formatters.inisial(label),
        style: AppTheme.caption.copyWith(
          color: textColor,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _MessageActionTile extends StatelessWidget {
  const _MessageActionTile({
    required this.icon,
    required this.label,
    required this.onTap,
    this.isDestructive = false,
  });

  final IconData icon;
  final String label;
  final VoidCallback onTap;
  final bool isDestructive;

  @override
  Widget build(BuildContext context) {
    final color = isDestructive ? Colors.red.shade700 : AppTheme.textPrimary;
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      leading: Icon(icon, color: color),
      title: Text(label, style: AppTheme.bodyMedium.copyWith(color: color)),
      onTap: onTap,
    );
  }
}

class _ConversationMediaTab extends StatelessWidget {
  const _ConversationMediaTab({
    required this.messages,
    required this.onOpenMessageAttachment,
  });

  final List<MessageModel> messages;
  final Future<void> Function(MessageModel) onOpenMessageAttachment;

  @override
  Widget build(BuildContext context) {
    if (messages.isEmpty) {
      return const _ConversationAssetEmptyState(
        icon: Icons.photo_library_outlined,
        title: 'Belum ada media',
        subtitle: 'Foto dan gambar dari percakapan ini akan muncul di sini.',
      );
    }

    return GridView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: messages.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 3,
        crossAxisSpacing: 8,
        mainAxisSpacing: 8,
      ),
      itemBuilder: (context, index) {
        final message = messages[index];
        return InkWell(
          onTap: () => onOpenMessageAttachment(message),
          borderRadius: BorderRadius.circular(14),
          child: ClipRRect(
            borderRadius: BorderRadius.circular(14),
            child: Stack(
              fit: StackFit.expand,
              children: [
                Image.network(
                  message.attachmentUrl ?? '',
                  fit: BoxFit.cover,
                  errorBuilder: (_, _, _) => Container(
                    color: AppTheme.extraLightGray,
                    alignment: Alignment.center,
                    child: const Icon(Icons.broken_image_outlined),
                  ),
                ),
                Positioned(
                  left: 6,
                  right: 6,
                  bottom: 6,
                  child: Container(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 6,
                      vertical: 4,
                    ),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.55),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: Text(
                      message.senderName,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: AppTheme.caption.copyWith(
                        color: Colors.white,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        );
      },
    );
  }
}

class _ConversationDocumentTab extends StatelessWidget {
  const _ConversationDocumentTab({
    required this.messages,
    required this.onOpenMessageAttachment,
  });

  final List<MessageModel> messages;
  final Future<void> Function(MessageModel) onOpenMessageAttachment;

  @override
  Widget build(BuildContext context) {
    if (messages.isEmpty) {
      return const _ConversationAssetEmptyState(
        icon: Icons.description_outlined,
        title: 'Belum ada dokumen',
        subtitle: 'File non-gambar dari percakapan ini akan muncul di sini.',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: messages.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final message = messages[index];
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 8,
          ),
          tileColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: AppTheme.dividerColor),
          ),
          leading: Icon(
            _fileIconForName(message.attachmentName ?? ''),
            color: AppTheme.primaryColor,
          ),
          title: Text(
            message.attachmentName ?? 'Lampiran',
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTheme.bodyMedium.copyWith(fontWeight: FontWeight.w700),
          ),
          subtitle: Text(
            '${message.senderName} - ${message.createdAt != null ? Formatters.waktuRingkas(message.createdAt!) : ''}',
            style: AppTheme.caption,
          ),
          trailing: const Icon(Icons.open_in_new_rounded, size: 18),
          onTap: () => onOpenMessageAttachment(message),
        );
      },
    );
  }
}

class _ConversationLinkTab extends StatelessWidget {
  const _ConversationLinkTab({required this.links});

  final List<_ConversationLinkEntry> links;

  @override
  Widget build(BuildContext context) {
    if (links.isEmpty) {
      return const _ConversationAssetEmptyState(
        icon: Icons.link_off_rounded,
        title: 'Belum ada link',
        subtitle:
            'Semua tautan yang dibagikan di chat ini akan muncul di sini.',
      );
    }

    return ListView.separated(
      padding: const EdgeInsets.all(16),
      itemCount: links.length,
      separatorBuilder: (_, _) => const SizedBox(height: 10),
      itemBuilder: (context, index) {
        final item = links[index];
        return ListTile(
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 12,
            vertical: 8,
          ),
          tileColor: Colors.white,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: const BorderSide(color: AppTheme.dividerColor),
          ),
          leading: const Icon(Icons.link_rounded, color: AppTheme.primaryColor),
          title: Text(
            item.url,
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
            style: AppTheme.bodyMedium.copyWith(fontWeight: FontWeight.w700),
          ),
          subtitle: Text(
            '${item.message.senderName} - ${item.message.createdAt != null ? Formatters.waktuRingkas(item.message.createdAt!) : ''}',
            style: AppTheme.caption,
          ),
          trailing: const Icon(Icons.open_in_new_rounded, size: 18),
          onTap: () => _launchDetectedUrl(item.url),
        );
      },
    );
  }
}

class _ConversationAssetEmptyState extends StatelessWidget {
  const _ConversationAssetEmptyState({
    required this.icon,
    required this.title,
    required this.subtitle,
  });

  final IconData icon;
  final String title;
  final String subtitle;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, size: 40, color: AppTheme.textSecondary),
            const SizedBox(height: 12),
            Text(title, style: AppTheme.heading3),
            const SizedBox(height: 6),
            Text(
              subtitle,
              style: AppTheme.bodyMedium,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _ConversationLinkEntry {
  const _ConversationLinkEntry({required this.message, required this.url});

  final MessageModel message;
  final String url;
}

final RegExp _urlRegex = RegExp(
  r'((https?:\/\/|www\.)[^\s]+)',
  caseSensitive: false,
);
final RegExp _linkOrMentionRegex = RegExp(
  r'((https?:\/\/|www\.)[^\s]+|@[A-Za-z0-9_]+)',
  caseSensitive: false,
);

const List<String> _quickReactionEmojis = ['👍', '❤️', '😂', '🙏', '🔥'];

const List<String> _reactionPickerEmojis = [
  '👍',
  '❤️',
  '😂',
  '😮',
  '😢',
  '🙏',
  '🔥',
  '🎉',
  '✅',
  '👏',
];

bool _isImageFileName(String value) {
  final lower = value.toLowerCase();
  return lower.endsWith('.jpg') ||
      lower.endsWith('.jpeg') ||
      lower.endsWith('.png') ||
      lower.endsWith('.gif') ||
      lower.endsWith('.webp');
}

IconData _fileIconForName(String value) {
  final lower = value.toLowerCase();
  if (_isImageFileName(lower)) {
    return Icons.image_outlined;
  }
  if (lower.endsWith('.pdf')) {
    return Icons.picture_as_pdf_outlined;
  }
  if (lower.endsWith('.doc') || lower.endsWith('.docx')) {
    return Icons.description_outlined;
  }
  if (lower.endsWith('.xls') ||
      lower.endsWith('.xlsx') ||
      lower.endsWith('.csv')) {
    return Icons.table_chart_outlined;
  }
  if (lower.endsWith('.zip') || lower.endsWith('.rar')) {
    return Icons.folder_zip_outlined;
  }
  if (lower.endsWith('.mp4') ||
      lower.endsWith('.mov') ||
      lower.endsWith('.avi')) {
    return Icons.video_file_outlined;
  }
  return Icons.attach_file_rounded;
}

String _formatDuration(int totalSeconds) {
  final safeSeconds = totalSeconds < 0 ? 0 : totalSeconds;
  final minutes = safeSeconds ~/ 60;
  final seconds = safeSeconds % 60;
  return '${minutes.toString().padLeft(2, '0')}:${seconds.toString().padLeft(2, '0')}';
}

Future<void> _launchDetectedUrl(String rawUrl) async {
  final normalized =
      rawUrl.startsWith('http://') || rawUrl.startsWith('https://')
      ? rawUrl
      : 'https://$rawUrl';
  final uri = Uri.tryParse(normalized);
  if (uri == null) {
    return;
  }
  await launchUrl(uri, mode: LaunchMode.externalApplication);
}

String _mentionHandleForName(String displayName) {
  final compact = displayName
      .trim()
      .replaceAll(RegExp(r'[^A-Za-z0-9\s]'), '')
      .replaceAll(RegExp(r'\s+'), '_');
  return compact.isEmpty ? 'user' : compact;
}
