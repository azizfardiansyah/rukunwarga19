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
      try {
        return await ref.watch(subscriptionPaymentServiceProvider).getPlans();
      } catch (error) {
        if (ErrorClassifier.isAuthError(error)) {
          ref.read(authProvider.notifier).logout();
        }
        rethrow;
      }
    });

class SubscriptionScreen extends ConsumerStatefulWidget {
  const SubscriptionScreen({super.key});

  @override
  ConsumerState<SubscriptionScreen> createState() => _SubscriptionScreenState();
}

class _SubscriptionScreenState extends ConsumerState<SubscriptionScreen> {
  SubscriptionCheckout? _checkout;
  String _selectedPlanCode = '';
  bool _isCreatingCheckout = false;
  bool _isCheckingStatus = false;
  bool _isOpeningPayment = false;
  bool _isRefreshingAccount = false;

  Future<void> _createCheckout(String planCode) async {
    if (planCode.isEmpty) {
      ErrorClassifier.showErrorSnackBar(
        context,
        StateError('Pilih paket subscription terlebih dahulu.'),
      );
      return;
    }

    setState(() => _isCreatingCheckout = true);
    try {
      final checkout = await ref
          .read(subscriptionPaymentServiceProvider)
          .createCheckout(planCode: planCode);
      if (!mounted) {
        return;
      }

      setState(() => _checkout = checkout);
      ErrorClassifier.showSuccessSnackBar(
        context,
        'Checkout berhasil dibuat. Lanjutkan pembayaran di Midtrans.',
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
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
      if (!mounted) {
        return;
      }
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
    if (!mounted) {
      return;
    }
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
      ref.invalidate(subscriptionPlansProvider);
      await ref.read(authProvider.notifier).refreshAuth();
      if (!mounted) {
        return;
      }

      final latestAuth = ref.read(authProvider);
      final isPremiumActive =
          latestAuth.requiresSubscription && latestAuth.hasActiveSubscription;

      ErrorClassifier.showSuccessSnackBar(
        context,
        isPremiumActive
            ? 'Pembayaran terkonfirmasi. Role dan akses premium sudah aktif.'
            : 'Status pembayaran diperbarui.',
      );
    } catch (e) {
      if (!mounted) {
        return;
      }
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
      if (!mounted) {
        return;
      }

      if (showFeedback) {
        final latestAuth = ref.read(authProvider);
        final isPremiumActive =
            latestAuth.requiresSubscription && latestAuth.hasActiveSubscription;
        ErrorClassifier.showSuccessSnackBar(
          context,
          isPremiumActive
              ? 'Role dan akses premium sudah aktif.'
              : 'Data akun diperbarui.',
        );
      }
    } catch (e) {
      if (!mounted) {
        return;
      }
      ErrorClassifier.showErrorSnackBar(context, e);
    } finally {
      if (mounted) {
        setState(() => _isRefreshingAccount = false);
      }
    }
  }

  void _syncSelectedPlan(List<SubscriptionPlan> plans, AuthState auth) {
    if (plans.isEmpty || plans.any((plan) => plan.code == _selectedPlanCode)) {
      return;
    }

    final preferredCodes = <String>[
      auth.subscriptionPlan,
      AppConstants.subscriptionPlanForRole(auth.role) ?? '',
      plans.first.code,
    ];

    for (final code in preferredCodes) {
      if (code.isNotEmpty && plans.any((plan) => plan.code == code)) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (!mounted) {
            return;
          }
          setState(() => _selectedPlanCode = code);
        });
        return;
      }
    }
  }

  SubscriptionPlan? _selectedPlan(List<SubscriptionPlan> plans) {
    for (final plan in plans) {
      if (plan.code == _selectedPlanCode) {
        return plan;
      }
    }

    if (plans.isNotEmpty) {
      return plans.first;
    }

    return null;
  }

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    final plansAsync = ref.watch(subscriptionPlansProvider);
    final canSelfSubscribe = AppConstants.canSelfSubscribe(auth.role);
    final isPremiumRole = auth.requiresSubscription;
    final hasPremiumAccess = isPremiumRole && auth.hasActiveSubscription;
    final plans = plansAsync.asData?.value ?? const <SubscriptionPlan>[];

    _syncSelectedPlan(plans, auth);

    final selectedPlan = _selectedPlan(plans);
    final currentStatusLabel = isPremiumRole
        ? AppConstants.subscriptionStatusLabel(auth.effectiveSubscriptionStatus)
        : canSelfSubscribe
        ? 'Bisa upgrade'
        : 'Tidak tersedia';
    final currentStatusColor = isPremiumRole
        ? _statusColor(auth.effectiveSubscriptionStatus)
        : canSelfSubscribe
        ? AppTheme.primaryColor
        : AppTheme.textSecondary;
    final hasCheckout = (_checkout?.orderId ?? '').isNotEmpty;

    return Scaffold(
      appBar: AppBar(title: const Text('Subscription & Pembayaran')),
      body: RefreshIndicator(
        onRefresh: () => _refreshAccount(showFeedback: false),
        child: ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.all(AppTheme.paddingMedium),
          children: [
            _buildHero(
              roleLabel: AppConstants.roleLabel(auth.role),
              statusLabel: currentStatusLabel,
              statusColor: currentStatusColor,
              auth: auth,
              selectedPlan: selectedPlan,
              canSelfSubscribe: canSelfSubscribe,
            ),
            const SizedBox(height: 16),
            if (!canSelfSubscribe)
              _buildNotice(
                icon: Icons.lock_outline_rounded,
                title: 'Role ini tidak bisa checkout sendiri',
                description:
                    'Sysadmin tidak memakai alur pembayaran self-service. Kelola akses dari menu manajemen user.',
                action: OutlinedButton(
                  onPressed: () => context.go(Routes.settings),
                  child: const Text('Kembali ke Settings'),
                ),
              )
            else ...[
              _buildSteps(
                hasCheckout: hasCheckout,
                hasPremiumAccess: hasPremiumAccess,
              ),
              const SizedBox(height: 16),
              plansAsync.when(
                data: (items) {
                  if (items.isEmpty) {
                    return _buildNotice(
                      icon: Icons.inventory_2_outlined,
                      title: 'Belum ada paket yang bisa dibeli',
                      description:
                          'Aktifkan plan di collection subscription_plans agar user bisa memilih role admin.',
                    );
                  }

                  return Column(
                    children: [
                      _buildPlanSelector(
                        auth: auth,
                        plans: items,
                        selectedPlan: selectedPlan,
                      ),
                      const SizedBox(height: 16),
                      _buildSummary(
                        auth: auth,
                        selectedPlan: selectedPlan,
                        statusLabel: currentStatusLabel,
                        statusColor: currentStatusColor,
                      ),
                      const SizedBox(height: 16),
                      _buildCheckoutCard(),
                      const SizedBox(height: 16),
                      _buildActionCard(
                        auth: auth,
                        selectedPlan: selectedPlan,
                        hasCheckout: hasCheckout,
                      ),
                    ],
                  );
                },
                loading: () => _buildNotice(
                  icon: Icons.sync_rounded,
                  title: 'Memuat paket subscription',
                  description:
                      'Sistem sedang mengambil daftar paket admin, tagihan, dan durasi dari server.',
                  loading: true,
                ),
                error: (error, _) => _buildNotice(
                  icon: Icons.warning_amber_rounded,
                  title: 'Daftar paket belum termuat',
                  description: ErrorClassifier.classify(error).message,
                  tone: AppTheme.errorColor,
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }

  Widget _buildHero({
    required String roleLabel,
    required String statusLabel,
    required Color statusColor,
    required AuthState auth,
    required SubscriptionPlan? selectedPlan,
    required bool canSelfSubscribe,
  }) {
    final targetRoleLabel = selectedPlan == null
        ? 'Belum pilih paket'
        : AppConstants.roleLabel(selectedPlan.targetRole);

    final description = !canSelfSubscribe
        ? 'Role ini tidak memakai checkout self-service.'
        : selectedPlan == null
        ? 'Pilih salah satu paket admin, buat checkout, lalu bayar di Midtrans. Setelah pembayaran sukses, role berubah otomatis.'
        : auth.role == AppConstants.roleWarga
        ? 'Pembayaran sukses akan mengubah role Warga menjadi ${AppConstants.roleLabel(selectedPlan.targetRole)} dan subscription langsung aktif.'
        : AppConstants.normalizeRole(auth.role) == selectedPlan.targetRole
        ? auth.subscriptionExpiredAt == null
              ? 'Paket ini akan mengaktifkan kembali akses ${AppConstants.roleLabel(selectedPlan.targetRole)}.'
              : 'Paket ini akan memperpanjang akses sampai setelah periode aktif berjalan selesai.'
        : 'Paket ini akan meng-upgrade role Anda ke ${AppConstants.roleLabel(selectedPlan.targetRole)} setelah pembayaran sukses.';

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
            'Kelola subscription admin',
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
              _pill(statusLabel, statusColor, filled: true),
              _pill(targetRoleLabel, Colors.white, filled: true),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            description,
            style: AppTheme.bodyMedium.copyWith(color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildSteps({
    required bool hasCheckout,
    required bool hasPremiumAccess,
  }) {
    final paymentDone = _checkout?.isPaid == true || hasPremiumAccess;

    return Container(
      padding: const EdgeInsets.all(AppTheme.paddingMedium),
      decoration: AppTheme.cardDecoration(),
      child: Row(
        children: [
          Expanded(
            child: _StepTile(
              index: '1',
              title: 'Pilih paket',
              active: _selectedPlanCode.isNotEmpty,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _StepTile(
              index: '2',
              title: 'Checkout',
              active: hasCheckout,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _StepTile(index: '3', title: 'Bayar', active: paymentDone),
          ),
        ],
      ),
    );
  }

  Widget _buildNotice({
    required IconData icon,
    required String title,
    required String description,
    Color? tone,
    bool loading = false,
    Widget? action,
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
          if (action != null) ...[
            const SizedBox(height: 16),
            SizedBox(width: double.infinity, child: action),
          ],
        ],
      ),
    );
  }

  Widget _buildPlanSelector({
    required AuthState auth,
    required List<SubscriptionPlan> plans,
    required SubscriptionPlan? selectedPlan,
  }) {
    return Container(
      padding: const EdgeInsets.all(AppTheme.paddingMedium),
      decoration: AppTheme.cardDecoration(),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Pilih paket admin',
            style: AppTheme.bodyLarge.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 8),
          const Text(
            'Hanya ada tiga role berbayar: Admin RT, Admin RW, dan Admin RW Pro.',
            style: AppTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          ...plans.map((plan) {
            final isSelected = selectedPlan?.code == plan.code;
            final intent = _planIntentLabel(
              currentRole: auth.role,
              targetRole: plan.targetRole,
            );

            return Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: InkWell(
                borderRadius: BorderRadius.circular(18),
                onTap: () => setState(() => _selectedPlanCode = plan.code),
                child: AnimatedContainer(
                  duration: const Duration(milliseconds: 160),
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: isSelected
                        ? AppTheme.primaryColor.withValues(alpha: 0.06)
                        : Colors.white,
                    borderRadius: BorderRadius.circular(18),
                    border: Border.all(
                      color: isSelected
                          ? AppTheme.primaryColor
                          : AppTheme.primaryColor.withValues(alpha: 0.12),
                      width: isSelected ? 1.4 : 1,
                    ),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Icon(
                            isSelected
                                ? Icons.radio_button_checked_rounded
                                : Icons.radio_button_off_rounded,
                            color: isSelected
                                ? AppTheme.primaryColor
                                : AppTheme.textSecondary,
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  plan.name,
                                  style: AppTheme.bodyMedium.copyWith(
                                    fontWeight: FontWeight.w800,
                                  ),
                                ),
                                const SizedBox(height: 6),
                                Wrap(
                                  spacing: 8,
                                  runSpacing: 8,
                                  children: [
                                    _pill(
                                      AppConstants.roleLabel(plan.targetRole),
                                      AppTheme.roleColor(plan.targetRole),
                                    ),
                                    _pill(
                                      intent,
                                      isSelected
                                          ? AppTheme.primaryColor
                                          : AppTheme.textSecondary,
                                    ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 12),
                          Text(
                            Formatters.rupiah(plan.amount),
                            style: AppTheme.bodyMedium.copyWith(
                              fontWeight: FontWeight.w800,
                              color: AppTheme.primaryDark,
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      Text(plan.description, style: AppTheme.bodySmall),
                      const SizedBox(height: 14),
                      Row(
                        children: [
                          Expanded(
                            child: _miniInfo(
                              'Durasi',
                              '${plan.durationDays} hari',
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: _miniInfo(
                              'Tagihan',
                              Formatters.rupiah(plan.amount),
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildSummary({
    required AuthState auth,
    required SubscriptionPlan? selectedPlan,
    required String statusLabel,
    required Color statusColor,
  }) {
    final nextRoleLabel = selectedPlan == null
        ? 'Belum dipilih'
        : AppConstants.roleLabel(selectedPlan.targetRole);
    final currentPlanLabel = auth.subscriptionPlan.isEmpty
        ? 'Belum ada'
        : AppConstants.subscriptionPlanLabel(auth.subscriptionPlan);
    final targetPlanLabel = selectedPlan?.name ?? 'Belum dipilih';

    final note = selectedPlan == null
        ? 'Pilih paket untuk melihat role target.'
        : auth.role == AppConstants.roleWarga
        ? 'Pembayaran sukses akan meng-upgrade akun warga menjadi ${AppConstants.roleLabel(selectedPlan.targetRole)}.'
        : AppConstants.normalizeRole(auth.role) == selectedPlan.targetRole
        ? 'Checkout ini akan memperpanjang akses role yang sama.'
        : 'Checkout ini akan meng-upgrade akses Anda ke ${AppConstants.roleLabel(selectedPlan.targetRole)}.';

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
                  'Status & target akses',
                  style: AppTheme.bodyLarge.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              _pill(statusLabel, statusColor),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              Expanded(
                child: _miniInfo(
                  'Role saat ini',
                  AppConstants.roleLabel(auth.role),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(child: _miniInfo('Setelah bayar', nextRoleLabel)),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(child: _miniInfo('Paket aktif', currentPlanLabel)),
              const SizedBox(width: 12),
              Expanded(child: _miniInfo('Paket dipilih', targetPlanLabel)),
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
          const SizedBox(height: 8),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: AppTheme.primaryColor.withValues(alpha: 0.06),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(note, style: AppTheme.bodySmall),
          ),
        ],
      ),
    );
  }

  Widget _buildCheckoutCard() {
    final checkout = _checkout;
    if (checkout == null) {
      return _buildNotice(
        icon: Icons.receipt_long_outlined,
        title: 'Belum ada checkout aktif',
        description:
            'Tekan "Buat Checkout" setelah memilih paket untuk menghasilkan order dan redirect URL Midtrans.',
      );
    }

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
                  'Checkout terakhir',
                  style: AppTheme.bodyLarge.copyWith(
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
              _pill(
                checkout.paymentState.toUpperCase(),
                _statusColor(checkout.paymentState),
              ),
            ],
          ),
          const SizedBox(height: 14),
          _detailRow('Order ID', checkout.orderId),
          _detailRow('Plan', checkout.planName),
          _detailRow(
            'Target role',
            AppConstants.roleLabel(checkout.targetRole),
          ),
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
    required AuthState auth,
    required SubscriptionPlan? selectedPlan,
    required bool hasCheckout,
  }) {
    final canCreateCheckout = selectedPlan != null;

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
            'Gunakan Midtrans Sandbox untuk pengujian dev. Setelah bayar, cek status dan refresh akses.',
            style: AppTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          SizedBox(
            width: double.infinity,
            child: ElevatedButton.icon(
              onPressed: !canCreateCheckout || _isCreatingCheckout
                  ? null
                  : () => _createCheckout(selectedPlan.code),
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
              label: Text(
                _primaryActionLabel(
                  currentRole: auth.role,
                  selectedPlan: selectedPlan,
                  hasPremiumAccess:
                      auth.requiresSubscription && auth.hasActiveSubscription,
                ),
              ),
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

  String _primaryActionLabel({
    required String currentRole,
    required SubscriptionPlan? selectedPlan,
    required bool hasPremiumAccess,
  }) {
    if (selectedPlan == null) {
      return 'Pilih Paket Dulu';
    }

    final normalizedCurrentRole = AppConstants.normalizeRole(currentRole);
    final targetRole = selectedPlan.targetRole;
    final targetLabel = AppConstants.roleLabel(targetRole);

    if (normalizedCurrentRole == AppConstants.roleWarga) {
      return 'Bayar & Jadi $targetLabel';
    }

    if (normalizedCurrentRole == targetRole) {
      return hasPremiumAccess
          ? 'Perpanjang $targetLabel'
          : 'Aktifkan $targetLabel';
    }

    return 'Upgrade ke $targetLabel';
  }

  String _planIntentLabel({
    required String currentRole,
    required String targetRole,
  }) {
    final normalizedCurrentRole = AppConstants.normalizeRole(currentRole);
    final normalizedTargetRole = AppConstants.normalizeRole(targetRole);

    if (normalizedCurrentRole == AppConstants.roleWarga) {
      return 'Aktivasi';
    }

    if (normalizedCurrentRole == normalizedTargetRole) {
      return 'Perpanjangan';
    }

    if (AppConstants.roleRank(normalizedTargetRole) >
        AppConstants.roleRank(normalizedCurrentRole)) {
      return 'Upgrade';
    }

    return 'Pilih paket';
  }

  Widget _miniInfo(String label, String value) {
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

  Widget _detailRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 110, child: Text(label, style: AppTheme.caption)),
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

  Widget _pill(String label, Color color, {bool filled = false}) {
    final background = filled
        ? color.withValues(alpha: color == Colors.white ? 0.92 : 0.18)
        : color.withValues(alpha: 0.12);
    final foreground = color == Colors.white ? AppTheme.primaryDark : color;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: background,
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

class _StepTile extends StatelessWidget {
  const _StepTile({
    required this.index,
    required this.title,
    required this.active,
  });

  final String index;
  final String title;
  final bool active;

  @override
  Widget build(BuildContext context) {
    final tone = active ? AppTheme.primaryColor : AppTheme.textSecondary;

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
              child: Text(
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
        ],
      ),
    );
  }
}
