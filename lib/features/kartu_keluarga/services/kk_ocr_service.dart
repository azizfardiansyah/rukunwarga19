import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';

import '../models/parsed_kk_member.dart';

class KkOcrService {
  Future<ParsedKkData> parseKkDataFromImage(String imagePath) async {
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final result = await recognizer.processImage(inputImage);
      return parseKkDataFromText(result.text);
    } finally {
      await recognizer.close();
    }
  }

  ParsedKkData parseKkDataFromText(String rawText) {
    final lines = rawText
        .split('\n')
        .map(_normalizeLine)
        .where((line) => line.isNotEmpty)
        .toList();

    final members = _parseMembers(lines);
    final noKk = _extractNoKk(lines, rawText);
    final alamat = _extractAlamat(lines);
    final rtRw = _extractRtRw(lines);

    return ParsedKkData(
      noKk: noKk,
      alamat: _toTitleCase(alamat),
      rt: rtRw.$1,
      rw: rtRw.$2,
      members: members,
    );
  }

  List<ParsedKkMember> _parseMembers(List<String> lines) {
    final members = <ParsedKkMember>[];
    final seenNik = <String>{};

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      final nik = _extractNik(line);
      if (nik == null || seenNik.contains(nik)) {
        continue;
      }

      final nama = _extractName(line, lines, i);
      final hubungan = _extractHubungan(lines, i);
      final jenisKelamin = _extractGender(lines, i);

      if (nama.isEmpty) {
        continue;
      }

      members.add(
        ParsedKkMember(
          nama: nama,
          nik: nik,
          hubungan: hubungan,
          jenisKelamin: jenisKelamin,
        ),
      );
      seenNik.add(nik);
    }

    if (members.isNotEmpty) {
      return members;
    }

    // Fallback parser: beberapa OCR KK menggabungkan tabel menjadi satu baris panjang.
    final flattened = lines.join(' ');
    final nikMatches = RegExp(r'(\d[\d\s]{15,22}\d)').allMatches(flattened);
    for (final match in nikMatches) {
      final nik = match.group(0)?.replaceAll(RegExp(r'[^0-9]'), '');
      if (nik == null || nik.length != 16 || seenNik.contains(nik)) {
        continue;
      }

      final start = match.start - 80;
      final safeStart = start < 0 ? 0 : start;
      final snippet = flattened.substring(safeStart, match.end);
      final words = snippet
          .split(RegExp(r'\s+'))
          .where((word) => RegExp(r"^[A-Z][A-Z'.-]*$").hasMatch(word))
          .toList();
      final nama = words.length >= 2
          ? '${words[words.length - 2]} ${words.last}'
          : words.join(' ');
      if (nama.isEmpty) {
        continue;
      }
      members.add(
        ParsedKkMember(
          nama: _toTitleCase(nama),
          nik: nik,
          hubungan: 'Anak',
          jenisKelamin: 'Laki-laki',
        ),
      );
      seenNik.add(nik);
    }

    return members;
  }

  String _extractNoKk(List<String> lines, String rawText) {
    for (final line in lines) {
      final upper = line.toUpperCase();
      if ((upper.contains('NO') && upper.contains('KK')) || upper.contains('NOKK')) {
        final match = RegExp(r'(\d[\d\s]{15,22}\d)').firstMatch(upper);
        if (match == null) continue;
        final candidate = match.group(0)!.replaceAll(RegExp(r'[^0-9]'), '');
        if (candidate.length == 16) return candidate;
      }
    }

    final rawUpper = rawText.toUpperCase();
    final nearKeyword = RegExp(r'NO[^A-Z0-9]{0,6}KK[^0-9]{0,12}(\d[\d\s]{15,22}\d)')
        .firstMatch(rawUpper);
    if (nearKeyword != null) {
      final candidate = nearKeyword.group(1)!.replaceAll(RegExp(r'[^0-9]'), '');
      if (candidate.length == 16) return candidate;
    }

    final all16Digits = RegExp(r'(\d[\d\s]{15,22}\d)').allMatches(rawUpper);
    for (final match in all16Digits) {
      final candidate = match.group(0)!.replaceAll(RegExp(r'[^0-9]'), '');
      if (candidate.length == 16) return candidate;
    }

    return '';
  }

  String _extractAlamat(List<String> lines) {
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (!line.contains('ALAMAT')) continue;

      final inline = line.replaceFirst('ALAMAT', '').trim();
      if (inline.isNotEmpty && !_isAddressStopLine(inline)) {
        return inline;
      }

      final maxIndex = (i + 3 < lines.length) ? i + 3 : lines.length - 1;
      for (var j = i + 1; j <= maxIndex; j++) {
        final nextLine = lines[j].trim();
        if (nextLine.isEmpty) continue;
        if (_isAddressStopLine(nextLine)) break;
        return nextLine;
      }
    }

    return '';
  }

  (String, String) _extractRtRw(List<String> lines) {
    final flattened = lines.join(' ');

    final combinedPattern = RegExp(
      r'RT\s*[/\-]?\s*RW\s*[:\s]*([0-9]{1,3})\s*[/\-]\s*([0-9]{1,3})',
    );
    final combinedMatch = combinedPattern.firstMatch(flattened);
    if (combinedMatch != null) {
      return (combinedMatch.group(1)!, combinedMatch.group(2)!);
    }

    final nearPattern = RegExp(
      r'RT\s*[:\s]*([0-9]{1,3})\D{0,10}RW\s*[:\s]*([0-9]{1,3})',
    );
    final nearMatch = nearPattern.firstMatch(flattened);
    if (nearMatch != null) {
      return (nearMatch.group(1)!, nearMatch.group(2)!);
    }

    String rt = '';
    String rw = '';
    for (final line in lines) {
      final rtMatch = RegExp(r'\bRT\b\s*[:\s]*([0-9]{1,3})').firstMatch(line);
      if (rtMatch != null) {
        rt = rtMatch.group(1)!;
      }
      final rwMatch = RegExp(r'\bRW\b\s*[:\s]*([0-9]{1,3})').firstMatch(line);
      if (rwMatch != null) {
        rw = rwMatch.group(1)!;
      }
    }

    return (rt, rw);
  }

  bool _isAddressStopLine(String input) {
    final upper = input.toUpperCase();
    return upper.contains('RT') ||
        upper.contains('RW') ||
        upper.contains('KEL') ||
        upper.contains('KEC') ||
        upper.contains('KAB') ||
        upper.contains('PROVINSI');
  }

  String _normalizeLine(String input) {
    final cleaned = input
        .replaceAll('|', ' ')
        .replaceAll(':', ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim()
        .toUpperCase();
    return cleaned;
  }

  String? _extractNik(String line) {
    final match = RegExp(r'(\d[\d\s]{15,22}\d)').firstMatch(line);
    if (match == null) return null;
    final candidate = match.group(0)!.replaceAll(RegExp(r'[^0-9]'), '');
    if (candidate.length != 16) return null;
    return candidate;
  }

  String _extractName(String line, List<String> lines, int index) {
    final beforeNik = line.split(RegExp(r'\d')).first.trim();
    if (_isLikelyName(beforeNik)) {
      return _toTitleCase(beforeNik);
    }

    for (var j = index - 1; j >= 0 && j >= index - 2; j--) {
      final candidate = lines[j].trim();
      if (_isLikelyName(candidate)) {
        return _toTitleCase(candidate);
      }
    }

    return '';
  }

  String _extractHubungan(List<String> lines, int index) {
    final upperContext = [
      lines[index],
      if (index + 1 < lines.length) lines[index + 1],
      if (index + 2 < lines.length) lines[index + 2],
    ].join(' ');

    if (upperContext.contains('KEPALA')) return 'Kepala Keluarga';
    if (upperContext.contains('ISTRI')) return 'Istri';
    if (upperContext.contains('SUAMI')) return 'Kepala Keluarga';
    if (upperContext.contains('ANAK')) return 'Anak';
    if (upperContext.contains('MENANTU')) return 'Menantu';
    if (upperContext.contains('CUCU')) return 'Cucu';
    if (upperContext.contains('ORANG TUA')) return 'Orang Tua';
    if (upperContext.contains('MERTUA')) return 'Mertua';
    if (upperContext.contains('PEMBANTU')) return 'Pembantu';
    if (upperContext.contains('FAMILI')) return 'Famili Lain';

    return 'Anak';
  }

  String _extractGender(List<String> lines, int index) {
    final upperContext = [
      lines[index],
      if (index + 1 < lines.length) lines[index + 1],
    ].join(' ');

    if (upperContext.contains('PEREMPUAN')) return 'Perempuan';
    if (upperContext.contains('LAKI')) return 'Laki-laki';
    if (upperContext.contains('PR')) return 'Perempuan';
    if (upperContext.contains('LK')) return 'Laki-laki';
    return 'Laki-laki';
  }

  bool _isLikelyName(String input) {
    if (input.isEmpty) return false;
    if (input.length < 3) return false;
    if (RegExp(r'\d').hasMatch(input)) return false;

    const blockedWords = {
      'NAMA',
      'KARTU',
      'KELUARGA',
      'NIK',
      'ALAMAT',
      'RT',
      'RW',
      'PROVINSI',
      'KABUPATEN',
      'KOTA',
      'KECAMATAN',
      'KELURAHAN',
      'AGAMA',
      'STATUS',
      'GOL',
      'DARAH',
    };

    final words = input.split(' ').where((word) => word.isNotEmpty).toList();
    if (words.isEmpty) return false;
    if (words.any((word) => blockedWords.contains(word))) return false;

    return true;
  }

  String _toTitleCase(String input) {
    return input
        .split(' ')
        .where((word) => word.isNotEmpty)
        .map((word) {
          final lower = word.toLowerCase();
          return '${lower[0].toUpperCase()}${lower.substring(1)}';
        })
        .join(' ');
  }
}
