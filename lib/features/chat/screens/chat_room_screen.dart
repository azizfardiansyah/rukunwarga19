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

class ChatRoomScreen extends ConsumerStatefulWidget {
  const ChatRoomScreen({super.key, required this.conversationId});

  final String conversationId;

  @override
  ConsumerState<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends ConsumerState<ChatRoomScreen> {
  final _messageCtrl = TextEditingController();
  final _scrollController = ScrollController();

  ChatMessagesData? _data;
  bool _isLoading = true;
  bool _isSending = false;
  PlatformFile? _selectedAttachment;
  MessageModel? _replyingTo;
  Timer? _pollTimer;
  Timer? _refreshDebounce;
  Future<void> Function()? _unsubscribeMessages;
  Future<void> Function()? _unsubscribeConversation;

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _bindRealtime();
    _pollTimer = Timer.periodic(
      const Duration(seconds: 5),
      (_) => _loadMessages(silent: true),
    );
  }

  Future<void> _bindRealtime() async {
    await _disposeRealtime();
    _unsubscribeMessages = await pb
        .collection(AppConstants.colMessages)
        .subscribe(
          '*',
          (_) => _scheduleRefresh(),
          filter: 'conversation = "${widget.conversationId}"',
        );
    _unsubscribeConversation = await pb
        .collection(AppConstants.colConversations)
        .subscribe(widget.conversationId, (_) => _scheduleRefresh());
  }

  void _scheduleRefresh() {
    _refreshDebounce?.cancel();
    _refreshDebounce = Timer(const Duration(milliseconds: 180), () {
      if (mounted) {
        _loadMessages(silent: true);
      }
    });
  }

  Future<void> _disposeRealtime() async {
    await _unsubscribeMessages?.call();
    await _unsubscribeConversation?.call();
    _unsubscribeMessages = null;
    _unsubscribeConversation = null;
  }

  Future<void> _loadMessages({bool silent = false}) async {
    if (!silent && mounted && _data == null) {
      setState(() => _isLoading = true);
    }

    try {
      final service = ref.read(chatServiceProvider);
      final result = await service.getMessages(widget.conversationId);
      if (!mounted) {
        return;
      }

      setState(() {
        _data = result;
        _isLoading = false;
        if (_replyingTo != null) {
          final match = result.messages.where(
            (item) => item.id == _replyingTo!.id,
          );
          _replyingTo = match.isEmpty ? null : match.first;
        }
      });
      _scrollToBottom();
      ref.read(chatRefreshTickProvider.notifier).bump();
    } catch (error) {
      if (!mounted) {
        return;
      }
      setState(() => _isLoading = false);
      if (!silent) {
        ErrorClassifier.showErrorSnackBar(context, error);
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
      );
    });
    _scrollToBottom();
  }

  Future<void> _showComposerActions() async {
    final auth = ref.read(authProvider);
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
              if (AppConstants.planIncludesFeature(
                planCode: auth.planCode,
                featureFlag: AppConstants.featurePolling,
              ))
                _MessageActionTile(
                  icon: Icons.poll_rounded,
                  label: 'Polling',
                  onTap: () {
                    Navigator.pop(sheetContext);
                    _showPollComposer();
                  },
                ),
              if (AppConstants.planIncludesFeature(
                planCode: auth.planCode,
                featureFlag: AppConstants.featureVoiceNote,
              ))
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
    if ((text.isEmpty && _selectedAttachment == null) || _isSending) {
      return;
    }

    setState(() => _isSending = true);
    try {
      final service = ref.read(chatServiceProvider);
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
                            ? const Color(0xFFE0F2F1)
                            : const Color(0xFFEAF4F1),
                        child: Icon(
                          item.isPrivate
                              ? Icons.support_agent_rounded
                              : item.isGroupRt
                              ? Icons.groups_rounded
                              : Icons.hub_rounded,
                          color: item.isPrivate
                              ? const Color(0xFF00796B)
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
                _MessageActionTile(
                  icon: Icons.reply_rounded,
                  label: 'Reply',
                  onTap: () {
                    Navigator.pop(context);
                    setState(() => _replyingTo = message);
                  },
                ),
              _MessageActionTile(
                icon: Icons.forward_rounded,
                label: 'Forward',
                onTap: () {
                  Navigator.pop(context);
                  _forwardMessage(message);
                },
              ),
              _MessageActionTile(
                icon: Icons.copy_all_rounded,
                label: 'Copy',
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
                label: message.isStarred ? 'Hapus Star' : 'Star',
                onTap: () async {
                  Navigator.pop(context);
                  await _runMessageAction(() async {
                    await ref
                        .read(chatServiceProvider)
                        .toggleMessageStar(message.id);
                  });
                },
              ),
              _MessageActionTile(
                icon: message.isPinned
                    ? Icons.push_pin_rounded
                    : Icons.push_pin_outlined,
                label: message.isPinned ? 'Lepas Pin' : 'Pin',
                onTap: () async {
                  Navigator.pop(context);
                  await _runMessageAction(() async {
                    await ref
                        .read(chatServiceProvider)
                        .toggleMessagePin(message.id);
                  });
                },
              ),
              if (message.isMine || auth.isSysadmin)
                _MessageActionTile(
                  icon: Icons.delete_outline_rounded,
                  label: 'Delete',
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

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
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
    _pollTimer?.cancel();
    _refreshDebounce?.cancel();
    _disposeRealtime();
    _messageCtrl.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final conversation = _data?.conversation;

    return Scaffold(
      appBar: AppBar(
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              conversation?.name ?? 'Chat',
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
            ),
            if (conversation != null)
              Text(
                conversation.subtitle,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: AppTheme.caption.copyWith(
                  color: Colors.white.withValues(alpha: 0.86),
                ),
              ),
          ],
        ),
      ),
      body: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              const Color(0xFFF2F7F5),
              Colors.white.withValues(alpha: 0.98),
              const Color(0xFFF7FBF9),
            ],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Column(
          children: [
            if (conversation != null)
              Container(
                width: double.infinity,
                margin: const EdgeInsets.fromLTRB(12, 10, 12, 6),
                padding: const EdgeInsets.symmetric(
                  horizontal: 12,
                  vertical: 10,
                ),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.8),
                  borderRadius: BorderRadius.circular(16),
                  border: Border.all(color: AppTheme.dividerColor),
                ),
                child: Row(
                  children: [
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: AppTheme.primaryColor.withValues(alpha: 0.12),
                        borderRadius: BorderRadius.circular(999),
                      ),
                      child: Text(
                        conversation.isPrivate
                            ? 'Inbox'
                            : conversation.isGroupRt
                            ? 'Grup RT'
                            : 'Forum RW',
                        style: AppTheme.caption.copyWith(
                          color: AppTheme.primaryColor,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(
                        conversation.lastMessageAt != null
                            ? 'Aktif ${Formatters.waktuRingkas(conversation.lastMessageAt!)}'
                            : conversation.subtitle,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: AppTheme.caption,
                      ),
                    ),
                  ],
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
                  : RefreshIndicator(
                      onRefresh: _loadMessages,
                      child: ListView.builder(
                        controller: _scrollController,
                        physics: const AlwaysScrollableScrollPhysics(),
                        padding: const EdgeInsets.fromLTRB(12, 8, 12, 12),
                        itemCount: _data!.messages.length,
                        itemBuilder: (context, index) {
                          final message = _data!.messages[index];
                          return _MessageBubble(
                            message: message,
                            onOpenAttachment: message.hasAttachment
                                ? () => _openAttachment(message)
                                : null,
                            onShowActions: () => _showMessageActions(message),
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
                  color: Colors.white,
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
                    if (_selectedAttachment != null)
                      _AttachmentDraftPreview(
                        attachment: _selectedAttachment!,
                        onClose: () =>
                            setState(() => _selectedAttachment = null),
                      ),
                    Row(
                      children: [
                        IconButton.filledTonal(
                          onPressed: _isSending ? null : _showComposerActions,
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
                              hintText: _replyingTo != null
                                  ? 'Tulis balasan...'
                                  : _selectedAttachment != null
                                  ? 'Tambahkan caption...'
                                  : 'Tulis pesan...',
                              filled: true,
                              fillColor: const Color(0xFFF7FAF9),
                              border: OutlineInputBorder(
                                borderRadius: BorderRadius.circular(16),
                                borderSide: BorderSide.none,
                              ),
                              contentPadding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 12,
                              ),
                            ),
                          ),
                        ),
                        const SizedBox(width: 8),
                        FilledButton(
                          onPressed: _isSending ? null : _sendMessage,
                          style: FilledButton.styleFrom(
                            backgroundColor: AppTheme.primaryColor,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 14,
                            ),
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
                              : const Icon(Icons.send_rounded),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
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
        color: const Color(0xFFF7FAF9),
        borderRadius: BorderRadius.circular(14),
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
        color: const Color(0xFFF7FAF9),
        borderRadius: BorderRadius.circular(14),
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
              : const Color(0xFFF4F7F5),
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
    final matches = _urlRegex.allMatches(text).toList(growable: false);
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
      final url = text.substring(match.start, match.end);
      spans.add(
        TextSpan(
          text: url,
          style: style.copyWith(
            color: style.color == Colors.white
                ? Colors.white
                : AppTheme.primaryColor,
            decoration: TextDecoration.underline,
            fontWeight: FontWeight.w600,
          ),
          recognizer: TapGestureRecognizer()
            ..onTap = () {
              _launchDetectedUrl(url);
            },
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
              : const Color(0xFFF4F7F5),
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
            : const Color(0xFFF4F7F5),
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
                      ? 'Polling aktif • multi-pilihan'
                      : 'Polling aktif • satu pilihan'
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
                    : const Color(0xFFE3ECE8),
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
    this.onOpenAttachment,
    this.onVotePoll,
  });

  final MessageModel message;
  final VoidCallback onShowActions;
  final VoidCallback? onOpenAttachment;
  final Future<void> Function(List<String> optionIds)? onVotePoll;

  @override
  Widget build(BuildContext context) {
    final isMine = message.isMine;
    final bubbleTextColor = isMine ? Colors.white : AppTheme.textPrimary;

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: GestureDetector(
        onLongPress: onShowActions,
        child: Container(
          margin: const EdgeInsets.only(bottom: 8),
          constraints: BoxConstraints(
            maxWidth: MediaQuery.of(context).size.width * 0.8,
          ),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          decoration: BoxDecoration(
            gradient: isMine
                ? AppTheme.primaryGradient
                : const LinearGradient(
                    colors: [Color(0xFFFFFFFF), Color(0xFFF8FBFA)],
                  ),
            borderRadius: BorderRadius.only(
              topLeft: const Radius.circular(16),
              topRight: const Radius.circular(16),
              bottomLeft: Radius.circular(isMine ? 16 : 6),
              bottomRight: Radius.circular(isMine ? 6 : 16),
            ),
            border: isMine
                ? null
                : Border.all(
                    color: AppTheme.dividerColor.withValues(alpha: 0.9),
                  ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  if (!isMine)
                    Expanded(
                      child: Text(
                        message.senderName,
                        style: AppTheme.caption.copyWith(
                          color: AppTheme.primaryColor,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    )
                  else
                    const Spacer(),
                  if (message.isStarred)
                    Icon(Icons.star_rounded, size: 14, color: bubbleTextColor),
                  if (message.isPinned) ...[
                    const SizedBox(width: 4),
                    Icon(
                      Icons.push_pin_rounded,
                      size: 14,
                      color: bubbleTextColor,
                    ),
                  ],
                ],
              ),
              if (!isMine) const SizedBox(height: 3),
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
                        : const Color(0xFFF4F7F5),
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
              ],
              const SizedBox(height: 5),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Text(
                    message.createdAt != null
                        ? Formatters.waktu(message.createdAt!)
                        : '',
                    style: AppTheme.caption.copyWith(
                      color: isMine
                          ? Colors.white.withValues(alpha: 0.84)
                          : AppTheme.textSecondary,
                    ),
                  ),
                  const SizedBox(width: 8),
                  GestureDetector(
                    onTap: onShowActions,
                    child: Icon(
                      Icons.expand_more_rounded,
                      size: 16,
                      color: isMine
                          ? Colors.white.withValues(alpha: 0.84)
                          : AppTheme.textSecondary,
                    ),
                  ),
                ],
              ),
            ],
          ),
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

final RegExp _urlRegex = RegExp(
  r'((https?:\/\/|www\.)[^\s]+)',
  caseSensitive: false,
);

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
