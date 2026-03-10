import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:pocketbase/pocketbase.dart';

import '../../features/auth/providers/auth_provider.dart';
import '../../shared/models/chat_model.dart';
import '../constants/app_constants.dart';
import '../utils/area_access.dart';
import 'pocketbase_service.dart';

class ChatService {
  ChatService(this._ref);

  final Ref _ref;

  AuthState get _auth => _ref.read(authProvider);

  Future<ChatBootstrapData> bootstrap() async {
    final auth = _auth;
    final authUser = auth.user;
    if (authUser == null) {
      throw ClientException(
        statusCode: 401,
        response: const {'message': 'Sesi telah berakhir'},
      );
    }

    final role = AppConstants.normalizeRole(auth.role);
    final area = await resolveAreaAccessContext(auth);
    final ensured = <RecordModel>[];

    if (auth.isSysadmin) {
      ensured.addAll(
        await pb.collection(AppConstants.colConversations).getFullList(
              sort: '-updated',
            ),
      );
    } else if (area.hasArea) {
      final selfScope = await _buildScopeForAuthUser(auth, area);
      if (role == AppConstants.roleWarga) {
        final privateRoom = await _ensurePrivateSupportConversation(
          scope: selfScope,
          createdBy: authUser.id,
        );
        final rtGroup = await _ensureRtConversation(
          scope: selfScope,
          createdBy: authUser.id,
        );
        if (privateRoom != null) {
          ensured.add(privateRoom);
        }
        if (rtGroup != null) {
          ensured.add(rtGroup);
        }
      } else {
        final scopedWarga = await _fetchScopedWargaScopes(auth, area);
        if (role == AppConstants.roleAdminRt) {
          final rtGroup = await _ensureRtConversation(
            scope: selfScope,
            createdBy: authUser.id,
          );
          final rwGroup = await _ensureRwConversation(
            scope: selfScope,
            createdBy: authUser.id,
          );
          if (rtGroup != null) {
            ensured.add(rtGroup);
          }
          if (rwGroup != null) {
            ensured.add(rwGroup);
          }
        }
        if (AppConstants.hasRwWideAccess(role)) {
          final rwGroup = await _ensureRwConversation(
            scope: selfScope,
            createdBy: authUser.id,
          );
          if (rwGroup != null) {
            ensured.add(rwGroup);
          }
        }

        for (final scope in scopedWarga) {
          final privateRoom = await _ensurePrivateSupportConversation(
            scope: scope,
            createdBy: authUser.id,
          );
          if (privateRoom != null) {
            ensured.add(privateRoom);
          }

          if (AppConstants.hasRwWideAccess(role)) {
            final rtGroup = await _ensureRtConversation(
              scope: scope,
              createdBy: authUser.id,
            );
            if (rtGroup != null) {
              ensured.add(rtGroup);
            }
          }
        }
      }
    }

    final unique = <String, RecordModel>{};
    for (final record in ensured) {
      unique[record.id] = record;
    }

    final accessible = unique.values.where((record) {
      return _canAccessConversation(
        auth: auth,
        context: area,
        conversation: record,
      );
    }).toList(growable: false);

    final memberships = await _ensureAndLoadMemberships(
      conversations: accessible,
      userId: authUser.id,
    );
    final unreadCounts = await _loadUnreadCounts(
      conversations: accessible,
      userId: authUser.id,
      memberships: memberships,
    );

    final models = accessible
        .map(
          (record) => _conversationFromRecord(
            record,
            currentUserId: authUser.id,
            membership: memberships[record.id],
            unreadCount: unreadCounts[record.id] ?? 0,
          ),
        )
        .toList()
      ..sort(_compareConversationModels);

    return ChatBootstrapData(
      role: role,
      canCreateAnnouncement: _canCreateAnnouncement(role),
      area: ChatAreaModel(
        rt: area.rt ?? 0,
        rw: area.rw ?? 0,
        desaKelurahan: area.desaKelurahan ?? '',
        kecamatan: area.kecamatan ?? '',
        kabupatenKota: area.kabupatenKota ?? '',
        provinsi: area.provinsi ?? '',
      ),
      inbox: models.where((item) => item.isPrivate).toList(growable: false),
      groups: models.where((item) => !item.isPrivate).toList(growable: false),
    );
  }

  Future<ChatMessagesData> getMessages(String conversationId) async {
    final auth = _auth;
    final authUser = auth.user;
    if (authUser == null) {
      throw ClientException(
        statusCode: 401,
        response: const {'message': 'Sesi telah berakhir'},
      );
    }

    final area = await resolveAreaAccessContext(auth);
    final conversation = await pb
        .collection(AppConstants.colConversations)
        .getOne(conversationId);

    if (!_canAccessConversation(
      auth: auth,
      context: area,
      conversation: conversation,
    )) {
      throw ClientException(
        statusCode: 403,
        response: const {'message': 'Akses percakapan ditolak.'},
      );
    }

    final membership = await _ensureMembership(
      conversationId: conversationId,
      userId: authUser.id,
    );
    final records = await pb.collection(AppConstants.colMessages).getFullList(
          sort: 'created',
          filter: 'conversation = "${_escapeFilterValue(conversationId)}"',
        );
    final replyIds = records
        .map((record) => _recordText(record, 'reply_to'))
        .where((id) => id.isNotEmpty)
        .toSet();
    final forwardedIds = records
        .map((record) => _recordText(record, 'forwarded_from'))
        .where((id) => id.isNotEmpty)
        .toSet();
    final relatedRecords = await _loadMessagesByIds({...replyIds, ...forwardedIds});
    final senderIds = <String>{
      ...records.map((record) => _recordText(record, 'sender')),
      ...relatedRecords.values.map((record) => _recordText(record, 'sender')),
    };
    final senderNames = await _loadSenderNames(senderIds);

    final updatedMembership = await _markConversationReadByMember(membership.id);

    return ChatMessagesData(
      conversation: _conversationFromRecord(
        conversation,
        currentUserId: authUser.id,
        membership: updatedMembership,
        unreadCount: 0,
      ),
      messages: records
          .map(
            (record) => _buildMessageModel(
              record,
              currentUserId: authUser.id,
              senderNames: senderNames,
              relatedRecords: relatedRecords,
            ),
          )
          .toList(growable: false),
    );
  }

  Future<MessageModel> sendMessage({
    required String conversationId,
    required String text,
    PlatformFile? attachment,
    String? replyToId,
    String? forwardedFromId,
  }) async {
    final auth = _auth;
    final authUser = auth.user;
    if (authUser == null) {
      throw ClientException(
        statusCode: 401,
        response: const {'message': 'Sesi telah berakhir'},
      );
    }

    final trimmedText = text.trim();
    if (trimmedText.isEmpty && attachment == null) {
      throw ClientException(
        statusCode: 400,
        response: const {'message': 'Pesan atau lampiran wajib diisi.'},
      );
    }

    final area = await resolveAreaAccessContext(auth);
    final conversation = await pb
        .collection(AppConstants.colConversations)
        .getOne(conversationId);

    if (!_canAccessConversation(
      auth: auth,
      context: area,
      conversation: conversation,
    )) {
      throw ClientException(
        statusCode: 403,
        response: const {'message': 'Akses percakapan ditolak.'},
      );
    }

    final membership = await _ensureMembership(
      conversationId: conversationId,
      userId: authUser.id,
    );
    final files = <http.MultipartFile>[];
    if (attachment != null) {
      files.add(await _multipartFromPlatformFile('attachment', attachment));
    }

    final body = <String, dynamic>{
      'conversation': conversationId,
      'sender': authUser.id,
      'text': trimmedText,
      'message_type': attachment != null ? 'file' : 'text',
      'is_starred': false,
      'is_pinned': false,
    };
    if ((replyToId ?? '').isNotEmpty) {
      body['reply_to'] = replyToId;
    }
    if ((forwardedFromId ?? '').isNotEmpty) {
      body['forwarded_from'] = forwardedFromId;
    }

    final record = await pb.collection(AppConstants.colMessages).create(
      body: body,
      files: files,
    );

    final preview = _previewForMessage(
      text: trimmedText,
      attachmentName: attachment?.name ?? _recordText(record, 'attachment'),
      isForwarded: (forwardedFromId ?? '').isNotEmpty,
      isReply: (replyToId ?? '').isNotEmpty,
    );
    await pb.collection(AppConstants.colConversations).update(
      conversationId,
      body: {
        'last_message': preview,
        'last_message_at': DateTime.now().toIso8601String(),
      },
    );

    await _markConversationReadByMember(membership.id);

    final relatedRecords = await _loadMessagesByIds({
      if ((replyToId ?? '').isNotEmpty) replyToId!,
      if ((forwardedFromId ?? '').isNotEmpty) forwardedFromId!,
    });
    final senderNames = await _loadSenderNames({
      authUser.id,
      ...relatedRecords.values.map((item) => _recordText(item, 'sender')),
    });

    return _buildMessageModel(
      record,
      currentUserId: authUser.id,
      senderNames: senderNames,
      relatedRecords: relatedRecords,
    );
  }

  Future<void> markConversationRead(String conversationId) async {
    final authUser = _auth.user;
    if (authUser == null) {
      return;
    }

    final membership = await _ensureMembership(
      conversationId: conversationId,
      userId: authUser.id,
    );
    await _markConversationReadByMember(membership.id);
  }

  Future<void> markConversationUnread(String conversationId) async {
    final authUser = _auth.user;
    if (authUser == null) {
      return;
    }

    final membership = await _ensureMembership(
      conversationId: conversationId,
      userId: authUser.id,
    );
    await pb.collection(AppConstants.colConversationMembers).update(
      membership.id,
      body: {'last_read_at': null},
    );
  }

  Future<void> setConversationPreference({
    required String conversationId,
    bool? isPinned,
    bool? isMuted,
    bool? isArchived,
  }) async {
    final authUser = _auth.user;
    if (authUser == null) {
      throw ClientException(
        statusCode: 401,
        response: const {'message': 'Sesi telah berakhir'},
      );
    }

    final membership = await _ensureMembership(
      conversationId: conversationId,
      userId: authUser.id,
    );
    final body = <String, dynamic>{};
    if (isPinned != null) {
      body['is_pinned'] = isPinned;
    }
    if (isMuted != null) {
      body['is_muted'] = isMuted;
    }
    if (isArchived != null) {
      body['is_archived'] = isArchived;
    }
    if (body.isEmpty) {
      return;
    }

    await pb.collection(AppConstants.colConversationMembers).update(
          membership.id,
          body: body,
        );
  }

  Future<void> toggleMessageStar(String messageId) async {
    final message = await _loadAccessibleMessage(messageId);
    await pb.collection(AppConstants.colMessages).update(
      message.id,
      body: {'is_starred': !(message.data['is_starred'] == true)},
    );
  }

  Future<void> toggleMessagePin(String messageId) async {
    final message = await _loadAccessibleMessage(messageId);
    await pb.collection(AppConstants.colMessages).update(
      message.id,
      body: {'is_pinned': !(message.data['is_pinned'] == true)},
    );
  }

  Future<void> deleteMessage(String messageId) async {
    final authUser = _auth.user;
    if (authUser == null) {
      throw ClientException(
        statusCode: 401,
        response: const {'message': 'Sesi telah berakhir'},
      );
    }

    final message = await _loadAccessibleMessage(messageId);
    if (_recordText(message, 'sender') != authUser.id && !_auth.isSysadmin) {
      throw ClientException(
        statusCode: 403,
        response: const {'message': 'Hanya pengirim yang dapat menghapus pesan.'},
      );
    }

    await pb.collection(AppConstants.colMessages).update(
      message.id,
      body: {
        'text': '',
        'deleted_at': DateTime.now().toIso8601String(),
        'deleted_by': authUser.id,
      },
    );
    await _syncConversationPreview(_recordText(message, 'conversation'));
  }

  Future<void> forwardMessage({
    required String messageId,
    required String targetConversationId,
  }) async {
    final message = await _loadAccessibleMessage(messageId);
    final attachmentUrl = _fileUrl(message, 'attachment');
    final files = <http.MultipartFile>[];
    if ((attachmentUrl ?? '').isNotEmpty) {
      files.add(
        await _multipartFromUrl(
          'attachment',
          attachmentUrl!,
          filename: _recordText(message, 'attachment'),
        ),
      );
    }

    final text = _recordText(message, 'text');
    final authUser = _auth.user;
    if (authUser == null) {
      throw ClientException(
        statusCode: 401,
        response: const {'message': 'Sesi telah berakhir'},
      );
    }

    final targetConversation = await pb
        .collection(AppConstants.colConversations)
        .getOne(targetConversationId);
    final area = await resolveAreaAccessContext(_auth);
    if (!_canAccessConversation(
      auth: _auth,
      context: area,
      conversation: targetConversation,
    )) {
      throw ClientException(
        statusCode: 403,
        response: const {'message': 'Tujuan forward tidak dapat diakses.'},
      );
    }

    final created = await pb.collection(AppConstants.colMessages).create(
      body: {
        'conversation': targetConversationId,
        'sender': authUser.id,
        'text': text,
        'message_type': files.isNotEmpty ? 'file' : 'text',
        'forwarded_from': messageId,
        'is_starred': false,
        'is_pinned': false,
      },
      files: files,
    );

    await pb.collection(AppConstants.colConversations).update(
      targetConversationId,
      body: {
        'last_message': _previewForMessage(
          text: text,
          attachmentName: _recordText(created, 'attachment'),
          isForwarded: true,
          isReply: false,
        ),
        'last_message_at': DateTime.now().toIso8601String(),
      },
    );
  }

  Future<ChatAnnouncementsData> getAnnouncements() async {
    final auth = _auth;
    final authUser = auth.user;
    if (authUser == null) {
      throw ClientException(
        statusCode: 401,
        response: const {'message': 'Sesi telah berakhir'},
      );
    }

    final role = AppConstants.normalizeRole(auth.role);
    final area = await resolveAreaAccessContext(auth);
    final records = await pb.collection(AppConstants.colAnnouncements).getFullList(
          sort: '-created',
        );
    final authorNames = await _loadSenderNames(
      records.map((record) => _recordText(record, 'author')).toSet(),
    );

    final items = records
        .where(
          (record) => _canAccessAnnouncement(
            auth: auth,
            context: area,
            record: record,
          ),
        )
        .map(
          (record) => AnnouncementModel(
            id: record.id,
            title: _recordText(record, 'title'),
            content: _recordText(record, 'content'),
            targetType: _recordText(record, 'target_type').isEmpty
                ? 'rw'
                : _recordText(record, 'target_type'),
            rt: _recordInt(record, 'rt'),
            rw: _recordInt(record, 'rw'),
            authorName:
                authorNames[_recordText(record, 'author')] ?? 'Pengurus',
            createdAt: DateTime.tryParse(_recordText(record, 'created')),
          ),
        )
        .toList(growable: false);

    return ChatAnnouncementsData(
      canCreate: _canCreateAnnouncement(role),
      items: items,
    );
  }

  Future<AnnouncementModel> createAnnouncement({
    required String title,
    required String content,
    required String targetType,
    int? targetRt,
    int? targetRw,
  }) async {
    final auth = _auth;
    final authUser = auth.user;
    if (authUser == null) {
      throw ClientException(
        statusCode: 401,
        response: const {'message': 'Sesi telah berakhir'},
      );
    }

    final role = AppConstants.normalizeRole(auth.role);
    if (!_canCreateAnnouncement(role)) {
      throw ClientException(
        statusCode: 403,
        response: const {'message': 'Hanya admin yang dapat membuat pengumuman.'},
      );
    }

    final area = await resolveAreaAccessContext(auth);
    if (!area.hasArea && !auth.isSysadmin) {
      throw ClientException(
        statusCode: 400,
        response: const {'message': 'Area admin belum lengkap.'},
      );
    }

    final normalizedTarget = role == AppConstants.roleAdminRt
        ? 'rt'
        : targetType.trim().toLowerCase() == 'rt'
            ? 'rt'
            : 'rw';
    final rt = normalizedTarget == 'rt' ? (targetRt ?? area.rt ?? 0) : 0;
    final rw = targetRw ?? area.rw ?? 0;

    final record = await pb.collection(AppConstants.colAnnouncements).create(
      body: {
        'author': authUser.id,
        'title': title.trim(),
        'content': content.trim(),
        'target_type': normalizedTarget,
        'rt': rt,
        'rw': rw,
        'desa_code': area.desaCode ?? '',
        'kecamatan_code': area.kecamatanCode ?? '',
        'kabupaten_code': area.kabupatenCode ?? '',
        'provinsi_code': area.provinsiCode ?? '',
        'desa_kelurahan': area.desaKelurahan ?? '',
        'kecamatan': area.kecamatan ?? '',
        'kabupaten_kota': area.kabupatenKota ?? '',
        'provinsi': area.provinsi ?? '',
        'is_published': true,
      },
    );

    return AnnouncementModel(
      id: record.id,
      title: _recordText(record, 'title'),
      content: _recordText(record, 'content'),
      targetType: _recordText(record, 'target_type').isEmpty
          ? 'rw'
          : _recordText(record, 'target_type'),
      rt: _recordInt(record, 'rt'),
      rw: _recordInt(record, 'rw'),
      authorName: await _resolveSenderName(authUser.id) ?? _userDisplayName(authUser),
      createdAt: DateTime.tryParse(_recordText(record, 'created')),
    );
  }

  Future<_ChatScope> _buildScopeForAuthUser(
    AuthState auth,
    AreaAccessContext area,
  ) async {
    final user = auth.user!;
    String displayName = _userDisplayName(user);
    if ((area.wargaId ?? '').isNotEmpty) {
      try {
        final warga = await pb.collection(AppConstants.colWarga).getOne(
              area.wargaId!,
            );
        final wargaName = _recordText(warga, 'nama_lengkap');
        if (wargaName.isNotEmpty) {
          displayName = wargaName;
        }
      } catch (_) {}
    }

    return _ChatScope(
      userId: user.id,
      displayName: displayName,
      rt: area.rt ?? 0,
      rw: area.rw ?? 0,
      desaCode: area.desaCode ?? '',
      kecamatanCode: area.kecamatanCode ?? '',
      kabupatenCode: area.kabupatenCode ?? '',
      provinsiCode: area.provinsiCode ?? '',
      desaKelurahan: area.desaKelurahan ?? '',
      kecamatan: area.kecamatan ?? '',
      kabupatenKota: area.kabupatenKota ?? '',
      provinsi: area.provinsi ?? '',
    );
  }

  Future<List<_ChatScope>> _fetchScopedWargaScopes(
    AuthState auth,
    AreaAccessContext area,
  ) async {
    final records = await pb.collection(AppConstants.colWarga).getFullList(
          sort: 'nama_lengkap',
          filter: buildWargaScopeFilter(auth, context: area),
        );

    final kkCache = <String, Future<RecordModel?>>{};
    final result = <_ChatScope>[];

    for (final warga in records) {
      final userId = _recordText(warga, 'user_id');
      final kkId = _recordText(warga, 'no_kk');
      if (userId.isEmpty || kkId.isEmpty) {
        continue;
      }

      kkCache.putIfAbsent(
        kkId,
        () async {
          try {
            return await pb.collection(AppConstants.colKartuKeluarga).getOne(
                  kkId,
                );
          } catch (_) {
            return null;
          }
        },
      );

      final kkRecord = await kkCache[kkId];
      if (kkRecord == null) {
        continue;
      }

      result.add(
        _ChatScope(
          userId: userId,
          displayName: _recordText(warga, 'nama_lengkap'),
          rt: _recordInt(warga, 'rt'),
          rw: _recordInt(warga, 'rw'),
          desaCode: _recordText(kkRecord, 'desa_code'),
          kecamatanCode: _recordText(kkRecord, 'kecamatan_code'),
          kabupatenCode: _recordText(kkRecord, 'kabupaten_code'),
          provinsiCode: _recordText(kkRecord, 'provinsi_code'),
          desaKelurahan: _recordText(kkRecord, 'desa_kelurahan'),
          kecamatan: _recordText(kkRecord, 'kecamatan'),
          kabupatenKota: _recordText(kkRecord, 'kabupaten_kota'),
          provinsi: _recordText(kkRecord, 'provinsi'),
        ),
      );
    }

    return result;
  }

  Future<RecordModel?> _ensurePrivateSupportConversation({
    required _ChatScope scope,
    required String createdBy,
  }) async {
    if (!scope.hasArea || scope.userId.isEmpty) {
      return null;
    }

    final key =
        'private:${scope.userId}:${scope.provinsiCodeOrName}:${scope.kabupatenCodeOrName}';
    return _ensureConversation(
      key: key,
      type: AppConstants.convPrivate,
      name: 'Layanan - ${scope.displayName.isEmpty ? 'Warga' : scope.displayName}',
      owner: scope.userId,
      createdBy: createdBy,
      scope: scope,
    );
  }

  Future<RecordModel?> _ensureRtConversation({
    required _ChatScope scope,
    required String createdBy,
  }) async {
    if (!scope.hasArea) {
      return null;
    }

    final key =
        'group_rt:${scope.rw}:${scope.rt}:${scope.provinsiCodeOrName}:${scope.kabupatenCodeOrName}:${scope.kecamatanCodeOrName}:${scope.desaCodeOrName}';
    return _ensureConversation(
      key: key,
      type: AppConstants.convGroupRt,
      name:
          'Grup RT ${scope.rt.toString().padLeft(2, '0')} / RW ${scope.rw.toString().padLeft(2, '0')}',
      owner: '',
      createdBy: createdBy,
      scope: scope,
    );
  }

  Future<RecordModel?> _ensureRwConversation({
    required _ChatScope scope,
    required String createdBy,
  }) async {
    if (!scope.hasArea) {
      return null;
    }

    final key =
        'group_rw:${scope.rw}:${scope.provinsiCodeOrName}:${scope.kabupatenCodeOrName}:${scope.kecamatanCodeOrName}:${scope.desaCodeOrName}';
    return _ensureConversation(
      key: key,
      type: AppConstants.convGroupRw,
      name: 'Forum RW ${scope.rw.toString().padLeft(2, '0')}',
      owner: '',
      createdBy: createdBy,
      scope: scope,
    );
  }

  Future<RecordModel> _ensureConversation({
    required String key,
    required String type,
    required String name,
    required String owner,
    required String createdBy,
    required _ChatScope scope,
  }) async {
    try {
      return await pb.collection(AppConstants.colConversations).getFirstListItem(
            'key = "${_escapeFilterValue(key)}"',
          );
    } on ClientException catch (error) {
      if (error.statusCode != 404) {
        rethrow;
      }
    }

    final body = <String, dynamic>{
      'key': key,
      'type': type,
      'name': name,
      'created_by': createdBy,
      'rt': scope.rt,
      'rw': scope.rw,
      'desa_code': scope.desaCode,
      'kecamatan_code': scope.kecamatanCode,
      'kabupaten_code': scope.kabupatenCode,
      'provinsi_code': scope.provinsiCode,
      'desa_kelurahan': scope.desaKelurahan,
      'kecamatan': scope.kecamatan,
      'kabupaten_kota': scope.kabupatenKota,
      'provinsi': scope.provinsi,
      'is_readonly': false,
      'last_message': '',
    };
    if (owner.isNotEmpty) {
      body['owner'] = owner;
    }

    return pb.collection(AppConstants.colConversations).create(body: body);
  }

  Future<Map<String, RecordModel>> _ensureAndLoadMemberships({
    required Iterable<RecordModel> conversations,
    required String userId,
  }) async {
    final result = <String, RecordModel>{};
    for (final conversation in conversations) {
      final membership = await _ensureMembership(
        conversationId: conversation.id,
        userId: userId,
      );
      result[conversation.id] = membership;
    }
    return result;
  }

  Future<RecordModel> _ensureMembership({
    required String conversationId,
    required String userId,
  }) async {
    try {
      return await pb
          .collection(AppConstants.colConversationMembers)
          .getFirstListItem(
            'conversation = "${_escapeFilterValue(conversationId)}" && user = "${_escapeFilterValue(userId)}"',
          );
    } on ClientException catch (error) {
      if (error.statusCode != 404) {
        rethrow;
      }
    }

    return pb.collection(AppConstants.colConversationMembers).create(
      body: {
        'conversation': conversationId,
        'user': userId,
        'member_role': 'participant',
        'last_read_at': null,
        'is_muted': false,
        'is_pinned': false,
        'is_archived': false,
      },
    );
  }

  Future<Map<String, int>> _loadUnreadCounts({
    required Iterable<RecordModel> conversations,
    required String userId,
    required Map<String, RecordModel> memberships,
  }) async {
    final result = <String, int>{};
    for (final conversation in conversations) {
      final membership = memberships[conversation.id];
      final readAt =
          membership == null ? '' : _recordText(membership, 'last_read_at');
      final conditions = <String>[
        'conversation = "${_escapeFilterValue(conversation.id)}"',
        'sender != "${_escapeFilterValue(userId)}"',
      ];
      if (readAt.isNotEmpty) {
        conditions.add('created > "${_escapeFilterValue(readAt)}"');
      }

      final page = await pb.collection(AppConstants.colMessages).getList(
            page: 1,
            perPage: 1,
            filter: conditions.join(' && '),
          );
      result[conversation.id] = page.totalItems;
    }
    return result;
  }

  Future<RecordModel> _markConversationReadByMember(String memberId) {
    return pb.collection(AppConstants.colConversationMembers).update(
      memberId,
      body: {'last_read_at': DateTime.now().toIso8601String()},
    );
  }

  bool _canAccessConversation({
    required AuthState auth,
    required AreaAccessContext context,
    required RecordModel conversation,
  }) {
    if (auth.user == null) {
      return false;
    }
    if (auth.isSysadmin) {
      return true;
    }
    if (!context.hasArea) {
      return false;
    }

    final role = AppConstants.normalizeRole(auth.role);
    final type = _recordText(conversation, 'type');
    final target = _ConversationScope.fromRecord(conversation);

    if (type == AppConstants.convPrivate) {
      if (_recordText(conversation, 'owner') == auth.user!.id) {
        return true;
      }
      if (role == AppConstants.roleWarga) {
        return false;
      }
      return _matchesScope(context, target, role);
    }

    if (type == AppConstants.convGroupRt) {
      return _matchesScope(context, target, role);
    }

    if (type == AppConstants.convGroupRw) {
      if (role == AppConstants.roleWarga) {
        return false;
      }
      return _matchesRwScope(context, target, role);
    }

    return false;
  }

  bool _canAccessAnnouncement({
    required AuthState auth,
    required AreaAccessContext context,
    required RecordModel record,
  }) {
    if (auth.isSysadmin) {
      return true;
    }
    if (!context.hasArea) {
      return false;
    }
    if (record.data['is_published'] != true) {
      return false;
    }

    final target = _ConversationScope.fromRecord(record);
    if (!_matchesRegion(context, target)) {
      return false;
    }
    if (target.rw != (context.rw ?? 0)) {
      return false;
    }

    final targetType = _recordText(record, 'target_type');
    if (targetType == 'rw') {
      return true;
    }

    final role = AppConstants.normalizeRole(auth.role);
    return target.rt == (context.rt ?? 0) ||
        role == AppConstants.roleAdminRw ||
        role == AppConstants.roleAdminRwPro;
  }

  Future<Map<String, String>> _loadSenderNames(Set<String> userIds) async {
    final result = <String, String>{};
    for (final userId in userIds.where((item) => item.isNotEmpty)) {
      final name = await _resolveSenderName(userId);
      if (name != null && name.isNotEmpty) {
        result[userId] = name;
      }
    }
    return result;
  }

  Future<String?> _resolveSenderName(String userId) async {
    try {
      final warga = await pb.collection(AppConstants.colWarga).getFirstListItem(
            'user_id = "${_escapeFilterValue(userId)}"',
          );
      final wargaName = _recordText(warga, 'nama_lengkap');
      if (wargaName.isNotEmpty) {
        return wargaName;
      }
    } catch (_) {}

    try {
      final user = await pb.collection(AppConstants.colUsers).getOne(userId);
      final userName = _userDisplayName(user);
      if (userName.isNotEmpty) {
        return userName;
      }
    } catch (_) {}

    return null;
  }

  Future<Map<String, RecordModel>> _loadMessagesByIds(Set<String> ids) async {
    final result = <String, RecordModel>{};
    for (final id in ids.where((item) => item.isNotEmpty)) {
      try {
        final record = await pb.collection(AppConstants.colMessages).getOne(id);
        result[id] = record;
      } catch (_) {}
    }
    return result;
  }

  Future<RecordModel> _loadAccessibleMessage(String messageId) async {
    final auth = _auth;
    final authUser = auth.user;
    if (authUser == null) {
      throw ClientException(
        statusCode: 401,
        response: const {'message': 'Sesi telah berakhir'},
      );
    }

    final message = await pb.collection(AppConstants.colMessages).getOne(messageId);
    final conversationId = _recordText(message, 'conversation');
    final conversation = await pb
        .collection(AppConstants.colConversations)
        .getOne(conversationId);
    final area = await resolveAreaAccessContext(auth);
    if (!_canAccessConversation(
      auth: auth,
      context: area,
      conversation: conversation,
    )) {
      throw ClientException(
        statusCode: 403,
        response: const {'message': 'Akses pesan ditolak.'},
      );
    }
    return message;
  }

  MessageModel _buildMessageModel(
    RecordModel record, {
    required String currentUserId,
    required Map<String, String> senderNames,
    required Map<String, RecordModel> relatedRecords,
  }) {
    final replyId = _recordText(record, 'reply_to');
    final replyRecord = relatedRecords[replyId];
    final forwardedId = _recordText(record, 'forwarded_from');
    final forwardedRecord = relatedRecords[forwardedId];
    final isDeleted = _recordText(record, 'deleted_at').isNotEmpty;

    return MessageModel(
      id: record.id,
      conversationId: _recordText(record, 'conversation'),
      senderId: _recordText(record, 'sender'),
      senderName: senderNames[_recordText(record, 'sender')] ?? 'Pengguna',
      text: _recordText(record, 'text'),
      messageType: _recordText(record, 'message_type').isEmpty
          ? 'text'
          : _recordText(record, 'message_type'),
      isMine: _recordText(record, 'sender') == currentUserId,
      isStarred: record.data['is_starred'] == true,
      isPinned: record.data['is_pinned'] == true,
      isDeleted: isDeleted,
      attachmentName: isDeleted || _recordText(record, 'attachment').isEmpty
          ? null
          : _recordText(record, 'attachment'),
      attachmentUrl: isDeleted ? null : _fileUrl(record, 'attachment'),
      replyToId: replyId.isEmpty ? null : replyId,
      replySenderName: replyRecord == null
          ? null
          : senderNames[_recordText(replyRecord, 'sender')] ?? 'Pengguna',
      replySnippet: replyRecord == null
          ? null
          : _recordText(replyRecord, 'text').isNotEmpty
              ? _recordText(replyRecord, 'text')
              : _recordText(replyRecord, 'attachment').isNotEmpty
                  ? 'Lampiran: ${_recordText(replyRecord, 'attachment')}'
                  : 'Pesan',
      forwardedFromId: forwardedId.isEmpty ? null : forwardedId,
      forwardedFromName: forwardedRecord == null
          ? null
          : senderNames[_recordText(forwardedRecord, 'sender')] ?? 'Pengguna',
      createdAt: DateTime.tryParse(_recordText(record, 'created')),
    );
  }

  ConversationModel _conversationFromRecord(
    RecordModel record, {
    required String currentUserId,
    RecordModel? membership,
    required int unreadCount,
  }) {
    final type = _recordText(record, 'type');
    final isOwner = _recordText(record, 'owner') == currentUserId;
    final title = type == AppConstants.convPrivate && isOwner
        ? 'Inbox Admin RT/RW'
        : _recordText(record, 'name');

    return ConversationModel(
      id: record.id,
      key: _recordText(record, 'key'),
      type: type,
      name: title,
      subtitle: type == AppConstants.convPrivate
          ? (isOwner
              ? 'Gunakan untuk tanya dokumen, surat, iuran, dan layanan.'
              : 'Percakapan layanan warga.')
          : type == AppConstants.convGroupRt
              ? 'Forum operasional warga dan pengurus di RT ini.'
              : 'Koordinasi lintas RT untuk pengurus RW.',
      rt: _recordInt(record, 'rt'),
      rw: _recordInt(record, 'rw'),
      isReadonly: record.data['is_readonly'] == true,
      unreadCount: unreadCount,
      isPinned: membership?.data['is_pinned'] == true,
      isMuted: membership?.data['is_muted'] == true,
      isArchived: membership?.data['is_archived'] == true,
      lastMessage: _recordText(record, 'last_message').isEmpty
          ? null
          : _recordText(record, 'last_message'),
      lastMessageAt: DateTime.tryParse(
        _recordText(record, 'last_message_at').isNotEmpty
            ? _recordText(record, 'last_message_at')
            : _recordText(record, 'updated'),
      ),
    );
  }

  int _compareConversationModels(ConversationModel left, ConversationModel right) {
    if (left.isPinned != right.isPinned) {
      return left.isPinned ? -1 : 1;
    }

    final leftTime = left.lastMessageAt?.toIso8601String() ?? '';
    final rightTime = right.lastMessageAt?.toIso8601String() ?? '';
    if (leftTime != rightTime) {
      return rightTime.compareTo(leftTime);
    }

    return left.name.toLowerCase().compareTo(right.name.toLowerCase());
  }

  bool _matchesScope(
    AreaAccessContext context,
    _ConversationScope target,
    String role,
  ) {
    if (!_matchesRegion(context, target)) {
      return false;
    }
    if (target.rw <= 0 || target.rw != (context.rw ?? 0)) {
      return false;
    }
    if (AppConstants.hasRwWideAccess(role)) {
      return true;
    }
    return target.rt > 0 && target.rt == (context.rt ?? 0);
  }

  bool _matchesRwScope(
    AreaAccessContext context,
    _ConversationScope target,
    String role,
  ) {
    if (role == AppConstants.roleWarga) {
      return false;
    }
    if (!_matchesRegion(context, target)) {
      return false;
    }
    return target.rw > 0 && target.rw == (context.rw ?? 0);
  }

  bool _matchesRegion(AreaAccessContext context, _ConversationScope target) {
    final hasCodes = (context.desaCode ?? '').isNotEmpty &&
        (context.kecamatanCode ?? '').isNotEmpty &&
        (context.kabupatenCode ?? '').isNotEmpty &&
        (context.provinsiCode ?? '').isNotEmpty &&
        target.desaCode.isNotEmpty &&
        target.kecamatanCode.isNotEmpty &&
        target.kabupatenCode.isNotEmpty &&
        target.provinsiCode.isNotEmpty;
    if (hasCodes) {
      return target.desaCode == context.desaCode &&
          target.kecamatanCode == context.kecamatanCode &&
          target.kabupatenCode == context.kabupatenCode &&
          target.provinsiCode == context.provinsiCode;
    }

    return _normalizeAreaValue(target.desaKelurahan) ==
            _normalizeAreaValue(context.desaKelurahan) &&
        _normalizeAreaValue(target.kecamatan) ==
            _normalizeAreaValue(context.kecamatan) &&
        _normalizeAreaValue(target.kabupatenKota) ==
            _normalizeAreaValue(context.kabupatenKota) &&
        _normalizeAreaValue(target.provinsi) ==
            _normalizeAreaValue(context.provinsi);
  }

  bool _canCreateAnnouncement(String role) {
    final normalized = AppConstants.normalizeRole(role);
    return normalized == AppConstants.roleAdminRt ||
        normalized == AppConstants.roleAdminRw ||
        normalized == AppConstants.roleAdminRwPro ||
        normalized == AppConstants.roleSysadmin;
  }

  Future<http.MultipartFile> _multipartFromPlatformFile(
    String field,
    PlatformFile file,
  ) async {
    if (file.bytes != null) {
      return http.MultipartFile.fromBytes(
        field,
        file.bytes!,
        filename: file.name,
      );
    }
    if ((file.path ?? '').isNotEmpty) {
      return http.MultipartFile.fromPath(
        field,
        file.path!,
        filename: file.name,
      );
    }
    throw ClientException(
      statusCode: 400,
      response: const {'message': 'File lampiran tidak valid.'},
    );
  }

  Future<http.MultipartFile> _multipartFromUrl(
    String field,
    String url, {
    required String filename,
  }) async {
    final response = await http.get(Uri.parse(url));
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw ClientException(
        statusCode: 400,
        response: const {'message': 'Lampiran forward tidak dapat diunduh.'},
      );
    }
    return http.MultipartFile.fromBytes(
      field,
      response.bodyBytes,
      filename: filename,
    );
  }

  String _previewForMessage({
    required String text,
    required String attachmentName,
    required bool isForwarded,
    required bool isReply,
  }) {
    final base = text.trim().isNotEmpty
        ? text.trim()
        : 'Lampiran: ${attachmentName.isEmpty ? 'file' : attachmentName}';
    if (isForwarded) {
      return 'Meneruskan: $base';
    }
    if (isReply) {
      return 'Balasan: $base';
    }
    return base;
  }

  Future<void> _syncConversationPreview(String conversationId) async {
    final latest = await pb.collection(AppConstants.colMessages).getList(
          page: 1,
          perPage: 1,
          sort: '-created',
          filter: 'conversation = "${_escapeFilterValue(conversationId)}"',
        );
    if (latest.items.isEmpty) {
      await pb.collection(AppConstants.colConversations).update(
        conversationId,
        body: {
          'last_message': '',
          'last_message_at': null,
        },
      );
      return;
    }

    final record = latest.items.first;
    final preview = _recordText(record, 'deleted_at').isNotEmpty
        ? 'Pesan dihapus'
        : _previewForMessage(
            text: _recordText(record, 'text'),
            attachmentName: _recordText(record, 'attachment'),
            isForwarded: _recordText(record, 'forwarded_from').isNotEmpty,
            isReply: _recordText(record, 'reply_to').isNotEmpty,
          );
    await pb.collection(AppConstants.colConversations).update(
      conversationId,
      body: {
        'last_message': preview,
        'last_message_at': _recordText(record, 'created'),
      },
    );
  }

  String? _fileUrl(RecordModel record, String field) {
    final filename = _recordText(record, field);
    if (filename.isEmpty) {
      return null;
    }
    return pb.files.getUrl(record, filename).toString();
  }
}

final chatServiceProvider = Provider<ChatService>((ref) => ChatService(ref));

class _ChatScope {
  const _ChatScope({
    required this.userId,
    required this.displayName,
    required this.rt,
    required this.rw,
    required this.desaCode,
    required this.kecamatanCode,
    required this.kabupatenCode,
    required this.provinsiCode,
    required this.desaKelurahan,
    required this.kecamatan,
    required this.kabupatenKota,
    required this.provinsi,
  });

  final String userId;
  final String displayName;
  final int rt;
  final int rw;
  final String desaCode;
  final String kecamatanCode;
  final String kabupatenCode;
  final String provinsiCode;
  final String desaKelurahan;
  final String kecamatan;
  final String kabupatenKota;
  final String provinsi;

  bool get hasArea => rt > 0 && rw > 0;
  String get desaCodeOrName =>
      desaCode.isNotEmpty ? desaCode : _normalizeAreaValue(desaKelurahan);
  String get kecamatanCodeOrName => kecamatanCode.isNotEmpty
      ? kecamatanCode
      : _normalizeAreaValue(kecamatan);
  String get kabupatenCodeOrName => kabupatenCode.isNotEmpty
      ? kabupatenCode
      : _normalizeAreaValue(kabupatenKota);
  String get provinsiCodeOrName =>
      provinsiCode.isNotEmpty ? provinsiCode : _normalizeAreaValue(provinsi);
}

class _ConversationScope {
  const _ConversationScope({
    required this.rt,
    required this.rw,
    required this.desaCode,
    required this.kecamatanCode,
    required this.kabupatenCode,
    required this.provinsiCode,
    required this.desaKelurahan,
    required this.kecamatan,
    required this.kabupatenKota,
    required this.provinsi,
  });

  factory _ConversationScope.fromRecord(RecordModel record) {
    return _ConversationScope(
      rt: _recordInt(record, 'rt'),
      rw: _recordInt(record, 'rw'),
      desaCode: _recordText(record, 'desa_code'),
      kecamatanCode: _recordText(record, 'kecamatan_code'),
      kabupatenCode: _recordText(record, 'kabupaten_code'),
      provinsiCode: _recordText(record, 'provinsi_code'),
      desaKelurahan: _recordText(record, 'desa_kelurahan'),
      kecamatan: _recordText(record, 'kecamatan'),
      kabupatenKota: _recordText(record, 'kabupaten_kota'),
      provinsi: _recordText(record, 'provinsi'),
    );
  }

  final int rt;
  final int rw;
  final String desaCode;
  final String kecamatanCode;
  final String kabupatenCode;
  final String provinsiCode;
  final String desaKelurahan;
  final String kecamatan;
  final String kabupatenKota;
  final String provinsi;
}

String _escapeFilterValue(String value) {
  return value.replaceAll(r'\', r'\\').replaceAll('"', r'\"');
}

String _recordText(RecordModel record, String field) {
  final fromGetter = record.getStringValue(field).trim();
  if (fromGetter.isNotEmpty) {
    return fromGetter;
  }
  return record.data[field]?.toString().trim() ?? '';
}

int _recordInt(RecordModel record, String field) {
  final raw = record.data[field];
  if (raw is int) {
    return raw;
  }
  return int.tryParse(_recordText(record, field)) ?? 0;
}

String _normalizeAreaValue(String? value) {
  return (value ?? '').trim().toLowerCase();
}

String _userDisplayName(RecordModel user) {
  final name = user.getStringValue('name').trim();
  if (name.isNotEmpty) {
    return name;
  }
  final email = user.getStringValue('email').trim();
  if (email.isNotEmpty && email.contains('@')) {
    return email.split('@').first;
  }
  return 'Pengguna';
}
