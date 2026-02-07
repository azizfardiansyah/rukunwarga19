import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../../app/theme.dart';
import '../../../core/services/pocketbase_service.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/formatters.dart';
import '../../../core/utils/error_classifier.dart';
import '../../../shared/models/chat_model.dart';

class ChatRoomScreen extends ConsumerStatefulWidget {
  final String conversationId;
  const ChatRoomScreen({super.key, required this.conversationId});

  @override
  ConsumerState<ChatRoomScreen> createState() => _ChatRoomScreenState();
}

class _ChatRoomScreenState extends ConsumerState<ChatRoomScreen> {
  final _messageCtrl = TextEditingController();
  final _scrollController = ScrollController();
  List<MessageModel> _messages = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadMessages();
    _subscribeToMessages();
  }

  Future<void> _loadMessages() async {
    try {
      final result = await pb.collection(AppConstants.colMessages).getList(
        page: 1,
        perPage: 100,
        sort: 'created',
        filter: 'conversation = "${widget.conversationId}"',
      );
      setState(() {
        _messages = result.items.map((r) => MessageModel.fromRecord(r)).toList();
        _isLoading = false;
      });
      _scrollToBottom();
    } catch (e) {
      setState(() => _isLoading = false);
    }
  }

  void _subscribeToMessages() {
    pb.collection(AppConstants.colMessages).subscribe('*', (e) {
      if (e.action == 'create' && e.record != null) {
        final msg = MessageModel.fromRecord(e.record!);
        if (msg.conversation == widget.conversationId) {
          setState(() => _messages.add(msg));
          _scrollToBottom();
        }
      }
    });
  }

  void _scrollToBottom() {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (_scrollController.hasClients) {
        _scrollController.animateTo(
          _scrollController.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      }
    });
  }

  Future<void> _sendMessage() async {
    final text = _messageCtrl.text.trim();
    if (text.isEmpty) return;

    _messageCtrl.clear();
    try {
      await pb.collection(AppConstants.colMessages).create(body: {
        'conversation': widget.conversationId,
        'sender': pb.authStore.record?.id ?? '',
        'text': text,
      });
    } catch (e) {
      if (mounted) ErrorClassifier.showErrorSnackBar(context, e);
    }
  }

  @override
  void dispose() {
    pb.collection(AppConstants.colMessages).unsubscribe('*');
    _messageCtrl.dispose();
    _scrollController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final currentUserId = pb.authStore.record?.id ?? '';

    return Scaffold(
      appBar: AppBar(title: const Text('Chat')),
      body: Column(
        children: [
          Expanded(
            child: _isLoading
                ? const Center(child: CircularProgressIndicator())
                : _messages.isEmpty
                    ? const Center(child: Text('Belum ada pesan'))
                    : ListView.builder(
                        controller: _scrollController,
                        padding: const EdgeInsets.all(AppTheme.paddingMedium),
                        itemCount: _messages.length,
                        itemBuilder: (context, index) {
                          final msg = _messages[index];
                          final isMe = msg.sender == currentUserId;
                          return Align(
                            alignment: isMe ? Alignment.centerRight : Alignment.centerLeft,
                            child: Container(
                              margin: const EdgeInsets.only(bottom: 8),
                              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                              constraints: BoxConstraints(maxWidth: MediaQuery.of(context).size.width * 0.75),
                              decoration: BoxDecoration(
                                color: isMe ? AppTheme.primaryColor : Colors.grey[200],
                                borderRadius: BorderRadius.circular(12),
                              ),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.end,
                                children: [
                                  Text(
                                    msg.text ?? '',
                                    style: TextStyle(color: isMe ? Colors.white : AppTheme.textPrimary),
                                  ),
                                  const SizedBox(height: 2),
                                  Text(
                                    msg.created != null ? Formatters.waktu(msg.created!) : '',
                                    style: TextStyle(
                                      fontSize: 10,
                                      color: isMe ? Colors.white70 : AppTheme.textSecondary,
                                    ),
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
          ),
          // Input area
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: Colors.white,
              boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 4)],
            ),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _messageCtrl,
                    decoration: const InputDecoration(
                      hintText: 'Ketik pesan...',
                      border: InputBorder.none,
                      contentPadding: EdgeInsets.symmetric(horizontal: 12),
                    ),
                    onSubmitted: (_) => _sendMessage(),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.send, color: AppTheme.primaryColor),
                  onPressed: _sendMessage,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
