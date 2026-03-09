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
  });

  final String code;
  final String name;
  final String description;
  final int amount;
  final int durationDays;
  final String targetRole;

  factory SubscriptionPlan.fromJson(Map<String, dynamic> json) {
    return SubscriptionPlan(
      code: json['code'] as String? ?? '',
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      amount: (json['amount'] as num?)?.toInt() ?? 0,
      durationDays: (json['durationDays'] as num?)?.toInt() ?? 0,
      targetRole: json['targetRole'] as String? ?? '',
    );
  }
}

class SubscriptionCheckout {
  const SubscriptionCheckout({
    required this.id,
    required this.orderId,
    required this.planCode,
    required this.targetRole,
    required this.planName,
    required this.grossAmount,
    required this.currency,
    required this.snapToken,
    required this.redirectUrl,
    required this.paymentState,
    required this.transactionStatus,
    required this.subscriptionApplied,
    this.transactionId,
    this.paymentType,
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
  final String planName;
  final int grossAmount;
  final String currency;
  final String snapToken;
  final String redirectUrl;
  final String paymentState;
  final String transactionStatus;
  final bool subscriptionApplied;
  final String? transactionId;
  final String? paymentType;
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
    return SubscriptionCheckout(
      id: json['id'] as String? ?? '',
      orderId: json['orderId'] as String? ?? '',
      planCode: json['planCode'] as String? ?? '',
      targetRole: json['targetRole'] as String? ?? '',
      planName: json['planName'] as String? ?? '',
      grossAmount: (json['grossAmount'] as num?)?.toInt() ?? 0,
      currency: json['currency'] as String? ?? 'IDR',
      snapToken: json['snapToken'] as String? ?? '',
      redirectUrl: json['redirectUrl'] as String? ?? '',
      paymentState: json['paymentState'] as String? ?? '',
      transactionStatus: json['transactionStatus'] as String? ?? '',
      subscriptionApplied: json['subscriptionApplied'] as bool? ?? false,
      transactionId: json['transactionId'] as String?,
      paymentType: json['paymentType'] as String?,
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

  Future<List<SubscriptionPlan>> getPlans() async {
    try {
      final response = await _pb
          .send<Map<String, dynamic>>(_plansPath)
          .timeout(_requestTimeout);
      final rawPlans = response['plans'] as List<dynamic>? ?? const [];

      return rawPlans
          .map(
            (item) => SubscriptionPlan.fromJson(
              Map<String, dynamic>.from(item as Map),
            ),
          )
          .toList();
    } on TimeoutException {
      return _loadPlansFromCollection();
    } on ClientException catch (error) {
      if (error.statusCode == 401 || error.statusCode == 403) {
        rethrow;
      }
      return _loadPlansFromCollection();
    } catch (_) {
      return _loadPlansFromCollection();
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

  Future<List<SubscriptionPlan>> _loadPlansFromCollection() async {
    final currentRole = AppConstants.normalizeRole(
      _pb.authStore.record?.getStringValue('role') ?? AppConstants.roleWarga,
    );

    final records = await _pb
        .collection(AppConstants.colSubscriptionPlans)
        .getFullList(filter: 'is_active = true', sort: 'sort_order,created')
        .timeout(_requestTimeout);

    return records
        .map(_planFromRecord)
        .where(
          (plan) => AppConstants.canPurchaseRole(
            currentRole: currentRole,
            targetRole: plan.targetRole,
          ),
        )
        .toList();
  }

  SubscriptionPlan _planFromRecord(RecordModel record) {
    return SubscriptionPlan(
      code: record.getStringValue('code'),
      name: record.getStringValue('name'),
      description: record.getStringValue('description'),
      amount: record.getIntValue('amount'),
      durationDays: record.getIntValue('duration_days'),
      targetRole: record.getStringValue('target_role'),
    );
  }
}
