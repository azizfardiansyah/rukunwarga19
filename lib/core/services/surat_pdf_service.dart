import 'dart:typed_data';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pdf/pdf.dart';
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';

import '../constants/app_constants.dart';
import '../utils/formatters.dart';
import 'pocketbase_service.dart';
import 'surat_service.dart';

class SuratPdfService {
  Future<Uint8List> buildPdf(SuratDetailData detail) async {
    final request = detail.request;
    final templateBody = await _loadTemplateBody(request.jenisSurat);
    final renderedBody = _renderTemplate(templateBody, detail);

    final document = pw.Document(
      title: request.title,
      author: AppConstants.appName,
      subject: request.purpose,
    );

    document.addPage(
      pw.MultiPage(
        pageFormat: PdfPageFormat.a4,
        margin: const pw.EdgeInsets.fromLTRB(40, 48, 40, 48),
        build: (context) => [
          pw.Center(
            child: pw.Text(
              request.title.toUpperCase(),
              style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
              textAlign: pw.TextAlign.center,
            ),
          ),
          pw.SizedBox(height: 8),
          pw.Center(
            child: pw.Text(
              request.outputNumber?.trim().isNotEmpty == true
                  ? 'Nomor: ${request.outputNumber!.trim()}'
                  : 'Nomor: -',
              style: const pw.TextStyle(fontSize: 10),
            ),
          ),
          pw.SizedBox(height: 24),
          pw.Text(
            renderedBody,
            style: const pw.TextStyle(fontSize: 11, lineSpacing: 4),
            textAlign: pw.TextAlign.justify,
          ),
          pw.SizedBox(height: 20),
          pw.Text(
            'Ringkasan data surat',
            style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          _buildInfoTable(detail),
          pw.SizedBox(height: 20),
          pw.Text(
            'Field pengajuan',
            style: pw.TextStyle(fontSize: 12, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 8),
          _buildPayloadTable(detail),
          pw.SizedBox(height: 28),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.end,
            children: [
              pw.Column(
                crossAxisAlignment: pw.CrossAxisAlignment.center,
                children: [
                  pw.Text(
                    '${detail.request.kabupatenKota ?? detail.request.provinsi ?? 'Wilayah'}, ${Formatters.tanggalLengkap(DateTime.now())}',
                    style: const pw.TextStyle(fontSize: 10),
                  ),
                  pw.SizedBox(height: 48),
                  pw.Text(
                    _signerLabel(detail),
                    style: pw.TextStyle(
                      fontSize: 11,
                      fontWeight: pw.FontWeight.bold,
                    ),
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    );

    return document.save();
  }

  Future<void> sharePdf(SuratDetailData detail) async {
    final bytes = await buildPdf(detail);
    await Printing.sharePdf(bytes: bytes, filename: _pdfFilename(detail));
  }

  Future<void> printPdf(SuratDetailData detail) async {
    final bytes = await buildPdf(detail);
    await Printing.layoutPdf(
      name: _pdfFilename(detail),
      onLayout: (_) async => bytes,
    );
  }

  Future<String> _loadTemplateBody(String code) async {
    try {
      final record = await pb
          .collection(AppConstants.colSuratTemplates)
          .getFirstListItem('code = "$code"');
      final body = record.getStringValue('template_body').trim();
      if (body.isNotEmpty) {
        return body;
      }
    } catch (_) {}

    return 'Yang bertanda tangan di bawah ini menerangkan bahwa {{nama_warga}} adalah warga RT {{rt}} / RW {{rw}} untuk keperluan {{purpose}}.';
  }

  String _renderTemplate(String body, SuratDetailData detail) {
    final request = detail.request;
    final map = <String, String>{
      'title': request.title,
      'purpose': request.purpose,
      'nama_warga': detail.warga?.namaLengkap ?? 'Warga',
      'nik': detail.warga?.nik ?? '-',
      'rt': '${request.rt ?? 0}',
      'rw': '${request.rw ?? 0}',
      'desa_kelurahan': request.desaKelurahan ?? '-',
      'kecamatan': request.kecamatan ?? '-',
      'kabupaten_kota': request.kabupatenKota ?? '-',
      'provinsi': request.provinsi ?? '-',
    };

    for (final entry in request.requestPayload.entries) {
      map[entry.key] = entry.value?.toString() ?? '';
    }

    var rendered = body;
    for (final entry in map.entries) {
      rendered = rendered.replaceAll('{{${entry.key}}}', entry.value);
    }
    return rendered;
  }

  pw.Widget _buildInfoTable(SuratDetailData detail) {
    final request = detail.request;
    final rows = <List<String>>[
      ['Pemohon', detail.warga?.namaLengkap ?? '-'],
      ['NIK', detail.warga?.nik ?? '-'],
      ['No. KK', detail.kk?.noKk ?? '-'],
      ['Status', AppConstants.suratStatusLabel(request.status)],
      ['Approval', AppConstants.suratApprovalLabel(request.approvalLevel)],
      [
        'Diajukan',
        request.created == null
            ? '-'
            : Formatters.tanggalWaktu(request.created!),
      ],
    ];

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
      columnWidths: const {0: pw.FlexColumnWidth(2), 1: pw.FlexColumnWidth(5)},
      children: rows
          .map(
            (row) => pw.TableRow(
              children: row
                  .map(
                    (cell) => pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text(
                        cell,
                        style: const pw.TextStyle(fontSize: 10),
                      ),
                    ),
                  )
                  .toList(),
            ),
          )
          .toList(),
    );
  }

  pw.Widget _buildPayloadTable(SuratDetailData detail) {
    final config = AppConstants.suratTypeOption(detail.request.jenisSurat);
    final rows = <List<String>>[
      ['Keperluan', detail.request.purpose],
    ];

    for (final field in config.fields) {
      rows.add([
        field.label,
        detail.request.requestPayload[field.key]?.toString() ?? '-',
      ]);
    }

    return pw.Table(
      border: pw.TableBorder.all(color: PdfColors.grey300, width: 0.5),
      columnWidths: const {0: pw.FlexColumnWidth(2), 1: pw.FlexColumnWidth(5)},
      children: rows
          .map(
            (row) => pw.TableRow(
              children: row
                  .map(
                    (cell) => pw.Padding(
                      padding: const pw.EdgeInsets.all(8),
                      child: pw.Text(
                        cell,
                        style: const pw.TextStyle(fontSize: 10),
                      ),
                    ),
                  )
                  .toList(),
            ),
          )
          .toList(),
    );
  }

  String _signerLabel(SuratDetailData detail) {
    if (detail.request.requiresRwApproval) {
      return 'Mengetahui,\nPengurus RW';
    }
    return 'Mengetahui,\nPengurus RT';
  }

  String _pdfFilename(SuratDetailData detail) {
    final code = detail.request.jenisSurat;
    final slug =
        detail.warga?.namaLengkap
            .trim()
            .toLowerCase()
            .replaceAll(RegExp(r'[^a-z0-9]+'), '_')
            .replaceAll(RegExp(r'_+'), '_') ??
        'warga';
    return '$code-$slug.pdf';
  }
}

final suratPdfServiceProvider = Provider<SuratPdfService>(
  (ref) => SuratPdfService(),
);
