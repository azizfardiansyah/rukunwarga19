class ParsedKkMember {
  ParsedKkMember({
    required this.nama,
    required this.nik,
    required this.hubungan,
    required this.jenisKelamin,
    this.tempatLahir = '',
    this.tanggalLahir = '',
    this.agama = '',
    this.pendidikan = '',
    this.jenisPekerjaan = '',
    this.golonganDarah = '',
  });

  String nama;
  String nik;
  String hubungan;
  String jenisKelamin;
  String tempatLahir;
  String tanggalLahir;
  String agama;
  String pendidikan;
  String jenisPekerjaan;
  String golonganDarah;

  ParsedKkMember copyWith({
    String? nama,
    String? nik,
    String? hubungan,
    String? jenisKelamin,
    String? tempatLahir,
    String? tanggalLahir,
    String? agama,
    String? pendidikan,
    String? jenisPekerjaan,
    String? golonganDarah,
  }) {
    return ParsedKkMember(
      nama: nama ?? this.nama,
      nik: nik ?? this.nik,
      hubungan: hubungan ?? this.hubungan,
      jenisKelamin: jenisKelamin ?? this.jenisKelamin,
      tempatLahir: tempatLahir ?? this.tempatLahir,
      tanggalLahir: tanggalLahir ?? this.tanggalLahir,
      agama: agama ?? this.agama,
      pendidikan: pendidikan ?? this.pendidikan,
      jenisPekerjaan: jenisPekerjaan ?? this.jenisPekerjaan,
      golonganDarah: golonganDarah ?? this.golonganDarah,
    );
  }
}

class ParsedKkData {
  ParsedKkData({
    required this.noKk,
    required this.namaKepalaKeluarga,
    required this.alamat,
    required this.rt,
    required this.rw,
    required this.kelurahan,
    required this.kecamatan,
    required this.kabupatenKota,
    required this.provinsi,
    required this.members,
  });

  final String noKk;
  final String namaKepalaKeluarga;
  final String alamat;
  final String rt;
  final String rw;
  final String kelurahan;
  final String kecamatan;
  final String kabupatenKota;
  final String provinsi;
  final List<ParsedKkMember> members;
}
