import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:google_mlkit_text_recognition/google_mlkit_text_recognition.dart';
import 'package:image/image.dart' as img;
import 'package:path_provider/path_provider.dart';

import '../models/parsed_kk_member.dart';

class KkOcrService {
  static const String _memberTableMarker = '__KK_MEMBER_TABLE__';
  static const String _memberStructMarker = '__KK_MEMBER_STRUCT__';
  static const String _memberStructPrefix = 'ROW|';

  Future<ParsedKkData> parseKkDataFromImage(String imagePath) async {
    final recognizer = TextRecognizer(script: TextRecognitionScript.latin);
    try {
      final inputImage = InputImage.fromFilePath(imagePath);
      final result = await recognizer.processImage(inputImage);
      var combinedText = result.text;

      try {
        final memberTableText = await _extractMemberTableTextFromImage(
          imagePath,
          recognizer,
        );
        if (memberTableText.trim().isNotEmpty) {
          combinedText = '$combinedText\n$_memberTableMarker\n$memberTableText';
        }
      } catch (_) {
        // Jangan gagalkan proses utama jika OCR crop tabel gagal.
      }

      return parseKkDataFromText(combinedText);
    } finally {
      await recognizer.close();
    }
  }

  ParsedKkData parseKkDataFromText(String rawText) {
    final structIndex = rawText.indexOf(_memberStructMarker);
    final tableIndex = rawText.indexOf(_memberTableMarker);

    final markerPositions = [
      structIndex,
      tableIndex,
    ].where((idx) => idx >= 0).toList()..sort();
    final firstMarkerIndex = markerPositions.isNotEmpty
        ? markerPositions.first
        : -1;

    final headerRaw = firstMarkerIndex >= 0
        ? rawText.substring(0, firstMarkerIndex).trim()
        : rawText;

    String structuredMemberRaw = '';
    if (structIndex >= 0) {
      final start = structIndex + _memberStructMarker.length;
      var end = rawText.length;
      if (tableIndex >= 0 && tableIndex > start) {
        end = tableIndex;
      }
      structuredMemberRaw = rawText.substring(start, end).trim();
    }

    String memberHintRaw = '';
    if (tableIndex >= 0) {
      final start = tableIndex + _memberTableMarker.length;
      var end = rawText.length;
      if (structIndex >= 0 && structIndex > start) {
        end = structIndex;
      }
      memberHintRaw = rawText.substring(start, end).trim();
    }

    if (kDebugMode) {
      debugPrint('[KK OCR] ===== RAW OCR TEXT START =====');
      _debugPrintLong(headerRaw);
      debugPrint('[KK OCR] ===== RAW OCR TEXT END =====');
      if (structuredMemberRaw.isNotEmpty) {
        debugPrint('[KK OCR] ===== MEMBER STRUCT OCR START =====');
        _debugPrintLong(structuredMemberRaw);
        debugPrint('[KK OCR] ===== MEMBER STRUCT OCR END =====');
      }
      if (memberHintRaw.isNotEmpty) {
        debugPrint('[KK OCR] ===== MEMBER TABLE OCR START =====');
        _debugPrintLong(memberHintRaw);
        debugPrint('[KK OCR] ===== MEMBER TABLE OCR END =====');
      }
    }

    final lines = headerRaw
        .split('\n')
        .map(_normalizeLine)
        .where((line) => line.isNotEmpty)
        .toList();

    final noKk = _extractNoKk(lines, headerRaw);
    final structuredLines = structuredMemberRaw
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
    var members = _parseStructuredMembers(structuredLines, noKkHint: noKk);
    if (members.isEmpty) {
      final memberHintLines = memberHintRaw
          .split('\n')
          .map(_normalizeLine)
          .where((line) => line.isNotEmpty)
          .toList();
      members = _parseMembers(
        memberHintLines,
        noKkHint: noKk,
        requireTableHeader: false,
      );
    }
    if (members.isEmpty) {
      members = _parseMembers(lines, noKkHint: noKk);
    }
    final namaKepalaKeluarga = _extractNamaKepalaKeluarga(lines);
    final alamat = _extractAlamat(lines);
    final rtRw = _extractRtRw(lines);
    final kelurahan = _extractKelurahan(lines);
    final kecamatan = _extractKecamatan(lines);
    final kabupatenKota = _extractKabupatenKota(lines);
    final provinsi = _extractProvinsi(lines);

    final parsed = ParsedKkData(
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

    if (kDebugMode) {
      debugPrint(
        '[KK OCR] HEADER => no_kk=${parsed.noKk}, nama_kk=${parsed.namaKepalaKeluarga}, '
        'alamat=${parsed.alamat}, rt=${parsed.rt}, rw=${parsed.rw}, '
        'desa_kel=${parsed.kelurahan}, kec=${parsed.kecamatan}, kab_kota=${parsed.kabupatenKota}, prov=${parsed.provinsi}',
      );
      if (parsed.members.isEmpty) {
        debugPrint('[KK OCR] MEMBER PARSE RESULT => kosong');
      } else {
        for (var i = 0; i < parsed.members.length; i++) {
          final m = parsed.members[i];
          debugPrint(
            '[KK OCR] MEMBER[$i] => nama=${m.nama}, nik=${m.nik}, jk=${m.jenisKelamin}, '
            'tempat=${m.tempatLahir}, tgl=${m.tanggalLahir}, agama=${m.agama}, '
            'pendidikan=${m.pendidikan}, pekerjaan=${m.jenisPekerjaan}, goldar=${m.golonganDarah}, hubungan=${m.hubungan}',
          );
        }
      }
    }

    return parsed;
  }

  List<ParsedKkMember> _parseStructuredMembers(
    List<String> lines, {
    String noKkHint = '',
  }) {
    final members = <ParsedKkMember>[];
    final seenNik = <String>{};

    for (final rawLine in lines) {
      if (!rawLine.startsWith(_memberStructPrefix)) {
        continue;
      }
      final parts = rawLine.split('|');
      if (parts.length < 10) {
        continue;
      }

      final nama = _normalizeStructuredName(parts[1]);
      final nikCandidate =
          _extract16DigitsWithOcrCorrection(parts[2]) ??
          parts[2].replaceAll(RegExp(r'[^0-9]'), '');

      if (nama.isEmpty ||
          nikCandidate.length != 16 ||
          seenNik.contains(nikCandidate)) {
        continue;
      }
      if (!_isLikelyMemberNik(nikCandidate, noKkHint: noKkHint)) {
        continue;
      }

      final jenisKelamin = _normalizeStructuredJenisKelamin(parts[3]);
      final tempatLahir = _toTitleCase(_cleanStructuredField(parts[4]));
      final tanggalLahir = _normalizeTanggalFromToken(
        _cleanStructuredField(parts[5]),
      );
      final agama = _toTitleCase(_normalizeAgama(parts[6]));
      final pendidikan = _toTitleCase(_cleanStructuredField(parts[7]));
      final pekerjaan = _toTitleCase(_cleanStructuredField(parts[8]));
      final golonganDarah = _normalizeGolonganDarah(parts[9]);

      members.add(
        ParsedKkMember(
          nama: nama,
          nik: nikCandidate,
          hubungan: '',
          jenisKelamin: jenisKelamin,
          tempatLahir: tempatLahir,
          tanggalLahir: tanggalLahir,
          agama: agama,
          pendidikan: pendidikan,
          jenisPekerjaan: pekerjaan,
          golonganDarah: golonganDarah,
        ),
      );
      seenNik.add(nikCandidate);
    }

    return members;
  }

  List<ParsedKkMember> _parseMembers(
    List<String> lines, {
    String noKkHint = '',
    bool requireTableHeader = true,
  }) {
    final members = <ParsedKkMember>[];
    final seenNik = <String>{};
    var inMemberTable = !requireTableHeader;

    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];

      if (!inMemberTable && _looksLikeMemberTableHeader(line)) {
        inMemberTable = true;
        continue;
      }
      if (inMemberTable && _isMemberTableEnd(line)) {
        break;
      }
      if (!inMemberTable) {
        continue;
      }

      final nik = _extractNik(line);
      if (nik == null || seenNik.contains(nik)) {
        continue;
      }
      if (!_isLikelyMemberNik(nik, noKkHint: noKkHint)) {
        continue;
      }

      var detailSource = line;
      if (!_containsDateToken(line) &&
          i + 1 < lines.length &&
          !_looksLikeMemberTableHeader(lines[i + 1]) &&
          !_isMemberTableEnd(lines[i + 1])) {
        detailSource = '$line ${lines[i + 1]}';
      }

      final detail = _extractMemberDetailFromLine(
        detailSource,
        nikOverride: nik,
      );
      final nama = detail.nama.isNotEmpty
          ? detail.nama
          : _extractName(line, lines, i);
      final jenisKelamin = detail.jenisKelamin.isNotEmpty
          ? detail.jenisKelamin
          : _extractGender(lines, i);

      if (nama.isEmpty) {
        continue;
      }

      members.add(
        ParsedKkMember(
          nama: nama,
          nik: nik,
          hubungan: '',
          jenisKelamin: jenisKelamin,
          tempatLahir: _toTitleCase(detail.tempatLahir),
          tanggalLahir: detail.tanggalLahir,
          agama: _toTitleCase(detail.agama),
          pendidikan: _toTitleCase(detail.pendidikan),
          jenisPekerjaan: _toTitleCase(detail.jenisPekerjaan),
          golonganDarah: detail.golonganDarah,
        ),
      );
      seenNik.add(nik);
    }

    if (members.isNotEmpty) {
      return members;
    }

    // Fallback parser: beberapa OCR KK menggabungkan tabel menjadi satu baris panjang.
    final tableEndIdx = lines.indexWhere(_isMemberTableEnd);
    final tableSlice = tableEndIdx > 0 ? lines.sublist(0, tableEndIdx) : lines;
    final flattened = tableSlice.join(' ');
    final nikMatches = RegExp(r'(\d[\d\s]{15,22}\d)').allMatches(flattened);
    for (final match in nikMatches) {
      final nik = match.group(0)?.replaceAll(RegExp(r'[^0-9]'), '');
      if (nik == null || nik.length != 16 || seenNik.contains(nik)) {
        continue;
      }
      if (!_isLikelyMemberNik(nik, noKkHint: noKkHint)) {
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
          hubungan: '',
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
    final upper = line.toUpperCase();
    if (upper.contains('NO KK') ||
        upper.contains('NOMOR KK') ||
        upper.contains('KARTU KELUARGA') ||
        upper.contains('NIK') ||
        upper.contains('STATUS PERKAWINAN') ||
        upper.contains('DOKUMEN IMIGRASI') ||
        upper.contains('NAMA ORANG TUA')) {
      return null;
    }

    final candidate = _extract16DigitsWithOcrCorrection(upper);
    if (candidate == null || candidate.length != 16) return null;
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

  ({
    String nama,
    String jenisKelamin,
    String tempatLahir,
    String tanggalLahir,
    String agama,
    String pendidikan,
    String jenisPekerjaan,
    String golonganDarah,
  })
  _extractMemberDetailFromLine(String line, {String? nikOverride}) {
    final nikMatch = _findNikTokenMatch(line, nikOverride: nikOverride);
    if (nikMatch == null) {
      return (
        nama: '',
        jenisKelamin: '',
        tempatLahir: '',
        tanggalLahir: '',
        agama: '',
        pendidikan: '',
        jenisPekerjaan: '',
        golonganDarah: '',
      );
    }

    final left = line.substring(0, nikMatch.$1).trim();
    var remaining = line.substring(nikMatch.$2).trim();

    final nama = _extractNameBeforeNik(left);
    var jenisKelamin = '';
    var tempatLahir = '';
    var tanggalLahir = '';
    var agama = '';
    var pendidikan = '';
    var jenisPekerjaan = '';
    var golonganDarah = '';

    final genderMatch = RegExp(
      r'\b(PEREMPUAN|LAKI[\s\-\/]*LAKI|LAKILAKI|LAKI|PR|LK)\b',
    ).firstMatch(remaining);
    if (genderMatch != null) {
      jenisKelamin = _normalizeJenisKelamin(genderMatch.group(1) ?? '');
      if (genderMatch.start <= 4) {
        remaining = remaining.substring(genderMatch.end).trim();
      }
    }

    final tanggalMatch = RegExp(
      r'\b([0-3]?\d[-\/\.][0-1]?\d[-\/\.]\d{2,4})\b',
    ).firstMatch(remaining);
    if (tanggalMatch != null) {
      tempatLahir = _cleanMemberDetailValue(
        remaining.substring(0, tanggalMatch.start),
      );
      tanggalLahir = _normalizeTanggalFromToken(tanggalMatch.group(1) ?? '');
      remaining = remaining.substring(tanggalMatch.end).trim();
    }

    final agamaMatch = _findAgamaMatch(remaining);
    if (agamaMatch != null) {
      if (tanggalMatch == null && tempatLahir.isEmpty && agamaMatch.start > 0) {
        tempatLahir = _cleanMemberDetailValue(
          remaining.substring(0, agamaMatch.start),
        );
      }
      agama = _normalizeAgama(agamaMatch.group(0) ?? '');
      remaining = remaining.substring(agamaMatch.end).trim();
    }

    final golDarahMatch = RegExp(
      r'(TIDAK\s+TAHU|AB[+-]?|A[+-]?|B[+-]?|O[+-]?|-)\s*$',
    ).firstMatch(remaining);
    if (golDarahMatch != null) {
      golonganDarah = _normalizeGolonganDarah(golDarahMatch.group(1) ?? '');
      remaining = remaining.substring(0, golDarahMatch.start).trim();
    }

    final pendidikanPekerjaan = _splitPendidikanDanPekerjaan(remaining);
    pendidikan = pendidikanPekerjaan.$1;
    jenisPekerjaan = pendidikanPekerjaan.$2;

    return (
      nama: nama,
      jenisKelamin: jenisKelamin,
      tempatLahir: tempatLahir,
      tanggalLahir: tanggalLahir,
      agama: agama,
      pendidikan: pendidikan,
      jenisPekerjaan: jenisPekerjaan,
      golonganDarah: golonganDarah,
    );
  }

  String _extractNameBeforeNik(String input) {
    var candidate = input.replaceFirst(RegExp(r'^\d+\s*'), '').trim();
    candidate = candidate
        .replaceAll(RegExp(r"[^A-Z\s'.-]"), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (!_isLikelyName(candidate)) return '';
    return _toTitleCase(candidate);
  }

  String _normalizeJenisKelamin(String input) {
    final upper = input.toUpperCase().replaceAll(RegExp(r'[^A-Z]'), '');
    if (upper == 'PR' || upper.contains('PEREMPUAN')) {
      return 'Perempuan';
    }
    return 'Laki-laki';
  }

  String _normalizeTanggalFromToken(String input) {
    final cleaned = input.replaceAll(RegExp(r'[\/\.]'), '-').trim();
    final match = RegExp(
      r'^(\d{1,2})-(\d{1,2})-(\d{2,4})$',
    ).firstMatch(cleaned);
    if (match == null) {
      return cleaned;
    }

    final day = int.tryParse(match.group(1) ?? '');
    final month = int.tryParse(match.group(2) ?? '');
    final yearRaw = int.tryParse(match.group(3) ?? '');
    if (day == null || month == null || yearRaw == null) {
      return cleaned;
    }

    final year = yearRaw < 100
        ? (yearRaw <= 30 ? 2000 + yearRaw : 1900 + yearRaw)
        : yearRaw;
    if (day < 1 || day > 31 || month < 1 || month > 12) {
      return cleaned;
    }

    final dd = day.toString().padLeft(2, '0');
    final mm = month.toString().padLeft(2, '0');
    final yyyy = year.toString().padLeft(4, '0');
    return '$dd-$mm-$yyyy';
  }

  RegExpMatch? _findAgamaMatch(String input) {
    return RegExp(
      r'\b(ISLAM|KRISTEN|KATOLIK|KATHOLIK|KHATOLIK|HINDU|BUDDHA|BUDHA|KONGHUCU|KONGHUCHU)\b',
    ).firstMatch(input);
  }

  String _normalizeAgama(String input) {
    final upper = input.toUpperCase();
    if (upper.contains('ISLAM')) return 'Islam';
    if (upper.contains('KRISTEN')) return 'Kristen';
    if (upper.contains('KATOLIK') ||
        upper.contains('KATHOLIK') ||
        upper.contains('KHATOLIK')) {
      return 'Katolik';
    }
    if (upper.contains('HINDU')) return 'Hindu';
    if (upper.contains('BUDDHA') || upper.contains('BUDHA')) return 'Buddha';
    if (upper.contains('KONGHUCU') || upper.contains('KONGHUCHU')) {
      return 'Konghucu';
    }
    return _cleanMemberDetailValue(input);
  }

  String _normalizeGolonganDarah(String input) {
    final upper = input.toUpperCase().replaceAll(RegExp(r'\s+'), '');
    if (upper.isEmpty || upper == '-') return '';
    if (upper == 'TIDAKTAHU') return 'Tidak Tahu';
    if (upper == 'AB' ||
        upper == 'A' ||
        upper == 'B' ||
        upper == 'O' ||
        upper == 'A+' ||
        upper == 'A-' ||
        upper == 'B+' ||
        upper == 'B-' ||
        upper == 'AB+' ||
        upper == 'AB-' ||
        upper == 'O+' ||
        upper == 'O-') {
      return upper;
    }
    return _cleanMemberDetailValue(input);
  }

  (String, String) _splitPendidikanDanPekerjaan(String input) {
    final cleaned = _cleanMemberDetailValue(input);
    if (cleaned.isEmpty) return ('', '');

    final compact = cleaned
        .toUpperCase()
        .replaceAll(RegExp(r'\s*/\s*'), '/')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();

    const pendidikanPhrases = <String>[
      'TIDAK/BELUM SEKOLAH',
      'TIDAK BELUM SEKOLAH',
      'BELUM TAMAT SD/SEDERAJAT',
      'TAMAT SD/SEDERAJAT',
      'SLTP/SEDERAJAT',
      'SLTA/SEDERAJAT',
      'DIPLOMA I/II',
      'AKADEMI/DIPLOMA III/SARJANA MUDA',
      'AKADEMI/DIPLOMA III/S. MUDA',
      'DIPLOMA IV/STRATA I',
      'STRATA II',
      'STRATA III',
    ];

    for (final phrase in pendidikanPhrases) {
      if (!compact.startsWith(phrase)) continue;
      var pekerjaan = compact.substring(phrase.length).trim();
      if (pekerjaan.startsWith('/')) {
        pekerjaan = pekerjaan.substring(1).trim();
      }
      return (phrase, _cleanMemberDetailValue(pekerjaan));
    }

    const pekerjaanKeywords = <String>[
      'WIRASWASTA',
      'KARYAWAN SWASTA',
      'BELUM/TIDAK BEKERJA',
      'BELUM BEKERJA',
      'TIDAK BEKERJA',
      'PELAJAR/MAHASISWA',
      'PNS',
      'PETANI',
      'PEDAGANG',
      'BURUH',
      'NELAYAN',
      'PENSIUNAN',
      'MENGURUS RUMAH TANGGA',
    ];

    var splitIndex = -1;
    for (final keyword in pekerjaanKeywords) {
      final idx = compact.indexOf(keyword);
      if (idx <= 0) continue;
      if (splitIndex < 0 || idx < splitIndex) {
        splitIndex = idx;
      }
    }
    if (splitIndex > 0) {
      final pendidikan = _cleanMemberDetailValue(
        compact.substring(0, splitIndex),
      );
      final pekerjaan = _cleanMemberDetailValue(compact.substring(splitIndex));
      return (pendidikan, pekerjaan);
    }

    return ('', compact);
  }

  void _debugPrintLong(String text) {
    const chunkSize = 700;
    for (var i = 0; i < text.length; i += chunkSize) {
      final end = (i + chunkSize < text.length) ? i + chunkSize : text.length;
      debugPrint(text.substring(i, end));
    }
  }

  bool _looksLikeMemberTableHeader(String line) {
    return line.contains('NAMA LENGKAP') && line.contains('NIK');
  }

  bool _isMemberTableEnd(String line) {
    return line.contains('STATUS PERKAWINAN') ||
        line.contains('DOKUMEN IMIGRASI') ||
        line.contains('NAMA ORANG TUA');
  }

  bool _containsDateToken(String line) {
    return RegExp(r'\b[0-3]?\d[-\/\.][0-1]?\d[-\/\.]\d{2,4}\b').hasMatch(line);
  }

  (int, int)? _findNikTokenMatch(String line, {String? nikOverride}) {
    final normalized = _normalizeOcrDigits(line.toUpperCase());
    final matches = RegExp(
      r'([0-9][0-9\s]{14,30}[0-9])',
    ).allMatches(normalized);
    for (final match in matches) {
      final token = match.group(0) ?? '';
      final digits = token.replaceAll(RegExp(r'[^0-9]'), '');
      if (digits.length == 16) {
        if (nikOverride != null &&
            nikOverride.isNotEmpty &&
            digits != nikOverride) {
          continue;
        }
        return (match.start, match.end);
      }
      if (digits.length > 16 && nikOverride != null && nikOverride.isNotEmpty) {
        if (digits.contains(nikOverride)) {
          return (match.start, match.end);
        }
      }
    }
    return null;
  }

  bool _isLikelyMemberNik(String nik, {String noKkHint = ''}) {
    if (nik.length != 16) return false;
    if (RegExp(r'^0+$').hasMatch(nik)) return false;
    if (RegExp(r'^(\d)\1{15}$').hasMatch(nik)) return false;

    if (noKkHint.length >= 6) {
      final prefix = noKkHint.substring(0, 6);
      if (!nik.startsWith(prefix)) {
        return false;
      }
    }

    var day = int.tryParse(nik.substring(6, 8)) ?? 0;
    final month = int.tryParse(nik.substring(8, 10)) ?? 0;
    if (day > 40) day -= 40;
    if (day < 1 || day > 31) return false;
    if (month < 1 || month > 12) return false;

    return true;
  }

  Future<String> _extractMemberTableTextFromImage(
    String imagePath,
    TextRecognizer recognizer,
  ) async {
    final file = File(imagePath);
    if (!await file.exists()) return '';

    final bytes = await file.readAsBytes();
    final decoded = img.decodeImage(bytes);
    if (decoded == null) return '';

    final width = decoded.width;
    final height = decoded.height;
    if (width <= 0 || height <= 0) return '';

    final rowTexts = <String>[];
    var emptyStreak = 0;
    for (var rowIndex = 0; rowIndex < 10; rowIndex++) {
      final rowRect = _memberRowRect(
        width: width,
        height: height,
        rowIndex: rowIndex,
      );
      if (rowRect == null) {
        continue;
      }

      final cropped = img.copyCrop(
        decoded,
        x: rowRect.$1,
        y: rowRect.$2,
        width: rowRect.$3,
        height: rowRect.$4,
      );
      final upscaled = img.copyResize(
        cropped,
        width: rowRect.$3 * 3,
        height: rowRect.$4 * 3,
        interpolation: img.Interpolation.cubic,
      );
      final gray = img.grayscale(upscaled);
      final enhanced = img.adjustColor(
        gray,
        contrast: 1.45,
        brightness: 1.08,
        saturation: 0.0,
      );
      final encoded = img.encodeJpg(enhanced, quality: 98);

      final tempDir = await getTemporaryDirectory();
      final tempPath =
          '${tempDir.path}${Platform.pathSeparator}kk_member_row_$rowIndex.jpg';
      final tempFile = File(tempPath);
      await tempFile.writeAsBytes(encoded, flush: true);

      try {
        final inputImage = InputImage.fromFilePath(tempPath);
        final result = await recognizer.processImage(inputImage);
        final text = result.text
            .replaceAll('\n', ' ')
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim();
        if (kDebugMode) {
          debugPrint('[KK OCR] MEMBER ROW[$rowIndex] => $text');
        }

        final digitsCount = RegExp(r'\d').allMatches(text).length;
        final hasLikelyName = RegExp(r'[A-Z]{3,}').hasMatch(text);
        final hasData = digitsCount >= 8 || (hasLikelyName && text.length > 12);
        if (hasData) {
          rowTexts.add(text);
          emptyStreak = 0;
        } else {
          emptyStreak += 1;
        }
      } finally {
        if (await tempFile.exists()) {
          await tempFile.delete();
        }
      }

      if (rowIndex >= 3 && emptyStreak >= 3) {
        break;
      }
    }

    if (rowTexts.isNotEmpty) {
      return rowTexts.join('\n');
    }

    final tableRect = _memberTableRect(width: width, height: height);
    if (tableRect == null) return '';
    final tableCrop = img.copyCrop(
      decoded,
      x: tableRect.$1,
      y: tableRect.$2,
      width: tableRect.$3,
      height: tableRect.$4,
    );
    final tableUpscaled = img.copyResize(
      tableCrop,
      width: tableRect.$3 * 2,
      height: tableRect.$4 * 2,
      interpolation: img.Interpolation.cubic,
    );
    final tableEnhanced = img.adjustColor(
      img.grayscale(tableUpscaled),
      contrast: 1.35,
      brightness: 1.06,
      saturation: 0.0,
    );
    final fallbackBytes = img.encodeJpg(tableEnhanced, quality: 98);
    final tempDir = await getTemporaryDirectory();
    final fallbackPath =
        '${tempDir.path}${Platform.pathSeparator}kk_member_table_crop.jpg';
    final fallbackFile = File(fallbackPath);
    await fallbackFile.writeAsBytes(fallbackBytes, flush: true);
    try {
      final inputImage = InputImage.fromFilePath(fallbackPath);
      final result = await recognizer.processImage(inputImage);
      return result.text;
    } finally {
      if (await fallbackFile.exists()) {
        await fallbackFile.delete();
      }
    }
  }

  (int, int, int, int)? _memberTableRect({
    required int width,
    required int height,
  }) {
    final x = (width * 0.015).round();
    final y = (height * 0.165).round();
    final w = (width * 0.97).round();
    final h = (height * 0.275).round();
    if (w <= 0 || h <= 0) return null;
    final safeX = x.clamp(0, width - 1);
    final safeY = y.clamp(0, height - 1);
    final safeW = w.clamp(1, width - safeX);
    final safeH = h.clamp(1, height - safeY);
    return (safeX, safeY, safeW, safeH);
  }

  (int, int, int, int)? _memberRowRect({
    required int width,
    required int height,
    required int rowIndex,
  }) {
    final table = _memberTableRect(width: width, height: height);
    if (table == null) return null;

    final tableX = table.$1;
    final tableY = table.$2;
    final tableW = table.$3;
    final tableH = table.$4;

    final dataX = tableX + (tableW * 0.03).round();
    final dataW = (tableW * 0.96).round();
    final dataStartY = tableY + (tableH * 0.22).round();
    final rowHeight = (tableH * 0.073).round();
    final dataY = dataStartY + (rowIndex * rowHeight);

    if (dataW <= 0 || rowHeight <= 0) return null;
    final safeX = dataX.clamp(0, width - 1);
    final safeY = dataY.clamp(0, height - 1);
    final safeW = dataW.clamp(1, width - safeX);
    final safeH = rowHeight.clamp(1, height - safeY);
    return (safeX, safeY, safeW, safeH);
  }

  String _cleanMemberDetailValue(String input) {
    return input
        .replaceAll(RegExp(r'^[\-\.:]+'), '')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  String _cleanStructuredField(String input) {
    return input
        .toUpperCase()
        .replaceAll(RegExp(r'[^A-Z0-9/\-\+\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
  }

  String _normalizeStructuredName(String input) {
    final upper = input
        .toUpperCase()
        .replaceAll(RegExp(r"[^A-Z\s'.-]"), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (upper.isEmpty || !_isLikelyName(upper)) return '';
    return _toTitleCase(upper);
  }

  String _normalizeStructuredJenisKelamin(String input) {
    final upper = input.toUpperCase();
    if (upper.contains('PEREMPUAN') || upper.contains('PR')) {
      return 'Perempuan';
    }
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
