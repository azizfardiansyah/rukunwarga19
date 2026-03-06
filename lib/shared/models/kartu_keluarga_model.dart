import 'package:pocketbase/pocketbase.dart';

class KartuKeluargaModel {
  final String id;
  final String noKk;
  final String kepalaKeluarga; // relasi ke warga
  final String alamat;
  final String rt;
  final String rw;
  final String? desaKelurahan;
  final String? kecamatan;
  final String? kabupatenKota;
  final String? provinsi;
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
    this.desaKelurahan,
    this.kecamatan,
    this.kabupatenKota,
    this.provinsi,
    this.scanKk,
    this.created,
    this.updated,
    this.anggota,
  });

  static String _asString(RecordModel record, String field) {
    final value = record.getStringValue(field);
    if (value.isNotEmpty) return value;
    final raw = record.data[field];
    return raw?.toString() ?? '';
  }

  factory KartuKeluargaModel.fromRecord(RecordModel record) {
    return KartuKeluargaModel(
      id: record.id,
      noKk: _asString(record, 'no_kk'),
      kepalaKeluarga: record.getStringValue('kepala_keluarga'),
      alamat: record.getStringValue('alamat'),
      rt: _asString(record, 'rt'),
      rw: _asString(record, 'rw'),
      desaKelurahan: record.getStringValue('desa_kelurahan').isNotEmpty
          ? record.getStringValue('desa_kelurahan')
          : record.getStringValue('kelurahan'),
      kecamatan: record.getStringValue('kecamatan'),
      kabupatenKota: record.getStringValue('kabupaten_kota').isNotEmpty
          ? record.getStringValue('kabupaten_kota')
          : record.getStringValue('kota'),
      provinsi: record.getStringValue('provinsi'),
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
      'desa_kelurahan': desaKelurahan,
      'kecamatan': kecamatan,
      'kabupaten_kota': kabupatenKota,
      'provinsi': provinsi,
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
      kartuKeluarga: record.getStringValue('no_kk'),
      warga: record.getStringValue('warga'),
      hubungan: record.getStringValue('hubungan'),
      created: DateTime.tryParse(record.getStringValue('created')),
    );
  }

  Map<String, dynamic> toJson() {
    return {'no_kk': kartuKeluarga, 'warga': warga, 'hubungan': hubungan};
  }
}
