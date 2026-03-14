import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:iconsax_flutter/iconsax_flutter.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../../app/theme.dart';
import '../../../shared/models/warga_model.dart';

/// Export format types
enum ExportFormat {
  csv('CSV', Iconsax.document_text_1, 'Format tabel, bisa dibuka di Excel'),
  json('JSON', Iconsax.code_1, 'Format data terstruktur'),
  txt('Teks', Iconsax.document, 'Format teks sederhana');

  const ExportFormat(this.label, this.icon, this.description);
  final String label;
  final IconData icon;
  final String description;
}

/// Export columns
enum ExportColumn {
  nik('NIK', true),
  namaLengkap('Nama Lengkap', true),
  jenisKelamin('Jenis Kelamin', true),
  tempatLahir('Tempat Lahir', false),
  tanggalLahir('Tanggal Lahir', true),
  umur('Umur', true),
  agama('Agama', true),
  statusPernikahan('Status Pernikahan', true),
  pekerjaan('Pekerjaan', true),
  pendidikan('Pendidikan', true),
  golonganDarah('Golongan Darah', false),
  alamat('Alamat', false),
  rt('RT', true),
  rw('RW', true),
  noHp('No. HP', false);

  const ExportColumn(this.label, this.defaultSelected);
  final String label;
  final bool defaultSelected;
}

class WargaExportDialog extends StatefulWidget {
  const WargaExportDialog({super.key, required this.wargaList});

  final List<WargaModel> wargaList;

  @override
  State<WargaExportDialog> createState() => _WargaExportDialogState();
}

class _WargaExportDialogState extends State<WargaExportDialog> {
  ExportFormat _selectedFormat = ExportFormat.csv;
  final Set<ExportColumn> _selectedColumns = {};
  bool _isExporting = false;
  String? _errorMessage;

  @override
  void initState() {
    super.initState();
    // Initialize with default selected columns
    for (final col in ExportColumn.values) {
      if (col.defaultSelected) {
        _selectedColumns.add(col);
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final isDark = AppTheme.isDark(context);

    return Dialog(
      backgroundColor: AppTheme.cardColorFor(context),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: Container(
        constraints: const BoxConstraints(maxWidth: 500, maxHeight: 600),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            _buildHeader(context),
            // Content
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 20),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    // Summary
                    _buildSummary(isDark),
                    const SizedBox(height: 16),
                    // Format selection
                    _buildFormatSelection(isDark),
                    const SizedBox(height: 16),
                    // Column selection
                    _buildColumnSelection(isDark),
                    if (_errorMessage != null) ...[
                      const SizedBox(height: 12),
                      _buildErrorMessage(),
                    ],
                  ],
                ),
              ),
            ),
            // Actions
            _buildActions(context),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppTheme.primaryGradient,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: Colors.white.withValues(alpha: 0.2),
              borderRadius: BorderRadius.circular(12),
            ),
            child: const Icon(Iconsax.export_1, color: Colors.white),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Export Data Warga',
                  style: AppTheme.heading3.copyWith(color: Colors.white),
                ),
                const SizedBox(height: 2),
                Text(
                  'Download laporan dalam format pilihan',
                  style: AppTheme.caption.copyWith(
                    color: Colors.white.withValues(alpha: 0.8),
                  ),
                ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => Navigator.pop(context),
            icon: const Icon(Iconsax.close_circle, color: Colors.white),
          ),
        ],
      ),
    );
  }

  Widget _buildSummary(bool isDark) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.primaryColor.withValues(alpha: isDark ? 0.15 : 0.08),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: AppTheme.primaryColor.withValues(alpha: 0.2),
        ),
      ),
      child: Row(
        children: [
          Icon(Iconsax.info_circle,
              size: 20, color: AppTheme.primaryColor),
          const SizedBox(width: 12),
          Expanded(
            child: RichText(
              text: TextSpan(
                style: AppTheme.bodySmall.copyWith(
                  color: AppTheme.primaryTextFor(context),
                ),
                children: [
                  const TextSpan(text: 'Akan mengexport '),
                  TextSpan(
                    text: '${widget.wargaList.length} data warga',
                    style: const TextStyle(fontWeight: FontWeight.w700),
                  ),
                  const TextSpan(text: ' sesuai filter yang dipilih.'),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildFormatSelection(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          'Format Export',
          style: AppTheme.heading4.copyWith(
            color: AppTheme.primaryTextFor(context),
          ),
        ),
        const SizedBox(height: 10),
        ...ExportFormat.values.map((format) {
          final isSelected = _selectedFormat == format;
          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Material(
              color: isSelected
                  ? AppTheme.primaryColor.withValues(alpha: isDark ? 0.2 : 0.1)
                  : AppTheme.cardColorFor(context),
              borderRadius: BorderRadius.circular(12),
              child: InkWell(
                onTap: () => setState(() => _selectedFormat = format),
                borderRadius: BorderRadius.circular(12),
                child: Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(
                      color: isSelected
                          ? AppTheme.primaryColor
                          : AppTheme.cardBorderColorFor(context),
                      width: isSelected ? 2 : 1,
                    ),
                  ),
                  child: Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: isSelected
                              ? AppTheme.primaryColor
                              : AppTheme.secondaryTextFor(context)
                                  .withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Icon(
                          format.icon,
                          size: 18,
                          color: isSelected
                              ? Colors.white
                              : AppTheme.secondaryTextFor(context),
                        ),
                      ),
                      const SizedBox(width: 12),
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              format.label,
                              style: AppTheme.bodyMedium.copyWith(
                                fontWeight: FontWeight.w600,
                                color: AppTheme.primaryTextFor(context),
                              ),
                            ),
                            Text(
                              format.description,
                              style: AppTheme.caption.copyWith(
                                color: AppTheme.secondaryTextFor(context),
                              ),
                            ),
                          ],
                        ),
                      ),
                      Icon(
                        isSelected
                            ? Icons.radio_button_checked_rounded
                            : Icons.radio_button_off_rounded,
                        color: isSelected
                            ? AppTheme.primaryColor
                            : AppTheme.secondaryTextFor(context),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildColumnSelection(bool isDark) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
          children: [
            Expanded(
              child: Text(
                'Kolom Data',
                style: AppTheme.heading4.copyWith(
                  color: AppTheme.primaryTextFor(context),
                ),
              ),
            ),
            TextButton(
              onPressed: _selectAllColumns,
              child: Text(
                _selectedColumns.length == ExportColumn.values.length
                    ? 'Hapus Semua'
                    : 'Pilih Semua',
                style: AppTheme.caption.copyWith(
                  color: AppTheme.primaryColor,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: ExportColumn.values.map((col) {
            final isSelected = _selectedColumns.contains(col);
            return FilterChip(
              label: Text(col.label),
              selected: isSelected,
              onSelected: (selected) {
                setState(() {
                  if (selected) {
                    _selectedColumns.add(col);
                  } else {
                    _selectedColumns.remove(col);
                  }
                });
              },
              selectedColor:
                  AppTheme.primaryColor.withValues(alpha: isDark ? 0.3 : 0.15),
              checkmarkColor: AppTheme.primaryColor,
              labelStyle: AppTheme.caption.copyWith(
                color: isSelected
                    ? AppTheme.primaryColor
                    : AppTheme.primaryTextFor(context),
                fontWeight: isSelected ? FontWeight.w600 : FontWeight.normal,
              ),
              backgroundColor: AppTheme.cardColorFor(context),
              side: BorderSide(
                color: isSelected
                    ? AppTheme.primaryColor.withValues(alpha: 0.5)
                    : AppTheme.cardBorderColorFor(context),
              ),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(20),
              ),
            );
          }).toList(),
        ),
        const SizedBox(height: 8),
        Text(
          '${_selectedColumns.length} kolom dipilih',
          style: AppTheme.caption.copyWith(
            color: AppTheme.secondaryTextFor(context),
          ),
        ),
      ],
    );
  }

  Widget _buildErrorMessage() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.errorColor.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: AppTheme.errorColor.withValues(alpha: 0.3)),
      ),
      child: Row(
        children: [
          const Icon(Iconsax.warning_2,
              size: 18, color: AppTheme.errorColor),
          const SizedBox(width: 10),
          Expanded(
            child: Text(
              _errorMessage!,
              style: AppTheme.caption.copyWith(color: AppTheme.errorColor),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActions(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        color: AppTheme.cardColorFor(context),
        border: Border(
          top: BorderSide(color: AppTheme.cardBorderColorFor(context)),
        ),
      ),
      child: Row(
        children: [
          Expanded(
            child: OutlinedButton(
              onPressed: _isExporting ? null : () => Navigator.pop(context),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              child: const Text('Batal'),
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            flex: 2,
            child: FilledButton.icon(
              onPressed:
                  _isExporting || _selectedColumns.isEmpty ? null : _export,
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(12),
                ),
              ),
              icon: _isExporting
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: Colors.white,
                      ),
                    )
                  : const Icon(Iconsax.export_1, size: 18),
              label: Text(_isExporting ? 'Mengexport...' : 'Export'),
            ),
          ),
        ],
      ),
    );
  }

  void _selectAllColumns() {
    setState(() {
      if (_selectedColumns.length == ExportColumn.values.length) {
        _selectedColumns.clear();
      } else {
        _selectedColumns.addAll(ExportColumn.values);
      }
    });
  }

  Future<void> _export() async {
    if (_selectedColumns.isEmpty) {
      setState(() => _errorMessage = 'Pilih minimal satu kolom untuk export');
      return;
    }

    setState(() {
      _isExporting = true;
      _errorMessage = null;
    });

    try {
      HapticFeedback.mediumImpact();

      String content;
      String extension;
      String mimeType;

      switch (_selectedFormat) {
        case ExportFormat.csv:
          content = _generateCsv();
          extension = 'csv';
          mimeType = 'text/csv';
          break;
        case ExportFormat.json:
          content = _generateJson();
          extension = 'json';
          mimeType = 'application/json';
          break;
        case ExportFormat.txt:
          content = _generateTxt();
          extension = 'txt';
          mimeType = 'text/plain';
          break;
      }

      final timestamp = DateTime.now().toIso8601String().replaceAll(':', '-').split('.')[0];
      final fileName = 'laporan_warga_$timestamp.$extension';

      // Try file-based sharing first, fallback to clipboard
      bool shareSuccess = false;
      
      if (!kIsWeb) {
        try {
          final tempDir = await getTemporaryDirectory();
          final file = File('${tempDir.path}/$fileName');
          await file.writeAsString(content, encoding: utf8);

          if (!mounted) return;

          // Share file using new SharePlus API
          final result = await SharePlus.instance.share(
            ShareParams(
              files: [XFile(file.path, mimeType: mimeType)],
              subject: 'Laporan Data Warga',
              text: 'Laporan data warga (${widget.wargaList.length} data)',
            ),
          );

          shareSuccess = result.status == ShareResultStatus.success || 
                         result.status == ShareResultStatus.dismissed;
        } catch (e) {
          // If file sharing fails, try text sharing
          debugPrint('File share failed: $e');
        }
      }

      // Fallback: Share as text or copy to clipboard
      if (!shareSuccess) {
        try {
          await SharePlus.instance.share(
            ShareParams(
              text: content,
              subject: 'Laporan Data Warga - $fileName',
            ),
          );
          shareSuccess = true;
        } catch (e) {
          // Last resort: copy to clipboard
          await Clipboard.setData(ClipboardData(text: content));
          if (!mounted) return;
          
          Navigator.pop(context);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Row(
                children: [
                  const Icon(Iconsax.copy, color: Colors.white, size: 18),
                  const SizedBox(width: 10),
                  const Expanded(child: Text('Data disalin ke clipboard')),
                ],
              ),
              backgroundColor: AppTheme.infoColor,
              behavior: SnackBarBehavior.floating,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
            ),
          );
          return;
        }
      }

      if (!mounted) return;
      Navigator.pop(context);

      // Show success feedback
      HapticFeedback.heavyImpact();
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Row(
            children: [
              const Icon(Iconsax.tick_circle, color: Colors.white, size: 18),
              const SizedBox(width: 10),
              Expanded(child: Text('Export berhasil: $fileName')),
            ],
          ),
          backgroundColor: AppTheme.successColor,
          behavior: SnackBarBehavior.floating,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
        ),
      );
    } catch (e) {
      setState(() {
        _isExporting = false;
        _errorMessage = 'Gagal export: ${e.toString()}';
      });
      HapticFeedback.vibrate();
    }
  }

  String _generateCsv() {
    final buffer = StringBuffer();

    // Header row
    final headers =
        _selectedColumns.map((col) => '"${col.label}"').join(',');
    buffer.writeln(headers);

    // Data rows
    for (final warga in widget.wargaList) {
      final values = _selectedColumns.map((col) {
        final value = _getColumnValue(warga, col);
        // Escape quotes and wrap in quotes
        return '"${value.replaceAll('"', '""')}"';
      }).join(',');
      buffer.writeln(values);
    }

    return buffer.toString();
  }

  String _generateJson() {
    final data = widget.wargaList.map((warga) {
      final map = <String, dynamic>{};
      for (final col in _selectedColumns) {
        map[col.name] = _getColumnValue(warga, col);
      }
      return map;
    }).toList();

    // Simple JSON serialization
    return _toJsonString(data);
  }

  String _toJsonString(List<Map<String, dynamic>> data) {
    final buffer = StringBuffer();
    buffer.writeln('[');
    for (int i = 0; i < data.length; i++) {
      buffer.write('  {');
      final entries = data[i].entries.toList();
      for (int j = 0; j < entries.length; j++) {
        final entry = entries[j];
        final value = entry.value
            .toString()
            .replaceAll('\\', '\\\\')
            .replaceAll('"', '\\"');
        buffer.write('"${entry.key}": "$value"');
        if (j < entries.length - 1) buffer.write(', ');
      }
      buffer.write('}');
      if (i < data.length - 1) buffer.writeln(',');
    }
    buffer.writeln();
    buffer.writeln(']');
    return buffer.toString();
  }

  String _generateTxt() {
    final buffer = StringBuffer();
    buffer.writeln('═════════════════════════════════════════════════');
    buffer.writeln('             LAPORAN DATA WARGA');
    buffer.writeln('═════════════════════════════════════════════════');
    buffer.writeln('');
    buffer.writeln('Total Data: ${widget.wargaList.length} warga');
    buffer.writeln('Tanggal Export: ${DateTime.now().toString().split('.')[0]}');
    buffer.writeln('');
    buffer.writeln('─────────────────────────────────────────────────');
    buffer.writeln('');

    for (int i = 0; i < widget.wargaList.length; i++) {
      final warga = widget.wargaList[i];
      buffer.writeln('${i + 1}. ${warga.namaLengkap}');
      buffer.writeln('   ─────────────────────');

      for (final col in _selectedColumns) {
        if (col == ExportColumn.namaLengkap) continue; // Already shown
        buffer.writeln('   ${col.label}: ${_getColumnValue(warga, col)}');
      }
      buffer.writeln('');
    }

    buffer.writeln('═════════════════════════════════════════════════');
    buffer.writeln('         - Akhir Laporan -');
    buffer.writeln('═════════════════════════════════════════════════');

    return buffer.toString();
  }

  String _getColumnValue(WargaModel warga, ExportColumn col) {
    switch (col) {
      case ExportColumn.nik:
        return warga.nik;
      case ExportColumn.namaLengkap:
        return warga.namaLengkap;
      case ExportColumn.jenisKelamin:
        return warga.jenisKelamin;
      case ExportColumn.tempatLahir:
        return warga.tempatLahir;
      case ExportColumn.tanggalLahir:
        return warga.tanggalLahir != null
            ? '${warga.tanggalLahir!.day}/${warga.tanggalLahir!.month}/${warga.tanggalLahir!.year}'
            : '-';
      case ExportColumn.umur:
        return _calculateAge(warga.tanggalLahir).toString();
      case ExportColumn.agama:
        return warga.agama.isEmpty ? '-' : warga.agama;
      case ExportColumn.statusPernikahan:
        return warga.statusPernikahan.isEmpty ? '-' : warga.statusPernikahan;
      case ExportColumn.pekerjaan:
        return warga.pekerjaan.isEmpty ? '-' : warga.pekerjaan;
      case ExportColumn.pendidikan:
        return warga.pendidikan.isEmpty ? '-' : warga.pendidikan;
      case ExportColumn.golonganDarah:
        return warga.golonganDarah.isEmpty ? '-' : warga.golonganDarah;
      case ExportColumn.alamat:
        return warga.alamat.isEmpty ? '-' : warga.alamat;
      case ExportColumn.rt:
        return warga.rt;
      case ExportColumn.rw:
        return warga.rw;
      case ExportColumn.noHp:
        return warga.noHp.isEmpty ? '-' : warga.noHp;
    }
  }

  int _calculateAge(DateTime? birthDate) {
    if (birthDate == null) return 0;
    final now = DateTime.now();
    int age = now.year - birthDate.year;
    if (now.month < birthDate.month ||
        (now.month == birthDate.month && now.day < birthDate.day)) {
      age--;
    }
    return age;
  }
}
