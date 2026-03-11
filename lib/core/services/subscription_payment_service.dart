import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pocketbase/pocketbase.dart';

import '../constants/app_constants.dart';
import 'pocketbase_service.dart';

final subscriptionPaymentServiceProvider = Provider<SubscriptionPaymentService>(
  (ref) {
    return SubscriptionPaymentService(pb);
  },
);

class SubscriptionPlan {
  const SubscriptionPlan({
    required this.code,
    required this.name,
    required this.description,
    required this.amount,
    required this.durationDays,
    required this.targetRole,
    required this.planCode,
    required this.targetSystemRole,
    required this.scopeLevel,
    required this.featureFlags,
  });

  final String code;
  final String name;
  final String description;
  final int amount;
  final int durationDays;
  final String targetRole;
  final String planCode;
  final String targetSystemRole;
  final String scopeLevel;
  final List<String> featureFlags;

  factory SubscriptionPlan.fromJson(Map<String, dynamic> json) {
    final planCode = AppConstants.normalizePlanCode(
      json['planCode'] as String? ?? '',
      fallbackRole: json['targetRole'] as String?,
      subscriptionPlan: json['code'] as String?,
    );
    final targetSystemRole = AppConstants.effectiveSystemRole(
      role: json['targetRole'] as String?,
      systemRole: json['targetSystemRole'] as String?,
    );
    return SubscriptionPlan(
      code: json['code'] as String? ?? '',
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      amount: (json['amount'] as num?)?.toInt() ?? 0,
      durationDays: (json['durationDays'] as num?)?.toInt() ?? 0,
      targetRole: AppConstants.effectiveLegacyRole(
        role: json['targetRole'] as String?,
        systemRole: targetSystemRole,
        planCode: planCode,
        subscriptionPlan: json['code'] as String?,
      ),
      planCode: planCode,
      targetSystemRole: targetSystemRole,
      scopeLevel: json['scopeLevel'] as String? ?? '',
      featureFlags: _stringList(json['featureFlags']),
    );
  }
}

class SubscriptionCatalog {
  const SubscriptionCatalog({
    required this.plans,
    required this.environment,
    required this.checkoutReady,
    this.checkoutMessage,
  });

  final List<SubscriptionPlan> plans;
  final String environment;
  final bool checkoutReady;
  final String? checkoutMessage;

  factory SubscriptionCatalog.fromJson(Map<String, dynamic> json) {
    final rawPlans = json['plans'] as List<dynamic>? ?? const [];
    final hasCheckoutReady = json.containsKey('checkoutReady');
    final checkoutReady = json['checkoutReady'] as bool? ?? false;
    final checkoutMessage = json['checkoutMessage'] as String?;
    return SubscriptionCatalog(
      plans: rawPlans
          .map(
            (item) => SubscriptionPlan.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList(growable: false),
      environment: json['environment'] as String? ?? 'sandbox',
      checkoutReady: hasCheckoutReady ? checkoutReady : false,
      checkoutMessage: hasCheckoutReady
          ? checkoutMessage
          : 'Status kesiapan checkout Midtrans belum dikirim server. Restart PocketBase agar hook subscription terbaru aktif.',
    );
  }
}

class SubscriptionCheckout {
  const SubscriptionCheckout({
    required this.id,
    required this.orderId,
    required this.planCode,
    required this.targetRole,
    required this.targetSystemRole,
    required this.planName,
    required this.grossAmount,
    required this.currency,
    required this.snapToken,
    required this.redirectUrl,
    required this.paymentState,
    required this.transactionStatus,
    required this.subscriptionApplied,
    required this.scopeLevel,
    required this.featureFlags,
    this.transactionId,
    this.paymentType,
    this.seatTarget,
    this.subscriptionStarted,
    this.subscriptionExpired,
    this.statusCode,
    this.statusMessage,
    this.created,
    this.updated,
  });

  final String id;
  final String orderId;
  final String planCode;
  final String targetRole;
  final String targetSystemRole;
  final String planName;
  final int grossAmount;
  final String currency;
  final String snapToken;
  final String redirectUrl;
  final String paymentState;
  final String transactionStatus;
  final bool subscriptionApplied;
  final String scopeLevel;
  final List<String> featureFlags;
  final String? transactionId;
  final String? paymentType;
  final String? seatTarget;
  final String? subscriptionStarted;
  final String? subscriptionExpired;
  final String? statusCode;
  final String? statusMessage;
  final DateTime? created;
  final DateTime? updated;

  bool get isPaid => paymentState == 'paid';
  bool get isPending =>
      paymentState == 'pending' || paymentState == 'token_ready';

  factory SubscriptionCheckout.fromJson(Map<String, dynamic> json) {
    final planCode = AppConstants.normalizePlanCode(
      json['planCode'] as String? ?? '',
      fallbackRole: json['targetRole'] as String?,
    );
    final targetSystemRole = AppConstants.effectiveSystemRole(
      role: json['targetRole'] as String?,
      systemRole: json['targetSystemRole'] as String?,
    );
    return SubscriptionCheckout(
      id: json['id'] as String? ?? '',
      orderId: json['orderId'] as String? ?? '',
      planCode: planCode,
      targetRole: AppConstants.effectiveLegacyRole(
        role: json['targetRole'] as String?,
        systemRole: targetSystemRole,
        planCode: planCode,
      ),
      targetSystemRole: targetSystemRole,
      planName: json['planName'] as String? ?? '',
      grossAmount: (json['grossAmount'] as num?)?.toInt() ?? 0,
      currency: json['currency'] as String? ?? 'IDR',
      snapToken: json['snapToken'] as String? ?? '',
      redirectUrl: json['redirectUrl'] as String? ?? '',
      paymentState: json['paymentState'] as String? ?? '',
      transactionStatus: json['transactionStatus'] as String? ?? '',
      subscriptionApplied: json['subscriptionApplied'] as bool? ?? false,
      scopeLevel: json['scopeLevel'] as String? ?? '',
      featureFlags: _stringList(json['featureFlags']),
      transactionId: json['transactionId'] as String?,
      paymentType: json['paymentType'] as String?,
      seatTarget: json['seatTarget'] as String?,
      subscriptionStarted: json['subscriptionStarted'] as String?,
      subscriptionExpired: json['subscriptionExpired'] as String?,
      statusCode: json['statusCode'] as String?,
      statusMessage: json['statusMessage'] as String?,
      created: DateTime.tryParse(json['created'] as String? ?? ''),
      updated: DateTime.tryParse(json['updated'] as String? ?? ''),
    );
  }
}

class SubscriptionPaymentService {
  SubscriptionPaymentService(this._pb);

  final PocketBase _pb;
  static const Duration _requestTimeout = Duration(seconds: 12);

  static const String _plansPath =
      '/api/rukunwarga/payments/subscription/plans';
  static const String _checkoutPath =
      '/api/rukunwarga/payments/subscription/snap';

  Future<SubscriptionCatalog> getCatalog() async {
    try {
      final response = await _pb
          .send<Map<String, dynamic>>(_plansPath)
          .timeout(_requestTimeout);
      return SubscriptionCatalog.fromJson(response);
    } on TimeoutException {
      return _loadCatalogFromCollection();
    } on ClientException catch (error) {
      if (error.statusCode == 401 || error.statusCode == 403) {
        rethrow;
      }
      return _loadCatalogFromCollection();
    } catch (_) {
      return _loadCatalogFromCollection();
    }
  }

  Future<SubscriptionCheckout> createCheckout({
    required String planCode,
    List<String> enabledPayments = const [],
  }) async {
    final body = <String, dynamic>{'planCode': planCode};

    if (enabledPayments.isNotEmpty) {
      body['enabledPayments'] = enabledPayments;
    }

    final response = await _pb
        .send<Map<String, dynamic>>(_checkoutPath, method: 'POST', body: body)
        .timeout(_requestTimeout);

    return SubscriptionCheckout.fromJson(response);
  }

  Future<SubscriptionCheckout> getStatus(String orderId) async {
    final response = await _pb
        .send<Map<String, dynamic>>(
          '/api/rukunwarga/payments/subscription/status/$orderId',
        )
        .timeout(_requestTimeout);

    return SubscriptionCheckout.fromJson(response);
  }

  Future<SubscriptionCatalog> _loadCatalogFromCollection() async {
    final currentRole = AppConstants.effectiveLegacyRole(
      role: _pb.authStore.record?.getStringValue('role'),
      systemRole: _pb.authStore.record?.getStringValue('system_role'),
      planCode: _pb.authStore.record?.getStringValue('plan_code'),
      subscriptionPlan: _pb.authStore.record?.getStringValue(
        'subscription_plan',
      ),
    );

    final records = await _pb
        .collection(AppConstants.colSubscriptionPlans)
        .getFullList(filter: 'is_active = true', sort: 'sort_order,created')
        .timeout(_requestTimeout);

    final plans = records
        .map(_planFromRecord)
        .where(
          (plan) => AppConstants.canPurchaseRole(
            currentRole: currentRole,
            targetRole: plan.targetRole,
          ),
        )
        .toList(growable: false);

    return SubscriptionCatalog(
      plans: plans,
      environment: 'unknown',
      checkoutReady: false,
      checkoutMessage:
          'Status checkout tidak dapat diverifikasi dari server. Pastikan PocketBase memakai hook subscription terbaru lalu restart server.',
    );
  }

  SubscriptionPlan _planFromRecord(RecordModel record) {
    final planCode = AppConstants.normalizePlanCode(
      record.getStringValue('plan_code'),
      fallbackRole: record.getStringValue('target_role'),
      subscriptionPlan: record.getStringValue('code'),
    );
    final targetSystemRole = AppConstants.effectiveSystemRole(
      role: record.getStringValue('target_role'),
      systemRole: record.getStringValue('target_system_role'),
    );
    return SubscriptionPlan(
      code: record.getStringValue('code'),
      name: record.getStringValue('name'),
      description: record.getStringValue('description'),
      amount: record.getIntValue('amount'),
      durationDays: record.getIntValue('duration_days'),
      targetRole: AppConstants.effectiveLegacyRole(
        role: record.getStringValue('target_role'),
        systemRole: targetSystemRole,
        planCode: planCode,
        subscriptionPlan: record.getStringValue('code'),
      ),
      planCode: planCode,
      targetSystemRole: targetSystemRole,
      scopeLevel: record.getStringValue('scope_level'),
      featureFlags: _recordStringList(record, 'feature_flags'),
    );
  }
}

List<String> _recordStringList(RecordModel record, String field) {
  final raw = record.data[field];
  if (raw is List) {
    return raw
        .map((item) => item.toString())
        .where((item) => item.isNotEmpty)
        .toList(growable: false);
  }
  return const [];
}

List<String> _stringList(dynamic raw) {
  if (raw is! List) {
    return const [];
  }
  return raw
      .map((item) => item.toString())
      .where((item) => item.isNotEmpty)
      .toList(growable: false);
}
