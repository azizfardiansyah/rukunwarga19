import 'package:file_picker/file_picker.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:http/http.dart' as http;
import 'package:pocketbase/pocketbase.dart';

import '../../features/auth/providers/auth_provider.dart';
import '../../shared/models/chat_model.dart';
import '../../shared/models/workspace_access_model.dart';
import '../constants/app_constants.dart';
import '../utils/area_access.dart';
import 'pocketbase_service.dart';
import 'workspace_access_service.dart';

class ChatService {
  ChatService(this._ref);

  final Ref _ref;
  static const String _chatProfilesPath = '/api/rukunwarga/chat-users';
  static final Map<String, _CachedChatBootstrap> _bootstrapCache = {};
  static final Map<String, Future<ChatBootstrapData>>
      _inflightBootstrapRequests = {};
  static final Map<String, _CachedChatMessages> _messagesCache = {};
  static final Map<String, Future<ChatMessagesData>> _inflightMessageRequests =
      {};
  static const Duration _defaultBootstrapCacheAge = Duration(seconds: 3);
  static const Duration _defaultMessagesCacheAge = Duration(minutes: 30);
  bool? _conversationMembersCollectionAvailable;
  bool? _announcementViewsCollectionAvailable;

  AuthState get _auth => _ref.read(authProvider);

  ChatBootstrapData? getCachedBootstrap({
    Duration maxAge = _defaultBootstrapCacheAge,
  }) {
    final authUser = _auth.user;
    if (authUser == null) {
      return null;
    }
    final cached = _bootstrapCache[authUser.id];
    if (cached == null) {
      return null;
    }
    if (DateTime.now().toUtc().difference(cached.cachedAt) > maxAge) {
      _bootstrapCache.remove(authUser.id);
      return null;
    }
    return cached.data;
  }

  void invalidateBootstrapCache({String? userId}) {
    final effectiveUserId = (userId ?? _auth.user?.id ?? '').trim();
    if (effectiveUserId.isEmpty) {
      _bootstrapCache.clear();
      return;
    }
    _bootstrapCache.remove(effectiveUserId);
  }

  ChatMessagesData? getCachedMessages(
    String conversationId, {
    Duration maxAge = _defaultMessagesCacheAge,
  }) {
    final cached = _messagesCache[conversationId];
    if (cached == null) {
      return null;
    }
    if (DateTime.now().toUtc().difference(cached.cachedAt) > maxAge) {
      _messagesCache.remove(conversationId);
      return null;
    }
    return cached.data;
  }

  void cacheMessagesData(ChatMessagesData data) {
    if (data.conversation.id.trim().isEmpty) {
      return;
    }
    _messagesCache[data.conversation.id] = _CachedChatMessages(
      data: data,
      cachedAt: DateTime.now().toUtc(),
    );
  }

  Future<ChatBootstrapData> bootstrap({bool forceRefresh = false}) async {
    final auth = _auth;
    final authUser = auth.user;
    if (authUser == null) {
      throw ClientException(
        statusCode: 401,
        response: const {'message': 'Sesi telah berakhir'},
      );
    }

    final cacheKey = authUser.id;
    if (!forceRefresh) {
      final cached = getCachedBootstrap();
      if (cached != null) {
        return cached;
      }
      final inFlight = _inflightBootstrapRequests[cacheKey];
      if (inFlight != null) {
        return inFlight;
      }
    }

    final request = _bootstrapFromServer(auth: auth, authUser: authUser);
    _inflightBootstrapRequests[cacheKey] = request;
    try {
      final data = await request;
      _bootstrapCache[cacheKey] = _CachedChatBootstrap(
        data: data,
        cachedAt: DateTime.now().toUtc(),
      );
      return data;
    } finally {
      if (identical(_inflightBootstrapRequests[cacheKey], request)) {
        _inflightBootstrapRequests.remove(cacheKey);
      }
    }
  }

  Future<ChatBootstrapData> _bootstrapFromServer({
    required AuthState auth,
    required RecordModel authUser,
  }) async {
    final area = await resolveAreaAccessContext(auth);
    final ensured = <RecordModel>[];

    if (auth.isSysadmin) {
      ensured.addAll(
        await pb
            .collection(AppConstants.colConversations)
            .getFullList(sort: '-updated'),
      );
    } else if (area.hasArea) {
      final selfScope = await _buildScopeForAuthUser(auth, area);
      if (_isWarga(auth)) {
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
        if (_isRtScopedOperator(auth)) {
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
        if (_hasRwWideAccess(auth)) {
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

          if (_hasRwWideAccess(auth)) {
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

    final accessible = <RecordModel>[];
    for (final record in unique.values) {
      if (await _canAccessConversation(
        auth: auth,
        context: area,
        conversation: record,
      )) {
        accessible.add(record);
      }
    }

    final memberships = await _ensureAndLoadMemberships(
      conversations: accessible,
      userId: authUser.id,
    );
    final unreadCounts = await _loadUnreadCounts(
      conversations: accessible,
      userId: authUser.id,
      memberships: memberships,
    );
    final userProfiles = await _loadChatUserProfiles({
      authUser.id,
      ...accessible.map((record) => _recordText(record, 'owner')),
    });
    final hydratedUserProfiles = await _enrichPrivateConversationOwnerProfiles(
      conversations: accessible,
      profiles: userProfiles,
    );

    final models =
        accessible
            .map(
              (record) => _conversationFromRecord(
                record,
                currentUserId: authUser.id,
                membership: memberships[record.id],
                unreadCount: unreadCounts[record.id] ?? 0,
                userProfiles: hydratedUserProfiles,
              ),
            )
            .toList()
          ..sort(_compareConversationModels);

    return ChatBootstrapData(
      role: auth.role,
      systemRole: auth.systemRole,
      planCode: auth.planCode,
      canCreateAnnouncement: _canCreateAnnouncement(auth),
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
    final inFlight = _inflightMessageRequests[conversationId];
    if (inFlight != null) {
      return inFlight;
    }

    final request = _fetchMessagesFromServer(conversationId);
    _inflightMessageRequests[conversationId] = request;
    try {
      final data = await request;
      cacheMessagesData(data);
      return data;
    } finally {
      if (identical(_inflightMessageRequests[conversationId], request)) {
        _inflightMessageRequests.remove(conversationId);
      }
    }
  }

  Future<ChatMessagesData> _fetchMessagesFromServer(
    String conversationId,
  ) async {
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

    final existingMemberships = await _loadMembershipRecords(
      conversationId: conversationId,
      userId: authUser.id,
    );
    final canAccessConversation = await _canAccessConversation(
      auth: auth,
      context: area,
      conversation: conversation,
    );
    if (!canAccessConversation && existingMemberships.isEmpty) {
      throw ClientException(
        statusCode: 403,
        response: const {'message': 'Akses percakapan ditolak.'},
      );
    }

    RecordModel? membership = existingMemberships.isNotEmpty
        ? existingMemberships.first
        : await _ensureMembership(
            conversationId: conversationId,
            userId: authUser.id,
          );
    var participantMemberships = membership == null
        ? <RecordModel>[]
        : <RecordModel>[membership];
    try {
      participantMemberships = await _loadConversationMemberships(
        conversationId: conversationId,
        fallbackUserId: authUser.id,
      );
    } catch (_) {}
    final records = await pb
        .collection(AppConstants.colMessages)
        .getFullList(
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
    final relatedRecords = await _loadMessagesByIds({
      ...replyIds,
      ...forwardedIds,
    });
    final senderIds = <String>{
      ...records.map((record) => _recordText(record, 'sender')),
      ...relatedRecords.values.map((record) => _recordText(record, 'sender')),
      ...participantMemberships.map((record) => _recordText(record, 'user')),
      _recordText(conversation, 'owner'),
    };
    final senderProfiles = await _loadChatUserProfiles(senderIds);
    final hydratedSenderProfiles =
        await _enrichProfilesWithScopedWargaAvatarFallback(
          profiles: senderProfiles,
          rt: _recordInt(conversation, 'rt'),
          rw: _recordInt(conversation, 'rw'),
        );
    final pollsById = await _loadPollsForMessages(
      records,
      currentUserId: authUser.id,
    );
    Map<String, List<MessageReactionModel>> reactionMap = const {};
    try {
      reactionMap = await _loadMessageReactions(
        messageIds: records.map((record) => record.id).toSet(),
        currentUserId: authUser.id,
      );
    } catch (_) {}

    var updatedMembership = membership;
    if (membership != null &&
        _needsReadMarkerUpdate(
          membership: membership,
          messages: records,
          currentUserId: authUser.id,
        )) {
      try {
        updatedMembership = await _markConversationReadByMember(membership.id);
      } catch (_) {}
    }
    var refreshedMemberships = participantMemberships;
    try {
      refreshedMemberships = await _loadConversationMemberships(
        conversationId: conversationId,
        fallbackUserId: authUser.id,
      );
    } catch (_) {}
    try {
      await _syncMessageReadReceipts(
        messages: records,
        memberships: refreshedMemberships,
        currentUserId: authUser.id,
      );
    } catch (_) {}
    Map<String, _MessageReceiptSummary> receiptSummaries = const {};
    try {
      receiptSummaries = await _loadMessageReceiptSummaries(
        messages: records,
        memberships: refreshedMemberships,
        currentUserId: authUser.id,
      );
    } catch (_) {}
    final participants = _buildConversationParticipants(
      memberships: refreshedMemberships,
      profiles: hydratedSenderProfiles,
      currentUserId: authUser.id,
    );

    final result = ChatMessagesData(
      conversation: _conversationFromRecord(
        conversation,
        currentUserId: authUser.id,
        membership: updatedMembership,
        unreadCount: 0,
        userProfiles: hydratedSenderProfiles,
      ),
      messages: records
          .map(
            (record) => _buildMessageModel(
              record,
              currentUserId: authUser.id,
              senderProfiles: hydratedSenderProfiles,
              relatedRecords: relatedRecords,
              receiptSummaries: receiptSummaries,
              reactionModelsByMessage: reactionMap,
              pollsById: pollsById,
            ),
          )
          .toList(growable: false),
      participants: participants,
    );
    cacheMessagesData(result);
    return result;
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

    if (!await _canAccessConversation(
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
      'workspace': _recordText(conversation, 'workspace'),
      'sender': authUser.id,
      'sender_member': await _workspaceMemberId(),
      'text': trimmedText,
      'message_type': attachment != null ? 'file' : 'text',
      'sender_badge_label': AppConstants.roleLabel(auth.role),
      'is_starred': false,
      'is_pinned': false,
    };
    if ((replyToId ?? '').isNotEmpty) {
      body['reply_to'] = replyToId;
    }
    if ((forwardedFromId ?? '').isNotEmpty) {
      body['forwarded_from'] = forwardedFromId;
    }

    final record = await pb
        .collection(AppConstants.colMessages)
        .create(body: body, files: files);
    await _markMessageDeliveredToRecipients(
      conversationId: conversationId,
      messageId: record.id,
      senderId: authUser.id,
    );

    final preview = _previewForMessage(
      text: trimmedText,
      attachmentName: attachment?.name ?? _recordText(record, 'attachment'),
      isForwarded: (forwardedFromId ?? '').isNotEmpty,
      isReply: (replyToId ?? '').isNotEmpty,
    );
    await pb
        .collection(AppConstants.colConversations)
        .update(
          conversationId,
          body: {
            'last_message': preview,
            'last_message_at': DateTime.now().toIso8601String(),
          },
        );
    invalidateBootstrapCache();

    if (membership != null) {
      await _markConversationReadByMember(membership.id);
    }

    final relatedRecords = await _loadMessagesByIds({
      if ((replyToId ?? '').isNotEmpty) replyToId!,
      if ((forwardedFromId ?? '').isNotEmpty) forwardedFromId!,
    });
    final senderProfiles = await _loadChatUserProfiles({
      authUser.id,
      ...relatedRecords.values.map((item) => _recordText(item, 'sender')),
    });

    return _buildMessageModel(
      record,
      currentUserId: authUser.id,
      senderProfiles: senderProfiles,
      relatedRecords: relatedRecords,
      receiptSummaries: const {},
      reactionModelsByMessage: const {},
      pollsById: const {},
    );
  }

  Future<MessageModel> sendVoiceMessage({
    required String conversationId,
    required PlatformFile audioFile,
    required int durationSeconds,
    String? replyToId,
  }) async {
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

    if (!await _canAccessConversation(
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
    final record = await pb
        .collection(AppConstants.colMessages)
        .create(
          body: {
            'conversation': conversationId,
            'workspace': _recordText(conversation, 'workspace'),
            'sender': authUser.id,
            'sender_member': await _workspaceMemberId(),
            'text': '',
            'message_type': AppConstants.msgTypeVoice,
            'voice_duration_seconds': durationSeconds,
            'sender_badge_label': AppConstants.roleLabel(auth.role),
            'is_starred': false,
            'is_pinned': false,
            if ((replyToId ?? '').isNotEmpty) 'reply_to': replyToId,
          },
          files: [await _multipartFromPlatformFile('attachment', audioFile)],
        );
    await _markMessageDeliveredToRecipients(
      conversationId: conversationId,
      messageId: record.id,
      senderId: authUser.id,
    );

    await pb
        .collection(AppConstants.colConversations)
        .update(
          conversationId,
          body: {
            'last_message': 'Voice note',
            'last_message_at': DateTime.now().toIso8601String(),
          },
        );
    invalidateBootstrapCache();

    if (membership != null) {
      await _markConversationReadByMember(membership.id);
    }
    final senderProfiles = await _loadChatUserProfiles({authUser.id});
    return _buildMessageModel(
      record,
      currentUserId: authUser.id,
      senderProfiles: senderProfiles,
      relatedRecords: const {},
      receiptSummaries: const {},
      reactionModelsByMessage: const {},
      pollsById: const {},
    );
  }

  Future<ConversationModel> createScopedConversation({
    required String name,
    required String scopeType,
    String? orgUnitId,
    String? requiredPlanCode,
    bool isReadonly = false,
  }) async {
    final auth = _auth;
    final authUser = auth.user;
    if (authUser == null) {
      throw ClientException(
        statusCode: 401,
        response: const {'message': 'Sesi telah berakhir'},
      );
    }

    final profile = await _requireWorkspaceProfile();
    final normalizedScopeType = scopeType.trim().toLowerCase();
    final normalizedPlanCode = AppConstants.normalizePlanCode(
      requiredPlanCode ?? auth.planCode,
    );
    if (normalizedScopeType == AppConstants.convScopeCustom &&
        !profile.canCreateCustomGroup) {
      throw ClientException(
        statusCode: 403,
        response: const {
          'message': 'Plan Anda belum dapat membuat grup custom.',
        },
      );
    }

    RecordModel? orgUnit;
    if ((orgUnitId ?? '').isNotEmpty) {
      orgUnit = await pb
          .collection(AppConstants.colOrgUnits)
          .getOne(orgUnitId!);
      final targetOrgUnitId = orgUnit.id;
      if (!profile.member.isSysadmin &&
          !profile.canBroadcastUnit(targetOrgUnitId) &&
          !profile.canManageScheduleForUnit(targetOrgUnitId) &&
          !profile.hasUnitMembership(targetOrgUnitId)) {
        throw ClientException(
          statusCode: 403,
          response: const {'message': 'Akses unit chat ditolak.'},
        );
      }
    }

    final conversationRecord = await _ensureConversation(
      key:
          'scope:$normalizedScopeType:${orgUnit?.id ?? profile.workspace.id}:${_slugify(name)}',
      type: normalizedScopeType == AppConstants.convScopeRt
          ? AppConstants.convGroupRt
          : AppConstants.convGroupRw,
      name: name.trim(),
      owner: '',
      createdBy: authUser.id,
      scope: _ChatScope(
        userId: authUser.id,
        displayName: _userDisplayName(authUser),
        rt: orgUnit == null ? 0 : _recordInt(orgUnit, 'scope_rt'),
        rw: orgUnit == null
            ? profile.workspace.rw
            : _recordInt(orgUnit, 'scope_rw') > 0
            ? _recordInt(orgUnit, 'scope_rw')
            : profile.workspace.rw,
        desaCode: profile.workspace.desaCode ?? '',
        kecamatanCode: profile.workspace.kecamatanCode ?? '',
        kabupatenCode: profile.workspace.kabupatenCode ?? '',
        provinsiCode: profile.workspace.provinsiCode ?? '',
        desaKelurahan: profile.workspace.desaKelurahan ?? '',
        kecamatan: profile.workspace.kecamatan ?? '',
        kabupatenKota: profile.workspace.kabupatenKota ?? '',
        provinsi: profile.workspace.provinsi ?? '',
      ),
    );

    final updatedRecord = await pb
        .collection(AppConstants.colConversations)
        .update(
          conversationRecord.id,
          body: {
            'workspace': profile.workspace.id,
            'scope_type': normalizedScopeType,
            'org_unit': orgUnit?.id ?? '',
            'required_plan_code': normalizedPlanCode,
            'is_readonly': isReadonly,
          },
        );
    final membership = await _ensureMembership(
      conversationId: updatedRecord.id,
      userId: authUser.id,
    );
    invalidateBootstrapCache();
    return _conversationFromRecord(
      updatedRecord,
      currentUserId: authUser.id,
      membership: membership,
      unreadCount: 0,
      userProfiles: const {},
    );
  }

  Future<MessageModel> createPoll({
    required String conversationId,
    required String title,
    required List<String> options,
    bool allowMultipleChoice = false,
    bool allowAnonymousVote = false,
  }) async {
    final auth = _auth;
    final authUser = auth.user;
    if (authUser == null) {
      throw ClientException(
        statusCode: 401,
        response: const {'message': 'Sesi telah berakhir'},
      );
    }
    if (options.where((item) => item.trim().isNotEmpty).length < 2) {
      throw ClientException(
        statusCode: 400,
        response: const {'message': 'Polling minimal memiliki 2 opsi.'},
      );
    }

    final area = await resolveAreaAccessContext(auth);
    final conversation = await pb
        .collection(AppConstants.colConversations)
        .getOne(conversationId);
    if (!await _canAccessConversation(
      auth: auth,
      context: area,
      conversation: conversation,
    )) {
      throw ClientException(
        statusCode: 403,
        response: const {'message': 'Akses percakapan ditolak.'},
      );
    }

    final messageRecord = await pb
        .collection(AppConstants.colMessages)
        .create(
          body: {
            'conversation': conversationId,
            'workspace': _recordText(conversation, 'workspace'),
            'sender': authUser.id,
            'sender_member': await _workspaceMemberId(),
            'text': title.trim(),
            'message_type': AppConstants.msgTypePoll,
            'sender_badge_label': AppConstants.roleLabel(auth.role),
            'is_starred': false,
            'is_pinned': false,
          },
        );
    await _markMessageDeliveredToRecipients(
      conversationId: conversationId,
      messageId: messageRecord.id,
      senderId: authUser.id,
    );
    final pollRecord = await pb
        .collection(AppConstants.colChatPolls)
        .create(
          body: {
            'workspace': _recordText(conversation, 'workspace'),
            'conversation': conversationId,
            'message': messageRecord.id,
            'title': title.trim(),
            'allow_multiple_choice': allowMultipleChoice,
            'allow_anonymous_vote': allowAnonymousVote,
            'status': 'open',
          },
        );
    await pb
        .collection(AppConstants.colMessages)
        .update(messageRecord.id, body: {'poll': pollRecord.id});
    for (var index = 0; index < options.length; index++) {
      final label = options[index].trim();
      if (label.isEmpty) {
        continue;
      }
      await pb
          .collection(AppConstants.colChatPollOptions)
          .create(
            body: {
              'poll': pollRecord.id,
              'label': label,
              'sort_order': index + 1,
            },
          );
    }

    await pb
        .collection(AppConstants.colConversations)
        .update(
          conversationId,
          body: {
            'last_message': 'Polling: ${title.trim()}',
            'last_message_at': DateTime.now().toIso8601String(),
          },
        );
    invalidateBootstrapCache();

    final senderProfiles = await _loadChatUserProfiles({authUser.id});
    final enriched = await pb
        .collection(AppConstants.colMessages)
        .getOne(messageRecord.id);
    return _buildMessageModel(
      enriched,
      currentUserId: authUser.id,
      senderProfiles: senderProfiles,
      relatedRecords: const {},
      receiptSummaries: const {},
      reactionModelsByMessage: const {},
      pollsById: {
        pollRecord.id: await _loadPoll(
          pollRecord.id,
          currentUserId: authUser.id,
        ),
      },
    );
  }

  Future<ChatPollModel> votePoll({
    required String pollId,
    required List<String> optionIds,
  }) async {
    final authUser = _auth.user;
    if (authUser == null) {
      throw ClientException(
        statusCode: 401,
        response: const {'message': 'Sesi telah berakhir'},
      );
    }

    final poll = await _loadPoll(pollId, currentUserId: authUser.id);
    if (!poll.isOpen) {
      throw ClientException(
        statusCode: 400,
        response: const {'message': 'Polling sudah ditutup.'},
      );
    }
    if (!poll.allowMultipleChoice && optionIds.length > 1) {
      throw ClientException(
        statusCode: 400,
        response: const {'message': 'Polling ini hanya mendukung 1 pilihan.'},
      );
    }

    final existingVotes = await pb
        .collection(AppConstants.colChatPollVotes)
        .getFullList(
          filter:
              'poll = "${_escapeFilterValue(pollId)}" && user = "${_escapeFilterValue(authUser.id)}"',
        );
    for (final vote in existingVotes) {
      await pb.collection(AppConstants.colChatPollVotes).delete(vote.id);
    }

    for (final optionId in optionIds.where((item) => item.trim().isNotEmpty)) {
      await pb
          .collection(AppConstants.colChatPollVotes)
          .create(
            body: {
              'poll': pollId,
              'option': optionId,
              'user': authUser.id,
              'workspace_member': await _workspaceMemberId(),
            },
          );
    }

    return _loadPoll(pollId, currentUserId: authUser.id);
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
    final memberships = await _loadMembershipRecords(
      conversationId: conversationId,
      userId: authUser.id,
    );
    if (memberships.isEmpty) {
      if (membership == null) {
        return;
      }
      await _markConversationReadByMember(membership.id);
      final messages = await _loadConversationMessageRecords(conversationId);
      await _syncMessageReadReceipts(
        messages: messages,
        memberships: [membership],
        currentUserId: authUser.id,
      );
      invalidateBootstrapCache();
      return;
    }
    for (final item in memberships) {
      await _markConversationReadByMember(item.id);
    }
    final messages = await _loadConversationMessageRecords(conversationId);
    await _syncMessageReadReceipts(
      messages: messages,
      memberships: memberships,
      currentUserId: authUser.id,
    );
    invalidateBootstrapCache();
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
    final memberships = await _loadMembershipRecords(
      conversationId: conversationId,
      userId: authUser.id,
    );
    if (memberships.isEmpty) {
      if (membership == null) {
        return;
      }
      await _updateConversationMember(
        membership.id,
        body: {'last_read_at': null},
      );
      invalidateBootstrapCache();
      return;
    }
    for (final item in memberships) {
      await _updateConversationMember(item.id, body: {'last_read_at': null});
    }
    invalidateBootstrapCache();
  }

  Future<void> touchPresence(String conversationId) async {
    final authUser = _auth.user;
    if (authUser == null) {
      return;
    }
    final membership = await _ensureMembership(
      conversationId: conversationId,
      userId: authUser.id,
    );
    if (membership == null) {
      return;
    }
    await _updateConversationMember(
      membership.id,
      body: {'last_seen_at': DateTime.now().toUtc().toIso8601String()},
    );
  }

  Future<void> setTypingState({
    required String conversationId,
    required bool isTyping,
  }) async {
    final authUser = _auth.user;
    if (authUser == null) {
      return;
    }
    final membership = await _ensureMembership(
      conversationId: conversationId,
      userId: authUser.id,
    );
    if (membership == null) {
      return;
    }
    await _updateConversationMember(
      membership.id,
      body: {
        'typing_at': isTyping
            ? DateTime.now().toUtc().toIso8601String()
            : null,
        'last_seen_at': DateTime.now().toUtc().toIso8601String(),
      },
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

    final memberships = await _loadMembershipRecords(
      conversationId: conversationId,
      userId: authUser.id,
    );
    if (memberships.isEmpty) {
      if (membership == null) {
        return;
      }
      await _updateConversationMember(membership.id, body: body);
      invalidateBootstrapCache();
      return;
    }

    for (final item in memberships) {
      await _updateConversationMember(item.id, body: body);
    }
    invalidateBootstrapCache();
  }

  Future<void> toggleMessageStar(String messageId) async {
    final message = await _loadAccessibleMessage(messageId);
    await pb
        .collection(AppConstants.colMessages)
        .update(
          message.id,
          body: {'is_starred': !(message.data['is_starred'] == true)},
        );
  }

  Future<void> setMessagePin({
    required String messageId,
    required bool isPinned,
    Duration? duration,
  }) async {
    final message = await _loadAccessibleMessage(messageId);
    final body = <String, dynamic>{'is_pinned': isPinned};
    if (isPinned) {
      final effectiveDuration = duration ?? const Duration(days: 7);
      body['pinned_until'] = DateTime.now()
          .toUtc()
          .add(effectiveDuration)
          .toIso8601String();
    } else {
      body['pinned_until'] = null;
    }
    await pb
        .collection(AppConstants.colMessages)
        .update(message.id, body: body);
  }

  Future<void> toggleMessagePin(String messageId, {Duration? duration}) async {
    final message = await _loadAccessibleMessage(messageId);
    await setMessagePin(
      messageId: messageId,
      isPinned: !_isMessagePinnedRecord(message),
      duration: duration,
    );
  }

  Future<void> editMessage({
    required String messageId,
    required String text,
  }) async {
    final authUser = _auth.user;
    if (authUser == null) {
      throw ClientException(
        statusCode: 401,
        response: const {'message': 'Sesi telah berakhir'},
      );
    }

    final trimmedText = text.trim();
    if (trimmedText.isEmpty) {
      throw ClientException(
        statusCode: 400,
        response: const {'message': 'Isi pesan tidak boleh kosong.'},
      );
    }

    final message = await _loadAccessibleMessage(messageId);
    if (_recordText(message, 'sender') != authUser.id && !_auth.isSysadmin) {
      throw ClientException(
        statusCode: 403,
        response: const {'message': 'Hanya pengirim yang bisa mengedit pesan.'},
      );
    }
    if (_recordText(message, 'deleted_at').isNotEmpty) {
      throw ClientException(
        statusCode: 400,
        response: const {'message': 'Pesan yang dihapus tidak bisa diedit.'},
      );
    }
    if (_recordText(message, 'message_type') == AppConstants.msgTypePoll) {
      throw ClientException(
        statusCode: 400,
        response: const {'message': 'Polling tidak bisa diedit.'},
      );
    }

    await pb
        .collection(AppConstants.colMessages)
        .update(
          message.id,
          body: {
            'text': trimmedText,
            'edited_at': DateTime.now().toUtc().toIso8601String(),
            'edited_by': authUser.id,
          },
        );
    await _syncConversationPreview(_recordText(message, 'conversation'));
    invalidateBootstrapCache();
  }

  Future<void> toggleMessageReaction({
    required String messageId,
    required String emoji,
  }) async {
    final authUser = _auth.user;
    if (authUser == null) {
      throw ClientException(
        statusCode: 401,
        response: const {'message': 'Sesi telah berakhir'},
      );
    }
    final normalizedEmoji = emoji.trim();
    if (normalizedEmoji.isEmpty) {
      return;
    }

    await _loadAccessibleMessage(messageId);
    final existing = await pb
        .collection(AppConstants.colMessageReactions)
        .getFullList(
          filter:
              'message = "${_escapeFilterValue(messageId)}" && user = "${_escapeFilterValue(authUser.id)}"',
        );
    final sameEmoji = existing.where(
      (item) => _recordText(item, 'emoji') == normalizedEmoji,
    );
    if (sameEmoji.isNotEmpty) {
      for (final record in sameEmoji) {
        await pb.collection(AppConstants.colMessageReactions).delete(record.id);
      }
      for (final record in existing.where(
        (item) => !sameEmoji.contains(item),
      )) {
        await pb.collection(AppConstants.colMessageReactions).delete(record.id);
      }
      return;
    }

    if (existing.isNotEmpty) {
      await pb
          .collection(AppConstants.colMessageReactions)
          .update(existing.first.id, body: {'emoji': normalizedEmoji});
      for (final record in existing.skip(1)) {
        await pb.collection(AppConstants.colMessageReactions).delete(record.id);
      }
      return;
    }

    await pb
        .collection(AppConstants.colMessageReactions)
        .create(
          body: {
            'message': messageId,
            'user': authUser.id,
            'emoji': normalizedEmoji,
          },
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
        response: const {
          'message': 'Hanya pengirim yang dapat menghapus pesan.',
        },
      );
    }

    await pb
        .collection(AppConstants.colMessages)
        .update(
          message.id,
          body: {
            'text': '',
            'deleted_at': DateTime.now().toIso8601String(),
            'deleted_by': authUser.id,
          },
        );
    await _syncConversationPreview(_recordText(message, 'conversation'));
    invalidateBootstrapCache();
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
    if (!await _canAccessConversation(
      auth: _auth,
      context: area,
      conversation: targetConversation,
    )) {
      throw ClientException(
        statusCode: 403,
        response: const {'message': 'Tujuan forward tidak dapat diakses.'},
      );
    }
    final membership = await _ensureMembership(
      conversationId: targetConversationId,
      userId: authUser.id,
    );

    final created = await pb
        .collection(AppConstants.colMessages)
        .create(
          body: {
            'conversation': targetConversationId,
            'workspace': _recordText(targetConversation, 'workspace'),
            'sender': authUser.id,
            'sender_member': await _workspaceMemberId(),
            'text': text,
            'message_type': files.isNotEmpty ? 'file' : 'text',
            'forwarded_from': messageId,
            'sender_badge_label': AppConstants.roleLabel(_auth.role),
            'is_starred': false,
            'is_pinned': false,
          },
          files: files,
        );
    await _markMessageDeliveredToRecipients(
      conversationId: targetConversationId,
      messageId: created.id,
      senderId: authUser.id,
    );

    await pb
        .collection(AppConstants.colConversations)
        .update(
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
    invalidateBootstrapCache();
    if (membership != null) {
      await _markConversationReadByMember(membership.id);
    }
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

    final area = await resolveAreaAccessContext(auth);
    final records = await pb
        .collection(AppConstants.colAnnouncements)
        .getFullList(sort: '-published_at,-created');
    final accessible = records
        .where(
          (record) =>
              _canAccessAnnouncement(auth: auth, context: area, record: record),
        )
        .toList(growable: false);
    if (accessible.isEmpty) {
      return ChatAnnouncementsData(
        canCreate: _canCreateAnnouncement(auth),
        items: const [],
      );
    }

    final authorNames = await _loadSenderNames(
      accessible.map((record) => _recordText(record, 'author')).toSet(),
    );
    final recordIds = accessible.map((record) => record.id).toSet();
    final viewCounts = await _loadAnnouncementViewCounts(recordIds);
    final viewedIds = _shouldTrackAnnouncementView(auth)
        ? await _loadViewedAnnouncementIds(recordIds, authUser.id)
        : <String>{};
    final audienceCache = <String, int>{};
    final items = <AnnouncementModel>[];
    for (final record in accessible) {
      items.add(
        await _buildAnnouncementModel(
          auth: auth,
          context: area,
          record: record,
          authorNames: authorNames,
          viewCounts: viewCounts,
          viewedIds: viewedIds,
          audienceCache: audienceCache,
        ),
      );
    }

    items.sort((left, right) {
      final leftTime =
          left.publishedAt ?? left.createdAt ?? DateTime.fromMillisecondsSinceEpoch(0);
      final rightTime =
          right.publishedAt ??
          right.createdAt ??
          DateTime.fromMillisecondsSinceEpoch(0);
      return rightTime.compareTo(leftTime);
    });

    return ChatAnnouncementsData(
      canCreate: _canCreateAnnouncement(auth),
      items: items,
    );
  }

  Future<AnnouncementModel> getAnnouncementDetail(
    String announcementId, {
    bool markAsViewed = true,
  }) async {
    final auth = _auth;
    final authUser = auth.user;
    if (authUser == null) {
      throw ClientException(
        statusCode: 401,
        response: const {'message': 'Sesi telah berakhir'},
      );
    }

    final area = await resolveAreaAccessContext(auth);
    final record = await pb
        .collection(AppConstants.colAnnouncements)
        .getOne(announcementId);
    if (!_canAccessAnnouncement(auth: auth, context: area, record: record)) {
      throw ClientException(
        statusCode: 403,
        response: const {'message': 'Akses pengumuman ditolak.'},
      );
    }

    if (markAsViewed && _shouldTrackAnnouncementView(auth)) {
      await markAnnouncementViewed(announcementId);
    }

    return _hydrateAnnouncementModel(
      auth: auth,
      context: area,
      record: record,
      currentUserId: authUser.id,
    );
  }

  Future<AnnouncementModel> createAnnouncement({
    required String title,
    required String content,
    required String targetType,
    int? targetRt,
    int? targetRw,
    String? orgUnitId,
    PlatformFile? attachment,
    bool publishNow = true,
  }) async {
    final auth = _auth;
    final authUser = auth.user;
    if (authUser == null) {
      throw ClientException(
        statusCode: 401,
        response: const {'message': 'Sesi telah berakhir'},
      );
    }
    if (!_canCreateAnnouncement(auth)) {
      throw ClientException(
        statusCode: 403,
        response: const {'message': 'Anda tidak memiliki akses fitur ini.'},
      );
    }

    final area = await resolveAreaAccessContext(auth);
    final profile = await _ref
        .read(workspaceAccessServiceProvider)
        .getCurrentAccessProfile();
    _validateAnnouncementPayload(
      title: title,
      content: content,
      targetType: targetType,
      attachment: attachment,
    );
    final normalizedTarget = _normalizeAnnouncementTarget(
      auth: auth,
      context: area,
      targetType: targetType,
      targetRt: targetRt,
      targetRw: targetRw,
    );
    await _ensureAnnouncementUnitAccess(profile: profile, orgUnitId: orgUnitId);

    final nowIso = DateTime.now().toUtc().toIso8601String();
    final files = <http.MultipartFile>[];
    if (attachment != null) {
      files.add(await _multipartFromPlatformFile('attachment', attachment));
    }

    final created = await pb
        .collection(AppConstants.colAnnouncements)
        .create(
          body: {
            'workspace': profile?.workspace.id ?? '',
            'org_unit': orgUnitId ?? '',
            'author': authUser.id,
            'title': title.trim(),
            'content': content.trim(),
            'target_type': normalizedTarget.targetType,
            'rt': normalizedTarget.rt,
            'rw': normalizedTarget.rw,
            'source_module': 'manual',
            'publish_state': publishNow ? 'published' : 'draft',
            'published_by_member': profile?.member.id ?? '',
            'published_at': publishNow ? nowIso : null,
            'view_count': 0,
            'desa_code': area.desaCode ?? '',
            'kecamatan_code': area.kecamatanCode ?? '',
            'kabupaten_code': area.kabupatenCode ?? '',
            'provinsi_code': area.provinsiCode ?? '',
            'desa_kelurahan': area.desaKelurahan ?? '',
            'kecamatan': area.kecamatan ?? '',
            'kabupaten_kota': area.kabupatenKota ?? '',
            'provinsi': area.provinsi ?? '',
            'is_published': publishNow,
          },
          files: files,
        );

    return _hydrateAnnouncementModel(
      auth: auth,
      context: area,
      record: created,
      currentUserId: authUser.id,
    );
  }

  Future<AnnouncementModel> updateAnnouncement({
    required String announcementId,
    required String title,
    required String content,
    required String targetType,
    int? targetRt,
    int? targetRw,
    String? orgUnitId,
    PlatformFile? attachment,
    bool publishNow = true,
    bool removeAttachment = false,
  }) async {
    final auth = _auth;
    final authUser = auth.user;
    if (authUser == null) {
      throw ClientException(
        statusCode: 401,
        response: const {'message': 'Sesi telah berakhir'},
      );
    }

    final area = await resolveAreaAccessContext(auth);
    final existing = await pb
        .collection(AppConstants.colAnnouncements)
        .getOne(announcementId);
    if (!_canEditAnnouncement(auth: auth, context: area, record: existing)) {
      throw ClientException(
        statusCode: 403,
        response: const {
          'message': 'Edit hanya untuk draft atau pengumuman yang baru diterbitkan.',
        },
      );
    }

    _validateAnnouncementPayload(
      title: title,
      content: content,
      targetType: targetType,
      attachment: attachment,
    );
    final profile = await _ref
        .read(workspaceAccessServiceProvider)
        .getCurrentAccessProfile();
    await _ensureAnnouncementUnitAccess(profile: profile, orgUnitId: orgUnitId);
    final normalizedTarget = _normalizeAnnouncementTarget(
      auth: auth,
      context: area,
      targetType: targetType,
      targetRt: targetRt,
      targetRw: targetRw,
    );

    final nowIso = DateTime.now().toUtc().toIso8601String();
    final wasPublished = existing.data['is_published'] == true;
    final body = <String, dynamic>{
      'title': title.trim(),
      'content': content.trim(),
      'target_type': normalizedTarget.targetType,
      'rt': normalizedTarget.rt,
      'rw': normalizedTarget.rw,
      'org_unit': orgUnitId ?? '',
      'publish_state': publishNow ? 'published' : 'draft',
      'is_published': publishNow,
      'published_at': publishNow
          ? (wasPublished
                ? (_recordText(existing, 'published_at').isNotEmpty
                      ? _recordText(existing, 'published_at')
                      : nowIso)
                : nowIso)
          : null,
      'published_by_member': profile?.member.id ?? '',
      'workspace': _recordText(existing, 'workspace'),
      'author': _recordText(existing, 'author'),
      'view_count': _recordInt(existing, 'view_count'),
      'desa_code': _recordText(existing, 'desa_code'),
      'kecamatan_code': _recordText(existing, 'kecamatan_code'),
      'kabupaten_code': _recordText(existing, 'kabupaten_code'),
      'provinsi_code': _recordText(existing, 'provinsi_code'),
      'desa_kelurahan': _recordText(existing, 'desa_kelurahan'),
      'kecamatan': _recordText(existing, 'kecamatan'),
      'kabupaten_kota': _recordText(existing, 'kabupaten_kota'),
      'provinsi': _recordText(existing, 'provinsi'),
    };
    if (removeAttachment) {
      body['attachment'] = [];
    }

    final files = <http.MultipartFile>[];
    if (attachment != null) {
      files.add(await _multipartFromPlatformFile('attachment', attachment));
    }
    final updated = await pb
        .collection(AppConstants.colAnnouncements)
        .update(announcementId, body: body, files: files);

    return _hydrateAnnouncementModel(
      auth: auth,
      context: area,
      record: updated,
      currentUserId: authUser.id,
    );
  }

  Future<void> deleteAnnouncement(String announcementId) async {
    final auth = _auth;
    final authUser = auth.user;
    if (authUser == null) {
      throw ClientException(
        statusCode: 401,
        response: const {'message': 'Sesi telah berakhir'},
      );
    }

    final area = await resolveAreaAccessContext(auth);
    final record = await pb
        .collection(AppConstants.colAnnouncements)
        .getOne(announcementId);
    if (!_canDeleteAnnouncement(auth: auth, context: area, record: record)) {
      throw ClientException(
        statusCode: 403,
        response: const {'message': 'Anda tidak bisa menghapus pengumuman ini.'},
      );
    }

    final viewRecords = await _loadAnnouncementViewRecords(
      announcementIds: {announcementId},
    );
    for (final view in viewRecords) {
      try {
        await pb.collection(AppConstants.colAnnouncementViews).delete(view.id);
      } catch (_) {}
    }
    await pb.collection(AppConstants.colAnnouncements).delete(announcementId);
  }

  Future<AnnouncementStatsModel> getAnnouncementStats(
    String announcementId,
  ) async {
    final auth = _auth;
    final authUser = auth.user;
    if (authUser == null) {
      throw ClientException(
        statusCode: 401,
        response: const {'message': 'Sesi telah berakhir'},
      );
    }

    final area = await resolveAreaAccessContext(auth);
    final record = await pb
        .collection(AppConstants.colAnnouncements)
        .getOne(announcementId);
    if (!_canAccessAnnouncement(auth: auth, context: area, record: record) ||
        !_canViewAnnouncementStats(auth: auth, context: area, record: record)) {
      throw ClientException(
        statusCode: 403,
        response: const {'message': 'Akses statistik pengumuman ditolak.'},
      );
    }

    final viewRecords = await _loadAnnouncementViewRecords(
      announcementIds: {announcementId},
    );
    final firstViewedAt = viewRecords.isEmpty
        ? null
        : viewRecords
              .map((item) => _recordDateTime(item, 'viewed_at') ?? _recordDateTime(item, 'created'))
              .whereType<DateTime>()
              .reduce((left, right) => left.isBefore(right) ? left : right);
    final lastViewedAt = viewRecords.isEmpty
        ? null
        : viewRecords
              .map((item) => _recordDateTime(item, 'viewed_at') ?? _recordDateTime(item, 'created'))
              .whereType<DateTime>()
              .reduce((left, right) => left.isAfter(right) ? left : right);
    await _syncAnnouncementViewCount(
      announcementId,
      viewRecords.length,
      currentCount: _recordInt(record, 'view_count'),
    );

    return AnnouncementStatsModel(
      announcementId: announcementId,
      totalViews: viewRecords.length,
      targetAudienceCount: await _countAnnouncementTargetAudience(record),
      firstViewedAt: firstViewedAt,
      lastViewedAt: lastViewedAt,
    );
  }

  Future<void> markAnnouncementViewed(String announcementId) async {
    final auth = _auth;
    final authUser = auth.user;
    if (authUser == null || !_shouldTrackAnnouncementView(auth)) {
      return;
    }
    await _upsertAnnouncementView(
      announcementId: announcementId,
      userId: authUser.id,
    );
  }

  Future<bool> canAccessAnnouncementRecord(RecordModel record) async {
    final auth = _auth;
    if (auth.user == null) {
      return false;
    }
    final area = await resolveAreaAccessContext(auth);
    return _canAccessAnnouncement(auth: auth, context: area, record: record);
  }

  Future<_ChatScope> _buildScopeForAuthUser(
    AuthState auth,
    AreaAccessContext area,
  ) async {
    final user = auth.user!;
    String displayName = _userDisplayName(user);
    if ((area.wargaId ?? '').isNotEmpty) {
      try {
        final warga = await pb
            .collection(AppConstants.colWarga)
            .getOne(area.wargaId!);
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
    final records = await pb
        .collection(AppConstants.colWarga)
        .getFullList(
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

      kkCache.putIfAbsent(kkId, () async {
        try {
          return await pb
              .collection(AppConstants.colKartuKeluarga)
              .getOne(kkId);
        } catch (_) {
          return null;
        }
      });

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
      name:
          'Layanan - ${scope.displayName.isEmpty ? 'Warga' : scope.displayName}',
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
      return await pb
          .collection(AppConstants.colConversations)
          .getFirstListItem('key = "${_escapeFilterValue(key)}"');
    } on ClientException catch (error) {
      if (error.statusCode != 404) {
        rethrow;
      }
    }

    final profile = await _ref
        .read(workspaceAccessServiceProvider)
        .getCurrentAccessProfile();
    final body = <String, dynamic>{
      'key': key,
      'type': type,
      'name': name,
      'created_by': createdBy,
      'workspace': profile?.workspace.id ?? '',
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
      'scope_type': type == AppConstants.convPrivate
          ? AppConstants.convScopePrivateSupport
          : type == AppConstants.convGroupRt
          ? AppConstants.convScopeRt
          : AppConstants.convScopeRw,
      'required_plan_code': type == AppConstants.convGroupRw
          ? AppConstants.planRt
          : AppConstants.planFree,
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
      if (membership != null) {
        result[conversation.id] = membership;
      }
    }
    return result;
  }

  Future<RecordModel?> _ensureMembership({
    required String conversationId,
    required String userId,
  }) async {
    if (_conversationMembersCollectionAvailable == false) {
      return null;
    }
    final existing = await _loadMembershipRecords(
      conversationId: conversationId,
      userId: userId,
    );
    if (existing.isNotEmpty) {
      return existing.first;
    }

    try {
      final created = await pb
          .collection(AppConstants.colConversationMembers)
          .create(
            body: {
              'conversation': conversationId,
              'user': userId,
              'member_role': 'participant',
              'last_read_at': null,
              'last_seen_at': DateTime.now().toUtc().toIso8601String(),
              'typing_at': null,
              'is_muted': false,
              'is_pinned': false,
              'is_archived': false,
            },
          );
      _conversationMembersCollectionAvailable = true;
      return created;
    } on ClientException catch (error) {
      if (_isMissingCollectionContext(error)) {
        _conversationMembersCollectionAvailable = false;
        return null;
      }
      rethrow;
    }
  }

  Future<Map<String, int>> _loadUnreadCounts({
    required Iterable<RecordModel> conversations,
    required String userId,
    required Map<String, RecordModel> memberships,
  }) async {
    final result = <String, int>{};
    for (final conversation in conversations) {
      final membership = memberships[conversation.id];
      if (membership == null && _conversationMembersCollectionAvailable == false) {
        result[conversation.id] = 0;
        continue;
      }
      final readAt = membership == null
          ? ''
          : _recordText(membership, 'last_read_at');
      final conditions = <String>[
        'conversation = "${_escapeFilterValue(conversation.id)}"',
        'sender != "${_escapeFilterValue(userId)}"',
      ];
      if (readAt.isNotEmpty) {
        conditions.add('created > "${_escapeFilterValue(readAt)}"');
      }

      final page = await pb
          .collection(AppConstants.colMessages)
          .getList(page: 1, perPage: 1, filter: conditions.join(' && '));
      result[conversation.id] = page.totalItems;
    }
    return result;
  }

  Future<RecordModel?> _markConversationReadByMember(String memberId) {
    return _updateConversationMember(
      memberId,
      body: {
        'last_read_at': DateTime.now().toUtc().toIso8601String(),
        'last_seen_at': DateTime.now().toUtc().toIso8601String(),
      },
    );
  }

  Future<bool> _canAccessConversation({
    required AuthState auth,
    required AreaAccessContext context,
    required RecordModel conversation,
  }) async {
    if (auth.user == null) {
      return false;
    }
    if (auth.isSysadmin) {
      return true;
    }
    if (!context.hasArea) {
      return false;
    }

    final type = _recordText(conversation, 'type');
    final target = _ConversationScope.fromRecord(conversation);
    final scopeType = _recordText(conversation, 'scope_type');
    final requiredPlanCode = _recordText(conversation, 'required_plan_code');
    final orgUnitId = _recordText(conversation, 'org_unit');

    if (scopeType.isNotEmpty) {
      if (requiredPlanCode.isNotEmpty &&
          !auth.isSysadmin &&
          !AppConstants.satisfiesPlanRequirement(
            currentPlanCode: auth.planCode,
            requiredPlanCode: requiredPlanCode,
          )) {
        return false;
      }
      return _canAccessScopedConversation(
        auth: auth,
        context: context,
        scopeType: scopeType,
        orgUnitId: orgUnitId,
        target: target,
      );
    }

    if (type == AppConstants.convPrivate) {
      if (_recordText(conversation, 'owner') == auth.user!.id) {
        return true;
      }
      if (_isWarga(auth)) {
        return false;
      }
      return _matchesScope(context, target, auth);
    }

    if (type == AppConstants.convGroupRt) {
      return _matchesScope(context, target, auth);
    }

    if (type == AppConstants.convGroupRw) {
      if (_isWarga(auth)) {
        return false;
      }
      return _matchesRwScope(context, target, auth);
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

    final target = _ConversationScope.fromRecord(record);
    if (!_matchesAnnouncementRegion(context, target)) {
      return false;
    }
    if (target.rw != (context.rw ?? 0)) {
      return false;
    }

    final targetType = _normalizeAnnouncementTargetType(
      _recordText(record, 'target_type'),
    );
    if (_isWarga(auth)) {
      if (!_announcementIsPublished(record)) {
        return false;
      }
      if (targetType == 'all' || targetType == 'rw') {
        return true;
      }
      return target.rt == (context.rt ?? 0);
    }

    return true;
  }

  Future<AnnouncementModel> _hydrateAnnouncementModel({
    required AuthState auth,
    required AreaAccessContext context,
    required RecordModel record,
    required String currentUserId,
  }) async {
    final authorNames = await _loadSenderNames({_recordText(record, 'author')});
    final viewCounts = await _loadAnnouncementViewCounts({record.id});
    final viewedIds = _shouldTrackAnnouncementView(auth)
        ? await _loadViewedAnnouncementIds({record.id}, currentUserId)
        : <String>{};
    return _buildAnnouncementModel(
      auth: auth,
      context: context,
      record: record,
      authorNames: authorNames,
      viewCounts: viewCounts,
      viewedIds: viewedIds,
      audienceCache: <String, int>{},
    );
  }

  Future<AnnouncementModel> _buildAnnouncementModel({
    required AuthState auth,
    required AreaAccessContext context,
    required RecordModel record,
    required Map<String, String> authorNames,
    required Map<String, int> viewCounts,
    required Set<String> viewedIds,
    required Map<String, int> audienceCache,
  }) async {
    final audienceKey = _announcementAudienceCacheKey(record);
    final targetAudienceCount = audienceCache[audienceKey] ??
        await _countAnnouncementTargetAudience(record);
    audienceCache[audienceKey] = targetAudienceCount;
    final fallbackPublishState = _announcementIsPublished(record)
        ? 'published'
        : 'draft';

    return AnnouncementModel(
      id: record.id,
      title: _recordText(record, 'title'),
      content: _recordText(record, 'content'),
      targetType: _normalizeAnnouncementTargetType(
        _recordText(record, 'target_type'),
      ),
      rt: _recordInt(record, 'rt'),
      rw: _recordInt(record, 'rw'),
      authorId: _recordText(record, 'author'),
      authorName:
          authorNames[_recordText(record, 'author')] ?? 'Pengurus',
      isPublished: _announcementIsPublished(record),
      createdAt: _recordDateTime(record, 'created'),
      updatedAt: _recordDateTime(record, 'updated'),
      publishedAt: _recordDateTime(record, 'published_at'),
      workspaceId: _recordText(record, 'workspace').isEmpty
          ? null
          : _recordText(record, 'workspace'),
      orgUnitId: _recordText(record, 'org_unit').isEmpty
          ? null
          : _recordText(record, 'org_unit'),
      sourceModule: _recordText(record, 'source_module').isEmpty
          ? null
          : _recordText(record, 'source_module'),
      publishState: _recordText(record, 'publish_state').isEmpty
          ? fallbackPublishState
          : _recordText(record, 'publish_state'),
      publishedByMemberId: _recordText(record, 'published_by_member').isEmpty
          ? null
          : _recordText(record, 'published_by_member'),
      attachmentName: _recordText(record, 'attachment').isEmpty
          ? null
          : _recordText(record, 'attachment'),
      attachmentUrl: _fileUrl(record, 'attachment'),
      viewCount: viewCounts[record.id] ?? _recordInt(record, 'view_count'),
      targetAudienceCount: targetAudienceCount,
      hasViewed: viewedIds.contains(record.id),
      isMine: _recordText(record, 'author') == (_auth.user?.id ?? ''),
      canEdit: _canEditAnnouncement(auth: auth, context: context, record: record),
      canDelete: _canDeleteAnnouncement(
        auth: auth,
        context: context,
        record: record,
      ),
      canViewStats: _canViewAnnouncementStats(
        auth: auth,
        context: context,
        record: record,
      ),
    );
  }

  bool _announcementIsPublished(RecordModel record) {
    return record.data['is_published'] == true ||
        _recordText(record, 'publish_state').toLowerCase() == 'published';
  }

  String _normalizeAnnouncementTargetType(String raw) {
    final value = raw.trim().toLowerCase();
    if (value == 'all') {
      return 'all';
    }
    if (value == 'rt') {
      return 'rt';
    }
    return 'rw';
  }

  bool _shouldTrackAnnouncementView(AuthState auth) => _isWarga(auth);

  bool _matchesAnnouncementRegion(
    AreaAccessContext context,
    _ConversationScope target,
  ) {
    final hasTargetRegion =
        target.desaCode.isNotEmpty ||
        target.kecamatanCode.isNotEmpty ||
        target.kabupatenCode.isNotEmpty ||
        target.provinsiCode.isNotEmpty ||
        target.desaKelurahan.isNotEmpty ||
        target.kecamatan.isNotEmpty ||
        target.kabupatenKota.isNotEmpty ||
        target.provinsi.isNotEmpty;
    if (!hasTargetRegion) {
      return true;
    }
    return _matchesRegion(context, target);
  }

  bool _canEditAnnouncement({
    required AuthState auth,
    required AreaAccessContext context,
    required RecordModel record,
  }) {
    if (auth.user == null) {
      return false;
    }
    if (auth.isSysadmin) {
      return true;
    }
    if (_isWarga(auth)) {
      return false;
    }
    if (_recordText(record, 'author') != auth.user!.id) {
      return false;
    }
    if (!_canAccessAnnouncement(auth: auth, context: context, record: record)) {
      return false;
    }
    if (!_announcementIsPublished(record)) {
      return true;
    }
    final baseline =
        _recordDateTime(record, 'published_at') ??
        _recordDateTime(record, 'created');
    if (baseline == null) {
      return false;
    }
    return baseline.isAfter(
      DateTime.now().toUtc().subtract(const Duration(hours: 1)),
    );
  }

  bool _canDeleteAnnouncement({
    required AuthState auth,
    required AreaAccessContext context,
    required RecordModel record,
  }) {
    if (auth.user == null) {
      return false;
    }
    if (auth.isSysadmin) {
      return true;
    }
    if (_isWarga(auth)) {
      return false;
    }
    if (!_canAccessAnnouncement(auth: auth, context: context, record: record)) {
      return false;
    }
    return _recordText(record, 'author') == auth.user!.id;
  }

  bool _canViewAnnouncementStats({
    required AuthState auth,
    required AreaAccessContext context,
    required RecordModel record,
  }) {
    if (auth.user == null) {
      return false;
    }
    if (auth.isSysadmin) {
      return true;
    }
    if (_isWarga(auth) ||
        !_canAccessAnnouncement(auth: auth, context: context, record: record)) {
      return false;
    }
    if (_recordText(record, 'author') == auth.user!.id) {
      return true;
    }
    return _hasRwWideAccess(auth);
  }

  void _validateAnnouncementPayload({
    required String title,
    required String content,
    required String targetType,
    PlatformFile? attachment,
  }) {
    final trimmedTitle = title.trim();
    final trimmedContent = content.trim();
    if (trimmedTitle.length < 5 || trimmedTitle.length > 100) {
      throw ClientException(
        statusCode: 400,
        response: const {
          'message': 'Judul wajib diisi dengan panjang 5-100 karakter.',
        },
      );
    }
    if (trimmedContent.length < 10 || trimmedContent.length > 1000) {
      throw ClientException(
        statusCode: 400,
        response: const {
          'message': 'Isi wajib diisi dengan panjang 10-1000 karakter.',
        },
      );
    }
    final normalizedTarget = _normalizeAnnouncementTargetType(targetType);
    if (!{'rt', 'rw', 'all'}.contains(normalizedTarget)) {
      throw ClientException(
        statusCode: 400,
        response: const {'message': 'Pilih target pengumuman.'},
      );
    }
    if (attachment != null) {
      _validateAnnouncementAttachment(attachment);
    }
  }

  void _validateAnnouncementAttachment(PlatformFile file) {
    if (file.size > 5 * 1024 * 1024) {
      throw ClientException(
        statusCode: 400,
        response: const {'message': 'File terlalu besar. Maksimal 5 MB.'},
      );
    }
    final extension = '.${(file.extension ?? '').trim().toLowerCase()}';
    if (!{'.jpg', '.jpeg', '.png', '.pdf'}.contains(extension)) {
      throw ClientException(
        statusCode: 400,
        response: const {
          'message': 'Format file harus JPG, PNG, atau PDF.',
        },
      );
    }
  }

  _NormalizedAnnouncementTarget _normalizeAnnouncementTarget({
    required AuthState auth,
    required AreaAccessContext context,
    required String targetType,
    int? targetRt,
    int? targetRw,
  }) {
    if (!context.hasArea && !auth.isSysadmin) {
      throw ClientException(
        statusCode: 400,
        response: const {'message': 'Area admin belum lengkap.'},
      );
    }
    final normalizedTarget = _normalizeAnnouncementTargetType(targetType);
    final effectiveRw = targetRw ?? context.rw ?? 0;
    if (!auth.isSysadmin && effectiveRw <= 0) {
      throw ClientException(
        statusCode: 400,
        response: const {'message': 'Nomor RW target tidak valid.'},
      );
    }

    if (_isRtScopedOperator(auth)) {
      if (normalizedTarget == 'rt') {
        return _NormalizedAnnouncementTarget(
          targetType: 'rt',
          rt: context.rt ?? 0,
          rw: effectiveRw,
        );
      }
      return _NormalizedAnnouncementTarget(
        targetType: 'rw',
        rt: 0,
        rw: effectiveRw,
      );
    }

    if (normalizedTarget == 'rt') {
      final effectiveRt = targetRt ?? 0;
      if (effectiveRt <= 0) {
        throw ClientException(
          statusCode: 400,
          response: const {'message': 'Nomor RT target tidak valid.'},
        );
      }
      return _NormalizedAnnouncementTarget(
        targetType: 'rt',
        rt: effectiveRt,
        rw: effectiveRw,
      );
    }

    return _NormalizedAnnouncementTarget(
      targetType: normalizedTarget == 'all' ? 'all' : 'rw',
      rt: 0,
      rw: effectiveRw,
    );
  }

  Future<void> _ensureAnnouncementUnitAccess({
    required WorkspaceAccessProfile? profile,
    required String? orgUnitId,
  }) async {
    if ((orgUnitId ?? '').isEmpty || profile == null || profile.member.isSysadmin) {
      return;
    }
    if (!profile.canBroadcastUnit(orgUnitId!)) {
      throw ClientException(
        statusCode: 403,
        response: const {'message': 'Anda tidak memiliki hak broadcast unit ini.'},
      );
    }
  }

  Future<List<RecordModel>> _loadAnnouncementViewRecords({
    required Set<String> announcementIds,
    String? userId,
  }) async {
    if (_announcementViewsCollectionAvailable == false) {
      return const [];
    }
    if (announcementIds.isEmpty) {
      return const [];
    }

    final filters = <String>[
      '(${announcementIds.map((id) => 'announcement = "${_escapeFilterValue(id)}"').join(' || ')})',
    ];
    if ((userId ?? '').trim().isNotEmpty) {
      filters.add('user = "${_escapeFilterValue(userId!.trim())}"');
    }

    try {
      final records = await pb
          .collection(AppConstants.colAnnouncementViews)
          .getFullList(
            sort: '-viewed_at,-created',
            filter: filters.join(' && '),
          );
      _announcementViewsCollectionAvailable = true;
      return records;
    } on ClientException catch (error) {
      if (_isMissingCollectionContext(error)) {
        _announcementViewsCollectionAvailable = false;
        return const [];
      }
      rethrow;
    }
  }

  Future<Map<String, int>> _loadAnnouncementViewCounts(
    Set<String> announcementIds,
  ) async {
    final records = await _loadAnnouncementViewRecords(announcementIds: announcementIds);
    final counts = <String, int>{};
    for (final record in records) {
      final announcementId = _recordText(record, 'announcement');
      if (announcementId.isEmpty) {
        continue;
      }
      counts.update(announcementId, (value) => value + 1, ifAbsent: () => 1);
    }
    return counts;
  }

  Future<Set<String>> _loadViewedAnnouncementIds(
    Set<String> announcementIds,
    String userId,
  ) async {
    final records = await _loadAnnouncementViewRecords(
      announcementIds: announcementIds,
      userId: userId,
    );
    return records
        .map((record) => _recordText(record, 'announcement'))
        .where((id) => id.isNotEmpty)
        .toSet();
  }

  Future<void> _upsertAnnouncementView({
    required String announcementId,
    required String userId,
  }) async {
    if (_announcementViewsCollectionAvailable == false) {
      return;
    }
    final nowIso = DateTime.now().toUtc().toIso8601String();
    try {
      final existing = await _loadAnnouncementViewRecords(
        announcementIds: {announcementId},
        userId: userId,
      );
      if (existing.isEmpty) {
        await pb
            .collection(AppConstants.colAnnouncementViews)
            .create(
              body: {
                'announcement': announcementId,
                'user': userId,
                'viewed_at': nowIso,
              },
            );
      } else {
        await pb
            .collection(AppConstants.colAnnouncementViews)
            .update(existing.first.id, body: {'viewed_at': nowIso});
        for (final duplicate in existing.skip(1)) {
          try {
            await pb.collection(AppConstants.colAnnouncementViews).delete(
              duplicate.id,
            );
          } catch (_) {}
        }
      }
      final counts = await _loadAnnouncementViewCounts({announcementId});
      await _syncAnnouncementViewCount(
        announcementId,
        counts[announcementId] ?? 0,
      );
    } on ClientException catch (error) {
      if (_isMissingCollectionContext(error)) {
        _announcementViewsCollectionAvailable = false;
        return;
      }
      rethrow;
    }
  }

  Future<void> _syncAnnouncementViewCount(
    String announcementId,
    int totalViews, {
    int? currentCount,
  }
  ) async {
    if (currentCount != null && currentCount == totalViews) {
      return;
    }
    try {
      if (currentCount == null) {
        final record = await pb
            .collection(AppConstants.colAnnouncements)
            .getOne(announcementId);
        if (_recordInt(record, 'view_count') == totalViews) {
          return;
        }
      }
      await pb
          .collection(AppConstants.colAnnouncements)
          .update(announcementId, body: {'view_count': totalViews});
    } catch (_) {}
  }

  String _announcementAudienceCacheKey(RecordModel record) {
    return [
      _normalizeAnnouncementTargetType(_recordText(record, 'target_type')),
      _recordInt(record, 'rt'),
      _recordInt(record, 'rw'),
      _recordText(record, 'desa_code'),
      _recordText(record, 'kecamatan_code'),
      _recordText(record, 'kabupaten_code'),
      _recordText(record, 'provinsi_code'),
      _recordText(record, 'desa_kelurahan'),
      _recordText(record, 'kecamatan'),
      _recordText(record, 'kabupaten_kota'),
      _recordText(record, 'provinsi'),
    ].join('|');
  }

  Future<int> _countAnnouncementTargetAudience(RecordModel record) async {
    final filter = _buildAnnouncementAudienceFilter(record);
    final rows = await pb
        .collection(AppConstants.colWarga)
        .getFullList(filter: filter);
    return rows.length;
  }

  String _buildAnnouncementAudienceFilter(RecordModel record) {
    final conditions = <String>[];
    final rw = _recordInt(record, 'rw');
    if (rw > 0) {
      conditions.add('rw = $rw');
    }
    if (_normalizeAnnouncementTargetType(_recordText(record, 'target_type')) ==
        'rt') {
      final rt = _recordInt(record, 'rt');
      if (rt > 0) {
        conditions.add('rt = $rt');
      }
    }

    final scope = _ConversationScope.fromRecord(record);
    final hasCodes =
        scope.desaCode.isNotEmpty &&
        scope.kecamatanCode.isNotEmpty &&
        scope.kabupatenCode.isNotEmpty &&
        scope.provinsiCode.isNotEmpty;
    if (hasCodes) {
      conditions.add('no_kk.desa_code = "${_escapeFilterValue(scope.desaCode)}"');
      conditions.add(
        'no_kk.kecamatan_code = "${_escapeFilterValue(scope.kecamatanCode)}"',
      );
      conditions.add(
        'no_kk.kabupaten_code = "${_escapeFilterValue(scope.kabupatenCode)}"',
      );
      conditions.add(
        'no_kk.provinsi_code = "${_escapeFilterValue(scope.provinsiCode)}"',
      );
    } else if (scope.desaKelurahan.isNotEmpty &&
        scope.kecamatan.isNotEmpty &&
        scope.kabupatenKota.isNotEmpty &&
        scope.provinsi.isNotEmpty) {
      conditions.add(
        'no_kk.desa_kelurahan ~ "${_escapeFilterValue(scope.desaKelurahan)}"',
      );
      conditions.add('no_kk.kecamatan ~ "${_escapeFilterValue(scope.kecamatan)}"');
      conditions.add(
        'no_kk.kabupaten_kota ~ "${_escapeFilterValue(scope.kabupatenKota)}"',
      );
      conditions.add('no_kk.provinsi ~ "${_escapeFilterValue(scope.provinsi)}"');
    }

    return conditions.join(' && ');
  }

  Future<bool> _canAccessScopedConversation({
    required AuthState auth,
    required AreaAccessContext context,
    required String scopeType,
    required String orgUnitId,
    required _ConversationScope target,
  }) async {
    if (auth.isSysadmin) {
      return true;
    }

    switch (scopeType) {
      case AppConstants.convScopeDeveloperSupport:
      case AppConstants.convScopePrivateSupport:
        return _matchesScope(context, target, auth);
      case AppConstants.convScopeRt:
        return _matchesScope(context, target, auth);
      case AppConstants.convScopeRw:
        return _matchesRwScope(context, target, auth);
      case AppConstants.convScopeDkm:
      case AppConstants.convScopePosyandu:
      case AppConstants.convScopeCustom:
        return _hasActiveOrgMembership(orgUnitId);
      default:
        return false;
    }
  }

  Future<Map<String, String>> _loadSenderNames(Set<String> userIds) async {
    final result = <String, String>{};
    final profiles = await _loadChatUserProfiles(userIds);
    for (final entry in profiles.entries) {
      if (entry.value.displayName.isNotEmpty) {
        result[entry.key] = entry.value.displayName;
      }
    }
    return result;
  }

  Future<Map<String, _ChatUserProfile>> _loadChatUserProfiles(
    Set<String> userIds,
  ) async {
    final result = <String, _ChatUserProfile>{};
    final requestedIds = userIds.where((item) => item.isNotEmpty).toSet();
    if (requestedIds.isEmpty) {
      return result;
    }

    try {
      final query = requestedIds.join(',');
      final response = await pb.send<Map<String, dynamic>>(
        '$_chatProfilesPath/$query',
        method: 'GET',
      );
      final items = response['items'] as List<dynamic>? ?? const [];
      for (final item in items) {
        final json = Map<String, dynamic>.from(item as Map);
        final userId = json['userId']?.toString() ?? '';
        if (userId.isEmpty) {
          continue;
        }
        result[userId] = _ChatUserProfile(
          displayName: json['displayName']?.toString() ?? 'Pengguna',
          avatarUrl: _normalizeChatAvatarUrl(json['avatarUrl']?.toString()),
          role: AppConstants.effectiveLegacyRole(
            role: json['role']?.toString(),
            systemRole: json['systemRole']?.toString(),
            planCode: json['planCode']?.toString(),
          ),
          systemRole: AppConstants.effectiveSystemRole(
            role: json['role']?.toString(),
            systemRole: json['systemRole']?.toString(),
          ),
          planCode: AppConstants.effectivePlanCode(
            role: json['role']?.toString(),
            planCode: json['planCode']?.toString(),
          ),
        );
      }
    } catch (_) {}

    for (final userId in requestedIds.where(
      (item) => !result.containsKey(item),
    )) {
      final profile = await _resolveChatUserProfile(userId);
      if (profile != null) {
        result[userId] = profile;
      }
    }
    return result;
  }

  String? _normalizeChatAvatarUrl(String? value) {
    final raw = (value ?? '').trim();
    if (raw.isEmpty) {
      return null;
    }
    if (raw.startsWith('http://') || raw.startsWith('https://')) {
      return raw;
    }
    if (raw.startsWith('/')) {
      return '$pocketBaseUrl$raw';
    }
    return '$pocketBaseUrl/$raw';
  }

  Future<Map<String, _ChatUserProfile>>
  _enrichPrivateConversationOwnerProfiles({
    required Iterable<RecordModel> conversations,
    required Map<String, _ChatUserProfile> profiles,
  }) async {
    final result = Map<String, _ChatUserProfile>.from(profiles);
    final wargaCache = <String, _ChatUserProfile?>{};

    for (final conversation in conversations) {
      if (_recordText(conversation, 'type') != AppConstants.convPrivate) {
        continue;
      }

      final ownerId = _recordText(conversation, 'owner');
      if (ownerId.isEmpty) {
        continue;
      }

      final existing = result[ownerId];
      if ((existing?.avatarUrl ?? '').trim().isNotEmpty) {
        continue;
      }

      final fallbackName = (existing?.displayName ?? '').trim().isNotEmpty
          ? existing!.displayName.trim()
          : _recordText(
              conversation,
              'name',
            ).replaceFirst(RegExp(r'^Layanan\s*-\s*'), '').trim();
      if (fallbackName.isEmpty) {
        continue;
      }

      final cacheKey =
          '${fallbackName.toLowerCase()}|${_recordInt(conversation, 'rt')}|${_recordInt(conversation, 'rw')}';
      final fallbackProfile = wargaCache.containsKey(cacheKey)
          ? wargaCache[cacheKey]
          : await _resolveScopedWargaProfileByName(
              displayName: fallbackName,
              rt: _recordInt(conversation, 'rt'),
              rw: _recordInt(conversation, 'rw'),
              baseProfile: existing,
            );
      wargaCache[cacheKey] = fallbackProfile;

      if (fallbackProfile != null) {
        result[ownerId] = fallbackProfile;
      }
    }

    return result;
  }

  Future<Map<String, _ChatUserProfile>>
  _enrichProfilesWithScopedWargaAvatarFallback({
    required Map<String, _ChatUserProfile> profiles,
    required int rt,
    required int rw,
  }) async {
    final result = Map<String, _ChatUserProfile>.from(profiles);
    final wargaCache = <String, _ChatUserProfile?>{};

    for (final entry in result.entries.toList()) {
      if ((entry.value.avatarUrl ?? '').trim().isNotEmpty) {
        continue;
      }

      final displayName = entry.value.displayName.trim();
      if (displayName.isEmpty) {
        continue;
      }

      final cacheKey = '${displayName.toLowerCase()}|$rt|$rw';
      final fallbackProfile = wargaCache.containsKey(cacheKey)
          ? wargaCache[cacheKey]
          : await _resolveScopedWargaProfileByName(
              displayName: displayName,
              rt: rt,
              rw: rw,
              baseProfile: entry.value,
            );
      wargaCache[cacheKey] = fallbackProfile;

      if (fallbackProfile != null) {
        result[entry.key] = fallbackProfile;
      }
    }

    return result;
  }

  Future<_ChatUserProfile?> _resolveScopedWargaProfileByName({
    required String displayName,
    required int rt,
    required int rw,
    _ChatUserProfile? baseProfile,
  }) async {
    final normalizedName = _normalizePersonName(displayName);
    if (normalizedName.isEmpty) {
      return baseProfile;
    }

    final clauses = <String>[];
    if (rt > 0) {
      clauses.add('rt = $rt');
    }
    if (rw > 0) {
      clauses.add('rw = $rw');
    }

    try {
      final records = await pb
          .collection(AppConstants.colWarga)
          .getFullList(
            sort: 'nama_lengkap',
            filter: clauses.isEmpty ? '' : clauses.join(' && '),
          );
      if (records.isEmpty) {
        return baseProfile;
      }
      RecordModel? warga;
      for (final record in records) {
        if (_normalizePersonName(_recordText(record, 'nama_lengkap')) ==
            normalizedName) {
          warga = record;
          break;
        }
      }
      warga ??= records.firstWhere(
        (record) => _normalizePersonName(
          _recordText(record, 'nama_lengkap'),
        ).contains(normalizedName),
        orElse: () => records.first,
      );
      final fotoWarga = _recordText(warga, 'foto_warga');
      final avatarUrl = fotoWarga.isNotEmpty
          ? getFileUrl(warga, fotoWarga)
          : null;

      return _ChatUserProfile(
        displayName: _recordText(warga, 'nama_lengkap').trim().isNotEmpty
            ? _recordText(warga, 'nama_lengkap').trim()
            : displayName.trim(),
        avatarUrl: avatarUrl ?? baseProfile?.avatarUrl,
        role: baseProfile?.role ?? AppConstants.roleWarga,
        systemRole: baseProfile?.systemRole ?? AppConstants.systemRoleWarga,
        planCode: baseProfile?.planCode ?? AppConstants.planFree,
      );
    } catch (_) {
      return baseProfile;
    }
  }

  Future<List<RecordModel>> _loadMembershipRecords({
    required String conversationId,
    required String userId,
  }) async {
    if (_conversationMembersCollectionAvailable == false) {
      return const <RecordModel>[];
    }
    try {
      final records = await pb
          .collection(AppConstants.colConversationMembers)
          .getFullList(
            sort: '-updated,-created',
            filter:
                'conversation = "${_escapeFilterValue(conversationId)}" && user = "${_escapeFilterValue(userId)}"',
          );
      _conversationMembersCollectionAvailable = true;
      return records;
    } on ClientException catch (error) {
      if (_isMissingCollectionContext(error)) {
        _conversationMembersCollectionAvailable = false;
        return const <RecordModel>[];
      }
      rethrow;
    }
  }

  Future<List<RecordModel>> _loadConversationMemberships({
    required String conversationId,
    String? fallbackUserId,
  }) async {
    if (_conversationMembersCollectionAvailable == false) {
      return const <RecordModel>[];
    }
    try {
      final records = await pb
          .collection(AppConstants.colConversationMembers)
          .getFullList(
            sort: 'created',
            filter: 'conversation = "${_escapeFilterValue(conversationId)}"',
          );
      _conversationMembersCollectionAvailable = true;
      return records;
    } on ClientException catch (error) {
      final userId = (fallbackUserId ?? _auth.user?.id ?? '').trim();
      if (_isMissingCollectionContext(error)) {
        _conversationMembersCollectionAvailable = false;
        return const <RecordModel>[];
      }
      if (error.statusCode == 403 && userId.isNotEmpty) {
        return _loadMembershipRecords(
          conversationId: conversationId,
          userId: userId,
        );
      }
      rethrow;
    }
  }

  Future<RecordModel?> _updateConversationMember(
    String memberId, {
    required Map<String, dynamic> body,
  }) async {
    if (_conversationMembersCollectionAvailable == false) {
      return null;
    }
    try {
      final record = await pb
          .collection(AppConstants.colConversationMembers)
          .update(memberId, body: body);
      _conversationMembersCollectionAvailable = true;
      return record;
    } on ClientException catch (error) {
      if (_isMissingCollectionContext(error)) {
        _conversationMembersCollectionAvailable = false;
        return null;
      }
      rethrow;
    }
  }

  bool _isMissingCollectionContext(ClientException error) {
    final message = error.response['message']?.toString().toLowerCase() ?? '';
    return error.statusCode == 404 &&
        message.contains('missing collection context');
  }

  Future<List<RecordModel>> _loadConversationMessageRecords(
    String conversationId,
  ) {
    return pb
        .collection(AppConstants.colMessages)
        .getFullList(
          sort: 'created',
          filter: 'conversation = "${_escapeFilterValue(conversationId)}"',
        );
  }

  List<ChatParticipantModel> _buildConversationParticipants({
    required List<RecordModel> memberships,
    required Map<String, _ChatUserProfile> profiles,
    required String currentUserId,
  }) {
    return memberships
        .map((membership) {
          final userId = _recordText(membership, 'user');
          final profile = profiles[userId];
          return ChatParticipantModel(
            userId: userId,
            displayName: profile?.displayName ?? 'Pengguna',
            avatarUrl: profile?.avatarUrl,
            lastSeenAt: _recordDateTime(membership, 'last_seen_at'),
            typingAt: _recordDateTime(membership, 'typing_at'),
            isCurrentUser: userId == currentUserId,
          );
        })
        .where((item) => item.userId.isNotEmpty)
        .toList(growable: false);
  }

  Future<void> _markMessageDeliveredToRecipients({
    required String conversationId,
    required String messageId,
    required String senderId,
  }) async {
    final memberships = await _loadConversationMemberships(
      conversationId: conversationId,
    );
    final deliveredAt = DateTime.now().toUtc().toIso8601String();

    for (final membership in memberships) {
      final userId = _recordText(membership, 'user');
      if (userId.isEmpty || userId == senderId) {
        continue;
      }

      final existing = await pb
          .collection(AppConstants.colMessageReads)
          .getFullList(
            filter:
                'message = "${_escapeFilterValue(messageId)}" && user = "${_escapeFilterValue(userId)}"',
          );
      if (existing.isNotEmpty) {
        await pb
            .collection(AppConstants.colMessageReads)
            .update(existing.first.id, body: {'delivered_at': deliveredAt});
        continue;
      }

      await pb
          .collection(AppConstants.colMessageReads)
          .create(
            body: {
              'message': messageId,
              'user': userId,
              'delivered_at': deliveredAt,
              'read_at': null,
            },
          );
    }
  }

  Future<void> _syncMessageReadReceipts({
    required List<RecordModel> messages,
    required List<RecordModel> memberships,
    required String currentUserId,
  }) async {
    final ownMemberships = memberships
        .where((item) => _recordText(item, 'user') == currentUserId)
        .toList(growable: false);
    if (ownMemberships.isEmpty) {
      return;
    }
    final membership = ownMemberships.first;
    final readAt = _recordDateTime(membership, 'last_read_at');
    if (readAt == null) {
      return;
    }

    for (final message in messages) {
      if (_recordText(message, 'sender') == currentUserId) {
        continue;
      }
      final createdAt = _recordDateTime(message, 'created');
      if (createdAt == null || createdAt.isAfter(readAt)) {
        continue;
      }

      final existing = await pb
          .collection(AppConstants.colMessageReads)
          .getFullList(
            filter:
                'message = "${_escapeFilterValue(message.id)}" && user = "${_escapeFilterValue(currentUserId)}"',
          );
      final body = {
        'delivered_at': _recordText(message, 'created').isNotEmpty
            ? _recordText(message, 'created')
            : DateTime.now().toUtc().toIso8601String(),
        'read_at': readAt.toIso8601String(),
      };
      if (existing.isNotEmpty) {
        await pb
            .collection(AppConstants.colMessageReads)
            .update(existing.first.id, body: body);
      } else {
        await pb
            .collection(AppConstants.colMessageReads)
            .create(
              body: {'message': message.id, 'user': currentUserId, ...body},
            );
      }
    }
  }

  Future<Map<String, _MessageReceiptSummary>> _loadMessageReceiptSummaries({
    required List<RecordModel> messages,
    required List<RecordModel> memberships,
    required String currentUserId,
  }) async {
    final result = <String, _MessageReceiptSummary>{};
    final messageIds = messages.map((item) => item.id).toSet();
    if (messageIds.isEmpty) {
      return result;
    }

    final receiptRecords = await _loadMessageReceiptRecords(messageIds);
    final receiptMap = <String, List<RecordModel>>{};
    for (final record in receiptRecords) {
      final messageId = _recordText(record, 'message');
      if (messageId.isEmpty) {
        continue;
      }
      receiptMap.putIfAbsent(messageId, () => <RecordModel>[]).add(record);
    }

    final participantUserIds = memberships
        .map((item) => _recordText(item, 'user'))
        .where((item) => item.isNotEmpty)
        .toSet();

    for (final message in messages) {
      final senderId = _recordText(message, 'sender');
      final recipientCount = participantUserIds
          .where((id) => id != senderId)
          .length;
      final receipts = receiptMap[message.id] ?? const <RecordModel>[];
      final deliveredCount = receipts
          .where((item) => _recordText(item, 'delivered_at').isNotEmpty)
          .map((item) => _recordText(item, 'user'))
          .where((id) => id.isNotEmpty && id != senderId)
          .toSet()
          .length;
      final readCount = receipts
          .where((item) => _recordText(item, 'read_at').isNotEmpty)
          .map((item) => _recordText(item, 'user'))
          .where((id) => id.isNotEmpty && id != senderId)
          .toSet()
          .length;

      final status = recipientCount <= 0
          ? 'sent'
          : readCount >= recipientCount
          ? 'read'
          : deliveredCount >= recipientCount
          ? 'delivered'
          : 'sent';

      result[message.id] = _MessageReceiptSummary(
        recipientCount: recipientCount,
        deliveredCount: deliveredCount,
        readCount: readCount,
        status: status,
      );
    }

    return result;
  }

  Future<List<RecordModel>> _loadMessageReceiptRecords(
    Set<String> messageIds,
  ) async {
    final result = <RecordModel>[];
    final ids = messageIds.toList(growable: false);
    for (var start = 0; start < ids.length; start += 15) {
      final chunk = ids.skip(start).take(15).toList(growable: false);
      if (chunk.isEmpty) {
        continue;
      }
      final filter = chunk
          .map((id) => 'message = "${_escapeFilterValue(id)}"')
          .join(' || ');
      result.addAll(
        await pb
            .collection(AppConstants.colMessageReads)
            .getFullList(filter: filter),
      );
    }
    return result;
  }

  Future<Map<String, List<MessageReactionModel>>> _loadMessageReactions({
    required Set<String> messageIds,
    required String currentUserId,
  }) async {
    final result = <String, List<MessageReactionModel>>{};
    if (messageIds.isEmpty) {
      return result;
    }

    final records = <RecordModel>[];
    final ids = messageIds.toList(growable: false);
    for (var start = 0; start < ids.length; start += 15) {
      final chunk = ids.skip(start).take(15).toList(growable: false);
      if (chunk.isEmpty) {
        continue;
      }
      final filter = chunk
          .map((id) => 'message = "${_escapeFilterValue(id)}"')
          .join(' || ');
      records.addAll(
        await pb
            .collection(AppConstants.colMessageReactions)
            .getFullList(filter: filter),
      );
    }

    final grouped = <String, Map<String, _ReactionBucket>>{};
    for (final record in records) {
      final messageId = _recordText(record, 'message');
      final emoji = _recordText(record, 'emoji');
      if (messageId.isEmpty || emoji.isEmpty) {
        continue;
      }
      final byEmoji = grouped.putIfAbsent(
        messageId,
        () => <String, _ReactionBucket>{},
      );
      final bucket = byEmoji.putIfAbsent(emoji, () => _ReactionBucket());
      bucket.count += 1;
      if (_recordText(record, 'user') == currentUserId) {
        bucket.reactedByMe = true;
      }
    }

    for (final entry in grouped.entries) {
      final reactions =
          entry.value.entries
              .map(
                (item) => MessageReactionModel(
                  emoji: item.key,
                  count: item.value.count,
                  reactedByMe: item.value.reactedByMe,
                ),
              )
              .toList(growable: false)
            ..sort((left, right) {
              final countCompare = right.count.compareTo(left.count);
              if (countCompare != 0) {
                return countCompare;
              }
              return left.emoji.compareTo(right.emoji);
            });
      result[entry.key] = reactions;
    }

    return result;
  }

  bool _needsReadMarkerUpdate({
    required RecordModel membership,
    required List<RecordModel> messages,
    required String currentUserId,
  }) {
    final lastReadAt = _recordDateTime(membership, 'last_read_at');
    for (final message in messages.reversed) {
      if (_recordText(message, 'sender') == currentUserId) {
        continue;
      }
      final createdAt = _recordDateTime(message, 'created');
      if (createdAt == null) {
        continue;
      }
      return lastReadAt == null || createdAt.isAfter(lastReadAt);
    }
    return false;
  }

  String _normalizePersonName(String value) {
    return value.trim().toLowerCase().replaceAll(RegExp(r'\s+'), ' ');
  }

  Future<_ChatUserProfile?> _resolveChatUserProfile(String userId) async {
    String displayName = '';
    String? avatarUrl;

    try {
      final warga = await pb
          .collection(AppConstants.colWarga)
          .getFirstListItem('user_id = "${_escapeFilterValue(userId)}"');
      final wargaName = _recordText(warga, 'nama_lengkap');
      if (wargaName.isNotEmpty) {
        displayName = wargaName;
      }
      final fotoWarga = _recordText(warga, 'foto_warga');
      if (fotoWarga.isNotEmpty) {
        avatarUrl = getFileUrl(warga, fotoWarga);
      }
    } catch (_) {}

    try {
      final user = await pb.collection(AppConstants.colUsers).getOne(userId);
      final avatarFile = _recordText(user, 'avatar');
      return _ChatUserProfile(
        displayName: displayName.isNotEmpty
            ? displayName
            : _userDisplayName(user),
        avatarUrl: avatarFile.isNotEmpty
            ? getFileUrl(user, avatarFile)
            : avatarUrl,
        role: AppConstants.effectiveLegacyRole(
          role: _recordText(user, 'role'),
          systemRole: _recordText(user, 'system_role'),
          planCode: _recordText(user, 'plan_code'),
          subscriptionPlan: _recordText(user, 'subscription_plan'),
        ),
        systemRole: AppConstants.effectiveSystemRole(
          role: _recordText(user, 'role'),
          systemRole: _recordText(user, 'system_role'),
        ),
        planCode: AppConstants.effectivePlanCode(
          role: _recordText(user, 'role'),
          planCode: _recordText(user, 'plan_code'),
          subscriptionPlan: _recordText(user, 'subscription_plan'),
        ),
      );
    } catch (_) {
      if (displayName.isEmpty) {
        return null;
      }

      return _ChatUserProfile(
        displayName: displayName,
        avatarUrl: avatarUrl,
        role: AppConstants.roleWarga,
        systemRole: AppConstants.systemRoleWarga,
        planCode: AppConstants.planFree,
      );
    }
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

  Future<Map<String, ChatPollModel>> _loadPollsForMessages(
    List<RecordModel> messages, {
    required String currentUserId,
  }) async {
    final pollsById = <String, ChatPollModel>{};
    final pollIds = messages
        .map((record) => _recordText(record, 'poll'))
        .where((id) => id.isNotEmpty)
        .toSet();
    for (final pollId in pollIds) {
      try {
        pollsById[pollId] = await _loadPoll(
          pollId,
          currentUserId: currentUserId,
        );
      } catch (_) {}
    }
    return pollsById;
  }

  Future<bool> _hasActiveOrgMembership(String orgUnitId) async {
    if (orgUnitId.isEmpty) {
      return false;
    }
    final profile = await _ref
        .read(workspaceAccessServiceProvider)
        .getCurrentAccessProfile();
    if (profile == null) {
      return false;
    }
    if (profile.member.isSysadmin) {
      return true;
    }
    return profile.hasUnitMembership(orgUnitId);
  }

  Future<String> _workspaceMemberId() async {
    final profile = await _ref
        .read(workspaceAccessServiceProvider)
        .getCurrentAccessProfile();
    return profile?.member.id ?? '';
  }

  Future<ChatPollModel> _loadPoll(
    String pollId, {
    required String currentUserId,
  }) async {
    final pollRecord = await pb
        .collection(AppConstants.colChatPolls)
        .getOne(pollId);
    final optionRecords = await pb
        .collection(AppConstants.colChatPollOptions)
        .getFullList(
          filter: 'poll = "${_escapeFilterValue(pollId)}"',
          sort: 'sort_order,created',
        );
    final voteRecords = await pb
        .collection(AppConstants.colChatPollVotes)
        .getFullList(filter: 'poll = "${_escapeFilterValue(pollId)}"');

    final selectedOptionIds = voteRecords
        .where((vote) => _recordText(vote, 'user') == currentUserId)
        .map((vote) => _recordText(vote, 'option'))
        .toSet();
    final voteCountByOption = <String, int>{};
    for (final vote in voteRecords) {
      final optionId = _recordText(vote, 'option');
      voteCountByOption[optionId] = (voteCountByOption[optionId] ?? 0) + 1;
    }

    return ChatPollModel(
      id: pollRecord.id,
      title: _recordText(pollRecord, 'title'),
      status: _recordText(pollRecord, 'status').isEmpty
          ? 'open'
          : _recordText(pollRecord, 'status'),
      allowMultipleChoice: pollRecord.data['allow_multiple_choice'] == true,
      allowAnonymousVote: pollRecord.data['allow_anonymous_vote'] == true,
      options: optionRecords
          .map(
            (option) => ChatPollOptionModel(
              id: option.id,
              label: _recordText(option, 'label'),
              sortOrder: _recordInt(option, 'sort_order'),
              voteCount: voteCountByOption[option.id] ?? 0,
              isSelected: selectedOptionIds.contains(option.id),
            ),
          )
          .toList(growable: false),
      closedAt: DateTime.tryParse(_recordText(pollRecord, 'closed_at')),
    );
  }

  Future<WorkspaceAccessProfile> _requireWorkspaceProfile() async {
    final profile = await _ref
        .read(workspaceAccessServiceProvider)
        .getCurrentAccessProfile();
    if (profile == null) {
      throw ClientException(
        statusCode: 403,
        response: const {'message': 'Workspace aktif belum tersedia.'},
      );
    }
    return profile;
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

    final message = await pb
        .collection(AppConstants.colMessages)
        .getOne(messageId);
    final conversationId = _recordText(message, 'conversation');
    final conversation = await pb
        .collection(AppConstants.colConversations)
        .getOne(conversationId);
    final area = await resolveAreaAccessContext(auth);
    if (!await _canAccessConversation(
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
    required Map<String, _ChatUserProfile> senderProfiles,
    required Map<String, RecordModel> relatedRecords,
    required Map<String, _MessageReceiptSummary> receiptSummaries,
    required Map<String, List<MessageReactionModel>> reactionModelsByMessage,
    required Map<String, ChatPollModel> pollsById,
  }) {
    final replyId = _recordText(record, 'reply_to');
    final replyRecord = relatedRecords[replyId];
    final forwardedId = _recordText(record, 'forwarded_from');
    final forwardedRecord = relatedRecords[forwardedId];
    final isDeleted = _recordText(record, 'deleted_at').isNotEmpty;
    final voiceDuration = _recordInt(record, 'voice_duration_seconds');
    final senderId = _recordText(record, 'sender');
    final senderProfile = senderProfiles[senderId];
    final pinnedUntil = _recordDateTime(record, 'pinned_until');
    final receiptSummary = receiptSummaries[record.id];

    return MessageModel(
      id: record.id,
      conversationId: _recordText(record, 'conversation'),
      senderId: senderId,
      senderName: senderProfile?.displayName ?? 'Pengguna',
      text: _recordText(record, 'text'),
      messageType: _recordText(record, 'message_type').isEmpty
          ? 'text'
          : _recordText(record, 'message_type'),
      isMine: senderId == currentUserId,
      isStarred: record.data['is_starred'] == true,
      isPinned: _isMessagePinnedRecord(record, pinnedUntil: pinnedUntil),
      isDeleted: isDeleted,
      attachmentName: isDeleted || _recordText(record, 'attachment').isEmpty
          ? null
          : _recordText(record, 'attachment'),
      attachmentUrl: isDeleted ? null : _fileUrl(record, 'attachment'),
      replyToId: replyId.isEmpty ? null : replyId,
      replySenderName: replyRecord == null
          ? null
          : senderProfiles[_recordText(replyRecord, 'sender')]?.displayName ??
                'Pengguna',
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
          : senderProfiles[_recordText(forwardedRecord, 'sender')]
                    ?.displayName ??
                'Pengguna',
      createdAt: DateTime.tryParse(_recordText(record, 'created')),
      editedAt: _recordDateTime(record, 'edited_at'),
      pinnedUntil: pinnedUntil,
      voiceDurationSeconds: voiceDuration > 0 ? voiceDuration : null,
      pollId: _recordText(record, 'poll').isEmpty
          ? null
          : _recordText(record, 'poll'),
      senderBadgeLabel: _recordText(record, 'sender_badge_label').isEmpty
          ? null
          : _recordText(record, 'sender_badge_label'),
      senderAvatarUrl: senderProfile?.avatarUrl,
      senderPlanCode: senderProfile?.planCode,
      senderSystemRole: senderProfile?.systemRole,
      deliveryStatus: senderId == currentUserId
          ? receiptSummary?.status ?? 'sent'
          : null,
      deliveredCount: receiptSummary?.deliveredCount ?? 0,
      readCount: receiptSummary?.readCount ?? 0,
      recipientCount: receiptSummary?.recipientCount ?? 0,
      reactions: reactionModelsByMessage[record.id] ?? const [],
      poll: pollsById[_recordText(record, 'poll')],
    );
  }

  ConversationModel _conversationFromRecord(
    RecordModel record, {
    required String currentUserId,
    RecordModel? membership,
    required int unreadCount,
    required Map<String, _ChatUserProfile> userProfiles,
  }) {
    final type = _recordText(record, 'type');
    final ownerId = _recordText(record, 'owner');
    final isOwner = ownerId == currentUserId;
    final ownerProfile = userProfiles[ownerId];
    final rawName = _recordText(record, 'name');
    final title = type == AppConstants.convPrivate
        ? (isOwner
              ? 'Inbox Admin RT/RW'
              : (ownerProfile?.displayName ??
                    rawName
                        .replaceFirst(RegExp(r'^Layanan\\s*-\\s*'), '')
                        .trim()))
        : rawName;
    final rt = _recordInt(record, 'rt');
    final rw = _recordInt(record, 'rw');
    final participantRole = ownerProfile == null
        ? null
        : AppConstants.roleFromSystemRolePlan(
            systemRole: ownerProfile.systemRole,
            planCode: ownerProfile.planCode,
          );

    return ConversationModel(
      id: record.id,
      key: _recordText(record, 'key'),
      type: type,
      name: title,
      subtitle: type == AppConstants.convPrivate
          ? 'RT ${rt.toString().padLeft(2, '0')} / RW ${rw.toString().padLeft(2, '0')}'
          : type == AppConstants.convGroupRt
          ? 'Forum operasional warga dan pengurus di RT ini.'
          : 'Koordinasi lintas RT untuk pengurus RW.',
      rt: rt,
      rw: rw,
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
      workspaceId: _recordText(record, 'workspace').isEmpty
          ? null
          : _recordText(record, 'workspace'),
      orgUnitId: _recordText(record, 'org_unit').isEmpty
          ? null
          : _recordText(record, 'org_unit'),
      scopeType: _recordText(record, 'scope_type').isEmpty
          ? null
          : _recordText(record, 'scope_type'),
      requiredPlanCode: _recordText(record, 'required_plan_code').isEmpty
          ? null
          : _recordText(record, 'required_plan_code'),
      avatarUrl: type == AppConstants.convPrivate
          ? ownerProfile?.avatarUrl
          : null,
      badgeLabel: type == AppConstants.convPrivate && participantRole != null
          ? AppConstants.roleLabel(participantRole)
          : null,
      participantPlanCode: type == AppConstants.convPrivate
          ? ownerProfile?.planCode
          : null,
      participantSystemRole: type == AppConstants.convPrivate
          ? ownerProfile?.systemRole
          : null,
    );
  }

  int _compareConversationModels(
    ConversationModel left,
    ConversationModel right,
  ) {
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
    AuthState auth,
  ) {
    if (!_matchesRegion(context, target)) {
      return false;
    }
    if (target.rw <= 0 || target.rw != (context.rw ?? 0)) {
      return false;
    }
    if (_hasRwWideAccess(auth)) {
      return true;
    }
    return target.rt > 0 && target.rt == (context.rt ?? 0);
  }

  bool _matchesRwScope(
    AreaAccessContext context,
    _ConversationScope target,
    AuthState auth,
  ) {
    if (_isWarga(auth)) {
      return false;
    }
    if (!_matchesRegion(context, target)) {
      return false;
    }
    return target.rw > 0 && target.rw == (context.rw ?? 0);
  }

  bool _matchesRegion(AreaAccessContext context, _ConversationScope target) {
    final hasCodes =
        (context.desaCode ?? '').isNotEmpty &&
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

  bool _canCreateAnnouncement(AuthState auth) {
    return auth.isSysadmin || auth.isOperator;
  }

  bool _isWarga(AuthState auth) => !auth.isOperator && !auth.isSysadmin;

  bool _hasRwWideAccess(AuthState auth) =>
      auth.isSysadmin || auth.hasRwWideAccess;

  bool _isRtScopedOperator(AuthState auth) =>
      auth.isOperator && !auth.isSysadmin && !auth.hasRwWideAccess;

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
    final latest = await pb
        .collection(AppConstants.colMessages)
        .getList(
          page: 1,
          perPage: 1,
          sort: '-created',
          filter: 'conversation = "${_escapeFilterValue(conversationId)}"',
        );
    if (latest.items.isEmpty) {
      await pb
          .collection(AppConstants.colConversations)
          .update(
            conversationId,
            body: {'last_message': '', 'last_message_at': null},
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
    await pb
        .collection(AppConstants.colConversations)
        .update(
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

class _ChatUserProfile {
  const _ChatUserProfile({
    required this.displayName,
    required this.avatarUrl,
    required this.role,
    required this.systemRole,
    required this.planCode,
  });

  final String displayName;
  final String? avatarUrl;
  final String role;
  final String systemRole;
  final String planCode;
}

class _CachedChatBootstrap {
  const _CachedChatBootstrap({required this.data, required this.cachedAt});

  final ChatBootstrapData data;
  final DateTime cachedAt;
}

class _CachedChatMessages {
  const _CachedChatMessages({required this.data, required this.cachedAt});

  final ChatMessagesData data;
  final DateTime cachedAt;
}

class _MessageReceiptSummary {
  const _MessageReceiptSummary({
    required this.recipientCount,
    required this.deliveredCount,
    required this.readCount,
    required this.status,
  });

  final int recipientCount;
  final int deliveredCount;
  final int readCount;
  final String status;
}

class _ReactionBucket {
  _ReactionBucket();

  int count = 0;
  bool reactedByMe = false;
}

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
  String get kecamatanCodeOrName =>
      kecamatanCode.isNotEmpty ? kecamatanCode : _normalizeAreaValue(kecamatan);
  String get kabupatenCodeOrName => kabupatenCode.isNotEmpty
      ? kabupatenCode
      : _normalizeAreaValue(kabupatenKota);
  String get provinsiCodeOrName =>
      provinsiCode.isNotEmpty ? provinsiCode : _normalizeAreaValue(provinsi);
}

class _NormalizedAnnouncementTarget {
  const _NormalizedAnnouncementTarget({
    required this.targetType,
    required this.rt,
    required this.rw,
  });

  final String targetType;
  final int rt;
  final int rw;
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

DateTime? _recordDateTime(RecordModel record, String field) {
  final raw = _recordText(record, field);
  if (raw.isEmpty) {
    return null;
  }
  return DateTime.tryParse(raw)?.toUtc();
}

bool _isMessagePinnedRecord(RecordModel record, {DateTime? pinnedUntil}) {
  if (record.data['is_pinned'] != true) {
    return false;
  }
  final expiresAt = pinnedUntil ?? _recordDateTime(record, 'pinned_until');
  if (expiresAt == null) {
    return true;
  }
  return expiresAt.isAfter(DateTime.now().toUtc());
}

String _normalizeAreaValue(String? value) {
  return (value ?? '').trim().toLowerCase();
}

String _slugify(String value) {
  final normalized = value.trim().toLowerCase();
  final buffer = StringBuffer();
  var lastDash = false;
  for (final rune in normalized.runes) {
    final character = String.fromCharCode(rune);
    final isAlphaNumeric = RegExp(r'[a-z0-9]').hasMatch(character);
    if (isAlphaNumeric) {
      buffer.write(character);
      lastDash = false;
      continue;
    }
    if (!lastDash && buffer.isNotEmpty) {
      buffer.write('-');
      lastDash = true;
    }
  }
  return buffer.toString().replaceAll(RegExp(r'-+$'), '');
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
