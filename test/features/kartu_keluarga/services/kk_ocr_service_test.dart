import 'package:flutter_test/flutter_test.dart';

import 'package:rukunwarga19/features/kartu_keluarga/services/kk_ocr_service.dart';

void main() {
  group('KkOcrService.parseKkDataFromText', () {
    test('infers gender, birth date, and child relationship from NIK', () {
      final service = KkOcrService();
      final rawText = [
        'NAMA KEPALA KELUARGA MUHAMMAD FAJAR',
        'NO KK 3217060101010001',
        'ALAMAT JL MAWAR 1',
        'RT/RW 001/002',
        'DESA/KELURAHAN CIBEUREUM',
        'KECAMATAN CIMAHI SELATAN',
        'KABUPATEN/KOTA CIMAHI',
        'PROVINSI JAWA BARAT',
        '__KK_MEMBER_STRUCT__',
        _row([
          'MUHAMMAD FAJAR',
          '3217060505050008',
          '',
          'BANDUNG',
          '',
          'ISLAM',
          'SLTA/SEDERAJAT',
          'KARYAWAN SWASTA',
          'O',
        ]),
        _row([
          'LAHADIZA JHAN RANIA',
          '3277035808230002',
          '',
          '',
          '',
          '',
          '',
          '',
          '',
        ]),
      ].join('\n');

      final parsed = service.parseKkDataFromText(rawText);

      expect(parsed.members, hasLength(2));
      expect(parsed.members[0].hubungan, 'Ayah');
      expect(parsed.members[1].jenisKelamin, 'Perempuan');
      expect(parsed.members[1].tanggalLahir, '18-08-2023');
      expect(parsed.members[1].hubungan, 'Anak');
    });

    test('infers spouse role for second adult member with opposite gender', () {
      final service = KkOcrService();
      final rawText = [
        'NAMA KEPALA KELUARGA SITI AMINAH',
        'NO KK 3217060101010002',
        'ALAMAT JL KENANGA 2',
        '__KK_MEMBER_STRUCT__',
        _row([
          'SITI AMINAH',
          '3217066305900001',
          '',
          '',
          '',
          'ISLAM',
          '',
          '',
          '',
        ]),
        _row([
          'AHMAD RIZAL',
          '3217061201880002',
          '',
          '',
          '',
          'ISLAM',
          '',
          '',
          '',
        ]),
      ].join('\n');

      final parsed = service.parseKkDataFromText(rawText);

      expect(parsed.members, hasLength(2));
      expect(parsed.members[0].jenisKelamin, 'Perempuan');
      expect(parsed.members[0].hubungan, 'Ibu');
      expect(parsed.members[1].jenisKelamin, 'Laki-laki');
      expect(parsed.members[1].hubungan, 'Ayah');
    });

    test('prefers cleaner head name from header when row name is noisier', () {
      final service = KkOcrService();
      final rawText = [
        'NAMA KEPALA KELUARGA MUHAMMAD FAJAR',
        'NO KK 3217060101010003',
        'ALAMAT JL MELATI 3',
        '__KK_MEMBER_STRUCT__',
        _row([
          'MUHAMMAD FAAAJARRRR',
          '3217060505050008',
          '',
          '',
          '',
          'ISLAM',
          '',
          '',
          '',
        ]),
      ].join('\n');

      final parsed = service.parseKkDataFromText(rawText);

      expect(parsed.members, hasLength(1));
      expect(parsed.members.first.nama, 'Muhammad Fajar');
      expect(parsed.members.first.hubungan, 'Ayah');
    });

    test(
      'inserts head member from header when row members miss kepala keluarga',
      () {
        final service = KkOcrService();
        final rawText = [
          'NAMA KEPALA KELUARGA AZIS FARDIANSYAH',
          'NO KK 3277030903210004',
          'ALAMAT JL CIHANJUANG KP BABUT TENGAH GG SIRNA GALIH',
          '__KK_MEMBER_STRUCT__',
          _row([
            'JARINI ALFIANI',
            '3217056505050008',
            '',
            'BANDUNG',
            '',
            '',
            '',
            '',
            'TIDAK TAHU',
          ]),
          _row([
            'LAHADIZA JHAN RANIA',
            '3277035808230002',
            '',
            'AAN ASA',
            '',
            '',
            '',
            '',
            '',
          ]),
        ].join('\n');

        final parsed = service.parseKkDataFromText(rawText);

        expect(parsed.members, hasLength(3));
        expect(parsed.members.first.nama, 'Azis Fardiansyah');
        expect(parsed.members.first.hubungan, 'Ayah');
        expect(parsed.members.first.jenisKelamin, 'Laki-laki');
        expect(parsed.members[1].nama, 'Jarini Alfiani');
        expect(parsed.members[1].hubungan, 'Ibu');
        expect(parsed.members[2].nama, 'Lahadiza Jhan Rania');
        expect(parsed.members[2].tempatLahir, isEmpty);
      },
    );

    test('merges structured rows with member-table rows and reorders head first', () {
      final service = KkOcrService();
      final rawText = [
        'NAMA KEPALA KELUARGA AZIS FARDIANSYAH',
        'NO KK 3277030903210004',
        'ALAMAT JL CIHANJUANG KP BABUT TENGAH GG SIRNA GALIH',
        '__KK_MEMBER_STRUCT__',
        _row([
          'JARINI ALFIANI',
          '3217056505050008',
          '',
          'BANDUNG',
          '',
          '',
          '',
          '',
          'TIDAK TAHU',
        ]),
        _row([
          'LAHADIZA JHAN RANIA',
          '3277035808230002',
          '',
          '',
          '',
          '',
          '',
          '',
          '',
        ]),
        '__KK_MEMBER_TABLE__',
        '1 AZIS FARDIANSYAH 3277032209880009 LAKI-LAKI CIMAHI 22-09-1988 ISLAM AKADEMI/DIPLOMA III/SARJANA MUDA WIRASWASTA A',
        '2 ARINI ALFIANI 3217056505950008 PEREMPUAN BANDUNG 25-05-1995 ISLAM SLTA/SEDERAJAT KARYAWAN SWASTA TIDAK TAHU',
        '3 MUHAMMAD SINA AL KAUTSAR 3277031803210004 LAKI-LAKI BANDUNG BARAT 18-03-2021 ISLAM TIDAK/BELUM SEKOLAH BELUM/TIDAK BEKERJA TIDAK TAHU',
        '4 HADIZA JIHAN RANIA 3277035808230002 PEREMPUAN CIMAHI 18-08-2023 ISLAM TIDAK/BELUM SEKOLAH BELUM/TIDAK BEKERJA TIDAK TAHU',
      ].join('\n');

      final parsed = service.parseKkDataFromText(rawText);

      expect(parsed.members, hasLength(4));
      expect(parsed.members.first.nama, 'Azis Fardiansyah');
      expect(parsed.members.first.nik, '3277032209880009');
      expect(parsed.members.first.hubungan, 'Ayah');
      expect(parsed.members[1].nama, 'Arini Alfiani');
      expect(parsed.members[1].nik, '3217056505950008');
      expect(parsed.members[1].hubungan, 'Ibu');
      expect(parsed.members[2].nama, 'Muhammad Sina Al Kautsar');
      expect(parsed.members[2].hubungan, 'Anak');
      expect(parsed.members[3].nama, 'Hadiza Jihan Rania');
      expect(parsed.members[3].tempatLahir, 'Cimahi');
    });

    test(
      'ignores fake structured nik rows and keeps compact-date member rows separated',
      () {
        final service = KkOcrService();
        final rawText = [
          'NAMA KEPALA KELUARGA AZIS FARDIANSYAH',
          'NO KK 3277030903210004',
          'ALAMAT JL CIHANJUANG KP BABUT TENGAH GG SIRNA GALIH',
          '__KK_MEMBER_STRUCT__',
          _row(['', '2768301501351471', '', '', '', '', '', '', '']),
          _row(['', '1347142502871842', '', '', '', '', '', '', '']),
          _row([
            'JARINI ALFIANI',
            '3217056505050008',
            '',
            'BANDUNG',
            '',
            '',
            '',
            '',
            'TIDAK TAHU',
          ]),
          _row([
            'LAHADIZA JHAN RANIA',
            '3277035808230002',
            '',
            '',
            '',
            '',
            '',
            '',
            '',
          ]),
          '__KK_MEMBER_TABLE__',
          '1 JAAIS FARDIANSYAH 3277032209880009 LAKH AW JOMAH 22091988 ISLAM AKADEMI/DIPLOMA III/SARJANA MUDA WIRASWASTA A',
          '2 ARINI ALFIANI 3217056505950008 PEREMPUAN BANDUNG 25051995 ISLAM SLTA/SEDERAJAT KARYAWAN SWASTA TIDAK TAHU',
          '3 MUHAMMAD SINA AL KAUTSAR 3277031803210004 LAKI-LAKI RANDUNG BARAT 18032021 ISLAM TIDAK/BELUM SEKOLAH BELUM/TIDAK BEKERJA TIDAK TAHU',
          '4 HADIZA JIHAN RANIA 3277035808230002 PERBUPUAN CMAAH 18082023 ISLAM TIDAK/BELUM SEKOLAH BELUM/TIDAK BEKERJA TIDAK TAHU',
        ].join('\n');

        final parsed = service.parseKkDataFromText(rawText);

        expect(parsed.members, hasLength(4));
        expect(
          parsed.members.map((member) => member.nama),
          isNot(contains('(Nama tidak terbaca)')),
        );
        expect(parsed.members[0].nama, 'Azis Fardiansyah');
        expect(parsed.members[0].nik, '3277032209880009');
        expect(parsed.members[0].tanggalLahir, '22-09-1988');
        expect(parsed.members[1].nama, 'Arini Alfiani');
        expect(parsed.members[1].hubungan, 'Ibu');
        expect(parsed.members[2].nama, 'Muhammad Sina Al Kautsar');
        expect(parsed.members[2].tempatLahir, 'Bandung Barat');
        expect(parsed.members[2].tanggalLahir, '18-03-2021');
        expect(parsed.members[3].nama, 'Hadiza Jihan Rania');
        expect(parsed.members[3].tempatLahir, 'Cimahi');
      },
    );
  });
}

String _row(List<String> values) => 'ROW|${values.join('|')}';
