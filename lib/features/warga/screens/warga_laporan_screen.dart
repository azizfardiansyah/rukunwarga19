import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';

import '../../../app/theme.dart';
import '../../../core/constants/app_constants.dart';
import '../../../core/services/pocketbase_service.dart';
import '../../../shared/models/warga_model.dart';
import '../../../shared/widgets/app_skeleton.dart';
import '../../../shared/widgets/app_surface.dart';
import '../../auth/providers/auth_provider.dart';
import '../widgets/warga_chart_widgets.dart';
import '../widgets/warga_export_dialog.dart';
import '../widgets/warga_laporan_cards.dart';

/// Enum untuk jenis laporan
enum LaporanType {
  demografi('Demografi', Iconsax.people_copy),
  umur('Umur', Iconsax.calendar_1),
  pekerjaan('Pekerjaan', Iconsax.briefcase_copy),
  pendidikan('Pendidikan', Iconsax.book_1),
  statusPernikahan('Status Pernikahan', Iconsax.heart_copy),
  agama('Agama', Iconsax.menu_board_copy),
  distribusiRt('Distribusi RT', Iconsax.buildings_2_copy),
  pendatang('Pendatang', Iconsax.user_add_copy),
  bantuanSosial('Bantuan Sosial', Iconsax.gift_copy);

  const LaporanType(this.label, this.icon);
  final String label;
  final IconData icon;
}

class WargaLaporanScreen extends ConsumerStatefulWidget {
  const WargaLaporanScreen({super.key});

  @override
  ConsumerState<WargaLaporanScreen> createState() => _WargaLaporanScreenState();
}

class _WargaLaporanScreenState extends ConsumerState<WargaLaporanScreen> {
  LaporanType _selectedType = LaporanType.demografi;
  String? _filterRt;
  String? _filterRw;
  String? _filterJenisKelamin;
  String? _filterUmur;
  String? _filterStatusPernikahan;
  String? _filterPekerjaan;
  String? _filterPendidikan;
  String? _filterAgama;
  int? _filterBulan;
  int? _filterTahun;

  // State untuk data - null berarti belum fetch
  List<WargaModel>? _wargaList;
  bool _isLoading = false;
  String? _error;

  // Fetch data berdasarkan filter
  Future<void> _fetchData() async {
    if (_isLoading) return;
    
    setState(() {
      _isLoading = true;
      _error = null;
    });

    try {
      final auth = ref.read(authProvider);
      if (auth.user == null) {
        setState(() {
          _wargaList = [];
          _isLoading = false;
        });
        return;
      }

      // Build filter query
      final filterParts = <String>[];
      
      if (_filterRt != null) {
        filterParts.add('rt = "$_filterRt"');
      }
      if (_filterRw != null) {
        filterParts.add('rw = "$_filterRw"');
      }
      if (_filterJenisKelamin != null) {
        filterParts.add('jenis_kelamin = "$_filterJenisKelamin"');
      }
      if (_filterAgama != null) {
        filterParts.add('agama = "$_filterAgama"');
      }
      if (_filterStatusPernikahan != null) {
        filterParts.add('status_pernikahan = "$_filterStatusPernikahan"');
      }
      if (_filterPekerjaan != null) {
        filterParts.add('pekerjaan ~ "$_filterPekerjaan"');
      }
      if (_filterPendidikan != null) {
        filterParts.add('pendidikan ~ "$_filterPendidikan"');
      }
      if (_filterBulan != null) {
        // Filter by created month
        final year = _filterTahun ?? DateTime.now().year;
        final startDate = DateTime(year, _filterBulan!, 1);
        final endDate = DateTime(year, _filterBulan! + 1, 1);
        filterParts.add('created >= "${startDate.toIso8601String()}"');
        filterParts.add('created < "${endDate.toIso8601String()}"');
      } else if (_filterTahun != null) {
        final startDate = DateTime(_filterTahun!, 1, 1);
        final endDate = DateTime(_filterTahun! + 1, 1, 1);
        filterParts.add('created >= "${startDate.toIso8601String()}"');
        filterParts.add('created < "${endDate.toIso8601String()}"');
      }

      final filterQuery = filterParts.isNotEmpty ? filterParts.join(' && ') : '';

      final records = await pb.collection(AppConstants.colWarga).getFullList(
        sort: 'nama_lengkap',
        filter: filterQuery,
      );

      setState(() {
        _wargaList = records.map(WargaModel.fromRecord).toList();
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Laporan Data Warga'),
        actions: [
          if (_wargaList != null)
            IconButton(
              onPressed: _fetchData,
              icon: const Icon(Iconsax.refresh),
              tooltip: 'Refresh Data',
            ),
          if (_wargaList != null && _wargaList!.isNotEmpty)
            IconButton(
              onPressed: () => _showExportDialog(context),
              icon: const Icon(Iconsax.export_1),
              tooltip: 'Export Data',
            ),
        ],
      ),
      body: AppPageBackground(
        padding: const EdgeInsets.fromLTRB(14, 8, 14, 20),
        child: Column(
          children: [
            _buildLaporanTypeDropdown(isDark),
            const SizedBox(height: 12),
            _buildFilters(isDark),
            const SizedBox(height: 14),
            // Tombol Tampilkan Data
            _buildFetchButton(),
            const SizedBox(height: 14),
            Expanded(
              child: _buildMainContent(),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildFetchButton() {
    return SizedBox(
      width: double.infinity,
      child: FilledButton.icon(
        onPressed: _isLoading ? null : _fetchData,
        icon: _isLoading
            ? const SizedBox(
                width: 18,
                height: 18,
                child: CircularProgressIndicator(
                  strokeWidth: 2,
                  color: Colors.white,
                ),
              )
            : const Icon(Iconsax.search_normal),
        label: Text(_isLoading ? 'Memuat...' : 'Tampilkan Laporan'),
        style: FilledButton.styleFrom(
          padding: const EdgeInsets.symmetric(vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
    );
  }

  Widget _buildMainContent() {
    // Belum fetch - tampilkan panduan
    if (_wargaList == null && !_isLoading && _error == null) {
      return Center(
        child: AppSurfaceCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Iconsax.filter,
                size: 64,
                color: AppTheme.primaryColor.withValues(alpha: 0.5),
              ),
              const SizedBox(height: 16),
              Text(
                'Pilih Filter & Tampilkan',
                style: AppTheme.heading3,
              ),
              const SizedBox(height: 8),
              Text(
                'Pilih jenis laporan dan filter yang diinginkan,\nlalu tekan tombol "Tampilkan Laporan"',
                style: AppTheme.bodyMedium.copyWith(
                  color: AppTheme.secondaryTextFor(context),
                ),
                textAlign: TextAlign.center,
              ),
            ],
          ),
        ),
      );
    }

    // Loading
    if (_isLoading) {
      return const _LaporanSkeleton();
    }

    // Error
    if (_error != null) {
      return Center(
        child: AppSurfaceCard(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Iconsax.warning_2,
                  size: 48, color: AppTheme.errorColor),
              const SizedBox(height: 12),
              Text('Gagal memuat data: $_error', style: AppTheme.bodyMedium),
              const SizedBox(height: 12),
              FilledButton(
                onPressed: _fetchData,
                child: const Text('Coba Lagi'),
              ),
            ],
          ),
        ),
      );
    }

    // Data loaded
    return _buildContent(_wargaList!);
  }

  Widget _buildLaporanTypeDropdown(bool isDark) {
    return AppSurfaceCard(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              gradient: AppTheme.primaryGradient,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Icon(_selectedType.icon, color: Colors.white, size: 18),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: DropdownButtonHideUnderline(
              child: DropdownButton<LaporanType>(
                value: _selectedType,
                isExpanded: true,
                icon: Icon(Icons.keyboard_arrow_down_rounded,
                    color: AppTheme.secondaryTextFor(context)),
                style: AppTheme.bodyMedium.copyWith(
                  fontWeight: FontWeight.w600,
                  color: AppTheme.primaryTextFor(context),
                ),
                dropdownColor: AppTheme.cardColorFor(context),
                items: LaporanType.values.map((type) {
                  return DropdownMenuItem(
                    value: type,
                    child: Row(
                      children: [
                        Icon(type.icon, size: 18, color: AppTheme.primaryColor),
                        const SizedBox(width: 10),
                        Text(type.label),
                      ],
                    ),
                  );
                }).toList(),
                onChanged: (value) {
                  if (value != null) {
                    HapticFeedback.selectionClick();
                    setState(() {
                      _selectedType = value;
                      _resetAdditionalFilters();
                    });
                  }
                },
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFilters(bool isDark) {
    final filters = _buildFilterList();
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: filters),
    );
  }

  List<Widget> _buildFilterList() {
    final filters = <Widget>[];
    filters.add(_buildFilterChip(
      label: _filterRt == null ? 'Semua RT' : 'RT $_filterRt',
      onTap: () => _showRtFilterSheet(),
      isActive: _filterRt != null,
    ));
    filters.add(const SizedBox(width: 8));

    if (_selectedType == LaporanType.distribusiRt ||
        _selectedType == LaporanType.demografi) {
      filters.add(_buildFilterChip(
        label: _filterRw == null ? 'Semua RW' : 'RW $_filterRw',
        onTap: () => _showRwFilterSheet(),
        isActive: _filterRw != null,
      ));
      filters.add(const SizedBox(width: 8));
    }

    if ([LaporanType.demografi, LaporanType.umur, LaporanType.statusPernikahan,
         LaporanType.bantuanSosial].contains(_selectedType)) {
      filters.add(_buildFilterChip(
        label: _filterJenisKelamin ?? 'Semua Gender',
        onTap: () => _showGenderFilterSheet(),
        isActive: _filterJenisKelamin != null,
      ));
      filters.add(const SizedBox(width: 8));
    }

    if ([LaporanType.demografi, LaporanType.statusPernikahan, LaporanType.pekerjaan,
         LaporanType.pendidikan, LaporanType.agama, LaporanType.bantuanSosial]
        .contains(_selectedType)) {
      filters.add(_buildFilterChip(
        label: _filterUmur ?? 'Semua Umur',
        onTap: () => _showUmurFilterSheet(),
        isActive: _filterUmur != null,
      ));
      filters.add(const SizedBox(width: 8));
    }

    if (_selectedType == LaporanType.pendatang) {
      filters.add(_buildFilterChip(
        label: _filterBulan == null ? 'Semua Bulan' : _getMonthName(_filterBulan!),
        onTap: () => _showBulanFilterSheet(),
        isActive: _filterBulan != null,
      ));
      filters.add(const SizedBox(width: 8));
      filters.add(_buildFilterChip(
        label: _filterTahun == null ? 'Semua Tahun' : '$_filterTahun',
        onTap: () => _showTahunFilterSheet(),
        isActive: _filterTahun != null,
      ));
      filters.add(const SizedBox(width: 8));
    }

    if (_hasActiveFilters()) {
      filters.add(_buildFilterChip(
        label: 'Reset',
        onTap: _resetFilters,
        isActive: false,
        isReset: true,
      ));
    }
    return filters;
  }

  Widget _buildFilterChip({
    required String label,
    required VoidCallback onTap,
    required bool isActive,
    bool isReset = false,
  }) {
    final isDark = AppTheme.isDark(context);
    return Material(
      color: isReset
          ? AppTheme.errorColor.withValues(alpha: 0.1)
          : isActive
              ? AppTheme.primaryColor.withValues(alpha: isDark ? 0.2 : 0.1)
              : AppTheme.cardColorFor(context),
      borderRadius: BorderRadius.circular(20),
      child: InkWell(
        onTap: () {
          HapticFeedback.selectionClick();
          onTap();
        },
        borderRadius: BorderRadius.circular(20),
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            border: Border.all(
              color: isReset
                  ? AppTheme.errorColor.withValues(alpha: 0.3)
                  : isActive
                      ? AppTheme.primaryColor.withValues(alpha: 0.5)
                      : AppTheme.cardBorderColorFor(context),
            ),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (isReset)
                const Icon(Iconsax.close_circle, size: 14, color: AppTheme.errorColor),
              if (isReset) const SizedBox(width: 4),
              Text(
                label,
                style: AppTheme.caption.copyWith(
                  fontWeight: FontWeight.w600,
                  color: isReset
                      ? AppTheme.errorColor
                      : isActive
                          ? AppTheme.primaryColor
                          : AppTheme.secondaryTextFor(context),
                ),
              ),
              if (!isReset && isActive) ...[
                const SizedBox(width: 4),
                const Icon(Iconsax.tick_circle, size: 14, color: AppTheme.primaryColor),
              ],
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildContent(List<WargaModel> wargaList) {
    final filtered = _applyFilters(wargaList);
    if (filtered.isEmpty) {
      return Center(
        child: AppEmptyState(
          icon: Iconsax.search_status,
          title: 'Tidak ada data',
          message: 'Tidak ditemukan warga dengan filter yang dipilih.',
        ),
      );
    }
    return SingleChildScrollView(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _buildSummaryCards(filtered, wargaList.length),
          const SizedBox(height: 16),
          _buildChartSection(filtered),
          const SizedBox(height: 16),
          _buildDetailTable(filtered),
        ],
      ),
    );
  }

  Widget _buildSummaryCards(List<WargaModel> filtered, int totalAll) {
    final totalFiltered = filtered.length;
    final totalLaki = filtered.where((w) => w.jenisKelamin == 'Laki-laki').length;
    final totalPerempuan = filtered.where((w) => w.jenisKelamin == 'Perempuan').length;
    final uniqueKk = filtered.map((w) => w.noKkId).toSet().length;

    if (_selectedType == LaporanType.demografi) {
      return Column(
        children: [
          Row(
            children: [
              Expanded(
                child: LaporanSummaryCard(
                  title: 'Total Warga',
                  value: totalFiltered.toString(),
                  icon: Iconsax.people,
                  color: AppTheme.primaryColor,
                  subtitle: totalFiltered == totalAll ? 'Semua data' : 'dari $totalAll',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: LaporanSummaryCard(
                  title: 'Total KK',
                  value: uniqueKk.toString(),
                  icon: Iconsax.home_2,
                  color: AppTheme.warningColor,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: LaporanSummaryCard(
                  title: 'Laki-laki',
                  value: totalLaki.toString(),
                  icon: Iconsax.man,
                  color: AppTheme.infoColor,
                  subtitle: totalFiltered > 0
                      ? '${(totalLaki / totalFiltered * 100).toStringAsFixed(1)}%'
                      : '0%',
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: LaporanSummaryCard(
                  title: 'Perempuan',
                  value: totalPerempuan.toString(),
                  icon: Iconsax.woman,
                  color: AppTheme.secondaryColor,
                  subtitle: totalFiltered > 0
                      ? '${(totalPerempuan / totalFiltered * 100).toStringAsFixed(1)}%'
                      : '0%',
                ),
              ),
            ],
          ),
        ],
      );
    }

    if (_selectedType == LaporanType.bantuanSosial) {
      int lansia = 0;
      int jandaDuda = 0;
      int tidakBekerja = 0;
      for (final warga in filtered) {
        final umur = calculateAge(warga.tanggalLahir);
        if (umur >= 60) lansia++;
        if (warga.statusPernikahan.toLowerCase().contains('cerai')) jandaDuda++;
        final pLower = warga.pekerjaan.toLowerCase();
        if (pLower.contains('tidak') || pLower.isEmpty) tidakBekerja++;
      }
      return Row(
        children: [
          Expanded(child: LaporanSummaryCard(
            title: 'Lansia (60+)', value: lansia.toString(),
            icon: Iconsax.personalcard, color: AppTheme.warningColor)),
          const SizedBox(width: 10),
          Expanded(child: LaporanSummaryCard(
            title: 'Janda/Duda', value: jandaDuda.toString(),
            icon: Iconsax.user, color: AppTheme.secondaryColor)),
          const SizedBox(width: 10),
          Expanded(child: LaporanSummaryCard(
            title: 'Tidak Bekerja', value: tidakBekerja.toString(),
            icon: Iconsax.briefcase, color: AppTheme.errorColor)),
        ],
      );
    }

    return Row(
      children: [
        Expanded(child: LaporanSummaryCard(
          title: 'Total Warga', value: totalFiltered.toString(),
          icon: Iconsax.people, color: AppTheme.primaryColor)),
        const SizedBox(width: 10),
        Expanded(child: LaporanSummaryCard(
          title: 'Laki-laki', value: totalLaki.toString(),
          icon: Iconsax.man, color: AppTheme.infoColor)),
        const SizedBox(width: 10),
        Expanded(child: LaporanSummaryCard(
          title: 'Perempuan', value: totalPerempuan.toString(),
          icon: Iconsax.woman, color: AppTheme.secondaryColor)),
      ],
    );
  }

  Widget _buildChartSection(List<WargaModel> wargaList) {
    switch (_selectedType) {
      case LaporanType.demografi: return DemografiChart(wargaList: wargaList);
      case LaporanType.umur: return UmurChart(wargaList: wargaList);
      case LaporanType.pekerjaan: return PekerjaanChart(wargaList: wargaList);
      case LaporanType.pendidikan: return PendidikanChart(wargaList: wargaList);
      case LaporanType.statusPernikahan: return StatusPernikahanChart(wargaList: wargaList);
      case LaporanType.agama: return AgamaChart(wargaList: wargaList);
      case LaporanType.distribusiRt: return DistribusiRtChart(wargaList: wargaList);
      case LaporanType.pendatang: return PendatangChart(wargaList: wargaList);
      case LaporanType.bantuanSosial: return BantuanSosialChart(wargaList: wargaList);
    }
  }

  Widget _buildDetailTable(List<WargaModel> wargaList) {
    switch (_selectedType) {
      case LaporanType.demografi: return DemografiTable(wargaList: wargaList);
      case LaporanType.umur: return UmurTable(wargaList: wargaList);
      case LaporanType.pekerjaan: return PekerjaanTable(wargaList: wargaList);
      case LaporanType.pendidikan: return PendidikanTable(wargaList: wargaList);
      case LaporanType.statusPernikahan: return StatusPernikahanTable(wargaList: wargaList);
      case LaporanType.agama: return AgamaTable(wargaList: wargaList);
      case LaporanType.distribusiRt: return DistribusiRtTable(wargaList: wargaList);
      case LaporanType.pendatang: return PendatangTable(wargaList: wargaList);
      case LaporanType.bantuanSosial: return BantuanSosialTable(wargaList: wargaList);
    }
  }

  List<WargaModel> _applyFilters(List<WargaModel> wargaList) {
    return wargaList.where((warga) {
      if (_filterRt != null && warga.rt != _filterRt) return false;
      if (_filterRw != null && warga.rw != _filterRw) return false;
      if (_filterJenisKelamin != null && warga.jenisKelamin != _filterJenisKelamin) return false;
      if (_filterUmur != null) {
        final umur = calculateAge(warga.tanggalLahir);
        if (!_matchesUmurFilter(umur, _filterUmur!)) return false;
      }
      if (_filterStatusPernikahan != null && warga.statusPernikahan != _filterStatusPernikahan) {
        return false;
      }
      if (_filterPekerjaan != null &&
          !warga.pekerjaan.toLowerCase().contains(_filterPekerjaan!.toLowerCase())) {
        return false;
      }
      if (_filterPendidikan != null &&
          !warga.pendidikan.toLowerCase().contains(_filterPendidikan!.toLowerCase())) {
        return false;
      }
      if (_filterAgama != null && warga.agama != _filterAgama) {
        return false;
      }
      if (_filterBulan != null && warga.created?.month != _filterBulan) {
        return false;
      }
      if (_filterTahun != null && warga.created?.year != _filterTahun) {
        return false;
      }
      return true;
    }).toList();
  }

  bool _matchesUmurFilter(int umur, String filter) {
    switch (filter) {
      case 'Balita (0-5)': return umur >= 0 && umur <= 5;
      case 'Anak (6-12)': return umur >= 6 && umur <= 12;
      case 'Remaja (13-17)': return umur >= 13 && umur <= 17;
      case 'Dewasa (18-59)': return umur >= 18 && umur <= 59;
      case 'Lansia (60+)': return umur >= 60;
      default: return true;
    }
  }

  bool _hasActiveFilters() {
    return _filterRt != null || _filterRw != null || _filterJenisKelamin != null ||
        _filterUmur != null || _filterStatusPernikahan != null || _filterPekerjaan != null ||
        _filterPendidikan != null || _filterAgama != null || _filterBulan != null || _filterTahun != null;
  }

  void _resetFilters() {
    setState(() {
      _filterRt = null; _filterRw = null; _filterJenisKelamin = null;
      _filterUmur = null; _filterStatusPernikahan = null; _filterPekerjaan = null;
      _filterPendidikan = null; _filterAgama = null; _filterBulan = null; _filterTahun = null;
    });
  }

  void _resetAdditionalFilters() {
    _filterStatusPernikahan = null; _filterPekerjaan = null;
    _filterPendidikan = null; _filterAgama = null;
    _filterBulan = null; _filterTahun = null;
  }

  void _showRtFilterSheet() {
    final rtList = List.generate(10, (i) => (i + 1).toString().padLeft(2, '0'));
    _showFilterBottomSheet(
      title: 'Pilih RT',
      options: [null, ...rtList],
      labels: ['Semua RT', ...rtList.map((rt) => 'RT $rt')],
      selected: _filterRt,
      onSelected: (value) => setState(() => _filterRt = value),
    );
  }

  void _showRwFilterSheet() {
    final rwList = List.generate(5, (i) => (i + 1).toString().padLeft(2, '0'));
    _showFilterBottomSheet(
      title: 'Pilih RW',
      options: [null, ...rwList],
      labels: ['Semua RW', ...rwList.map((rw) => 'RW $rw')],
      selected: _filterRw,
      onSelected: (value) => setState(() => _filterRw = value),
    );
  }

  void _showGenderFilterSheet() {
    _showFilterBottomSheet(
      title: 'Pilih Jenis Kelamin',
      options: [null, 'Laki-laki', 'Perempuan'],
      labels: ['Semua Gender', 'Laki-laki', 'Perempuan'],
      selected: _filterJenisKelamin,
      onSelected: (value) => setState(() => _filterJenisKelamin = value),
    );
  }

  void _showUmurFilterSheet() {
    _showFilterBottomSheet(
      title: 'Pilih Kategori Umur',
      options: [null, 'Balita (0-5)', 'Anak (6-12)', 'Remaja (13-17)', 'Dewasa (18-59)', 'Lansia (60+)'],
      labels: ['Semua Umur', 'Balita (0-5)', 'Anak (6-12)', 'Remaja (13-17)', 'Dewasa (18-59)', 'Lansia (60+)'],
      selected: _filterUmur,
      onSelected: (value) => setState(() => _filterUmur = value),
    );
  }

  void _showBulanFilterSheet() {
    final months = List.generate(12, (i) => i + 1);
    _showFilterBottomSheet(
      title: 'Pilih Bulan',
      options: [null, ...months.map((m) => m.toString())],
      labels: ['Semua Bulan', ...months.map((m) => _getMonthName(m))],
      selected: _filterBulan?.toString(),
      onSelected: (value) => setState(() => _filterBulan = value == null ? null : int.tryParse(value)),
    );
  }

  void _showTahunFilterSheet() {
    final currentYear = DateTime.now().year;
    final years = List.generate(5, (i) => currentYear - i);
    _showFilterBottomSheet(
      title: 'Pilih Tahun',
      options: [null, ...years.map((y) => y.toString())],
      labels: ['Semua Tahun', ...years.map((y) => y.toString())],
      selected: _filterTahun?.toString(),
      onSelected: (value) => setState(() => _filterTahun = value == null ? null : int.tryParse(value)),
    );
  }

  String _getMonthName(int month) {
    const months = ['Januari', 'Februari', 'Maret', 'April', 'Mei', 'Juni',
      'Juli', 'Agustus', 'September', 'Oktober', 'November', 'Desember'];
    return months[month - 1];
  }

  void _showFilterBottomSheet({
    required String title,
    required List<String?> options,
    required List<String> labels,
    required String? selected,
    required void Function(String?) onSelected,
  }) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.cardColorFor(context),
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      isScrollControlled: true,
      builder: (ctx) {
        return DraggableScrollableSheet(
          initialChildSize: 0.5,
          minChildSize: 0.3,
          maxChildSize: 0.8,
          expand: false,
          builder: (_, scrollController) {
            return SafeArea(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 40, height: 4,
                    margin: const EdgeInsets.only(top: 12),
                    decoration: BoxDecoration(
                      color: AppTheme.dividerColor,
                      borderRadius: BorderRadius.circular(2),
                    ),
                  ),
                  Padding(
                    padding: const EdgeInsets.all(16),
                    child: Text(title, style: AppTheme.heading3),
                  ),
                  const Divider(height: 1),
                  Expanded(
                    child: ListView.builder(
                      controller: scrollController,
                      itemCount: options.length,
                      itemBuilder: (_, index) {
                        final isSelected = options[index] == selected;
                        return ListTile(
                          leading: Icon(
                            isSelected ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                            color: isSelected ? AppTheme.primaryColor : AppTheme.secondaryTextFor(context),
                          ),
                          title: Text(
                            labels[index],
                            style: AppTheme.bodyMedium.copyWith(
                              fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
                              color: AppTheme.primaryTextFor(context),
                            ),
                          ),
                          onTap: () {
                            HapticFeedback.selectionClick();
                            onSelected(options[index]);
                            Navigator.pop(ctx);
                          },
                        );
                      },
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
  }

  void _showExportDialog(BuildContext context) {
    if (_wargaList == null || _wargaList!.isEmpty) return;
    
    final filtered = _applyFilters(_wargaList!);
    showDialog(
      context: context,
      builder: (ctx) => WargaExportDialog(wargaList: filtered),
    );
  }
}

class _LaporanSkeleton extends StatelessWidget {
  const _LaporanSkeleton();

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      child: Column(
        children: [
          Row(
            children: List.generate(3, (_) => const Expanded(
              child: Padding(
                padding: EdgeInsets.symmetric(horizontal: 4),
                child: AppSkeleton(height: 90, borderRadius: 14),
              ),
            )),
          ),
          const SizedBox(height: 16),
          const AppSkeleton(height: 280, borderRadius: 16),
          const SizedBox(height: 16),
          AppSurfaceCard(
            child: Column(
              children: List.generate(6, (_) => const Padding(
                padding: EdgeInsets.only(bottom: 12),
                child: AppSkeleton(height: 44, borderRadius: 8),
              )),
            ),
          ),
        ],
      ),
    );
  }
}
