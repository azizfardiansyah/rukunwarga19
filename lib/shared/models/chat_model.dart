import 'package:pocketbase/pocketbase.dart';

class ChatAreaModel {
  const ChatAreaModel({
    required this.rt,
    required this.rw,
    required this.desaKelurahan,
    required this.kecamatan,
    required this.kabupatenKota,
    required this.provinsi,
  });

  final int rt;
  final int rw;
  final String desaKelurahan;
  final String kecamatan;
  final String kabupatenKota;
  final String provinsi;

  factory ChatAreaModel.fromJson(Map<String, dynamic> json) {
    return ChatAreaModel(
      rt: _jsonInt(json['rt']),
      rw: _jsonInt(json['rw']),
      desaKelurahan: json['desaKelurahan']?.toString() ?? '',
      kecamatan: json['kecamatan']?.toString() ?? '',
      kabupatenKota: json['kabupatenKota']?.toString() ?? '',
      provinsi: json['provinsi']?.toString() ?? '',
    );
  }

  String get scopeLabel {
    final parts = <String>[];
    if (rt > 0) {
      parts.add('RT ${rt.toString().padLeft(2, '0')}');
    }
    if (rw > 0) {
      parts.add('RW ${rw.toString().padLeft(2, '0')}');
    }
    if (desaKelurahan.isNotEmpty) {
      parts.add(desaKelurahan);
    }
    return parts.join(' / ');
  }
}

class ConversationModel {
  const ConversationModel({
    required this.id,
    required this.key,
    required this.type,
    required this.name,
    required this.subtitle,
    required this.rt,
    required this.rw,
    required this.isReadonly,
    required this.unreadCount,
    required this.isPinned,
    required this.isMuted,
    required this.isArchived,
    this.lastMessage,
    this.lastMessageAt,
  });

  final String id;
  final String key;
  final String type;
  final String name;
  final String subtitle;
  final int rt;
  final int rw;
  final bool isReadonly;
  final int unreadCount;
  final bool isPinned;
  final bool isMuted;
  final bool isArchived;
  final String? lastMessage;
  final DateTime? lastMessageAt;

  factory ConversationModel.fromJson(Map<String, dynamic> json) {
    return ConversationModel(
      id: json['id']?.toString() ?? '',
      key: json['key']?.toString() ?? '',
      type: json['type']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
      subtitle: json['subtitle']?.toString() ?? '',
      rt: _jsonInt(json['rt']),
      rw: _jsonInt(json['rw']),
      isReadonly: json['isReadonly'] == true,
      unreadCount: _jsonInt(json['unreadCount']),
      isPinned: json['isPinned'] == true,
      isMuted: json['isMuted'] == true,
      isArchived: json['isArchived'] == true,
      lastMessage: json['lastMessage']?.toString(),
      lastMessageAt: DateTime.tryParse(json['lastMessageAt']?.toString() ?? ''),
    );
  }

  factory ConversationModel.fromRecord(RecordModel record) {
    return ConversationModel(
      id: record.id,
      key: record.getStringValue('key'),
      type: record.getStringValue('type'),
      name: record.getStringValue('name'),
      subtitle: '',
      rt: _jsonInt(record.data['rt']),
      rw: _jsonInt(record.data['rw']),
      isReadonly: record.data['is_readonly'] == true,
      unreadCount: 0,
      isPinned: false,
      isMuted: false,
      isArchived: false,
      lastMessage: record.getStringValue('last_message'),
      lastMessageAt: DateTime.tryParse(record.getStringValue('last_message_at')),
    );
  }

  bool get isPrivate => type == 'private';
  bool get isGroupRt => type == 'group_rt';
  bool get isGroupRw => type == 'group_rw';
}

class MessageModel {
  const MessageModel({
    required this.id,
    required this.conversationId,
    required this.senderId,
    required this.senderName,
    required this.text,
    required this.messageType,
    required this.isMine,
    this.attachmentName,
    this.attachmentUrl,
    this.createdAt,
  });

  final String id;
  final String conversationId;
  final String senderId;
  final String senderName;
  final String text;
  final String messageType;
  final bool isMine;
  final String? attachmentName;
  final String? attachmentUrl;
  final DateTime? createdAt;

  bool get hasAttachment => (attachmentName ?? '').trim().isNotEmpty;

  factory MessageModel.fromJson(Map<String, dynamic> json) {
    return MessageModel(
      id: json['id']?.toString() ?? '',
      conversationId: json['conversationId']?.toString() ?? '',
      senderId: json['senderId']?.toString() ?? '',
      senderName: json['senderName']?.toString() ?? 'Pengguna',
      text: json['text']?.toString() ?? '',
      messageType: json['messageType']?.toString() ?? 'text',
      isMine: json['isMine'] == true,
      attachmentName: json['attachmentName']?.toString(),
      attachmentUrl: json['attachmentUrl']?.toString(),
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? ''),
    );
  }

  factory MessageModel.fromRecord(RecordModel record) {
    return MessageModel(
      id: record.id,
      conversationId: record.getStringValue('conversation'),
      senderId: record.getStringValue('sender'),
      senderName: '',
      text: record.getStringValue('text'),
      messageType: record.getStringValue('message_type'),
      isMine: false,
      attachmentName: record.getStringValue('attachment'),
      createdAt: DateTime.tryParse(record.getStringValue('created')),
    );
  }
}

class AnnouncementModel {
  const AnnouncementModel({
    required this.id,
    required this.title,
    required this.content,
    required this.targetType,
    required this.rt,
    required this.rw,
    required this.authorName,
    this.createdAt,
  });

  final String id;
  final String title;
  final String content;
  final String targetType;
  final int rt;
  final int rw;
  final String authorName;
  final DateTime? createdAt;

  factory AnnouncementModel.fromJson(Map<String, dynamic> json) {
    return AnnouncementModel(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      content: json['content']?.toString() ?? '',
      targetType: json['targetType']?.toString() ?? 'rw',
      rt: _jsonInt(json['rt']),
      rw: _jsonInt(json['rw']),
      authorName: json['authorName']?.toString() ?? 'Pengurus',
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? ''),
    );
  }

  String get targetLabel => targetType == 'rt'
      ? 'RT ${rt.toString().padLeft(2, '0')}'
      : 'RW ${rw.toString().padLeft(2, '0')}';
}

class ChatBootstrapData {
  const ChatBootstrapData({
    required this.role,
    required this.canCreateAnnouncement,
    required this.area,
    required this.inbox,
    required this.groups,
  });

  final String role;
  final bool canCreateAnnouncement;
  final ChatAreaModel area;
  final List<ConversationModel> inbox;
  final List<ConversationModel> groups;

  int get totalUnreadCount =>
      [...inbox, ...groups]
          .where((item) => !item.isArchived && !item.isMuted)
          .fold<int>(0, (sum, item) => sum + item.unreadCount);

  int get inboxUnreadCount => inbox
      .where((item) => !item.isArchived && !item.isMuted)
      .fold<int>(0, (sum, item) => sum + item.unreadCount);

  int get groupUnreadCount => groups
      .where((item) => !item.isArchived && !item.isMuted)
      .fold<int>(0, (sum, item) => sum + item.unreadCount);

  factory ChatBootstrapData.fromJson(Map<String, dynamic> json) {
    return ChatBootstrapData(
      role: json['role']?.toString() ?? '',
      canCreateAnnouncement: json['canCreateAnnouncement'] == true,
      area: ChatAreaModel.fromJson(
        Map<String, dynamic>.from(json['area'] as Map? ?? const {}),
      ),
      inbox: _jsonList(
        json['inbox'],
      ).map(ConversationModel.fromJson).toList(growable: false),
      groups: _jsonList(
        json['groups'],
      ).map(ConversationModel.fromJson).toList(growable: false),
    );
  }
}

class ChatMessagesData {
  const ChatMessagesData({required this.conversation, required this.messages});

  final ConversationModel conversation;
  final List<MessageModel> messages;

  factory ChatMessagesData.fromJson(Map<String, dynamic> json) {
    return ChatMessagesData(
      conversation: ConversationModel.fromJson(
        Map<String, dynamic>.from(json['conversation'] as Map? ?? const {}),
      ),
      messages: _jsonList(
        json['messages'],
      ).map(MessageModel.fromJson).toList(growable: false),
    );
  }
}

class ChatAnnouncementsData {
  const ChatAnnouncementsData({required this.canCreate, required this.items});

  final bool canCreate;
  final List<AnnouncementModel> items;

  factory ChatAnnouncementsData.fromJson(Map<String, dynamic> json) {
    return ChatAnnouncementsData(
      canCreate: json['canCreate'] == true,
      items: _jsonList(
        json['items'],
      ).map(AnnouncementModel.fromJson).toList(growable: false),
    );
  }
}

List<Map<String, dynamic>> _jsonList(dynamic raw) {
  if (raw is! List) {
    return const [];
  }
  return raw
      .whereType<Map>()
      .map((item) => Map<String, dynamic>.from(item))
      .toList(growable: false);
}

int _jsonInt(dynamic raw) {
  if (raw is int) {
    return raw;
  }
  return int.tryParse(raw?.toString() ?? '') ?? 0;
}
