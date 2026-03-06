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
    final namaKepalaKeluarga = _extractNamaKepalaKeluarga(lines);
    final alamat = _extractAlamat(lines);
    final rtRw = _extractRtRw(lines);
    final kelurahan = _extractKelurahan(lines);
    final kecamatan = _extractKecamatan(lines);
    final kabupatenKota = _extractKabupatenKota(lines);
    final provinsi = _extractProvinsi(lines);

    return ParsedKkData(
      noKk: noKk,
      namaKepalaKeluarga: _toTitleCase(namaKepalaKeluarga),
      alamat: _toTitleCase(alamat),
      rt: rtRw.$1,
      rw: rtRw.$2,
      kelurahan: _toTitleCase(kelurahan),
      kecamatan: _toTitleCase(kecamatan),
      kabupatenKota: _toTitleCase(kabupatenKota),
      provinsi: _toTitleCase(provinsi),
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
      if (!_looksLikeNoKkLine(upper)) continue;

      final candidate = _extract16DigitsWithOcrCorrection(upper);
      if (candidate != null) return candidate;

      final afterNo = _sliceAfterNoKkKeyword(upper);
      final afterCandidate = _extract16DigitsWithOcrCorrection(afterNo);
      if (afterCandidate != null) return afterCandidate;
    }

    final rawUpper = rawText.toUpperCase();
    final nearKeyword = RegExp(
      r'NO[^A-Z0-9]{0,8}(KK|KARTU KELUARGA)?[^A-Z0-9]{0,12}([A-Z0-9\s]{16,32})',
    ).allMatches(rawUpper);
    for (final match in nearKeyword) {
      final group = match.group(2) ?? '';
      final candidate = _extract16DigitsWithOcrCorrection(group);
      if (candidate != null) return candidate;
    }

    final fallback = _extract16DigitsWithOcrCorrection(rawUpper);
    return fallback ?? '';
  }

  String _extractAlamat(List<String> lines) {
    final alamatBoundaries = <RegExp>[
      RegExp(r'\bRT\s*[/\-]?\s*RW\b'),
      RegExp(r'\bDESA\s*/?\s*KELURAHAN\b'),
      RegExp(r'\bKELURAHAN\b'),
      RegExp(r'\bKECAMATAN\b'),
      RegExp(r'\bKABUPATEN\s*/?\s*KOTA\b'),
      RegExp(r'\bKAB\s*/?\s*KOTA\b'),
      RegExp(r'\bPROVINSI\b'),
      RegExp(r'\bKODE\s+POS\b'),
    ];

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (!line.contains('ALAMAT')) continue;

      final inline = _cleanupHeaderValue(
        _truncateAtBoundary(
          line.replaceFirst('ALAMAT', '').trim(),
          boundaryPatterns: alamatBoundaries,
        ),
      );
      final normalizedInline = _normalizeAlamatCandidate(inline);
      if (_isMeaningfulHeaderValue(normalizedInline)) {
        return normalizedInline;
      }

      final maxIndex = (i + 3 < lines.length) ? i + 3 : lines.length - 1;
      final addressParts = <String>[];
      for (var j = i + 1; j <= maxIndex; j++) {
        final nextLine = lines[j].trim();
        if (nextLine.isEmpty) continue;
        final chopped = _truncateAtBoundary(
          nextLine,
          boundaryPatterns: alamatBoundaries,
        );
        final cleaned = _cleanupHeaderValue(chopped);
        if (_isMeaningfulHeaderValue(cleaned)) {
          addressParts.add(cleaned);
        }
        if (_containsKnownHeaderLabel(nextLine)) {
          break;
        }
      }
      if (addressParts.isNotEmpty) {
        return _normalizeAlamatCandidate(addressParts.join(' '));
      }
    }

    final flattened = lines.join(' ');
    final flattenedMatch = RegExp(
      r'ALAMAT\s+(.+?)(?:RT\s*[/\-]?\s*RW|DESA\s*/?\s*KELURAHAN|KELURAHAN|KECAMATAN|KABUPATEN\s*/?\s*KOTA|KAB\s*/?\s*KOTA|PROVINSI|KODE\s+POS|$)',
    ).firstMatch(flattened);
    if (flattenedMatch != null) {
      final candidate = _normalizeAlamatCandidate(
        _cleanupHeaderValue(flattenedMatch.group(1) ?? ''),
      );
      if (_isMeaningfulHeaderValue(candidate)) {
        return candidate;
      }
    }

    return '';
  }

  String _extractNamaKepalaKeluarga(List<String> lines) {
    return _extractHeaderValue(
      lines,
      patterns: [RegExp(r'NAMA\s+KEPALA\s+KELUARGA')],
      lookAhead: 2,
      boundaryPatterns: [
        RegExp(r'\bNO\b'),
        RegExp(r'\bALAMAT\b'),
        RegExp(r'\bDESA\s*/?\s*KELURAHAN\b'),
        RegExp(r'\bKELURAHAN\b'),
        RegExp(r'\bKECAMATAN\b'),
        RegExp(r'\bKABUPATEN\s*/?\s*KOTA\b'),
        RegExp(r'\bKAB\s*/?\s*KOTA\b'),
        RegExp(r'\bPROVINSI\b'),
      ],
    );
  }

  String _extractKelurahan(List<String> lines) {
    return _extractHeaderValue(
      lines,
      patterns: [RegExp(r'DESA\s*/?\s*KELURAHAN'), RegExp(r'KELURAHAN')],
      lookAhead: 2,
      boundaryPatterns: [
        RegExp(r'\bKECAMATAN\b'),
        RegExp(r'\bKABUPATEN\s*/?\s*KOTA\b'),
        RegExp(r'\bKAB\s*/?\s*KOTA\b'),
        RegExp(r'\bPROVINSI\b'),
      ],
    );
  }

  String _extractKecamatan(List<String> lines) {
    return _extractHeaderValue(
      lines,
      patterns: [RegExp(r'KECAMATAN')],
      lookAhead: 2,
      boundaryPatterns: [
        RegExp(r'\bKABUPATEN\s*/?\s*KOTA\b'),
        RegExp(r'\bKAB\s*/?\s*KOTA\b'),
        RegExp(r'\bPROVINSI\b'),
      ],
    );
  }

  String _extractKabupatenKota(List<String> lines) {
    return _extractHeaderValue(
      lines,
      patterns: [RegExp(r'KABUPATEN\s*/?\s*KOTA'), RegExp(r'KAB\s*/?\s*KOTA')],
      lookAhead: 2,
      boundaryPatterns: [RegExp(r'\bPROVINSI\b')],
    );
  }

  String _extractProvinsi(List<String> lines) {
    return _extractHeaderValue(
      lines,
      patterns: [RegExp(r'PROVINSI')],
      lookAhead: 2,
    );
  }

  String _extractHeaderValue(
    List<String> lines, {
    required List<RegExp> patterns,
    int lookAhead = 1,
    List<RegExp> boundaryPatterns = const [],
  }) {
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];

      for (final pattern in patterns) {
        final match = pattern.firstMatch(line);
        if (match == null) continue;

        final inlineValue = _cleanupHeaderValue(
          _truncateAtBoundary(
            line.substring(match.end).trim(),
            boundaryPatterns: boundaryPatterns,
          ),
        );
        if (_isMeaningfulHeaderValue(inlineValue)) {
          return inlineValue;
        }

        final maxIndex = (i + lookAhead < lines.length)
            ? i + lookAhead
            : lines.length - 1;
        for (var j = i + 1; j <= maxIndex; j++) {
          final rawNextLine = lines[j].trim();
          final belongsToAnotherHeader =
              _containsKnownHeaderLabel(rawNextLine) &&
              !patterns.any((pattern) => pattern.hasMatch(rawNextLine));
          if (belongsToAnotherHeader) {
            break;
          }

          final nextLine = _cleanupHeaderValue(
            _truncateAtBoundary(
              rawNextLine,
              boundaryPatterns: boundaryPatterns,
            ),
          );
          if (_isMeaningfulHeaderValue(nextLine)) {
            return nextLine;
          }
        }
      }
    }

    return '';
  }

  String _cleanupHeaderValue(String input) {
    var cleaned = input
        .replaceAll(
          RegExp(
            r'^(NAMA\s+KEPALA\s+KELUARGA|ALAMAT|DESA\s*/?\s*KELURAHAN|KELURAHAN|KECAMATAN|KABUPATEN\s*/?\s*KOTA|KAB\s*/?\s*KOTA|PROVINSI)\s*',
          ),
          '',
        )
        .replaceAll(RegExp(r'^[\-\.:]+'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (cleaned == '-' || cleaned == '.' || cleaned == ':') {
      return '';
    }
    return cleaned;
  }

  bool _isMeaningfulHeaderValue(String value) {
    if (value.isEmpty || value.length < 2) return false;
    const labelsOnly = {
      'NAMA',
      'KEPALA',
      'KELUARGA',
      'ALAMAT',
      'DESA',
      'KELURAHAN',
      'KECAMATAN',
      'KABUPATEN',
      'KOTA',
      'PROVINSI',
    };
    if (labelsOnly.contains(value)) return false;
    return RegExp(r'[A-Z0-9]').hasMatch(value);
  }

  bool _containsKnownHeaderLabel(String input) {
    final upper = input.toUpperCase();
    return upper.contains('NAMA KEPALA KELUARGA') ||
        upper.contains('NO KK') ||
        upper.contains('NOMOR KK') ||
        upper.contains('ALAMAT') ||
        upper.contains('DESA') ||
        upper.contains('KELURAHAN') ||
        upper.contains('KECAMATAN') ||
        upper.contains('KABUPATEN') ||
        upper.contains('KOTA') ||
        upper.contains('PROVINSI');
  }

  bool _looksLikeNoKkLine(String line) {
    final upper = line.toUpperCase();
    return upper.contains('NO') &&
        (upper.contains('KK') || upper.contains('KARTU KELUARGA'));
  }

  String _sliceAfterNoKkKeyword(String line) {
    final upper = line.toUpperCase();
    final keywordMatch = RegExp(
      r'(NO\s*\.?\s*(KK|KARTU KELUARGA)?)',
    ).firstMatch(upper);
    if (keywordMatch == null) return upper;
    return upper.substring(keywordMatch.end).trim();
  }

  String? _extract16DigitsWithOcrCorrection(String source) {
    final normalized = _normalizeOcrDigits(source);

    final exact16 = RegExp(r'([0-9](?:\s*[0-9]){15})').allMatches(normalized);
    for (final match in exact16) {
      final digits = match.group(0)!.replaceAll(RegExp(r'\s+'), '');
      if (digits.length == 16) return digits;
    }

    final loose = RegExp(r'([0-9][0-9\s]{12,30})').allMatches(normalized);
    for (final match in loose) {
      final digits = match.group(0)!.replaceAll(RegExp(r'[^0-9]'), '');
      if (digits.length == 16) return digits;
      if (digits.length > 16) {
        return digits.substring(0, 16);
      }
    }

    return null;
  }

  String _normalizeOcrDigits(String input) {
    final upper = input.toUpperCase();
    final buf = StringBuffer();
    for (final ch in upper.split('')) {
      switch (ch) {
        case 'O':
        case 'Q':
        case 'D':
          buf.write('0');
          break;
        case 'I':
        case 'L':
          buf.write('1');
          break;
        case 'Z':
          buf.write('2');
          break;
        case 'S':
          buf.write('5');
          break;
        case 'G':
          buf.write('6');
          break;
        case 'B':
          buf.write('8');
          break;
        default:
          buf.write(ch);
      }
    }
    return buf.toString();
  }

  String _truncateAtBoundary(
    String input, {
    required List<RegExp> boundaryPatterns,
  }) {
    if (input.isEmpty || boundaryPatterns.isEmpty) return input;

    var cutIndex = input.length;
    for (final pattern in boundaryPatterns) {
      final match = pattern.firstMatch(input);
      if (match == null) continue;
      if (match.start < cutIndex) {
        cutIndex = match.start;
      }
    }
    if (cutIndex < input.length) {
      return input.substring(0, cutIndex).trim();
    }
    return input.trim();
  }

  String _normalizeAlamatCandidate(String input) {
    final value = input.replaceAll(RegExp(r'\s+'), ' ').trim();
    if (value.isEmpty) return value;

    final tokens = value
        .split(' ')
        .map(_normalizeAlamatToken)
        .where((token) => token.isNotEmpty)
        .toList();
    if (tokens.isEmpty) return '';

    const anchorTokens = {
      'JL',
      'JLN',
      'JALAN',
      'KP',
      'KAMPUNG',
      'GG',
      'GANG',
      'DS',
      'DESA',
      'PERUM',
      'BLOK',
    };
    final anchorIndex = tokens.indexWhere(anchorTokens.contains);
    final normalized = anchorIndex >= 0
        ? tokens.sublist(anchorIndex).toList()
        : tokens;

    while (normalized.isNotEmpty) {
      final alpha = normalized.first.replaceAll(RegExp(r'[^A-Z]'), '');
      if (alpha.isEmpty) {
        normalized.removeAt(0);
        continue;
      }
      if (anchorTokens.contains(alpha)) {
        break;
      }
      if (alpha.length <= 2) {
        normalized.removeAt(0);
        continue;
      }
      break;
    }

    return normalized.join(' ').trim();
  }

  String _normalizeAlamatToken(String rawToken) {
    var token = rawToken.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
    if (token.isEmpty) return '';

    if (token == 'JI' || token == 'J1' || token == 'JL1') {
      token = 'JL';
    }
    if (token == 'GGG') {
      token = 'GG';
    }

    return token;
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
