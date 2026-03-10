import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/chat_service.dart';
import '../../../core/services/pocketbase_service.dart';
import '../../../core/utils/error_classifier.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/models/chat_model.dart';

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
      const Duration(seconds: 4),
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
    if (!silent && mounted) {
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
      });
      _scrollToBottom();
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
      );
      _messageCtrl.clear();
      if (mounted && _data != null) {
        setState(() {
          _data = ChatMessagesData(
            conversation: _data!.conversation,
            messages: [..._data!.messages, sentMessage],
          );
          _selectedAttachment = null;
        });
        _scrollToBottom();
      } else if (mounted) {
        setState(() => _selectedAttachment = null);
      }
      await Future<void>.delayed(const Duration(milliseconds: 120));
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

    final launched = await launchUrl(
      uri,
      mode: LaunchMode.externalApplication,
    );
    if (!launched && mounted) {
      ErrorClassifier.showErrorSnackBar(
        context,
        const FormatException('Lampiran tidak dapat dibuka.'),
      );
    }
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 260),
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
        title: Text(conversation?.name ?? 'Chat'),
        bottom: conversation == null
            ? null
            : PreferredSize(
                preferredSize: const Size.fromHeight(34),
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 8),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: 10,
                          vertical: 4,
                        ),
                        decoration: BoxDecoration(
                          color: Colors.white.withValues(alpha: 0.16),
                          borderRadius: BorderRadius.circular(999),
                        ),
                        child: Text(
                          conversation.isPrivate
                              ? 'Inbox'
                              : conversation.isGroupRt
                                  ? 'Grup RT'
                                  : 'Forum RW',
                          style: AppTheme.caption.copyWith(
                            color: Colors.white,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          conversation.subtitle,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTheme.caption.copyWith(
                            color: Colors.white.withValues(alpha: 0.88),
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            colors: [Color(0xFFF3F7FF), Color(0xFFF8FBFF), Color(0xFFF7FFFC)],
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
          ),
        ),
        child: Column(
          children: [
            Expanded(
              child: _isLoading
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
                            padding: const EdgeInsets.fromLTRB(12, 12, 12, 16),
                            itemCount: _data!.messages.length,
                            itemBuilder: (context, index) {
                              final message = _data!.messages[index];
                              return _MessageBubble(
                                message: message,
                                onOpenAttachment: message.hasAttachment
                                    ? () => _openAttachment(message)
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
                      color: AppTheme.primaryColor.withValues(alpha: 0.06),
                      blurRadius: 18,
                      offset: const Offset(0, -4),
                    ),
                  ],
                ),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    if (_selectedAttachment != null)
                      Container(
                        margin: const EdgeInsets.only(bottom: 8),
                        padding: const EdgeInsets.symmetric(
                          horizontal: 12,
                          vertical: 10,
                        ),
                        decoration: BoxDecoration(
                          color: const Color(0xFFF4F7FB),
                          borderRadius: BorderRadius.circular(14),
                        ),
                        child: Row(
                          children: [
                            const Icon(
                              Icons.attach_file_rounded,
                              color: AppTheme.primaryColor,
                            ),
                            const SizedBox(width: 8),
                            Expanded(
                              child: Text(
                                _selectedAttachment!.name,
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                                style: AppTheme.bodyMedium.copyWith(
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            IconButton(
                              onPressed: () {
                                setState(() => _selectedAttachment = null);
                              },
                              icon: const Icon(Icons.close_rounded),
                            ),
                          ],
                        ),
                      ),
                    Row(
                      children: [
                        IconButton.filledTonal(
                          onPressed: _isSending ? null : _pickAttachment,
                          icon: const Icon(Icons.attach_file_rounded),
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
                              hintText: _selectedAttachment == null
                                  ? 'Tulis pesan...'
                                  : 'Tambahkan caption...',
                              filled: true,
                              fillColor: const Color(0xFFF4F7FB),
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

class _MessageBubble extends StatelessWidget {
  const _MessageBubble({
    required this.message,
    this.onOpenAttachment,
  });

  final MessageModel message;
  final VoidCallback? onOpenAttachment;

  @override
  Widget build(BuildContext context) {
    final isMine = message.isMine;

    return Align(
      alignment: isMine ? Alignment.centerRight : Alignment.centerLeft,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        constraints: BoxConstraints(
          maxWidth: MediaQuery.of(context).size.width * 0.78,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
        decoration: BoxDecoration(
          gradient: isMine
              ? AppTheme.primaryGradient
              : const LinearGradient(
                  colors: [Color(0xFFFFFFFF), Color(0xFFF5F8FC)],
                ),
          borderRadius: BorderRadius.only(
            topLeft: const Radius.circular(16),
            topRight: const Radius.circular(16),
            bottomLeft: Radius.circular(isMine ? 16 : 6),
            bottomRight: Radius.circular(isMine ? 6 : 16),
          ),
          border: isMine
              ? null
              : Border.all(color: AppTheme.dividerColor.withValues(alpha: 0.9)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (!isMine) ...[
              Text(
                message.senderName,
                style: AppTheme.caption.copyWith(
                  color: AppTheme.primaryColor,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 3),
            ],
            if (message.hasAttachment)
              InkWell(
                onTap: onOpenAttachment,
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  margin: EdgeInsets.only(bottom: message.text.isEmpty ? 0 : 8),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: isMine
                        ? Colors.white.withValues(alpha: 0.14)
                        : const Color(0xFFF1F5FB),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Icon(
                        Icons.attach_file_rounded,
                        size: 18,
                        color: isMine ? Colors.white : AppTheme.primaryColor,
                      ),
                      const SizedBox(width: 8),
                      Flexible(
                        child: Text(
                          message.attachmentName ?? 'Lampiran',
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: AppTheme.bodyMedium.copyWith(
                            color: isMine ? Colors.white : AppTheme.textPrimary,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            if (message.text.isNotEmpty)
              Text(
                message.text,
                style: AppTheme.bodyMedium.copyWith(
                  color: isMine ? Colors.white : AppTheme.textPrimary,
                  height: 1.35,
                ),
              ),
            const SizedBox(height: 5),
            Align(
              alignment: Alignment.centerRight,
              child: Text(
                message.createdAt != null
                    ? Formatters.waktu(message.createdAt!)
                    : '',
                style: AppTheme.caption.copyWith(
                  color: isMine
                      ? Colors.white.withValues(alpha: 0.84)
                      : AppTheme.textSecondary,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
