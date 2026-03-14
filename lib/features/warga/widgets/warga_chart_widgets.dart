import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

import '../../../app/theme.dart';
import '../../../shared/models/warga_model.dart';
import 'warga_laporan_cards.dart';

// ═══════════════════════════════════════════════════════════════════
// HELPER FUNCTIONS
// ═══════════════════════════════════════════════════════════════════

int calculateAge(DateTime? birthDate) {
  if (birthDate == null) return 0;
  final now = DateTime.now();
  int age = now.year - birthDate.year;
  if (now.month < birthDate.month ||
      (now.month == birthDate.month && now.day < birthDate.day)) {
    age--;
  }
  return age;
}

String getUmurKategori(int umur) {
  if (umur <= 5) return 'Balita (0-5)';
  if (umur <= 12) return 'Anak (6-12)';
  if (umur <= 17) return 'Remaja (13-17)';
  if (umur <= 59) return 'Dewasa (18-59)';
  return 'Lansia (60+)';
}

final List<Color> chartColors = [
  AppTheme.primaryColor,
  AppTheme.secondaryColor,
  AppTheme.accentColor,
  AppTheme.warningColor,
  AppTheme.infoColor,
  const Color(0xFFEC4899),
  const Color(0xFF14B8A6),
  const Color(0xFFF97316),
  const Color(0xFF6366F1),
  const Color(0xFF84CC16),
];

// ═══════════════════════════════════════════════════════════════════
// DEMOGRAFI CHART
// ═══════════════════════════════════════════════════════════════════

class DemografiChart extends StatelessWidget {
  const DemografiChart({super.key, required this.wargaList});
  final List<WargaModel> wargaList;

  @override
  Widget build(BuildContext context) {
    final totalLaki = wargaList.where((w) => w.jenisKelamin == 'Laki-laki').length;
    final totalPerempuan = wargaList.where((w) => w.jenisKelamin == 'Perempuan').length;
    final total = wargaList.length;

    return LaporanDetailCard(
      title: 'Distribusi Gender',
      icon: Iconsax.chart_2_copy,
      child: Row(
        children: [
          Expanded(
            child: AspectRatio(
              aspectRatio: 1,
              child: CustomPaint(
                painter: _PieChartPainter(
                  data: [
                    _PieData('Laki-laki', totalLaki.toDouble(), AppTheme.infoColor),
                    _PieData('Perempuan', totalPerempuan.toDouble(), AppTheme.secondaryColor),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(width: 20),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _LegendItem(
                  color: AppTheme.infoColor,
                  label: 'Laki-laki',
                  value: totalLaki,
                  percentage: total > 0 ? (totalLaki / total * 100) : 0,
                ),
                const SizedBox(height: 12),
                _LegendItem(
                  color: AppTheme.secondaryColor,
                  label: 'Perempuan',
                  value: totalPerempuan,
                  percentage: total > 0 ? (totalPerempuan / total * 100) : 0,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class DemografiTable extends StatelessWidget {
  const DemografiTable({super.key, required this.wargaList});
  final List<WargaModel> wargaList;

  @override
  Widget build(BuildContext context) {
    final total = wargaList.length;
    final totalLaki = wargaList.where((w) => w.jenisKelamin == 'Laki-laki').length;
    final totalPerempuan = wargaList.where((w) => w.jenisKelamin == 'Perempuan').length;

    return LaporanDetailCard(
      title: 'Detail Demografi',
      icon: Iconsax.grid_2_copy,
      child: Column(
        children: [
          const LaporanTableRow(
            label: 'Kategori',
            value: 'Jumlah',
            percentage: 0,
            isHeader: true,
          ),
          LaporanTableRow(
            label: 'Laki-laki',
            value: totalLaki.toString(),
            percentage: total > 0 ? (totalLaki / total * 100) : 0,
            color: AppTheme.infoColor,
          ),
          LaporanTableRow(
            label: 'Perempuan',
            value: totalPerempuan.toString(),
            percentage: total > 0 ? (totalPerempuan / total * 100) : 0,
            color: AppTheme.secondaryColor,
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// UMUR CHART
// ═══════════════════════════════════════════════════════════════════

class UmurChart extends StatelessWidget {
  const UmurChart({super.key, required this.wargaList});
  final List<WargaModel> wargaList;

  @override
  Widget build(BuildContext context) {
    final kategoris = <String, int>{};
    for (final warga in wargaList) {
      final umur = calculateAge(warga.tanggalLahir);
      final kategori = getUmurKategori(umur);
      kategoris[kategori] = (kategoris[kategori] ?? 0) + 1;
    }

    final sortedKeys = [
      'Balita (0-5)',
      'Anak (6-12)',
      'Remaja (13-17)',
      'Dewasa (18-59)',
      'Lansia (60+)',
    ];

    return LaporanDetailCard(
      title: 'Distribusi Kelompok Umur',
      icon: Iconsax.chart_1_copy,
      child: _BarChart(
        data: sortedKeys.map((k) {
          return _BarData(k, (kategoris[k] ?? 0).toDouble());
        }).toList(),
        colors: chartColors,
      ),
    );
  }
}

class UmurTable extends StatelessWidget {
  const UmurTable({super.key, required this.wargaList});
  final List<WargaModel> wargaList;

  @override
  Widget build(BuildContext context) {
    final total = wargaList.length;
    final kategoris = <String, int>{};
    for (final warga in wargaList) {
      final umur = calculateAge(warga.tanggalLahir);
      final kategori = getUmurKategori(umur);
      kategoris[kategori] = (kategoris[kategori] ?? 0) + 1;
    }

    final sortedKeys = [
      'Balita (0-5)',
      'Anak (6-12)',
      'Remaja (13-17)',
      'Dewasa (18-59)',
      'Lansia (60+)',
    ];

    return LaporanDetailCard(
      title: 'Detail Kelompok Umur',
      icon: Iconsax.grid_2_copy,
      child: Column(
        children: [
          const LaporanTableRow(
            label: 'Kategori',
            value: 'Jumlah',
            percentage: 0,
            isHeader: true,
          ),
          ...sortedKeys.asMap().entries.map((entry) {
            final count = kategoris[entry.value] ?? 0;
            return LaporanTableRow(
              label: entry.value,
              value: count.toString(),
              percentage: total > 0 ? (count / total * 100) : 0,
              color: chartColors[entry.key % chartColors.length],
            );
          }),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// PEKERJAAN CHART
// ═══════════════════════════════════════════════════════════════════

class PekerjaanChart extends StatelessWidget {
  const PekerjaanChart({super.key, required this.wargaList});
  final List<WargaModel> wargaList;

  @override
  Widget build(BuildContext context) {
    final kategoris = <String, int>{};
    for (final warga in wargaList) {
      final pekerjaan = warga.pekerjaan.isEmpty ? 'Tidak diketahui' : _normalizePekerjaan(warga.pekerjaan);
      kategoris[pekerjaan] = (kategoris[pekerjaan] ?? 0) + 1;
    }

    final sorted = kategoris.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));
    final topCategories = sorted.take(8).toList();

    return LaporanDetailCard(
      title: 'Distribusi Pekerjaan',
      icon: Iconsax.chart_1_copy,
      child: _BarChart(
        data: topCategories.map((e) => _BarData(e.key, e.value.toDouble())).toList(),
        colors: chartColors,
        horizontal: true,
      ),
    );
  }

  String _normalizePekerjaan(String pekerjaan) {
    final lower = pekerjaan.toLowerCase();
    if (lower.contains('swasta') || lower.contains('karyawan')) return 'Karyawan Swasta';
    if (lower.contains('pns') || lower.contains('asn')) return 'PNS/ASN';
    if (lower.contains('wiraswasta') || lower.contains('wirausaha')) return 'Wiraswasta';
    if (lower.contains('pelajar') || lower.contains('mahasiswa')) return 'Pelajar/Mahasiswa';
    if (lower.contains('tidak') || lower.contains('belum')) return 'Tidak Bekerja';
    if (lower.contains('irt') || lower.contains('rumah tangga')) return 'Ibu Rumah Tangga';
    if (lower.contains('pensiun')) return 'Pensiunan';
    return pekerjaan;
  }
}

class PekerjaanTable extends StatelessWidget {
  const PekerjaanTable({super.key, required this.wargaList});
  final List<WargaModel> wargaList;

  @override
  Widget build(BuildContext context) {
    final total = wargaList.length;
    final kategoris = <String, int>{};
    for (final warga in wargaList) {
      final pekerjaan = warga.pekerjaan.isEmpty ? 'Tidak diketahui' : warga.pekerjaan;
      kategoris[pekerjaan] = (kategoris[pekerjaan] ?? 0) + 1;
    }

    final sorted = kategoris.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return LaporanDetailCard(
      title: 'Detail Pekerjaan',
      icon: Iconsax.grid_2_copy,
      child: Column(
        children: [
          const LaporanTableRow(
            label: 'Pekerjaan',
            value: 'Jumlah',
            percentage: 0,
            isHeader: true,
          ),
          ...sorted.take(10).toList().asMap().entries.map((entry) {
            return LaporanTableRow(
              label: entry.value.key,
              value: entry.value.value.toString(),
              percentage: total > 0 ? (entry.value.value / total * 100) : 0,
              color: chartColors[entry.key % chartColors.length],
            );
          }),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// PENDIDIKAN CHART
// ═══════════════════════════════════════════════════════════════════

class PendidikanChart extends StatelessWidget {
  const PendidikanChart({super.key, required this.wargaList});
  final List<WargaModel> wargaList;

  @override
  Widget build(BuildContext context) {
    final kategoris = <String, int>{};
    final pendidikanOrder = [
      'Tidak Sekolah',
      'SD',
      'SMP',
      'SMA/SMK',
      'Diploma',
      'S1',
      'S2',
      'S3',
    ];

    for (final warga in wargaList) {
      final pendidikan = warga.pendidikan.isEmpty ? 'Tidak diketahui' : _normalizePendidikan(warga.pendidikan);
      kategoris[pendidikan] = (kategoris[pendidikan] ?? 0) + 1;
    }

    return LaporanDetailCard(
      title: 'Distribusi Pendidikan',
      icon: Iconsax.chart_1_copy,
      child: _BarChart(
        data: pendidikanOrder.where((k) => kategoris.containsKey(k)).map((k) {
          return _BarData(k, (kategoris[k] ?? 0).toDouble());
        }).toList(),
        colors: chartColors,
      ),
    );
  }

  String _normalizePendidikan(String pendidikan) {
    final lower = pendidikan.toLowerCase();
    if (lower.contains('tidak') || lower.contains('belum')) return 'Tidak Sekolah';
    if (lower.contains('sd') || lower.contains('sekolah dasar')) return 'SD';
    if (lower.contains('smp') || lower.contains('sltp')) return 'SMP';
    if (lower.contains('sma') || lower.contains('smk') || lower.contains('slta')) return 'SMA/SMK';
    if (lower.contains('diploma') || lower.contains('d3') || lower.contains('d4')) return 'Diploma';
    if (lower.contains('s1') || lower.contains('sarjana')) return 'S1';
    if (lower.contains('s2') || lower.contains('magister')) return 'S2';
    if (lower.contains('s3') || lower.contains('doktor')) return 'S3';
    return pendidikan;
  }
}

class PendidikanTable extends StatelessWidget {
  const PendidikanTable({super.key, required this.wargaList});
  final List<WargaModel> wargaList;

  @override
  Widget build(BuildContext context) {
    final total = wargaList.length;
    final kategoris = <String, int>{};
    for (final warga in wargaList) {
      final pendidikan = warga.pendidikan.isEmpty ? 'Tidak diketahui' : warga.pendidikan;
      kategoris[pendidikan] = (kategoris[pendidikan] ?? 0) + 1;
    }

    final sorted = kategoris.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return LaporanDetailCard(
      title: 'Detail Pendidikan',
      icon: Iconsax.grid_2_copy,
      child: Column(
        children: [
          const LaporanTableRow(
            label: 'Pendidikan',
            value: 'Jumlah',
            percentage: 0,
            isHeader: true,
          ),
          ...sorted.asMap().entries.map((entry) {
            return LaporanTableRow(
              label: entry.value.key,
              value: entry.value.value.toString(),
              percentage: total > 0 ? (entry.value.value / total * 100) : 0,
              color: chartColors[entry.key % chartColors.length],
            );
          }),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// STATUS PERNIKAHAN CHART
// ═══════════════════════════════════════════════════════════════════

class StatusPernikahanChart extends StatelessWidget {
  const StatusPernikahanChart({super.key, required this.wargaList});
  final List<WargaModel> wargaList;

  @override
  Widget build(BuildContext context) {
    final kategoris = <String, int>{};
    for (final warga in wargaList) {
      final status = warga.statusPernikahan.isEmpty ? 'Tidak diketahui' : warga.statusPernikahan;
      kategoris[status] = (kategoris[status] ?? 0) + 1;
    }

    final sorted = kategoris.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return LaporanDetailCard(
      title: 'Status Pernikahan',
      icon: Iconsax.chart_2_copy,
      child: Row(
        children: [
          Expanded(
            child: AspectRatio(
              aspectRatio: 1,
              child: CustomPaint(
                painter: _PieChartPainter(
                  data: sorted.asMap().entries.map((e) {
                    return _PieData(
                      e.value.key,
                      e.value.value.toDouble(),
                      chartColors[e.key % chartColors.length],
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: sorted.take(4).toList().asMap().entries.map((e) {
                final total = wargaList.length;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _LegendItem(
                    color: chartColors[e.key % chartColors.length],
                    label: e.value.key,
                    value: e.value.value,
                    percentage: total > 0 ? (e.value.value / total * 100) : 0,
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class StatusPernikahanTable extends StatelessWidget {
  const StatusPernikahanTable({super.key, required this.wargaList});
  final List<WargaModel> wargaList;

  @override
  Widget build(BuildContext context) {
    final total = wargaList.length;
    final kategoris = <String, int>{};
    for (final warga in wargaList) {
      final status = warga.statusPernikahan.isEmpty ? 'Tidak diketahui' : warga.statusPernikahan;
      kategoris[status] = (kategoris[status] ?? 0) + 1;
    }

    final sorted = kategoris.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return LaporanDetailCard(
      title: 'Detail Status Pernikahan',
      icon: Iconsax.grid_2_copy,
      child: Column(
        children: [
          const LaporanTableRow(
            label: 'Status',
            value: 'Jumlah',
            percentage: 0,
            isHeader: true,
          ),
          ...sorted.asMap().entries.map((entry) {
            return LaporanTableRow(
              label: entry.value.key,
              value: entry.value.value.toString(),
              percentage: total > 0 ? (entry.value.value / total * 100) : 0,
              color: chartColors[entry.key % chartColors.length],
            );
          }),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// AGAMA CHART
// ═══════════════════════════════════════════════════════════════════

class AgamaChart extends StatelessWidget {
  const AgamaChart({super.key, required this.wargaList});
  final List<WargaModel> wargaList;

  @override
  Widget build(BuildContext context) {
    final kategoris = <String, int>{};
    for (final warga in wargaList) {
      final agama = warga.agama.isEmpty ? 'Tidak diketahui' : warga.agama;
      kategoris[agama] = (kategoris[agama] ?? 0) + 1;
    }

    final sorted = kategoris.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return LaporanDetailCard(
      title: 'Distribusi Agama',
      icon: Iconsax.chart_2_copy,
      child: Row(
        children: [
          Expanded(
            child: AspectRatio(
              aspectRatio: 1,
              child: CustomPaint(
                painter: _PieChartPainter(
                  data: sorted.asMap().entries.map((e) {
                    return _PieData(
                      e.value.key,
                      e.value.value.toDouble(),
                      chartColors[e.key % chartColors.length],
                    );
                  }).toList(),
                ),
              ),
            ),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: sorted.take(6).toList().asMap().entries.map((e) {
                final total = wargaList.length;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _LegendItem(
                    color: chartColors[e.key % chartColors.length],
                    label: e.value.key,
                    value: e.value.value,
                    percentage: total > 0 ? (e.value.value / total * 100) : 0,
                  ),
                );
              }).toList(),
            ),
          ),
        ],
      ),
    );
  }
}

class AgamaTable extends StatelessWidget {
  const AgamaTable({super.key, required this.wargaList});
  final List<WargaModel> wargaList;

  @override
  Widget build(BuildContext context) {
    final total = wargaList.length;
    final kategoris = <String, int>{};
    for (final warga in wargaList) {
      final agama = warga.agama.isEmpty ? 'Tidak diketahui' : warga.agama;
      kategoris[agama] = (kategoris[agama] ?? 0) + 1;
    }

    final sorted = kategoris.entries.toList()
      ..sort((a, b) => b.value.compareTo(a.value));

    return LaporanDetailCard(
      title: 'Detail Agama',
      icon: Iconsax.grid_2_copy,
      child: Column(
        children: [
          const LaporanTableRow(
            label: 'Agama',
            value: 'Jumlah',
            percentage: 0,
            isHeader: true,
          ),
          ...sorted.asMap().entries.map((entry) {
            return LaporanTableRow(
              label: entry.value.key,
              value: entry.value.value.toString(),
              percentage: total > 0 ? (entry.value.value / total * 100) : 0,
              color: chartColors[entry.key % chartColors.length],
            );
          }),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// DISTRIBUSI RT CHART
// ═══════════════════════════════════════════════════════════════════

class DistribusiRtChart extends StatelessWidget {
  const DistribusiRtChart({super.key, required this.wargaList});
  final List<WargaModel> wargaList;

  @override
  Widget build(BuildContext context) {
    final kategoris = <String, int>{};
    for (final warga in wargaList) {
      final rt = 'RT ${warga.rt.padLeft(2, '0')}';
      kategoris[rt] = (kategoris[rt] ?? 0) + 1;
    }

    final sorted = kategoris.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    return LaporanDetailCard(
      title: 'Distribusi Warga per RT',
      icon: Iconsax.chart_1_copy,
      child: _BarChart(
        data: sorted.map((e) => _BarData(e.key, e.value.toDouble())).toList(),
        colors: chartColors,
      ),
    );
  }
}

class DistribusiRtTable extends StatelessWidget {
  const DistribusiRtTable({super.key, required this.wargaList});
  final List<WargaModel> wargaList;

  @override
  Widget build(BuildContext context) {
    final total = wargaList.length;
    final kategoris = <String, int>{};
    for (final warga in wargaList) {
      final rt = 'RT ${warga.rt.padLeft(2, '0')}';
      kategoris[rt] = (kategoris[rt] ?? 0) + 1;
    }

    final sorted = kategoris.entries.toList()
      ..sort((a, b) => a.key.compareTo(b.key));

    return LaporanDetailCard(
      title: 'Detail per RT',
      icon: Iconsax.grid_2_copy,
      child: Column(
        children: [
          const LaporanTableRow(
            label: 'RT',
            value: 'Jumlah',
            percentage: 0,
            isHeader: true,
          ),
          ...sorted.asMap().entries.map((entry) {
            return LaporanTableRow(
              label: entry.value.key,
              value: '${entry.value.value} warga',
              percentage: total > 0 ? (entry.value.value / total * 100) : 0,
              color: chartColors[entry.key % chartColors.length],
            );
          }),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// PENDATANG CHART (Placeholder - needs created_at data)
// ═══════════════════════════════════════════════════════════════════

class PendatangChart extends StatelessWidget {
  const PendatangChart({super.key, required this.wargaList});
  final List<WargaModel> wargaList;

  @override
  Widget build(BuildContext context) {
    // Group by creation month (assuming we have created field)
    // This is a placeholder - actual implementation depends on data structure
    return LaporanDetailCard(
      title: 'Data Pendatang',
      icon: Iconsax.chart_1_copy,
      child: Center(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            children: [
              Icon(
                Iconsax.profile_2user_copy,
                size: 48,
                color: AppTheme.secondaryTextFor(context),
              ),
              const SizedBox(height: 12),
              Text(
                'Data pendatang berdasarkan bulan pendaftaran',
                style: AppTheme.bodyMedium.copyWith(
                  color: AppTheme.secondaryTextFor(context),
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 8),
              Text(
                'Total warga terdaftar: ${wargaList.length}',
                style: AppTheme.heading3,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class PendatangTable extends StatelessWidget {
  const PendatangTable({super.key, required this.wargaList});
  final List<WargaModel> wargaList;

  @override
  Widget build(BuildContext context) {
    return LaporanDetailCard(
      title: 'Ringkasan Pendatang',
      icon: Iconsax.grid_2_copy,
      child: Column(
        children: [
          const LaporanTableRow(
            label: 'Kategori',
            value: 'Jumlah',
            percentage: 0,
            isHeader: true,
          ),
          LaporanTableRow(
            label: 'Total Warga Terdaftar',
            value: wargaList.length.toString(),
            percentage: 100,
            color: AppTheme.primaryColor,
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// BANTUAN SOSIAL CHART
// ═══════════════════════════════════════════════════════════════════

class BantuanSosialChart extends StatelessWidget {
  const BantuanSosialChart({super.key, required this.wargaList});
  final List<WargaModel> wargaList;

  @override
  Widget build(BuildContext context) {
    // Identify priority categories
    int lansia = 0;
    int jandaDuda = 0;
    int tidakBekerja = 0;

    for (final warga in wargaList) {
      final umur = calculateAge(warga.tanggalLahir);
      if (umur >= 60) {
        lansia++;
      }
      if (warga.statusPernikahan.toLowerCase().contains('cerai')) {
        jandaDuda++;
      }
      if (warga.pekerjaan.toLowerCase().contains('tidak') ||
          warga.pekerjaan.isEmpty) {
        tidakBekerja++;
      }
    }

    return LaporanDetailCard(
      title: 'Warga Prioritas Bantuan',
      icon: Iconsax.lovely_copy,
      child: Row(
        children: [
          Expanded(
            child: _PriorityCard(
              icon: Iconsax.user_copy,
              label: 'Lansia',
              value: lansia,
              color: AppTheme.warningColor,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _PriorityCard(
              icon: Iconsax.profile_circle_copy,
              label: 'Janda/Duda',
              value: jandaDuda,
              color: AppTheme.secondaryColor,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: _PriorityCard(
              icon: Iconsax.briefcase_copy,
              label: 'Tidak Bekerja',
              value: tidakBekerja,
              color: AppTheme.errorColor,
            ),
          ),
        ],
      ),
    );
  }
}

class BantuanSosialTable extends StatelessWidget {
  const BantuanSosialTable({super.key, required this.wargaList});
  final List<WargaModel> wargaList;

  @override
  Widget build(BuildContext context) {
    final total = wargaList.length;

    int lansia = 0;
    int jandaDuda = 0;
    int tidakBekerja = 0;

    for (final warga in wargaList) {
      final umur = calculateAge(warga.tanggalLahir);
      if (umur >= 60) {
        lansia++;
      }
      if (warga.statusPernikahan.toLowerCase().contains('cerai')) {
        jandaDuda++;
      }
      if (warga.pekerjaan.toLowerCase().contains('tidak') ||
          warga.pekerjaan.isEmpty) {
        tidakBekerja++;
      }
    }

    return LaporanDetailCard(
      title: 'Detail Prioritas Bantuan',
      icon: Iconsax.grid_2_copy,
      child: Column(
        children: [
          const LaporanTableRow(
            label: 'Kategori',
            value: 'Jumlah',
            percentage: 0,
            isHeader: true,
          ),
          LaporanTableRow(
            label: 'Lansia (60+)',
            value: lansia.toString(),
            percentage: total > 0 ? (lansia / total * 100) : 0,
            color: AppTheme.warningColor,
          ),
          LaporanTableRow(
            label: 'Janda/Duda',
            value: jandaDuda.toString(),
            percentage: total > 0 ? (jandaDuda / total * 100) : 0,
            color: AppTheme.secondaryColor,
          ),
          LaporanTableRow(
            label: 'Tidak Bekerja',
            value: tidakBekerja.toString(),
            percentage: total > 0 ? (tidakBekerja / total * 100) : 0,
            color: AppTheme.errorColor,
          ),
        ],
      ),
    );
  }
}

// ═══════════════════════════════════════════════════════════════════
// CUSTOM PAINTERS & WIDGETS
// ═══════════════════════════════════════════════════════════════════

class _PieData {
  const _PieData(this.label, this.value, this.color);
  final String label;
  final double value;
  final Color color;
}

class _PieChartPainter extends CustomPainter {
  _PieChartPainter({required this.data});
  final List<_PieData> data;

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = math.min(size.width, size.height) / 2 - 8;
    final total = data.fold<double>(0, (sum, item) => sum + item.value);

    if (total == 0) return;

    double startAngle = -math.pi / 2;

    for (final item in data) {
      final sweepAngle = (item.value / total) * 2 * math.pi;
      final paint = Paint()
        ..color = item.color
        ..style = PaintingStyle.fill;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        true,
        paint,
      );

      // Add white border between slices
      final borderPaint = Paint()
        ..color = Colors.white
        ..style = PaintingStyle.stroke
        ..strokeWidth = 2;

      canvas.drawArc(
        Rect.fromCircle(center: center, radius: radius),
        startAngle,
        sweepAngle,
        true,
        borderPaint,
      );

      startAngle += sweepAngle;
    }

    // Draw center circle for donut effect
    final centerPaint = Paint()
      ..color = Colors.white
      ..style = PaintingStyle.fill;
    canvas.drawCircle(center, radius * 0.5, centerPaint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => true;
}

class _LegendItem extends StatelessWidget {
  const _LegendItem({
    required this.color,
    required this.label,
    required this.value,
    required this.percentage,
  });

  final Color color;
  final String label;
  final int value;
  final double percentage;

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Container(
          width: 12,
          height: 12,
          decoration: BoxDecoration(
            color: color,
            borderRadius: BorderRadius.circular(3),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                label,
                style: AppTheme.caption.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primaryTextFor(context),
                ),
              ),
              Text(
                '$value (${percentage.toStringAsFixed(1)}%)',
                style: AppTheme.caption.copyWith(
                  color: AppTheme.secondaryTextFor(context),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _BarData {
  const _BarData(this.label, this.value);
  final String label;
  final double value;
}

class _BarChart extends StatelessWidget {
  const _BarChart({
    required this.data,
    required this.colors,
    this.horizontal = false,
  });

  final List<_BarData> data;
  final List<Color> colors;
  final bool horizontal;

  @override
  Widget build(BuildContext context) {
    if (data.isEmpty) {
      return const Center(child: Text('Tidak ada data'));
    }

    final maxValue = data.map((d) => d.value).reduce(math.max);
    final isDark = AppTheme.isDark(context);

    if (horizontal) {
      return Column(
        children: data.asMap().entries.map((entry) {
          final item = entry.value;
          final color = colors[entry.key % colors.length];
          final percentage = maxValue > 0 ? (item.value / maxValue) : 0.0;

          return Padding(
            padding: const EdgeInsets.only(bottom: 10),
            child: Row(
              children: [
                SizedBox(
                  width: 80,
                  child: Text(
                    item.label,
                    style: AppTheme.caption.copyWith(
                      color: AppTheme.primaryTextFor(context),
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: percentage,
                      minHeight: 20,
                      backgroundColor: color.withValues(alpha: isDark ? 0.15 : 0.1),
                      valueColor: AlwaysStoppedAnimation(color),
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                SizedBox(
                  width: 40,
                  child: Text(
                    item.value.toInt().toString(),
                    style: AppTheme.caption.copyWith(
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                    textAlign: TextAlign.right,
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      );
    }

    // Vertical bar chart
    return SizedBox(
      height: 180,
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        children: data.asMap().entries.map((entry) {
          final item = entry.value;
          final color = colors[entry.key % colors.length];
          final percentage = maxValue > 0 ? (item.value / maxValue) : 0.0;

          return Expanded(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 4),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    item.value.toInt().toString(),
                    style: AppTheme.caption.copyWith(
                      fontWeight: FontWeight.w700,
                      color: color,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Flexible(
                    child: FractionallySizedBox(
                      heightFactor: percentage,
                      child: Container(
                        decoration: BoxDecoration(
                          color: color,
                          borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(4),
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: 6),
                  SizedBox(
                    height: 30,
                    child: Text(
                      item.label,
                      style: AppTheme.caption.copyWith(
                        fontSize: 9,
                        color: AppTheme.secondaryTextFor(context),
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ),
                ],
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

class _PriorityCard extends StatelessWidget {
  const _PriorityCard({
    required this.icon,
    required this.label,
    required this.value,
    required this.color,
  });

  final IconData icon;
  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: color.withValues(alpha: isDark ? 0.15 : 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          Icon(icon, size: 28, color: color),
          const SizedBox(height: 8),
          Text(
            value.toString(),
            style: AppTheme.heading2.copyWith(color: color),
          ),
          const SizedBox(height: 2),
          Text(
            label,
            style: AppTheme.caption.copyWith(
              color: AppTheme.secondaryTextFor(context),
              fontWeight: FontWeight.w600,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}
