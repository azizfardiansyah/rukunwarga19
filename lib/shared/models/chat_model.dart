import 'package:pocketbase/pocketbase.dart';

import '../../core/constants/app_constants.dart';

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
    this.workspaceId,
    this.orgUnitId,
    this.scopeType,
    this.requiredPlanCode,
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
  final String? workspaceId;
  final String? orgUnitId;
  final String? scopeType;
  final String? requiredPlanCode;

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
      workspaceId: json['workspaceId']?.toString(),
      orgUnitId: json['orgUnitId']?.toString(),
      scopeType: json['scopeType']?.toString(),
      requiredPlanCode: json['requiredPlanCode']?.toString(),
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
      lastMessageAt: DateTime.tryParse(
        record.getStringValue('last_message_at'),
      ),
      workspaceId: _recordText(record, 'workspace'),
      orgUnitId: _recordText(record, 'org_unit'),
      scopeType: _recordText(record, 'scope_type'),
      requiredPlanCode: _recordText(record, 'required_plan_code'),
    );
  }

  bool get isPrivate => type == 'private';
  bool get isGroupRt => type == 'group_rt';
  bool get isGroupRw => type == 'group_rw';
  bool get isScopedConversation => (scopeType ?? '').trim().isNotEmpty;
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
    required this.isStarred,
    required this.isPinned,
    required this.isDeleted,
    this.attachmentName,
    this.attachmentUrl,
    this.replyToId,
    this.replySenderName,
    this.replySnippet,
    this.forwardedFromId,
    this.forwardedFromName,
    this.createdAt,
    this.voiceDurationSeconds,
    this.pollId,
    this.senderBadgeLabel,
    this.poll,
  });

  final String id;
  final String conversationId;
  final String senderId;
  final String senderName;
  final String text;
  final String messageType;
  final bool isMine;
  final bool isStarred;
  final bool isPinned;
  final bool isDeleted;
  final String? attachmentName;
  final String? attachmentUrl;
  final String? replyToId;
  final String? replySenderName;
  final String? replySnippet;
  final String? forwardedFromId;
  final String? forwardedFromName;
  final DateTime? createdAt;
  final int? voiceDurationSeconds;
  final String? pollId;
  final String? senderBadgeLabel;
  final ChatPollModel? poll;

  bool get hasAttachment => (attachmentName ?? '').trim().isNotEmpty;
  bool get hasReply => (replyToId ?? '').trim().isNotEmpty;
  bool get isForwarded => (forwardedFromId ?? '').trim().isNotEmpty;

  factory MessageModel.fromJson(Map<String, dynamic> json) {
    return MessageModel(
      id: json['id']?.toString() ?? '',
      conversationId: json['conversationId']?.toString() ?? '',
      senderId: json['senderId']?.toString() ?? '',
      senderName: json['senderName']?.toString() ?? 'Pengguna',
      text: json['text']?.toString() ?? '',
      messageType: json['messageType']?.toString() ?? 'text',
      isMine: json['isMine'] == true,
      isStarred: json['isStarred'] == true,
      isPinned: json['isPinned'] == true,
      isDeleted: json['isDeleted'] == true,
      attachmentName: json['attachmentName']?.toString(),
      attachmentUrl: json['attachmentUrl']?.toString(),
      replyToId: json['replyToId']?.toString(),
      replySenderName: json['replySenderName']?.toString(),
      replySnippet: json['replySnippet']?.toString(),
      forwardedFromId: json['forwardedFromId']?.toString(),
      forwardedFromName: json['forwardedFromName']?.toString(),
      createdAt: DateTime.tryParse(json['createdAt']?.toString() ?? ''),
      voiceDurationSeconds: _jsonNullableInt(json['voiceDurationSeconds']),
      pollId: json['pollId']?.toString(),
      senderBadgeLabel: json['senderBadgeLabel']?.toString(),
      poll: json['poll'] is Map
          ? ChatPollModel.fromJson(
              Map<String, dynamic>.from(json['poll'] as Map),
            )
          : null,
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
      isStarred: record.data['is_starred'] == true,
      isPinned: record.data['is_pinned'] == true,
      isDeleted: record.getStringValue('deleted_at').isNotEmpty,
      attachmentName: record.getStringValue('attachment'),
      replyToId: record.getStringValue('reply_to'),
      forwardedFromId: record.getStringValue('forwarded_from'),
      createdAt: DateTime.tryParse(record.getStringValue('created')),
      voiceDurationSeconds: _jsonNullableInt(
        record.data['voice_duration_seconds'],
      ),
      pollId: _recordText(record, 'poll'),
      senderBadgeLabel: _recordText(record, 'sender_badge_label'),
      poll: null,
    );
  }

  bool get isVoice => messageType == AppConstants.msgTypeVoice;

  bool get isPoll => messageType == AppConstants.msgTypePoll;
}

class ChatPollOptionModel {
  const ChatPollOptionModel({
    required this.id,
    required this.label,
    required this.sortOrder,
    this.voteCount = 0,
    this.isSelected = false,
  });

  final String id;
  final String label;
  final int sortOrder;
  final int voteCount;
  final bool isSelected;

  factory ChatPollOptionModel.fromJson(Map<String, dynamic> json) {
    return ChatPollOptionModel(
      id: json['id']?.toString() ?? '',
      label: json['label']?.toString() ?? '',
      sortOrder: _jsonInt(json['sortOrder']),
      voteCount: _jsonInt(json['voteCount']),
      isSelected: json['isSelected'] == true,
    );
  }
}

class ChatPollModel {
  const ChatPollModel({
    required this.id,
    required this.title,
    required this.status,
    required this.allowMultipleChoice,
    required this.allowAnonymousVote,
    required this.options,
    this.closedAt,
  });

  final String id;
  final String title;
  final String status;
  final bool allowMultipleChoice;
  final bool allowAnonymousVote;
  final List<ChatPollOptionModel> options;
  final DateTime? closedAt;

  factory ChatPollModel.fromJson(Map<String, dynamic> json) {
    return ChatPollModel(
      id: json['id']?.toString() ?? '',
      title: json['title']?.toString() ?? '',
      status: json['status']?.toString() ?? 'open',
      allowMultipleChoice: json['allowMultipleChoice'] == true,
      allowAnonymousVote: json['allowAnonymousVote'] == true,
      options: _jsonList(
        json['options'],
      ).map(ChatPollOptionModel.fromJson).toList(growable: false),
      closedAt: DateTime.tryParse(json['closedAt']?.toString() ?? ''),
    );
  }

  bool get isOpen => status == 'open';
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
    this.workspaceId,
    this.orgUnitId,
    this.sourceModule,
    this.publishState,
    this.publishedByMemberId,
  });

  final String id;
  final String title;
  final String content;
  final String targetType;
  final int rt;
  final int rw;
  final String authorName;
  final DateTime? createdAt;
  final String? workspaceId;
  final String? orgUnitId;
  final String? sourceModule;
  final String? publishState;
  final String? publishedByMemberId;

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
      workspaceId: json['workspaceId']?.toString(),
      orgUnitId: json['orgUnitId']?.toString(),
      sourceModule: json['sourceModule']?.toString(),
      publishState: json['publishState']?.toString(),
      publishedByMemberId: json['publishedByMemberId']?.toString(),
    );
  }

  String get targetLabel => targetType == 'rt'
      ? 'RT ${rt.toString().padLeft(2, '0')}'
      : 'RW ${rw.toString().padLeft(2, '0')}';
}

class ChatBootstrapData {
  const ChatBootstrapData({
    required this.role,
    required this.systemRole,
    required this.planCode,
    required this.canCreateAnnouncement,
    required this.area,
    required this.inbox,
    required this.groups,
  });

  final String role;
  final String systemRole;
  final String planCode;
  final bool canCreateAnnouncement;
  final ChatAreaModel area;
  final List<ConversationModel> inbox;
  final List<ConversationModel> groups;

  int get totalUnreadCount => [...inbox, ...groups]
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
      systemRole:
          json['systemRole']?.toString() ?? AppConstants.systemRoleWarga,
      planCode: json['planCode']?.toString() ?? AppConstants.planFree,
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

int? _jsonNullableInt(dynamic raw) {
  if (raw is int) {
    return raw;
  }
  return int.tryParse(raw?.toString() ?? '');
}

String _recordText(RecordModel record, String field) {
  final fromGetter = record.getStringValue(field).trim();
  if (fromGetter.isNotEmpty) {
    return fromGetter;
  }
  return record.data[field]?.toString().trim() ?? '';
}
