import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../../app/router.dart';
import '../../../app/theme.dart';
import '../../../core/services/pocketbase_service.dart';
import '../../../core/constants/app_constants.dart';
import '../../../shared/models/chat_model.dart';

final conversationListProvider =
    FutureProvider.autoDispose<List<ConversationModel>>((ref) async {
  final result = await pb.collection(AppConstants.colConversations).getList(
    page: 1, perPage: 100, sort: '-updated',
  );
  return result.items.map((r) => ConversationModel.fromRecord(r)).toList();
});

class ChatListScreen extends ConsumerWidget {
  const ChatListScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final chatAsync = ref.watch(conversationListProvider);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Chat'),
        actions: [
          IconButton(
            icon: const Icon(Icons.campaign),
            tooltip: 'Pengumuman',
            onPressed: () => context.push(Routes.announcements),
          ),
        ],
      ),
      body: chatAsync.when(
        data: (list) {
          if (list.isEmpty) {
            return const Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.chat_bubble_outline, size: 64, color: Colors.grey),
                  SizedBox(height: 16),
                  Text('Belum ada percakapan'),
                ],
              ),
            );
          }
          return ListView.builder(
            itemCount: list.length,
            itemBuilder: (context, index) {
              final conv = list[index];
              IconData icon;
              String title;
              if (conv.isPrivate) {
                icon = Icons.person;
                title = conv.nama ?? 'Chat Pribadi';
              } else if (conv.isGroupRt) {
                icon = Icons.group;
                title = 'Grup RT ${conv.targetRt ?? ""}';
              } else {
                icon = Icons.groups;
                title = 'Grup RW 19';
              }

              return ListTile(
                leading: CircleAvatar(
                  backgroundColor: AppTheme.primaryColor,
                  child: Icon(icon, color: Colors.white),
                ),
                title: Text(title),
                subtitle: Text(conv.type),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push('/chat/${conv.id}'),
              );
            },
          );
        },
        loading: () => const Center(child: CircularProgressIndicator()),
        error: (e, _) => Center(child: Text('Error: $e')),
      ),
    );
  }
}
