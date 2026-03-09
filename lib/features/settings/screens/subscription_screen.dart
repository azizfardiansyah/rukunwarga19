import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';

import '../../../app/router.dart';
import '../../../app/theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/subscription_payment_service.dart';
import '../../../core/utils/error_classifier.dart';
import '../../../core/utils/formatters.dart';
import '../../auth/providers/auth_provider.dart';

final subscriptionPlansProvider =
    FutureProvider.autoDispose<List<SubscriptionPlan>>((ref) async {
      return ref.watch(subscriptionPaymentServiceProvider).getPlans();
    });

class SubscriptionScreen extends ConsumerStatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  ConsumerState<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends ConsumerState<SubscriptionScreen> {
  SubscriptionCheckout? _checkout;
  bool _isCreatingCheckout = false;
  bool _isCheckingStatus = false;
  bool _isOpeningPayment = false;
  bool _isRefreshingAccount = false;

  Future<void> _createCheckout(String planCode) async {
    if (planCode.isEmpty) {
      ErrorClassifier.showErrorSnackBar(
        context,
        StateError('Plan subscription untuk role ini belum dikonfigurasi.'),
      );
      return;
    }

    setState(() => _isCreatingCheckout = true);
    try {
      final checkout = await ref
          .read(subscriptionPaymentServiceProvider)
          .createCheckout(planCode: planCode);
      if (!mounted) return;

      setState(() => _checkout = checkout);
      ErrorClassifier.showSuccessSnackBar(
        context,
        'Checkout berhasil dibuat. Buka pembayaran untuk lanjut.',
      );
    } catch (e) {
      if (!mounted) return;
      ErrorClassifier.showErrorSnackBar(context, e);
    } finally {
      if (mounted) {
        setState(() => _isCreatingCheckout = false);
      }
    }
  }

  Future<void> _openPayment() async {
    final redirectUrl = _checkout?.redirectUrl ?? '';
    final uri = Uri.tryParse(redirectUrl);

    if (redirectUrl.isEmpty || uri == null) {
      ErrorClassifier.showErrorSnackBar(
        context,
        StateError('Redirect URL pembayaran belum tersedia.'),
      );
      return;
    }

    setState(() => _isOpeningPayment = true);
    try {
      final launched = await launchUrl(
        uri,
        mode: LaunchMode.externalApplication,
      );

      if (!launched) {
        throw StateError('Link pembayaran tidak bisa dibuka.');
      }
    } catch (e) {
      if (!mounted) return;
      ErrorClassifier.showErrorSnackBar(context, e);
    } finally {
      if (mounted) {
        setState(() => _isOpeningPayment = false);
      }
    }
  }

  Future<void> _copyPaymentLink() async {
    final redirectUrl = _checkout?.redirectUrl ?? '';
    if (redirectUrl.isEmpty) {
      ErrorClassifier.showErrorSnackBar(
        context,
        StateError('Belum ada link pembayaran untuk disalin.'),
      );
      return;
    }

    await Clipboard.setData(ClipboardData(text: redirectUrl));
    if (!mounted) return;
    ErrorClassifier.showSuccessSnackBar(
      context,
      'Link pembayaran disalin ke clipboard.',
    );
  }

  Future<void> _checkStatus() async {
    final orderId = _checkout?.orderId ?? '';
    if (orderId.isEmpty) {
      ErrorClassifier.showErrorSnackBar(
        context,
        StateError('Buat checkout dulu sebelum cek status.'),
      );
      return;
    }

    setState(() => _isCheckingStatus = true);
    try {
      final checkout = await ref
          .read(subscriptionPaymentServiceProvider)
          .getStatus(orderId);

      setState(() => _checkout = checkout);
      await ref.read(authProvider.notifier).refreshAuth();
      if (!mounted) return;

      final latestAuth = ref.read(authProvider);
      ErrorClassifier.showSuccessSnackBar(
        context,
        latestAuth.hasActiveSubscription
            ? 'Pembayaran terkonfirmasi. Akses premium aktif.'
            : 'Status pembayaran diperbarui.',
      );
    } catch (e) {
      if (!mounted) return;
      ErrorClassifier.showErrorSnackBar(context, e);
    } finally {
      if (mounted) {
        setState(() => _isCheckingStatus = false);
      }
    }
  }

  Future<void> _refreshAccount({bool showFeedback = true}) async {
    setState(() => _isRefreshingAccount = true);
    try {
      ref.invalidate(subscriptionPlansProvider);
      await ref.read(authProvider.notifier).refreshAuth();
      if (!mounted) return;

      if (showFeedback) {
        final latestAuth = ref.read(authProvider);
        ErrorClassifier.showSuccessSnackBar(
          context,
          latestAuth.hasActiveSubscription
              ? 'Status akun sudah aktif.'
              : 'Data akun diperbarui.',
        );
      }
    } catch (e) {
      if (!mounted) return;
      ErrorClassifier.showErrorSnackBar(context, e);
    } finally {
      if (mounted) {
        setState(() => _isRefreshingAccount = false);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final plansAsync = ref.watch(subscriptionPlansProvider);
    final role = auth.role;
    final roleLabel = AppConstants.roleLabel(role);
    final requiresSubscription = auth.requiresSubscription;
    final effectiveStatus = auth.effectiveSubscriptionStatus;
    final expiry = auth.subscriptionExpiredAt;
    final targetPlanCode = auth.subscriptionPlan.isNotEmpty
        ? auth.subscriptionPlan
        : (AppConstants.subscriptionPlanForRole(role) ?? '');
    final plan = _resolvePlan(plansAsync.asData?.value, targetPlanCode, role);
    final hasCheckout = (_checkout?.orderId ?? '').isNotEmpty;
    final statusColor = _statusColor(effectiveStatus);
    final statusLabel = requiresSubscription
        ? AppConstants.subscriptionStatusLabel(effectiveStatus)
        : 'Tidak wajib';
    final isPlanLoading = plansAsync.isLoading && plan == null;

    return Scaffold(
      appBar: AppBar(title: const Text('Subscription & Pembayaran')),
      body: RefreshIndicator(
        onRefresh: () => _refreshAccount(showFeedback: false),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(AppTheme.paddingMedium),
          children: [
            _buildHeroCard(
              roleLabel: roleLabel,
              requiresSubscription: requiresSubscription,
              status: effectiveStatus,
              expiry: expiry,
              planName:
                  plan?.name ??
                  AppConstants.subscriptionPlanLabel(targetPlanCode),
            ),
            const SizedBox(height: 16),
            if (!requiresSubscription)
              _buildInfoCard(
                icon: Icons.info_outline_rounded,
                title: 'Role ini tidak membutuhkan subscription',
                description:
                    'Halaman ini tetap tersedia agar status akses mudah dicek, tetapi checkout Midtrans tidak diperlukan untuk role ini.',
                actions: [
                  SizedBox(
                    width: double.infinity,
                    child: OutlinedButton(
                      onPressed: () => context.go(Routes.settings),
                      child: const Text('Kembali ke Settings'),
                    ),
                  ),
                ],
              )
            else ...[
              _buildStepsCard(
                hasCheckout: hasCheckout,
                hasActiveAccess: auth.hasActiveSubscription,
              ),
              const SizedBox(height: 16),
              if (isPlanLoading)
                _buildInfoCard(
                  icon: Icons.sync_rounded,
                  title: 'Memuat paket subscription',
                  description:
                      'Sistem sedang mengambil tagihan dan durasi dari collection subscription_plans.',
                  loading: true,
                )
              else if (plansAsync.hasError)
                _buildInfoCard(
                  icon: Icons.warning_amber_rounded,
                  title: 'Daftar paket belum termuat',
                  description:
                      'Server belum mengembalikan data paket. Checkout tetap bisa dibuat dengan plan default role ini, tetapi harga dan durasi dari database belum tampil.',
                  tone: AppTheme.errorColor,
                ),
              if (isPlanLoading || plansAsync.hasError)
                const SizedBox(height: 16),
              _buildPlanCard(
                plan: plan,
                isActive: auth.hasActiveSubscription,
                targetPlanCode: targetPlanCode,
              ),
              const SizedBox(height: 16),
              _buildAccessCard(
                auth: auth,
                statusColor: statusColor,
                statusLabel: statusLabel,
                plan: plan,
                targetPlanCode: targetPlanCode,
              ),
              const SizedBox(height: 16),
              _buildCheckoutCard(),
              const SizedBox(height: 16),
              _buildActionCard(
                targetPlanCode: targetPlanCode,
                hasCheckout: hasCheckout,
                hasActiveAccess: auth.hasActiveSubscription,
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHeroCard({
    required String roleLabel,
    required bool requiresSubscription,
    required String status,
    required DateTime? expiry,
    required String planName,
  }) {
    final statusColor = _statusColor(status);
    final statusLabel = requiresSubscription
        ? AppConstants.subscriptionStatusLabel(status)
        : 'Tidak Wajib';

    return Container(
      padding: const EdgeInsets.all(AppTheme.paddingLarge),
      decoration: BoxDecoration(
        gradient: AppTheme.headerGradient,
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            roleLabel,
            style: AppTheme.caption.copyWith(
              color: Colors.white.withValues(alpha: 0.82),
              letterSpacing: 1.2,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            'Kelola akses premium',
            style: TextStyle(
              color: Colors.white,
              fontSize: 24,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _heroPill(label: statusLabel, color: statusColor),
              _heroPill(label: planName, color: Colors.white),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            !requiresSubscription
                ? 'Role ini tidak diproteksi paywall.'
                : expiry == null
                ? 'Akses premium belum aktif. Buat checkout Midtrans untuk mulai berlangganan.'
                : 'Akses berlaku sampai ${Formatters.tanggalWaktu(expiry)}.',
            style: AppTheme.bodyMedium.copyWith(color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildStepsCard({
    required bool hasCheckout,
    required bool hasActiveAccess,
  }) {
    final paymentDone = _checkout?.isPaid == true || hasActiveAccess;

    return Container(
      padding: const EdgeInsets.all(AppTheme.paddingMedium),
      decoration: AppTheme.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Alur pembayaran',
            style: AppTheme.bodyLarge.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: _StepCard(
                  index: '1',
                  title: 'Checkout',
                  subtitle: 'Buat order',
                  state: hasCheckout ? _StepState.done : _StepState.current,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StepCard(
                  index: '2',
                  title: 'Bayar',
                  subtitle: 'Buka Midtrans',
                  state: paymentDone
                      ? _StepState.done
                      : hasCheckout
                      ? _StepState.current
                      : _StepState.idle,
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: _StepCard(
                  index: '3',
                  title: 'Verifikasi',
                  subtitle: 'Cek status',
                  state: hasActiveAccess
                      ? _StepState.done
                      : hasCheckout
                      ? _StepState.current
                      : _StepState.idle,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildInfoCard({
    required IconData icon,
    required String title,
    required String description,
    Color? tone,
    bool loading = false,
    List<Widget> actions = const [],
  }) {
    final accent = tone ?? AppTheme.primaryColor;

    return Container(
      padding: const EdgeInsets.all(AppTheme.paddingMedium),
      decoration: AppTheme.cardDecoration(
        color: accent.withValues(alpha: 0.04),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: accent.withValues(alpha: 0.1),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: loading
                    ? Padding(
                        padding: const EdgeInsets.all(10),
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: accent,
                        ),
                      )
                    : Icon(icon, color: accent),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Text(
                  title,
                  style: AppTheme.bodyLarge.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(description, style: AppTheme.bodyMedium),
          if (actions.isNotEmpty) ...[const SizedBox(height: 16), ...actions],
        ],
      ),
    );
  }

  Widget _buildAccessCard({
    required AuthState auth,
    required Color statusColor,
    required String statusLabel,
    required SubscriptionPlan? plan,
    required String targetPlanCode,
  }) {
    final planName = auth.subscriptionPlan.isNotEmpty
        ? AppConstants.subscriptionPlanLabel(auth.subscriptionPlan)
        : (plan?.name ?? AppConstants.subscriptionPlanLabel(targetPlanCode));

    return Container(
      padding: const EdgeInsets.all(AppTheme.paddingMedium),
      decoration: AppTheme.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  'Status akses',
                  style: AppTheme.bodyLarge.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              _inlinePill(label: statusLabel, color: statusColor),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(child: _infoTile('Paket', planName)),
              const SizedBox(width: 12),
              Expanded(
                child: _infoTile('Role', AppConstants.roleLabel(auth.role)),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _detailRow(
            'Mulai',
            auth.subscriptionStartedAt == null
                ? 'Belum ada aktivasi'
                : Formatters.tanggalWaktu(auth.subscriptionStartedAt!),
          ),
          _detailRow(
            'Berakhir',
            auth.subscriptionExpiredAt == null
                ? 'Belum dijadwalkan'
                : Formatters.tanggalWaktu(auth.subscriptionExpiredAt!),
          ),
        ],
      ),
    );
  }

  Widget _buildPlanCard({
    required SubscriptionPlan? plan,
    required bool isActive,
    required String targetPlanCode,
  }) {
    final planName =
        plan?.name ?? AppConstants.subscriptionPlanLabel(targetPlanCode);
    final planDescription = plan?.description.isNotEmpty == true
        ? plan!.description
        : 'Paket bulanan untuk ${planName.toLowerCase()} dengan aktivasi melalui Midtrans Snap.';
    final amountLabel = plan == null
        ? 'Belum tersedia'
        : Formatters.rupiah(plan.amount);
    final durationLabel = plan == null || plan.durationDays <= 0
        ? 'Belum tersedia'
        : '${plan.durationDays} hari';

    return Container(
      padding: const EdgeInsets.all(AppTheme.paddingMedium),
      decoration: AppTheme.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(child: Text(planName, style: AppTheme.heading3)),
              if (isActive)
                Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 10,
                    vertical: 6,
                  ),
                  decoration: BoxDecoration(
                    color: AppTheme.successColor.withValues(alpha: 0.12),
                    borderRadius: BorderRadius.circular(999),
                  ),
                  child: Text(
                    'Sedang Aktif',
                    style: AppTheme.caption.copyWith(
                      color: AppTheme.successColor,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 10),
          Text(planDescription, style: AppTheme.bodyMedium),
          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(child: _infoTile('Tagihan', amountLabel)),
              const SizedBox(width: 12),
              Expanded(child: _infoTile('Durasi', durationLabel)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildCheckoutCard() {
    final checkout = _checkout;
    if (checkout == null) {
      return _buildInfoCard(
        icon: Icons.receipt_long_outlined,
        title: 'Belum ada checkout aktif',
        description:
            'Tekan "Buat Checkout" untuk menghasilkan order dan redirect URL Midtrans sebelum pembayaran dilakukan.',
      );
    }

    final paymentStateColor = _statusColor(checkout.paymentState);

    return Container(
      padding: const EdgeInsets.all(AppTheme.paddingMedium),
      decoration: AppTheme.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Checkout terakhir',
                      style: AppTheme.bodyLarge.copyWith(
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Text(
                      'Gunakan order ini untuk melanjutkan pembayaran atau sinkron status terbaru.',
                      style: AppTheme.bodySmall,
                    ),
                  ],
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: 10,
                  vertical: 6,
                ),
                decoration: BoxDecoration(
                  color: paymentStateColor.withValues(alpha: 0.12),
                  borderRadius: BorderRadius.circular(999),
                ),
                child: Text(
                  checkout.paymentState.toUpperCase(),
                  style: AppTheme.caption.copyWith(
                    color: paymentStateColor,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          _detailRow('Order ID', checkout.orderId),
          _detailRow('Plan', checkout.planName),
          _detailRow('Tagihan', Formatters.rupiah(checkout.grossAmount)),
          _detailRow('Status Midtrans', checkout.transactionStatus),
          if ((checkout.paymentType ?? '').isNotEmpty)
            _detailRow('Metode', checkout.paymentType!),
          if ((checkout.subscriptionExpired ?? '').isNotEmpty)
            _detailRow(
              'Akses Sampai',
              Formatters.tanggalWaktu(
                DateTime.parse(checkout.subscriptionExpired!),
              ),
            ),
          if (checkout.redirectUrl.isNotEmpty) ...[
            const SizedBox(height: 12),
            Text('Redirect URL', style: AppTheme.caption),
            const SizedBox(height: 6),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.primaryColor.withValues(alpha: 0.05),
                borderRadius: BorderRadius.circular(12),
              ),
              child: SelectableText(
                checkout.redirectUrl,
                style: AppTheme.bodySmall.copyWith(color: AppTheme.primaryDark),
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildActionCard({
    required String targetPlanCode,
    required bool hasCheckout,
    required bool hasActiveAccess,
  }) {
    final primaryLabel = hasActiveAccess
        ? 'Buat Checkout Perpanjangan'
        : hasCheckout
        ? 'Buat Checkout Baru'
        : 'Buat Checkout';

    return Container(
      padding: const EdgeInsets.all(AppTheme.paddingMedium),
      decoration: AppTheme.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Aksi',
            style: AppTheme.bodyLarge.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 6),
          const Text(
            'Gunakan Midtrans Sandbox untuk pengujian dev. Setelah bayar, selalu cek status dan refresh akses.',
            style: AppTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: _isCreatingCheckout
                  ? null
                  : () => _createCheckout(targetPlanCode),
              icon: _isCreatingCheckout
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Icons.payment_rounded),
              label: Text(primaryLabel),
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: !hasCheckout || _isOpeningPayment
                      ? null
                      : _openPayment,
                  icon: _isOpeningPayment
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.open_in_new_rounded),
                  label: const Text('Buka Pembayaran'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: !hasCheckout ? null : _copyPaymentLink,
                  icon: const Icon(Icons.copy_all_rounded),
                  label: const Text('Salin Link'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextButton.icon(
                  onPressed: !hasCheckout || _isCheckingStatus
                      ? null
                      : _checkStatus,
                  icon: _isCheckingStatus
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.sync_rounded),
                  label: const Text('Cek Status Midtrans'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextButton.icon(
                  onPressed: _isRefreshingAccount
                      ? null
                      : () => _refreshAccount(showFeedback: true),
                  icon: _isRefreshingAccount
                      ? const SizedBox(
                          width: 18,
                          height: 18,
                          child: CircularProgressIndicator(strokeWidth: 2),
                        )
                      : const Icon(Icons.verified_user_outlined),
                  label: const Text('Refresh Akses'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  SubscriptionPlan? _resolvePlan(
    List<SubscriptionPlan>? plans,
    String targetPlanCode,
    String role,
  ) {
    final availablePlans = plans ?? const <SubscriptionPlan>[];
    for (final plan in availablePlans) {
      if (plan.code == targetPlanCode) {
        return plan;
      }
    }

    final fallbackPlanCode = AppConstants.subscriptionPlanForRole(role);
    if (fallbackPlanCode == null) {
      return null;
    }

    for (final plan in availablePlans) {
      if (plan.code == fallbackPlanCode) {
        return plan;
      }
    }

    return null;
  }

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 112, child: Text(label, style: AppTheme.caption)),
          const Text(': '),
          Expanded(
            child: Text(
              value,
              style: AppTheme.bodySmall.copyWith(color: AppTheme.textPrimary),
            ),
          ),
        ],
      ),
    );
  }

  Widget _heroPill({required String label, required Color color}) {
    final foreground = color == Colors.white ? AppTheme.primaryDark : color;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 7),
      decoration: BoxDecoration(
        color: color.withValues(alpha: color == Colors.white ? 0.9 : 0.18),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: AppTheme.caption.copyWith(
          color: foreground,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _inlinePill({required String label, required Color color}) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        label,
        style: AppTheme.caption.copyWith(
          color: color,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _infoTile(String label, String value) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(label, style: AppTheme.caption),
          const SizedBox(height: 6),
          Text(
            value,
            style: AppTheme.bodyMedium.copyWith(fontWeight: FontWeight.w700),
          ),
        ],
      ),
    );
  }

  Color _statusColor(String status) {
    switch (status.trim().toLowerCase()) {
      case AppConstants.subscriptionStatusActive:
      case 'paid':
      case 'settlement':
        return AppTheme.successColor;
      case AppConstants.subscriptionStatusExpired:
      case 'expire':
      case 'deny':
      case 'cancel':
      case 'failed':
        return AppTheme.errorColor;
      case AppConstants.subscriptionStatusInactive:
      case 'pending':
      case 'token_ready':
      default:
        return AppTheme.warningColor;
    }
  }
}

enum _StepState { idle, current, done }

class _StepCard extends StatelessWidget {
  const _StepCard({
    required this.index,
    required this.title,
    required this.subtitle,
    required this.state,
  });

  final String index;
  final String title;
  final String subtitle;
  final _StepState state;

  @override
  Widget build(BuildContext context) {
    final tone = switch (state) {
      _StepState.done => AppTheme.successColor,
      _StepState.current => AppTheme.primaryColor,
      _StepState.idle => AppTheme.textSecondary,
    };

    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: tone.withValues(alpha: 0.06),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: tone.withValues(alpha: 0.12)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: BoxDecoration(
              color: tone,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Center(
              child: state == _StepState.done
                  ? const Icon(
                      Icons.check_rounded,
                      color: Colors.white,
                      size: 16,
                    )
                  : Text(
                      index,
                      style: const TextStyle(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
            ),
          ),
          const SizedBox(height: 10),
          Text(
            title,
            style: AppTheme.bodyMedium.copyWith(fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 4),
          Text(subtitle, style: AppTheme.caption),
        ],
      ),
    );
  }
}
