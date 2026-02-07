import 'package:pocketbase/pocketbase.dart';

class KartuKeluargaModel {
  final String id;
  final String noKk;
  final String kepalaKeluarga; // relasi ke warga
  final String alamat;
  final String rt;
  final String rw;
  final String? kelurahan;
  final String? kecamatan;
  final String? kota;
  final String? scanKk; // file upload
  final DateTime? created;
  final DateTime? updated;

  // Expand data
  final List<AnggotaKkModel>? anggota;

  KartuKeluargaModel({
    required this.id,
    required this.noKk,
    required this.kepalaKeluarga,
    required this.alamat,
    required this.rt,
    required this.rw,
    this.kelurahan,
    this.kecamatan,
    this.kota,
    this.scanKk,
    this.created,
    this.updated,
    this.anggota,
  });

  factory KartuKeluargaModel.fromRecord(RecordModel record) {
    return KartuKeluargaModel(
      id: record.id,
      noKk: record.getStringValue('no_kk'),
      kepalaKeluarga: record.getStringValue('kepala_keluarga'),
      alamat: record.getStringValue('alamat'),
      rt: record.getStringValue('rt'),
      rw: record.getStringValue('rw'),
      kelurahan: record.getStringValue('kelurahan'),
      kecamatan: record.getStringValue('kecamatan'),
      kota: record.getStringValue('kota'),
      scanKk: record.getStringValue('scan_kk'),
      created: DateTime.tryParse(record.getStringValue('created')),
      updated: DateTime.tryParse(record.getStringValue('updated')),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'no_kk': noKk,
      'kepala_keluarga': kepalaKeluarga,
      'alamat': alamat,
      'rt': rt,
      'rw': rw,
      'kelurahan': kelurahan,
      'kecamatan': kecamatan,
      'kota': kota,
    };
  }
}

class AnggotaKkModel {
  final String id;
  final String kartuKeluarga; // relasi ke kartu_keluarga
  final String warga; // relasi ke warga
  final String hubungan;
  final DateTime? created;

  AnggotaKkModel({
    required this.id,
    required this.kartuKeluarga,
    required this.warga,
    required this.hubungan,
    this.created,
  });

  factory AnggotaKkModel.fromRecord(RecordModel record) {
    return AnggotaKkModel(
      id: record.id,
      kartuKeluarga: record.getStringValue('kartu_keluarga'),
      warga: record.getStringValue('warga'),
      hubungan: record.getStringValue('hubungan'),
      created: DateTime.tryParse(record.getStringValue('created')),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'kartu_keluarga': kartuKeluarga,
      'warga': warga,
      'hubungan': hubungan,
    };
  }
}
