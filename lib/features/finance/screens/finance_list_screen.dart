import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/router.dart';
import '../../../app/theme.dart';
import '../../../core/utils/formatters.dart';
import '../../../shared/models/finance_model.dart';
import '../../auth/providers/auth_provider.dart';
import '../providers/finance_providers.dart';
import '../widgets/finance_widgets.dart';

class FinanceListScreen extends ConsumerStatefulWidget {
  const FinanceListScreen({super.key});

  @override
  ConsumerState<FinanceListScreen> createState() => _FinanceListScreenState();
}

class _FinanceListScreenState extends ConsumerState<FinanceListScreen> {
  String _approvalFilter = 'all';
  String _directionFilter = 'all';
  String _unitFilter = 'all';
  String _publishFilter = 'all';

  @override
  Widget build(BuildContext context) {
    final auth = ref.watch(authProvider);
    if (!auth.isOperator && !auth.isSysadmin) {
      return const FinanceAccessDenied();
    }

    final overviewAsync = ref.watch(financeOverviewProvider);
    return FinanceScreenShell(
      title: 'Keuangan',
      actions: [
        IconButton(
          tooltip: 'Refresh',
          onPressed: () => ref.read(financeRefreshTickProvider.notifier).bump(),
          icon: const Icon(Icons.refresh_rounded),
        ),
      ],
      floatingActionButton:
          overviewAsync.asData?.value.creatableUnits.isNotEmpty == true
          ? FloatingActionButton.extended(
              onPressed: () => context.push(Routes.financeForm),
              icon: const Icon(Icons.add),
              label: const Text('Buat Transaksi'),
            )
          : null,
      child: overviewAsync.when(
        data: (overview) {
          final canOpen =
              overview.profile.member.isSysadmin ||
              overview.visibleUnits.isNotEmpty;
          if (!canOpen) {
            return const FinanceAccessDenied();
          }

          final unitOptions = overview.visibleUnits;
          final transactions = overview.transactions
              .where((transaction) {
                final approvalMatch =
                    _approvalFilter == 'all' ||
                    transaction.approvalStatus == _approvalFilter;
                final directionMatch =
                    _directionFilter == 'all' ||
                    transaction.direction == _directionFilter;
                final publishMatch =
                    _publishFilter == 'all' ||
                    transaction.publishStatus == _publishFilter;
                final unitMatch =
                    _unitFilter == 'all' ||
                    transaction.orgUnitId == _unitFilter;
                return approvalMatch &&
                    directionMatch &&
                    publishMatch &&
                    unitMatch;
              })
              .toList(growable: false);

          return RefreshIndicator(
            onRefresh: () async {
              ref.read(financeRefreshTickProvider.notifier).bump();
              await ref.read(financeOverviewProvider.future);
            },
            child: ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.fromLTRB(
                AppTheme.paddingMedium,
                AppTheme.paddingMedium,
                AppTheme.paddingMedium,
                AppTheme.paddingLarge,
              ),
              children: [
                _FinanceHero(overview: overview),
                const SizedBox(height: 16),
                FinanceSectionCard(
                  title: 'Filter transaksi',
                  subtitle:
                      'Saring berdasarkan unit, arah transaksi, dan status approval.',
                  child: Column(
                    children: [
                      DropdownButtonFormField<String>(
                        initialValue: _unitFilter,
                        decoration: const InputDecoration(labelText: 'Unit'),
                        items: [
                          const DropdownMenuItem(
                            value: 'all',
                            child: Text('Semua unit'),
                          ),
                          ...unitOptions.map(
                            (unit) => DropdownMenuItem(
                              value: unit.id,
                              child: Text(unit.name),
                            ),
                          ),
                        ],
                        onChanged: (value) {
                          setState(() => _unitFilter = value ?? 'all');
                        },
                      ),
                      const SizedBox(height: 12),
                      Row(
                        children: [
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: _directionFilter,
                              decoration: const InputDecoration(
                                labelText: 'Arah',
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: 'all',
                                  child: Text('Semua'),
                                ),
                                DropdownMenuItem(
                                  value: 'in',
                                  child: Text('Pemasukan'),
                                ),
                                DropdownMenuItem(
                                  value: 'out',
                                  child: Text('Pengeluaran'),
                                ),
                              ],
                              onChanged: (value) {
                                setState(
                                  () => _directionFilter = value ?? 'all',
                                );
                              },
                            ),
                          ),
                          const SizedBox(width: 12),
                          Expanded(
                            child: DropdownButtonFormField<String>(
                              initialValue: _approvalFilter,
                              decoration: const InputDecoration(
                                labelText: 'Approval',
                              ),
                              items: const [
                                DropdownMenuItem(
                                  value: 'all',
                                  child: Text('Semua'),
                                ),
                                DropdownMenuItem(
                                  value: 'draft',
                                  child: Text('Draft'),
                                ),
                                DropdownMenuItem(
                                  value: 'submitted',
                                  child: Text('Submitted'),
                                ),
                                DropdownMenuItem(
                                  value: 'approved',
                                  child: Text('Approved'),
                                ),
                                DropdownMenuItem(
                                  value: 'rejected',
                                  child: Text('Rejected'),
                                ),
                              ],
                              onChanged: (value) {
                                setState(
                                  () => _approvalFilter = value ?? 'all',
                                );
                              },
                            ),
                          ),
                        ],
                      ),
                      const SizedBox(height: 12),
                      DropdownButtonFormField<String>(
                        initialValue: _publishFilter,
                        decoration: const InputDecoration(labelText: 'Publish'),
                        items: const [
                          DropdownMenuItem(value: 'all', child: Text('Semua')),
                          DropdownMenuItem(
                            value: 'pending',
                            child: Text('Pending'),
                          ),
                          DropdownMenuItem(
                            value: 'published',
                            child: Text('Published'),
                          ),
                        ],
                        onChanged: (value) {
                          setState(() => _publishFilter = value ?? 'all');
                        },
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 16),
                if (transactions.isEmpty)
                  const FinanceSectionCard(
                    title: 'Daftar transaksi',
                    child: FinanceEmptyState(
                      icon: Icons.receipt_long_outlined,
                      title: 'Belum ada transaksi',
                      message:
                          'Buat transaksi baru atau ubah filter untuk melihat ledger yang tersedia.',
                    ),
                  )
                else
                  FinanceSectionCard(
                    title: 'Daftar transaksi',
                    subtitle:
                        'Tap item untuk melihat detail, approval trail, dan aksi lanjutan.',
                    child: Column(
                      children: transactions
                          .map(
                            (transaction) => Padding(
                              padding: const EdgeInsets.only(bottom: 12),
                              child: _TransactionTile(
                                transaction: transaction,
                                unitName:
                                    overview
                                        .unitById(transaction.orgUnitId)
                                        ?.name ??
                                    '-',
                                accountLabel:
                                    overview
                                        .accountById(transaction.accountId)
                                        ?.label ??
                                    '-',
                                onTap: () => context.push(
                                  Routes.financeDetail.replaceFirst(
                                    ':id',
                                    transaction.id,
                                  ),
                                ),
                              ),
                            ),
                          )
                          .toList(growable: false),
                    ),
                  ),
              ],
            ),
          );
        },
        error: (error, _) => Center(
          child: Padding(
            padding: const EdgeInsets.all(AppTheme.paddingLarge),
            child: Text(
              'Gagal memuat ledger keuangan.\n${error.toString()}',
              textAlign: TextAlign.center,
              style: AppTheme.bodySmall,
            ),
          ),
        ),
        loading: () => const Center(child: CircularProgressIndicator()),
      ),
    );
  }
}

class _FinanceHero extends StatelessWidget {
  const _FinanceHero({required this.overview});

  final FinanceOverviewData overview;

  @override
  Widget build(BuildContext context) {
    final submitted = overview.transactions
        .where((item) => item.isSubmitted)
        .length;
    final approved = overview.transactions
        .where((item) => item.isApproved)
        .length;
    final published = overview.transactions
        .where((item) => item.isPublished)
        .length;

    return Container(
      padding: const EdgeInsets.all(AppTheme.paddingLarge),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF284B63), Color(0xFF3C6E71)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(AppTheme.radiusLarge),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Ledger Keuangan',
            style: AppTheme.heading2.copyWith(color: Colors.white),
          ),
          const SizedBox(height: 8),
          Text(
            'Pantau transaksi per unit, approval maker-checker, dan publish pengumuman kas.',
            style: AppTheme.bodySmall.copyWith(
              color: Colors.white.withValues(alpha: 0.86),
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              FinanceBadge(label: 'SUBMITTED $submitted', color: Colors.white),
              FinanceBadge(label: 'APPROVED $approved', color: Colors.white),
              FinanceBadge(label: 'PUBLISHED $published', color: Colors.white),
            ],
          ),
        ],
      ),
    );
  }
}

class _TransactionTile extends StatelessWidget {
  const _TransactionTile({
    required this.transaction,
    required this.unitName,
    required this.accountLabel,
    required this.onTap,
  });

  final FinanceTransactionModel transaction;
  final String unitName;
  final String accountLabel;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final amountColor = transaction.isIncoming
        ? AppTheme.successColor
        : AppTheme.errorColor;
    final directionLabel = financeDirectionLabel(transaction.direction);
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(AppTheme.radiusMedium),
        child: Container(
          decoration: AppTheme.cardDecoration(),
          padding: const EdgeInsets.all(AppTheme.paddingMedium),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 44,
                    height: 44,
                    decoration: BoxDecoration(
                      color: amountColor.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: Icon(
                      transaction.isIncoming
                          ? Icons.south_west_rounded
                          : Icons.north_east_rounded,
                      color: amountColor,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          transaction.title,
                          style: AppTheme.bodyMedium.copyWith(
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          '$unitName • $accountLabel',
                          style: AppTheme.bodySmall,
                        ),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded),
                ],
              ),
              const SizedBox(height: 12),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  FinanceBadge(label: directionLabel, color: amountColor),
                  FinanceBadge(
                    label: financeApprovalStatusLabel(
                      transaction.approvalStatus,
                    ),
                    color: AppTheme.statusColor(transaction.approvalStatus),
                  ),
                  FinanceBadge(
                    label: financePublishStatusLabel(transaction.publishStatus),
                    color: financePublishStatusColor(transaction.publishStatus),
                  ),
                ],
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: Text(
                      transaction.category,
                      style: AppTheme.bodySmall,
                    ),
                  ),
                  Text(
                    Formatters.rupiah(transaction.amount),
                    style: AppTheme.bodyLarge.copyWith(
                      fontWeight: FontWeight.w800,
                      color: amountColor,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}
