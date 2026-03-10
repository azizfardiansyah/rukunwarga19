import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../constants/app_constants.dart';
import '../utils/formatters.dart';
import 'laporan_service.dart';

class IuranPdfService {
  Future<Uint8List> buildOutstandingBillsPdf(
    LaporanOperationalData report, {
    required String generatedBy,
  }) async {
    final document = pw.Document(
      title: 'Rekap Tunggakan Iuran',
      author: AppConstants.appName,
      subject: 'Rekap iuran per KK yang belum lunas',
    );

    final outstandingBills = report.unpaidBills;
    final summary = report.iuranSummary;

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4.landscape,
        margin: const pw.EdgeInsets.fromLTRB(28, 28, 28, 28),
        build: (context) => [
          pw.Text(
            'REKAP IURAN BELUM MASUK',
            style: pw.TextStyle(fontSize: 18, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 6),
          pw.Text(
            'Periode laporan: ${report.preset.label} (${Formatters.tanggalPendek(report.startedAt)} - ${Formatters.tanggalPendek(report.endedAt)})',
            style: const pw.TextStyle(fontSize: 10),
          ),
          pw.Text(
            'Dibuat oleh: $generatedBy • ${Formatters.tanggalWaktu(DateTime.now())}',
            style: const pw.TextStyle(fontSize: 10),
          ),
          pw.SizedBox(height: 18),
          pw.Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _summaryBox('Total Tagihan', summary.totalBills.toString()),
              _summaryBox('Belum Lunas', summary.outstandingBills.toString()),
              _summaryBox(
                'Menunggu Verifikasi',
                summary.pendingVerificationBills.toString(),
              ),
              _summaryBox(
                'Total Tunggakan',
                Formatters.rupiah(summary.totalTunggakan),
              ),
            ],
          ),
          pw.SizedBox(height: 18),
          pw.Text(
            'Daftar KK Belum Lunas',
            style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          _buildOutstandingTable(outstandingBills),
        ],
      ),
    );

    return document.save();
  }

  Future<void> shareOutstandingBillsPdf(
    LaporanOperationalData report, {
    required String generatedBy,
  }) async {
    final bytes = await buildOutstandingBillsPdf(
      report,
      generatedBy: generatedBy,
    );
    await Printing.sharePdf(
      bytes: bytes,
      filename: _filename(report.preset),
    );
  }

  pw.Widget _summaryBox(String label, String value) {
    return pw.Container(
      width: 150,
      padding: const pw.EdgeInsets.all(10),
      decoration: pw.BoxDecoration(
        border: pw.Border.all(color: PdfColors.grey300, width: 0.7),
        borderRadius: pw.BorderRadius.circular(10),
        color: PdfColors.grey100,
      ),
      child: pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            value,
            style: pw.TextStyle(fontSize: 13, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 4),
          pw.Text(label, style: const pw.TextStyle(fontSize: 9)),
        ],
      ),
    );
  }

  pw.Widget _buildOutstandingTable(List reportItems) {
    final rows = <List<String>>[
      ['No', 'No. KK', 'Kepala Keluarga', 'Jenis', 'Tagihan', 'Jatuh Tempo', 'Status'],
    ];

    for (var index = 0; index < reportItems.length; index++) {
      final bill = reportItems[index];
      rows.add([
        '${index + 1}',
        bill.kkNumber,
        (bill.kkHolderName ?? '').trim().isEmpty ? '-' : bill.kkHolderName!,
        bill.typeLabel,
        Formatters.rupiah(bill.amount),
        bill.dueDate == null ? '-' : Formatters.tanggalPendek(bill.dueDate!),
        AppConstants.iuranBillStatusLabel(bill.status),
      ]);
    }

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.6),
      columnWidths: const {
        0: pw.FixedColumnWidth(28),
        1: pw.FlexColumnWidth(2.1),
        2: pw.FlexColumnWidth(2.2),
        3: pw.FlexColumnWidth(1.8),
        4: pw.FlexColumnWidth(1.4),
        5: pw.FlexColumnWidth(1.3),
        6: pw.FlexColumnWidth(1.6),
      },
      children: rows
          .asMap()
          .entries
          .map(
            (entry) => pw.TableRow(
              decoration: pw.BoxDecoration(
                color: entry.key == 0 ? PdfColors.grey200 : PdfColors.white,
              ),
              children: entry.value
                  .map(
                    (cell) => pw.Padding(
                      padding: const pw.EdgeInsets.all(6),
                      child: pw.Text(
                        cell,
                        style: pw.TextStyle(
                          fontSize: entry.key == 0 ? 9 : 8.5,
                          fontWeight: entry.key == 0
                              ? pw.FontWeight.bold
                              : pw.FontWeight.normal,
                        ),
                      ),
                    ),
                  )
                  .toList(),
            ),
          )
          .toList(),
    );
  }

  String _filename(LaporanRangePreset preset) =>
      'iuran-belum-masuk-${preset.name}.pdf';
}

final iuranPdfServiceProvider = Provider<IuranPdfService>(
  (ref) => IuranPdfService(),
);
