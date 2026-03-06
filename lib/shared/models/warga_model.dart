import 'package:pocketbase/pocketbase.dart';

class WargaModel {
  final String id;
  final String noKkId; // relasi ke kartu_keluarga
  final String nik;
  final String namaLengkap;
  final String tempatLahir;
  final DateTime? tanggalLahir;
  final String jenisKelamin;
  final String agama;
  final String statusPernikahan;
  final String pekerjaan;
  final String pendidikan;
  final String golonganDarah;
  final String alamat;
  final String rt;
  final String rw;
  final String noHp;
  final String? email;
  final String? userId; // relasi ke users collection
  final String? fotoKtp;
  final String? fotoWarga;
  final DateTime? created;
  final DateTime? updated;

  WargaModel({
    required this.id,
    required this.noKkId,
    required this.nik,
    required this.namaLengkap,
    required this.tempatLahir,
    this.tanggalLahir,
    required this.jenisKelamin,
    required this.agama,
    required this.statusPernikahan,
    required this.pekerjaan,
    required this.pendidikan,
    required this.golonganDarah,
    required this.alamat,
    required this.rt,
    required this.rw,
    required this.noHp,
    this.email,
    this.userId,
    this.fotoKtp,
    this.fotoWarga,
    this.created,
    this.updated,
  });

  static String _asString(RecordModel record, String field) {
    final fromGetter = record.getStringValue(field);
    if (fromGetter.isNotEmpty) return fromGetter;
    final raw = record.data[field];
    return raw?.toString() ?? '';
  }

  factory WargaModel.fromRecord(RecordModel record) {
    return WargaModel(
      id: record.id,
      noKkId: record.getStringValue('no_kk'),
      nik: record.getStringValue('nik'),
      namaLengkap: record.getStringValue('nama_lengkap'),
      tempatLahir: record.getStringValue('tempat_lahir'),
      tanggalLahir: DateTime.tryParse(record.getStringValue('tanggal_lahir')),
      jenisKelamin: record.getStringValue('jenis_kelamin'),
      agama: record.getStringValue('agama'),
      statusPernikahan: record.getStringValue('status_pernikahan'),
      pekerjaan: record.getStringValue('pekerjaan'),
      pendidikan: record.getStringValue('pendidikan'),
      golonganDarah: record.getStringValue('golongan_darah'),
      alamat: record.getStringValue('alamat'),
      rt: _asString(record, 'rt'),
      rw: _asString(record, 'rw'),
      noHp: _asString(record, 'no_hp'),
      email: record.getStringValue('email'),
      userId: record.getStringValue('user_id'),
      fotoKtp: record.getStringValue('foto_ktp'),
      fotoWarga: record.getStringValue('foto_warga'),
      created: DateTime.tryParse(record.getStringValue('created')),
      updated: DateTime.tryParse(record.getStringValue('updated')),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'no_kk': noKkId,
      'nik': nik,
      'nama_lengkap': namaLengkap,
      'tempat_lahir': tempatLahir,
      'tanggal_lahir': tanggalLahir?.toIso8601String(),
      'jenis_kelamin': jenisKelamin,
      'agama': agama,
      'status_pernikahan': statusPernikahan,
      'pekerjaan': pekerjaan,
      'pendidikan': pendidikan,
      'golongan_darah': golonganDarah,
      'alamat': alamat,
      'rt': rt,
      'rw': rw,
      'no_hp': noHp,
      'email': email,
      'user_id': userId,
    };
  }
}
