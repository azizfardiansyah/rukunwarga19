import 'package:pocketbase/pocketbase.dart';

class ConversationModel {
  final String id;
  final String type; // private, group_rt, group_rw
  final String? nama;
  final String? targetRt; // untuk group_rt
  final String? foto;
  final DateTime? created;
  final DateTime? updated;

  ConversationModel({
    required this.id,
    required this.type,
    this.nama,
    this.targetRt,
    this.foto,
    this.created,
    this.updated,
  });

  factory ConversationModel.fromRecord(RecordModel record) {
    return ConversationModel(
      id: record.id,
      type: record.getStringValue('type'),
      nama: record.getStringValue('nama'),
      targetRt: record.getStringValue('target_rt'),
      foto: record.getStringValue('foto'),
      created: DateTime.tryParse(record.getStringValue('created')),
      updated: DateTime.tryParse(record.getStringValue('updated')),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'type': type,
      'nama': nama,
      'target_rt': targetRt,
    };
  }

  bool get isPrivate => type == 'private';
  bool get isGroupRt => type == 'group_rt';
  bool get isGroupRw => type == 'group_rw';
}

class ConversationMemberModel {
  final String id;
  final String conversation;
  final String user;
  final DateTime? created;

  ConversationMemberModel({
    required this.id,
    required this.conversation,
    required this.user,
    this.created,
  });

  factory ConversationMemberModel.fromRecord(RecordModel record) {
    return ConversationMemberModel(
      id: record.id,
      conversation: record.getStringValue('conversation'),
      user: record.getStringValue('user'),
      created: DateTime.tryParse(record.getStringValue('created')),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'conversation': conversation,
      'user': user,
    };
  }
}

class MessageModel {
  final String id;
  final String conversation;
  final String sender;
  final String? text;
  final String? image;
  final DateTime? created;

  // Expand data
  final String? senderNama;

  MessageModel({
    required this.id,
    required this.conversation,
    required this.sender,
    this.text,
    this.image,
    this.created,
    this.senderNama,
  });

  factory MessageModel.fromRecord(RecordModel record) {
    return MessageModel(
      id: record.id,
      conversation: record.getStringValue('conversation'),
      sender: record.getStringValue('sender'),
      text: record.getStringValue('text'),
      image: record.getStringValue('image'),
      created: DateTime.tryParse(record.getStringValue('created')),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'conversation': conversation,
      'sender': sender,
      'text': text,
    };
  }
}

class MessageReadModel {
  final String id;
  final String message;
  final String user;
  final DateTime? readAt;

  MessageReadModel({
    required this.id,
    required this.message,
    required this.user,
    this.readAt,
  });

  factory MessageReadModel.fromRecord(RecordModel record) {
    return MessageReadModel(
      id: record.id,
      message: record.getStringValue('message'),
      user: record.getStringValue('user'),
      readAt: DateTime.tryParse(record.getStringValue('read_at')),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'message': message,
      'user': user,
      'read_at': readAt?.toIso8601String() ?? DateTime.now().toIso8601String(),
    };
  }
}

class AnnouncementModel {
  final String id;
  final String author;
  final String judul;
  final String isi;
  final String target; // all, atau nomor RT tertentu
  final DateTime? created;
  final DateTime? updated;

  // Expand data
  final String? authorNama;

  AnnouncementModel({
    required this.id,
    required this.author,
    required this.judul,
    required this.isi,
    required this.target,
    this.created,
    this.updated,
    this.authorNama,
  });

  factory AnnouncementModel.fromRecord(RecordModel record) {
    return AnnouncementModel(
      id: record.id,
      author: record.getStringValue('author'),
      judul: record.getStringValue('judul'),
      isi: record.getStringValue('isi'),
      target: record.getStringValue('target'),
      created: DateTime.tryParse(record.getStringValue('created')),
      updated: DateTime.tryParse(record.getStringValue('updated')),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'author': author,
      'judul': judul,
      'isi': isi,
      'target': target,
    };
  }
}
