import 'package:pocketbase/pocketbase.dart';

class DokumenModel {
  final String id;
  final String warga; // relasi ke warga
  final String jenis;
  final String file; // filename
  final String statusVerifikasi; // pending, verified, need_revision, rejected
  final String? catatan;
  final String? diverifikasiOleh; // relasi ke users
  final DateTime? tanggalVerifikasi;
  final DateTime? created;
  final DateTime? updated;

  DokumenModel({
    required this.id,
    required this.warga,
    required this.jenis,
    required this.file,
    required this.statusVerifikasi,
    this.catatan,
    this.diverifikasiOleh,
    this.tanggalVerifikasi,
    this.created,
    this.updated,
  });

  factory DokumenModel.fromRecord(RecordModel record) {
    return DokumenModel(
      id: record.id,
      warga: record.getStringValue('warga'),
      jenis: record.getStringValue('jenis'),
      file: record.getStringValue('file'),
      statusVerifikasi: record.getStringValue('status_verifikasi'),
      catatan: record.getStringValue('catatan'),
      diverifikasiOleh: record.getStringValue('diverifikasi_oleh'),
      tanggalVerifikasi: DateTime.tryParse(
        record.getStringValue('tanggal_verifikasi'),
      ),
      created: DateTime.tryParse(record.getStringValue('created')),
      updated: DateTime.tryParse(record.getStringValue('updated')),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'warga': warga,
      'jenis': jenis,
      'status_verifikasi': statusVerifikasi,
      'catatan': catatan,
      'diverifikasi_oleh': diverifikasiOleh,
      'tanggal_verifikasi': tanggalVerifikasi?.toIso8601String(),
    };
  }

  bool get isPending => statusVerifikasi == 'pending';
  bool get isVerified => statusVerifikasi == 'verified';
  bool get isNeedRevision => statusVerifikasi == 'need_revision';
  bool get isRejected => statusVerifikasi == 'rejected';
}
