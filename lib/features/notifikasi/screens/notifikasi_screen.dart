import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../../../app/theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/utils/error_classifier.dart';
import '../../../core/utils/formatters.dart';
import '../../../features/surat/providers/surat_providers.dart';
import '../../../shared/widgets/app_surface.dart';

class NotifikasiScreen extends ConsumerStatefulWidget {
  const NotifikasiScreen({super.key});

  @override
  ConsumerState<NotifikasiScreen> createState() => _NotifikasiScreenState();
}

class _NotifikasiScreenState extends ConsumerState<NotifikasiScreen> {
  String _query = '';

  @override
  Widget build(BuildContext context) {
    final notificationsAsync = ref.watch(suratNotificationsProvider);

    return Scaffold(
      appBar: AppBar(title: const Text('Notifikasi')),
      body: AppPageBackground(
        padding: const EdgeInsets.fromLTRB(16, 12, 16, 16),
        child: Column(
          children: [
            AppHeroPanel(
              eyebrow: 'Pusat Notifikasi',
              icon: Icons.notifications_active_outlined,
              title: 'Pembaruan surat dan layanan penting',
              subtitle:
                  'Pantau perubahan status surat dan tindakan pengurus secara realtime di satu tempat.',
            ),
            const SizedBox(height: 8),
            AppSearchBar(
              hintText: 'Cari notifikasi surat',
              value: _query,
              onChanged: (value) => setState(() => _query = value),
            ),
            const SizedBox(height: 8),
            Expanded(
              child: notificationsAsync.when(
                data: (items) {
                  final filtered = items.where((item) {
                    final query = _query.trim().toLowerCase();
                    if (query.isEmpty) {
                      return true;
                    }
                    final haystack =
                        '${item.request.title} ${item.log.description} ${item.wargaName} ${AppConstants.suratStatusLabel(item.request.status)}'
                            .toLowerCase();
                    return haystack.contains(query);
                  }).toList();

                  if (filtered.isEmpty) {
                    return ListView(
                      physics: const AlwaysScrollableScrollPhysics(),
                      children: const [
                        SizedBox(height: 80),
                        AppEmptyState(
                          icon: Icons.notifications_none_rounded,
                          title: 'Belum ada notifikasi',
                          message:
                              'Pembaruan surat dan aktivitas penting akan muncul di sini.',
                        ),
                      ],
                    );
                  }

                  return RefreshIndicator(
                    onRefresh: () async =>
                        ref.invalidate(suratNotificationsProvider),
                    child: ListView.separated(
                      physics: const AlwaysScrollableScrollPhysics(),
                      itemCount: filtered.length,
                      separatorBuilder: (_, _) => const SizedBox(height: 12),
                      itemBuilder: (context, index) {
                        final item = filtered[index];
                        return AppSurfaceCard(
                          padding: const EdgeInsets.all(14),
                          child: InkWell(
                            onTap: () =>
                                context.push('/surat/${item.request.id}'),
                            borderRadius: BorderRadius.circular(
                              AppTheme.radiusLarge,
                            ),
                            child: Row(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Container(
                                  width: 42,
                                  height: 42,
                                  decoration: BoxDecoration(
                                    color: AppTheme.statusColor(
                                      item.request.status,
                                    ).withValues(alpha: 0.12),
                                    borderRadius: BorderRadius.circular(14),
                                  ),
                                  child: Icon(
                                    Icons.campaign_outlined,
                                    color: AppTheme.statusColor(
                                      item.request.status,
                                    ),
                                  ),
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment:
                                        CrossAxisAlignment.start,
                                    children: [
                                      Row(
                                        children: [
                                          Expanded(
                                            child: Text(
                                              item.request.title,
                                              style: AppTheme.heading3.copyWith(
                                                fontSize: 15,
                                              ),
                                            ),
                                          ),
                                          Text(
                                            item.log.created == null
                                                ? '-'
                                                : Formatters.tanggalRelatif(
                                                    item.log.created!,
                                                  ),
                                            style: AppTheme.caption,
                                          ),
                                        ],
                                      ),
                                      const SizedBox(height: 4),
                                      Text(
                                        item.log.description,
                                        style: AppTheme.bodyMedium,
                                      ),
                                      const SizedBox(height: 8),
                                      Wrap(
                                        spacing: 8,
                                        runSpacing: 8,
                                        children: [
                                          _chip(
                                            item.wargaName,
                                            AppTheme.extraLightGray,
                                            AppTheme.textSecondary,
                                          ),
                                          _chip(
                                            AppConstants.suratStatusLabel(
                                              item.request.status,
                                            ),
                                            AppTheme.statusColor(
                                              item.request.status,
                                            ).withValues(alpha: 0.12),
                                            AppTheme.statusColor(
                                              item.request.status,
                                            ),
                                          ),
                                        ],
                                      ),
                                    ],
                                  ),
                                ),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
                  );
                },
                loading: () => const Center(child: CircularProgressIndicator()),
                error: (error, _) => Center(
                  child: AppSurfaceCard(
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          ErrorClassifier.classify(error).message,
                          style: AppTheme.bodyMedium,
                          textAlign: TextAlign.center,
                        ),
                        const SizedBox(height: 10),
                        FilledButton(
                          onPressed: () =>
                              ref.invalidate(suratNotificationsProvider),
                          child: const Text('Coba Lagi'),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _chip(String label, Color background, Color foreground) {
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
}

