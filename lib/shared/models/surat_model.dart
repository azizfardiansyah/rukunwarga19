import 'package:pocketbase/pocketbase.dart';

class SuratModel {
  final String id;
  final String warga; // relasi ke warga
  final String jenis;
  final String keperluan;
  final String status; // pending, approved, rejected
  final String? catatan;
  final String? catatanAdmin;
  final String? disetujuiOleh; // relasi ke users
  final DateTime? tanggalPersetujuan;
  final String? nomorSurat;
  final DateTime? created;
  final DateTime? updated;

  SuratModel({
    required this.id,
    required this.warga,
    required this.jenis,
    required this.keperluan,
    required this.status,
    this.catatan,
    this.catatanAdmin,
    this.disetujuiOleh,
    this.tanggalPersetujuan,
    this.nomorSurat,
    this.created,
    this.updated,
  });

  factory SuratModel.fromRecord(RecordModel record) {
    return SuratModel(
      id: record.id,
      warga: record.getStringValue('warga'),
      jenis: record.getStringValue('jenis'),
      keperluan: record.getStringValue('keperluan'),
      status: record.getStringValue('status'),
      catatan: record.getStringValue('catatan'),
      catatanAdmin: record.getStringValue('catatan_admin'),
      disetujuiOleh: record.getStringValue('disetujui_oleh'),
      tanggalPersetujuan:
          DateTime.tryParse(record.getStringValue('tanggal_persetujuan')),
      nomorSurat: record.getStringValue('nomor_surat'),
      created: DateTime.tryParse(record.getStringValue('created')),
      updated: DateTime.tryParse(record.getStringValue('updated')),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'warga': warga,
      'jenis': jenis,
      'keperluan': keperluan,
      'status': status,
      'catatan': catatan,
      'catatan_admin': catatanAdmin,
      'disetujui_oleh': disetujuiOleh,
      'tanggal_persetujuan': tanggalPersetujuan?.toIso8601String(),
      'nomor_surat': nomorSurat,
    };
  }

  bool get isPending => status == 'pending';
  bool get isApproved => status == 'approved';
  bool get isRejected => status == 'rejected';
}
