import 'package:pocketbase/pocketbase.dart';

class JenisIuranModel {
  final String id;
  final String nama;
  final num nominal;
  final String periode; // bulanan, tahunan, insidental
  final String? keterangan;
  final bool aktif;
  final DateTime? created;

  JenisIuranModel({
    required this.id,
    required this.nama,
    required this.nominal,
    required this.periode,
    this.keterangan,
    this.aktif = true,
    this.created,
  });

  factory JenisIuranModel.fromRecord(RecordModel record) {
    return JenisIuranModel(
      id: record.id,
      nama: record.getStringValue('nama'),
      nominal: record.getIntValue('nominal'),
      periode: record.getStringValue('periode'),
      keterangan: record.getStringValue('keterangan'),
      aktif: record.getBoolValue('aktif'),
      created: DateTime.tryParse(record.getStringValue('created')),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'nama': nama,
      'nominal': nominal,
      'periode': periode,
      'keterangan': keterangan,
      'aktif': aktif,
    };
  }
}

class IuranModel {
  final String id;
  final String warga; // relasi ke warga
  final String jenisIuran; // relasi ke jenis_iuran
  final DateTime tanggalBayar;
  final num jumlah;
  final String status; // lunas, belum_bayar, tertunggak
  final String? bulan; // format: 2026-02
  final String? keterangan;
  final String? dicatatOleh; // relasi ke users
  final DateTime? created;
  final DateTime? updated;

  IuranModel({
    required this.id,
    required this.warga,
    required this.jenisIuran,
    required this.tanggalBayar,
    required this.jumlah,
    required this.status,
    this.bulan,
    this.keterangan,
    this.dicatatOleh,
    this.created,
    this.updated,
  });

  factory IuranModel.fromRecord(RecordModel record) {
    return IuranModel(
      id: record.id,
      warga: record.getStringValue('warga'),
      jenisIuran: record.getStringValue('jenis_iuran'),
      tanggalBayar:
          DateTime.tryParse(record.getStringValue('tanggal_bayar')) ??
              DateTime.now(),
      jumlah: record.getIntValue('jumlah'),
      status: record.getStringValue('status'),
      bulan: record.getStringValue('bulan'),
      keterangan: record.getStringValue('keterangan'),
      dicatatOleh: record.getStringValue('dicatat_oleh'),
      created: DateTime.tryParse(record.getStringValue('created')),
      updated: DateTime.tryParse(record.getStringValue('updated')),
    );
  }

  Map<String, dynamic> toJson() {
    return {
      'warga': warga,
      'jenis_iuran': jenisIuran,
      'tanggal_bayar': tanggalBayar.toIso8601String(),
      'jumlah': jumlah,
      'status': status,
      'bulan': bulan,
      'keterangan': keterangan,
      'dicatat_oleh': dicatatOleh,
    };
  }

  bool get isLunas => status == 'lunas';
  bool get isTertunggak => status == 'tertunggak';
}
