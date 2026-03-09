import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pocketbase/pocketbase.dart';

import 'pocketbase_service.dart';

final subscriptionPaymentServiceProvider =
    Provider<SubscriptionPaymentService>((ref) {
      return SubscriptionPaymentService(pb);
    });

class SubscriptionPlan {
  const SubscriptionPlan({
    required this.code,
    required this.name,
    required this.description,
    required this.amount,
    required this.durationDays,
  });

  final String code;
  final String name;
  final String description;
  final int amount;
  final int durationDays;

  factory SubscriptionPlan.fromJson(Map<String, dynamic> json) {
    return SubscriptionPlan(
      code: json['code'] as String? ?? '',
      name: json['name'] as String? ?? '',
      description: json['description'] as String? ?? '',
      amount: (json['amount'] as num?)?.toInt() ?? 0,
      durationDays: (json['durationDays'] as num?)?.toInt() ?? 0,
    );
  }
}

class SubscriptionCheckout {
  const SubscriptionCheckout({
    required this.id,
    required this.orderId,
    required this.planCode,
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
  bool get isPending => paymentState == 'pending' || paymentState == 'token_ready';

  factory SubscriptionCheckout.fromJson(Map<String, dynamic> json) {
    return SubscriptionCheckout(
      id: json['id'] as String? ?? '',
      orderId: json['orderId'] as String? ?? '',
      planCode: json['planCode'] as String? ?? '',
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

  static const String _plansPath =
      '/api/rukunwarga/payments/subscription/plans';
  static const String _checkoutPath =
      '/api/rukunwarga/payments/subscription/snap';

  Future<List<SubscriptionPlan>> getPlans() async {
    final response = await _pb.send<Map<String, dynamic>>(_plansPath);
    final rawPlans = response['plans'] as List<dynamic>? ?? const [];

    return rawPlans
        .map((item) => SubscriptionPlan.fromJson(
              Map<String, dynamic>.from(item as Map),
            ))
        .toList();
  }

  Future<SubscriptionCheckout> createCheckout({
    required String planCode,
    List<String> enabledPayments = const [],
  }) async {
    final body = <String, dynamic>{'planCode': planCode};

    if (enabledPayments.isNotEmpty) {
      body['enabledPayments'] = enabledPayments;
    }

    final response = await _pb.send<Map<String, dynamic>>(
      _checkoutPath,
      method: 'POST',
      body: body,
    );

    return SubscriptionCheckout.fromJson(response);
  }

  Future<SubscriptionCheckout> getStatus(String orderId) async {
    final response = await _pb.send<Map<String, dynamic>>(
      '/api/rukunwarga/payments/subscription/status/$orderId',
    );

    return SubscriptionCheckout.fromJson(response);
  }
}
