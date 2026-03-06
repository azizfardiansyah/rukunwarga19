class ParsedKkMember {
  ParsedKkMember({
    required this.nama,
    required this.nik,
    required this.hubungan,
    required this.jenisKelamin,
  });

  String nama;
  String nik;
  String hubungan;
  String jenisKelamin;

  ParsedKkMember copyWith({
    String? nama,
    String? nik,
    String? hubungan,
    String? jenisKelamin,
  }) {
    return ParsedKkMember(
      nama: nama ?? this.nama,
      nik: nik ?? this.nik,
      hubungan: hubungan ?? this.hubungan,
      jenisKelamin: jenisKelamin ?? this.jenisKelamin,
    );
  }
}

class ParsedKkData {
  ParsedKkData({
    required this.noKk,
    required this.alamat,
    required this.rt,
    required this.rw,
    required this.members,
  });

  final String noKk;
  final String alamat;
  final String rt;
  final String rw;
  final List<ParsedKkMember> members;
}
