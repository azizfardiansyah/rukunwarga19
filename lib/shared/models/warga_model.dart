import 'package:pocketbase/pocketbase.dart';

class WargaModel {
  final String id;
  final String nik;
  final String namaLengkap;
  final String tempatLahir;
  final DateTime? tanggalLahir;
  final String jenisKelamin;
  final String agama;
  final String statusPernikahan;
  final String pekerjaan;
  final String alamat;
  final String rt;
  final String rw;
  final String? kelurahan;
  final String? kecamatan;
  final String? kota;
  final String noHp;
  final String? email;
  final String? userId; // relasi ke users collection
  final String? foto;
  final DateTime? created;
  final DateTime? updated;

  WargaModel({
    required this.id,
    required this.nik,
    required this.namaLengkap,
    required this.tempatLahir,
    this.tanggalLahir,
    required this.jenisKelamin,
    required this.agama,
    required this.statusPernikahan,
    required this.pekerjaan,
    required this.alamat,
    required this.rt,
    required this.rw,
    this.kelurahan,
    this.kecamatan,
    this.kota,
    required this.noHp,
    this.email,
    this.userId,
    this.foto,
    this.created,
    this.updated,
  });

  factory WargaModel.fromRecord(RecordModel record) {
    return WargaModel(
      id: record.id,
      nik: record.getStringValue('nik'),
      namaLengkap: record.getStringValue('nama_lengkap'),
      tempatLahir: record.getStringValue('tempat_lahir'),
      tanggalLahir: DateTime.tryParse(record.getStringValue('tanggal_lahir')),
      jenisKelamin: record.getStringValue('jenis_kelamin'),
      agama: record.getStringValue('agama'),
      statusPernikahan: record.getStringValue('status_pernikahan'),
      pekerjaan: record.getStringValue('pekerjaan'),
      alamat: record.getStringValue('alamat'),
      rt: record.getStringValue('rt'),
      rw: record.getStringValue('rw'),
      kelurahan: record.getStringValue('kelurahan'),
      kecamatan: record.getStringValue('kecamatan'),
      kota: record.getStringValue('kota'),
      noHp: record.getStringValue('no_hp'),
      email: record.getStringValue('email'),
      userId: record.getStringValue('user_id'),
      foto: record.getStringValue('foto'),
      created: DateTime.tryParse(record.getStringValue('created')),
      updated: DateTime.tryParse(record.getStringValue('updated')),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'nik': nik,
      'nama_lengkap': namaLengkap,
      'tempat_lahir': tempatLahir,
      'tanggal_lahir': tanggalLahir?.toIso8601String(),
      'jenis_kelamin': jenisKelamin,
      'agama': agama,
      'status_pernikahan': statusPernikahan,
      'pekerjaan': pekerjaan,
      'alamat': alamat,
      'rt': rt,
      'rw': rw,
      'kelurahan': kelurahan,
      'kecamatan': kecamatan,
      'kota': kota,
      'no_hp': noHp,
      'email': email,
      'user_id': userId,
    };
  }
}
