// ignore_for_file: unused_element, deprecated_member_use, avoid_web_libraries_in_flutter

import 'dart:html' as html;
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter/foundation.dart';

const _memberTableMarker = '__KK_MEMBER_TABLE__';
const _memberStructMarker = '__KK_MEMBER_STRUCT__';
const _memberStructPrefix = 'ROW|';

Future<String> runWebOcrImpl(
  Uint8List imageBytes, {
  String lang = 'ind+eng',
}) async {
  final tesseractAny = globalContext['Tesseract'];
  if (tesseractAny == null || !tesseractAny.isA<JSObject>()) {
    throw Exception(
      'Engine OCR web belum termuat. Refresh aplikasi lalu coba lagi.',
    );
  }
  final tesseract = tesseractAny as JSObject;

  final blob = html.Blob(<Object>[imageBytes], 'image/*');
  final objectUrl = html.Url.createObjectUrlFromBlob(blob);

  try {
    final fullText = await _recognizeText(
      tesseract: tesseract,
      source: objectUrl,
      lang: lang,
    );

    // ═══════════════════════════════════════════════════════════════════════
    // STRATEGY 1: NIK-Anchor method (PREFERRED - most robust)
    // Read entire member table as one block, then parse using NIK as anchor
    // ═══════════════════════════════════════════════════════════════════════
    final nikAnchorRows = await _extractMembersUsingNikAnchor(
      objectUrl: objectUrl,
      tesseract: tesseract,
      lang: lang,
    );
    if (nikAnchorRows.trim().isNotEmpty) {
      if (kDebugMode) {
        debugPrint('[KK OCR WEB] Using NIK-Anchor method');
      }
      return '${fullText.trim()}\n$_memberStructMarker\n${nikAnchorRows.trim()}';
    }

    // ═══════════════════════════════════════════════════════════════════════
    // STRATEGY 2: Per-row structured extraction (original method)
    // ═══════════════════════════════════════════════════════════════════════
    final structuredMemberRows = await _extractStructuredMemberRows(
      objectUrl: objectUrl,
      tesseract: tesseract,
      lang: lang,
    );
    if (structuredMemberRows.trim().isNotEmpty) {
      if (kDebugMode) {
        debugPrint('[KK OCR WEB] Using structured row method');
      }
      return '${fullText.trim()}\n$_memberStructMarker\n${structuredMemberRows.trim()}';
    }

    // ═══════════════════════════════════════════════════════════════════════
    // STRATEGY 3: Raw row text extraction
    // ═══════════════════════════════════════════════════════════════════════
    final memberRowText = await _extractMemberRowsText(
      objectUrl: objectUrl,
      tesseract: tesseract,
      lang: lang,
    );
    if (memberRowText.trim().isNotEmpty) {
      return '${fullText.trim()}\n$_memberTableMarker\n${memberRowText.trim()}';
    }

    // ═══════════════════════════════════════════════════════════════════════
    // STRATEGY 4: Simple crop fallback
    // ═══════════════════════════════════════════════════════════════════════
    final memberCropDataUrl = await _createMemberTableCropDataUrl(objectUrl);
    if (memberCropDataUrl == null) return fullText.trim();
    final memberText = await _recognizeText(
      tesseract: tesseract,
      source: memberCropDataUrl,
      lang: lang,
    );
    if (memberText.trim().isEmpty) return fullText.trim();
    return '${fullText.trim()}\n$_memberTableMarker\n${memberText.trim()}';
  } finally {
    html.Url.revokeObjectUrl(objectUrl);
  }
}

Future<String> _recognizeText({
  required JSObject tesseract,
  required String source,
  required String lang,
}) async {
  final promise = tesseract.callMethod<JSPromise<JSAny?>>(
    'recognize'.toJS,
    source.toJS,
    lang.toJS,
  );
  final resultAny = await promise.toDart;
  if (resultAny == null || !resultAny.isA<JSObject>()) return '';
  final result = resultAny as JSObject;

  final dataAny = result.getProperty<JSAny?>('data'.toJS);
  if (dataAny == null || !dataAny.isA<JSObject>()) return '';
  final data = dataAny as JSObject;

  final textAny = data.getProperty<JSAny?>('text'.toJS);
  if (textAny == null || !textAny.isA<JSString>()) return '';
  return (textAny as JSString).toDart;
}

// ═══════════════════════════════════════════════════════════════════════════
// NIK-ANCHOR METHOD: Read entire member table, then parse using NIK as anchor
// This is more robust because:
// 1. NIK is always 16 consecutive digits - easy to detect
// 2. No need for precise column cropping
// 3. Grid lines don't affect NIK detection as much
// ═══════════════════════════════════════════════════════════════════════════
Future<String> _extractMembersUsingNikAnchor({
  required String objectUrl,
  required JSObject tesseract,
  required String lang,
}) async {
  try {
    final image = html.ImageElement(src: objectUrl);
    await image.onLoad.first;
    final width = image.naturalWidth;
    final height = image.naturalHeight;
    if (width <= 0 || height <= 0) return '';

    // ═══════════════════════════════════════════════════════════════════════
    // HYBRID APPROACH: Read each ROW separately, then use NIK as anchor
    // This prevents data from different rows mixing together
    // ═══════════════════════════════════════════════════════════════════════
    final members = <Map<String, String>>[];
    var emptyStreak = 0;

    for (var rowIndex = 0; rowIndex < 10; rowIndex++) {
      final rowRect = _memberRowRect(
        imageWidth: width,
        imageHeight: height,
        rowIndex: rowIndex,
      );
      if (rowRect == null) continue;

      // Preprocess and OCR the entire row
      final rowDataUrl = _cropAndPreprocessForOcr(
        image: image,
        sx: rowRect.$1,
        sy: rowRect.$2,
        sw: rowRect.$3,
        sh: rowRect.$4,
        scale: 4,
        removeGridLines: true,
      );

      final rowText = await _recognizeText(
        tesseract: tesseract,
        source: rowDataUrl,
        lang: lang,
      );

      final rowNormalized = rowText
          .replaceAll('\n', ' ')
          .replaceAll(RegExp(r'\s+'), ' ')
          .trim()
          .toUpperCase();

      if (kDebugMode) {
        debugPrint('[KK OCR WEB] ROW[$rowIndex] raw: $rowNormalized');
      }

      // Parse the row using NIK as anchor
      final member = _parseRowUsingNikAnchor(rowNormalized);

      if (member != null) {
        if (kDebugMode) {
          debugPrint(
            '[KK OCR WEB] ROW[$rowIndex] MEMBER => nama=${member['nama']}, '
            'nik=${member['nik']}, jk=${member['jenisKelamin']}, '
            'tempat=${member['tempatLahir']}, tgl=${member['tanggalLahir']}, '
            'agama=${member['agama']}, pendidikan=${member['pendidikan']}, '
            'pekerjaan=${member['pekerjaan']}, goldar=${member['goldar']}',
          );
        }
        members.add(member);
        emptyStreak = 0;
      } else {
        if (kDebugMode) {
          debugPrint('[KK OCR WEB] ROW[$rowIndex] NO MEMBER FOUND');
        }
        emptyStreak++;
      }

      // Stop if we've seen too many empty rows
      if (rowIndex >= 4 && emptyStreak >= 2) break;
    }

    if (members.isEmpty) return '';

    // Build output rows
    final rows = <String>[];
    for (final member in members) {
      rows.add(
        '$_memberStructPrefix${member['nama']}|${member['nik']}|'
        '${member['jenisKelamin']}|${member['tempatLahir']}|'
        '${member['tanggalLahir']}|${member['agama']}|'
        '${member['pendidikan']}|${member['pekerjaan']}|${member['goldar']}',
      );
    }

    return rows.join('\n');
  } catch (e) {
    if (kDebugMode) {
      debugPrint('[KK OCR WEB] NIK-Anchor error: $e');
    }
    return '';
  }
}

/// Parse a single row text using NIK (16-digit number) as anchor point
/// This prevents data from mixing between different members
Map<String, String>? _parseRowUsingNikAnchor(String rowText) {
  if (rowText.isEmpty) return null;

  // Skip rows that are clearly header/label rows
  if (_looksLikeHeaderRow(rowText)) {
    if (kDebugMode) {
      debugPrint('[KK OCR WEB] Skipped header row: ${_truncate(rowText, 50)}');
    }
    return null;
  }

  // Find NIK in this row using multiple strategies
  String? nik;
  int nikStart = -1;
  int nikEnd = -1;

  // Strategy 1: Look for 16 consecutive digits (ideal case)
  final pureDigitMatch = RegExp(r'(\d{16})').firstMatch(rowText);
  if (pureDigitMatch != null) {
    nik = pureDigitMatch.group(1)!;
    nikStart = pureDigitMatch.start;
    nikEnd = pureDigitMatch.end;
    if (kDebugMode) {
      debugPrint('[KK OCR WEB] Found pure digit NIK: $nik');
    }
  }

  // Strategy 2: Look for 16-char sequence with common OCR errors
  // OCR often misreads digits as letters:
  // 0 → O, Q, D; 1 → I, L; 2 → Z, R; 5 → S; 7 → T, F, Y; 8 → B; 3 → E; 6 → G; 4 → A, H; 9 → P
  if (nik == null) {
    final nikPattern = RegExp(
      r'([0-9OQDILZSTBEGAFRHYP]{16,18})',
      caseSensitive: false,
    );
    final nikMatch = nikPattern.firstMatch(rowText);

    if (nikMatch != null) {
      var nikRaw = nikMatch.group(1)!.replaceAll(RegExp(r'\s+'), '');
      nikRaw = _normalizeOcrDigits(nikRaw);

      if (nikRaw.length >= 16 && _looksLikeNik(nikRaw.substring(0, 16))) {
        nik = nikRaw.substring(0, 16);
        nikStart = nikMatch.start;
        nikEnd = nikMatch.end;
        if (kDebugMode) {
          debugPrint('[KK OCR WEB] Found OCR-corrected NIK: $nik');
        }
      }
    }
  }

  // Strategy 3: Look for 16-char sequence with spaces (OCR sometimes adds spaces)
  if (nik == null) {
    final spacedNikPattern = RegExp(
      r'([0-9OQDILZSTBEGAFRHYP][0-9OQDILZSTBEGAFRHYP\s]{14,25}[0-9OQDILZSTBEGAFRHYP])',
      caseSensitive: false,
    );
    final nikMatch = spacedNikPattern.firstMatch(rowText);

    if (nikMatch != null) {
      var nikRaw = nikMatch.group(1)!.replaceAll(RegExp(r'\s+'), '');
      nikRaw = _normalizeOcrDigits(nikRaw);

      if (nikRaw.length >= 16 && _looksLikeNik(nikRaw.substring(0, 16))) {
        nik = nikRaw.substring(0, 16);
        nikStart = nikMatch.start;
        nikEnd = nikMatch.end;
        if (kDebugMode) {
          debugPrint('[KK OCR WEB] Found spaced NIK: $nik');
        }
      }
    }
  }

  if (nik == null || nikStart < 0) {
    if (kDebugMode) {
      debugPrint(
        '[KK OCR WEB] No valid NIK found in: ${_truncate(rowText, 80)}...',
      );
    }
    return null;
  }

  // Text BEFORE NIK = contains row number and name
  final beforeNik = rowText.substring(0, nikStart).trim();
  // Text AFTER NIK = contains all other fields (gender, tempat, etc)
  final afterNik = rowText.substring(nikEnd).trim();

  if (kDebugMode) {
    debugPrint('[KK OCR WEB] beforeNik: $beforeNik');
    debugPrint('[KK OCR WEB] afterNik: ${_truncate(afterNik, 100)}');
  }

  // Extract name from beforeNik (remove row number)
  final nama = _extractNameFromRowText(beforeNik);

  // Extract other fields from afterNik
  final jenisKelamin = _extractGenderFromRowText(afterNik);
  final tempatLahir = _extractTempatLahirFromRowText(afterNik, jenisKelamin);
  final tanggalLahir = _normalizeDateCandidate(afterNik);
  final agama = _normalizeAgamaCandidate(afterNik);
  final pendidikan = _extractPendidikanFromRowText(afterNik);
  final pekerjaan = _extractPekerjaanFromRowText(afterNik);
  final goldar = _extractGolDarahFromRowText(afterNik);

  // Validate: need either good name or good NIK
  final hasGoodName = nama.replaceAll(RegExp(r'[^A-Za-z]'), '').length >= 3;
  final hasGoodNik = nik.length == 16;

  if (!hasGoodName && !hasGoodNik) {
    if (kDebugMode) {
      debugPrint('[KK OCR WEB] Rejected: no good name or NIK');
    }
    return null;
  }

  return {
    'nama': nama,
    'nik': nik,
    'jenisKelamin': jenisKelamin,
    'tempatLahir': tempatLahir,
    'tanggalLahir': tanggalLahir,
    'agama': agama,
    'pendidikan': pendidikan,
    'pekerjaan': pekerjaan,
    'goldar': goldar,
  };
}

/// Extract name from text before NIK in a row
String _extractNameFromRowText(String text) {
  // First, remove common prefixes/noise from the start
  // Patterns like "| 3 I", "14 ", "| 1 ", "| 4 |", etc.
  var cleaned = text
      .replaceAll(RegExp(r'^[\s\|\[\]\(\)\-\_\.\,]+'), '')
      .replaceAll(RegExp(r'^[0-9]+[\s\|\[\]\(\)\-\_\.\,]+'), '')
      .toUpperCase();

  // Also handle: "| 3 IMUHAMMAD" → should become "MUHAMMAD"
  // Remove any remaining leading non-alpha after initial cleanup
  cleaned = cleaned.replaceAll(RegExp(r'^[^A-Z]+'), '');

  // In name context, digits are usually misread letters:
  // 1 → I, 0 → O, 5 → S, 8 → B, 3 → E, 4 → A, 6 → G, 7 → T
  cleaned = cleaned
      .replaceAll('1', 'I')
      .replaceAll('0', 'O')
      .replaceAll('5', 'S')
      .replaceAll('8', 'B')
      .replaceAll('3', 'E')
      .replaceAll('4', 'A')
      .replaceAll('6', 'G')
      .replaceAll('7', 'T');

  // Handle common OCR misreads in Indonesian names
  // KAUISAR → KAUSAR (extra I), FARDIANSYAH → FARDIANSYAH
  // Don't change these as they might be legitimate names

  cleaned = cleaned
      .replaceAll(RegExp(r'[^A-Z\s]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  // Remove noise words - expanded list to catch more OCR garbage
  const noise = {
    // Common KK labels
    'NO',
    'NAMA',
    'LENGKAP',
    'WNI',
    'JENIS',
    'KELAMIN',
    'LAKI',
    'PEREMPUAN',
    'TEMPAT',
    'TGL',
    'LAHIR',
    'TANGGAL',
    'AGAMA',
    'PENDIDIKAN',
    'PEKERJAAN',
    'GOLONGAN',
    'DARAH',
    'HUBUNGAN',
    'DALAM',
    'KELUARGA',
    'KEPALA',
    'ANAK',
    'ISTRI',
    'SUAMI',
    'STATUS',
    'PERKAWINAN',
    'KEWARGANEGARAAN',
    // OCR noise patterns
    'RR',
    'OW',
    'FR',
    'DD',
    'II',
    'TT',
    'PP',
    'SS',
    'OO',
    'NN',
    'MM',
    'AA',
    // Common misreads from other fields
    'TIDAK',
    'TAHU',
    'BELUM',
    'SEKOLAH',
    'TAMAT',
    'ISLAM',
    'KRISTEN',
    'KATOLIK',
    'HINDU',
    'BUDHA',
    'SLTA',
    'SLTP',
    'SD',
    'SEDERAJAT',
    'DIPLOMA',
    'SARJANA',
    'AKADEMI',
    'WIRASWASTA',
    'KARYAWAN',
    'SWASTA',
    'PELAJAR',
    'MAHASISWA',
    'BEKERJA',
    'MENGURUS',
    'RUMAH',
    'TANGGA',
    'PNS',
    'PETANI',
    'PEDAGANG',
    'PENSIUNAN',
    // Common city names that leak from other rows
    'BANDUNG',
    'CIMAHI',
    'JAKARTA',
    'SURABAYA',
    'SEMARANG',
  };

  final words = cleaned.split(' ').where((w) {
    if (w.isEmpty || w.length < 2) return false;
    if (noise.contains(w)) return false;
    if (w.length >= 3 && RegExp(r'^(.)\1+$').hasMatch(w)) return false;
    if (w.length >= 4 && !_hasReasonableVowelRatio(w)) return false;
    // Filter very short noise words that are likely fragments
    if (w.length <= 2 && !_isLikelyNamePart(w)) return false;
    return true;
  }).toList();

  if (words.isEmpty) return '';

  final merged = _mergeFragmentedNameWords(words);

  // Take the last N words if there are too many (names are usually at the end)
  // But first, detect and remove leading noise
  final cleanedWords = _removeLeadingNoise(merged);

  return cleanedWords.take(5).join(' ');
}

/// Check if a short word is likely part of a name
bool _isLikelyNamePart(String word) {
  // Common Indonesian name particles
  const particles = {'AL', 'EL', 'BIN', 'BINTI', 'NUR', 'NI', 'LA', 'I', 'WA'};
  return particles.contains(word.toUpperCase());
}

/// Remove leading garbage words that are not part of the name
List<String> _removeLeadingNoise(List<String> words) {
  if (words.isEmpty) return words;

  // Common patterns that indicate start of actual name
  // Skip words that are likely garbage from previous row
  var startIdx = 0;

  for (var i = 0; i < words.length; i++) {
    final w = words[i].toUpperCase();
    // Short words at the start are likely noise unless they're name particles
    if (w.length <= 3 && !_isLikelyNamePart(w) && i < words.length - 1) {
      startIdx = i + 1;
      continue;
    }
    // If we find a longer word, start from here
    if (w.length >= 4 || _isLikelyNamePart(w)) {
      startIdx = i;
      break;
    }
  }

  if (startIdx >= words.length) return words;
  return words.sublist(startIdx);
}

/// Extract gender from row text (after NIK)
String _extractGenderFromRowText(String text) {
  // Look for gender keywords at the START of afterNik text
  final upper = text.toUpperCase();

  // Check for PEREMPUAN first (it's longer)
  // Include common OCR typos: FEREMPUAN, PEREMPOAN, etc.
  final perempuanMatch = RegExp(
    r'\b([PF]ER[EO]M[PB]U[AO]N|PEREMPUAN|PR)\b',
    caseSensitive: false,
  ).firstMatch(upper);
  final lakiMatch = RegExp(
    r'\b(LAKI[-\s]*LAKI|LAK[ILl][-\s]*LAK[ILl]|LK)\b',
    caseSensitive: false,
  ).firstMatch(upper);

  if (perempuanMatch != null && lakiMatch != null) {
    // Both found - take the one that appears first
    return perempuanMatch.start < lakiMatch.start ? 'PEREMPUAN' : 'LAKI-LAKI';
  }
  if (perempuanMatch != null) return 'PEREMPUAN';
  if (lakiMatch != null) return 'LAKI-LAKI';

  return '';
}

/// Extract tempat lahir from row text (after NIK)
/// Exclude gender text that might be mistaken for tempat
String _extractTempatLahirFromRowText(String text, String gender) {
  var cleaned = text.toUpperCase();

  // Remove gender from the text first - including OCR typos
  // PEREMPUAN can be misread as FEREMPUAN, PEREMPOAN, etc.
  cleaned = cleaned
      .replaceFirst(
        RegExp(r'\b[PF]ER[EO]M[PB]U[AO]N\b', caseSensitive: false),
        '',
      )
      .replaceFirst(RegExp(r'\bPEREMPUAN\b'), '')
      .replaceFirst(RegExp(r'\bLAKI[-\s]*LAKI\b'), '')
      .replaceFirst(RegExp(r'\b[LP]R\b'), '') // PR or LR (typo)
      .replaceFirst(RegExp(r'\bLK\b'), '')
      .trim();

  // Remove date patterns
  cleaned = cleaned
      .replaceAll(RegExp(r'\b\d{1,2}[-/.]\d{1,2}[-/.]\d{2,4}\b'), '')
      .replaceAll(RegExp(r'\b\d{8}\b'), '') // Remove DDMMYYYY format
      .trim();

  // Look for city name - should be alphabetic words before the date
  final words = cleaned
      .split(RegExp(r'[\s\|]+'))
      .where((w) {
        if (w.isEmpty || w.length < 3) return false;
        // Must be mostly alphabetic
        final alphaCount = w.replaceAll(RegExp(r'[^A-Z]'), '').length;
        if (alphaCount < w.length * 0.7) return false;
        // Filter out known non-place words (expanded list)
        const notPlace = {
          'ISLAM',
          'KRISTEN',
          'KATOLIK',
          'HINDU',
          'BUDHA',
          'KONGHUCU',
          'SLTA',
          'SLTP',
          'DIPLOMA',
          'AKADEMI',
          'SARJANA',
          'WIRASWASTA',
          'KARYAWAN',
          'SWASTA',
          'BEKERJA',
          'BELUM',
          'TIDAK',
          'TAHU',
          'SEKOLAH',
          'TAMAT',
          'PELAJAR',
          'MAHASISWA',
          // Gender typos
          'FEREMPUAN',
          'PEREMPOAN',
          'PEREMFUAN',
          'LAKL',
          'LAKII',
          // Common OCR noise
          'CIA', // fragment from CIMAHI
          'HI', // fragment
          'MAH', // fragment
          'MAHI', // fragment but could be valid
        };
        if (notPlace.contains(w)) return false;
        if (!_hasReasonableVowelRatio(w)) return false;
        return true;
      })
      .take(2)
      .toList();

  if (words.isEmpty) return '';

  final result = words.join(' ');

  // Try fuzzy match
  final fuzzy = _fuzzyMatchTempatLahirWeb(result);
  return fuzzy ?? (result.length >= 4 ? result : '');
}

/// Extract pendidikan from row text
String _extractPendidikanFromRowText(String text) {
  final upper = text.toUpperCase();

  // Direct keyword matching
  if (upper.contains('AKADEMI') ||
      upper.contains('DIPLOMA III') ||
      upper.contains('SARJANA MUDA')) {
    return 'AKADEMI/DIPLOMA III/SARJANA MUDA';
  }
  if (upper.contains('DIPLOMA IV') ||
      RegExp(r'\bSTRATA\s*I\b').hasMatch(upper)) {
    return 'DIPLOMA IV/STRATA I';
  }
  if (RegExp(r'\bSTRATA\s*II\b').hasMatch(upper)) return 'STRATA II';
  if (RegExp(r'\bSTRATA\s*III\b').hasMatch(upper)) return 'STRATA III';
  if (upper.contains('SLTA') ||
      upper.contains('SMA') ||
      upper.contains('SMK')) {
    return 'SLTA/SEDERAJAT';
  }
  if (upper.contains('SLTP') || upper.contains('SMP')) {
    return 'SLTP/SEDERAJAT';
  }
  if (upper.contains('TAMAT') && upper.contains('SD')) {
    return 'TAMAT SD/SEDERAJAT';
  }
  if (upper.contains('BELUM') && upper.contains('TAMAT')) {
    return 'BELUM TAMAT SD/SEDERAJAT';
  }
  if ((upper.contains('TIDAK') || upper.contains('BELUM')) &&
      upper.contains('SEKOLAH')) {
    return 'TIDAK/BELUM SEKOLAH';
  }

  return '';
}

/// Extract pekerjaan from row text
String _extractPekerjaanFromRowText(String text) {
  final upper = text.toUpperCase();

  // Common OCR typos/fragments
  // WIRASWASTA can be: WIRASWASIA, WIRAS WASTA, W1RASWASTA
  if (upper.contains('WIRASWAST') ||
      RegExp(r'W[I1]RAS\s*W[AO]ST[AO]').hasMatch(upper)) {
    return 'WIRASWASTA';
  }
  if (upper.contains('KARYAWAN') && upper.contains('SWASTA')) {
    return 'KARYAWAN SWASTA';
  }
  if (upper.contains('KARYAWAN')) return 'KARYAWAN SWASTA';
  if (upper.contains('PELAJAR') || upper.contains('MAHASISWA')) {
    return 'PELAJAR/MAHASISWA';
  }
  // BELUM/TIDAK BEKERJA - OCR may read as BEKER/A, BEKERYA, etc
  if ((upper.contains('BELUM') || upper.contains('TIDAK')) &&
      (upper.contains('BEKERJA') || upper.contains('BEKER'))) {
    return 'BELUM/TIDAK BEKERJA';
  }
  // "TIDAKBEKERJA" as single word without spaces
  if (upper.contains('TIDAKBEKERJA') || upper.contains('BELUMBEKERJA')) {
    return 'BELUM/TIDAK BEKERJA';
  }
  if (upper.contains('MENGURUS') && upper.contains('RUMAH')) {
    return 'MENGURUS RUMAH TANGGA';
  }
  // IRT (Ibu Rumah Tangga) abbreviation
  if (RegExp(r'\bIRT\b').hasMatch(upper)) return 'MENGURUS RUMAH TANGGA';
  if (RegExp(r'\bPNS\b').hasMatch(upper)) return 'PNS';
  if (upper.contains('PETANI')) return 'PETANI';
  if (upper.contains('PEDAGANG')) return 'PEDAGANG';
  if (upper.contains('BURUH')) return 'BURUH';
  if (upper.contains('NELAYAN')) return 'NELAYAN';
  if (upper.contains('PENSIUNAN')) return 'PENSIUNAN';
  // TNI/POLRI
  if (RegExp(r'\bTNI\b').hasMatch(upper)) return 'TNI';
  if (RegExp(r'\bPOLRI\b').hasMatch(upper)) return 'POLRI';
  if (upper.contains('DOKTER')) return 'DOKTER';
  if (upper.contains('GURU')) return 'GURU';
  if (upper.contains('DOSEN')) return 'DOSEN';
  if (upper.contains('SOPIR') || upper.contains('DRIVER')) return 'SOPIR';
  if (upper.contains('OJEK') || upper.contains('OJOL')) {
    return 'TRANSPORTASI';
  }

  return '';
}

/// Extract golongan darah from row text
String _extractGolDarahFromRowText(String text) {
  final upper = text.toUpperCase();

  // "TIDAK TAHU" is common - check various OCR typos
  // TIDAKTAHU, T1DAK TAHU, TIDAK TAHU, TDK TAHU
  if ((upper.contains('TIDAK') ||
          upper.contains('TDK') ||
          upper.contains('T1DAK')) &&
      (upper.contains('TAHU') || upper.contains('TAU'))) {
    return 'TIDAK TAHU';
  }
  if (upper.contains('TIDAKTAHU') || upper.contains('TDKTAHU')) {
    return 'TIDAK TAHU';
  }

  // Look for blood type - could be anywhere in the text
  // AB+, AB-, A+, A-, B+, B-, O+, O-
  // Also handle "A 1" which OCR might produce for "A +"
  final bloodMatch = RegExp(
    r'\b(AB|[ABO])[\s]?([+\-]|POSITIF|NEGATIF)?\b',
    caseSensitive: false,
  ).firstMatch(upper);

  if (bloodMatch != null) {
    var type = bloodMatch.group(1)!;
    final modifier = bloodMatch.group(2) ?? '';
    if (modifier.contains('POSITIF') || modifier == '+') {
      return '$type+';
    }
    if (modifier.contains('NEGATIF') || modifier == '-') {
      return '$type-';
    }
    // Just the letter without + or - is valid
    return type;
  }

  return '';
}

/// Extract name from context text (text before NIK)
String _extractNameFromContext(String context) {
  // Clean up the context
  var cleaned = context
      .replaceAll(RegExp(r'\d+'), ' ') // Remove numbers
      .replaceAll(RegExp(r'[^A-Z\s]'), ' ') // Keep only letters
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  // Remove common noise words
  const noise = {
    'NO',
    'NAMA',
    'LENGKAP',
    'NIK',
    'NOMOR',
    'INDUK',
    'KEPENDUDUKAN',
    'WNI',
    'STATUS',
    'HUBUNGAN',
    'DALAM',
    'KELUARGA',
    'KEPALA',
    'ANAK',
    'ISTRI',
    'SUAMI',
    'JENIS',
    'KELAMIN',
    'TEMPAT',
    'TGL',
    'LAHIR',
    'AGAMA',
    'PENDIDIKAN',
    'PEKERJAAN',
    'GOLONGAN',
    'DARAH',
    'TANGGAL',
    // OCR noise
    'RR',
    'OW',
    'FR',
    'RE',
    'OL',
    'EF',
    'SE',
    'AP',
    'FE',
    'AW',
    'EV',
    'AN',
    'OO',
    'HE',
    'DE',
    'DD',
    'IU',
    'MIA',
    'BII',
    'BI',
    'BH',
    'CE',
    'NP',
    'SS',
    'WS',
    'SO',
    'WA',
    'WN',
    'II',
    'TT',
    'PP',
    'NW',
    'RI',
  };

  final words = cleaned.split(' ').where((w) {
    if (w.isEmpty || w.length < 2) return false;
    if (noise.contains(w)) return false;
    // Skip words with repeating characters like "OOO", "RRR"
    if (w.length >= 3 && RegExp(r'^(.)\1+$').hasMatch(w)) return false;
    // Skip words without reasonable vowel ratio
    if (w.length >= 4 && !_hasReasonableVowelRatio(w)) return false;
    return true;
  }).toList();

  if (words.isEmpty) return '';

  // Take last valid words (names usually appear at the end before NIK)
  // But limit to reasonable name length (max 5 words)
  final nameWords = words.length > 5 ? words.sublist(words.length - 5) : words;

  // Merge fragmented words
  final merged = _mergeFragmentedNameWords(nameWords);
  return merged.join(' ').trim();
}

/// Extract tempat lahir from context (text after NIK)
String _extractTempatLahirFromContext(String context) {
  // Try to find city name pattern after gender
  final afterGender = context
      .replaceFirst(RegExp(r'LAKI[-\s]*LAKI|PEREMPUAN|LK|PR'), '')
      .trim();

  // Look for text before date pattern
  final beforeDate = afterGender.split(RegExp(r'\d{1,2}[-/]\d{1,2}')).first;
  var candidate = beforeDate
      .replaceAll(RegExp(r'\d+'), ' ')
      .replaceAll(RegExp(r'[^A-Z\s]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();

  // Remove noise
  const noise = {
    'WNI',
    'ISLAM',
    'KRISTEN',
    'KATOLIK',
    'HINDU',
    'BUDHA',
    'KONGHUCU',
    'SLTA',
    'SLTP',
    'SD',
    'SARJANA',
    'DIPLOMA',
    'WIRASWASTA',
    'KARYAWAN',
    'SWASTA',
    'PNS',
    'PELAJAR',
    'MAHASISWA',
    'RR',
    'OW',
    'FR',
    'DD',
    'II',
    'TT',
    'PP',
    'AN',
  };

  final words = candidate.split(' ').where((w) {
    if (w.isEmpty || w.length < 3) return false;
    if (noise.contains(w)) return false;
    if (!_hasReasonableVowelRatio(w)) return false;
    return true;
  }).toList();

  if (words.isEmpty) return '';

  final result = words.take(2).join(' ');

  // Try fuzzy matching
  final fuzzy = _fuzzyMatchTempatLahirWeb(result);
  return fuzzy ?? (result.length >= 4 ? result : '');
}

/// Extract pendidikan from context (text after NIK)
String _extractPendidikanFromContext(String context) {
  // Direct keyword matching first
  final upper = context.toUpperCase();

  if (upper.contains('AKADEMI') ||
      upper.contains('DIPLOMA III') ||
      upper.contains('SARJANA MUDA')) {
    return 'AKADEMI/DIPLOMA III/SARJANA MUDA';
  }
  if (upper.contains('DIPLOMA IV') || upper.contains('STRATA I')) {
    return 'DIPLOMA IV/STRATA I';
  }
  if (upper.contains('STRATA II')) return 'STRATA II';
  if (upper.contains('STRATA III')) return 'STRATA III';
  if (upper.contains('SLTA')) return 'SLTA/SEDERAJAT';
  if (upper.contains('SLTP')) return 'SLTP/SEDERAJAT';
  if (upper.contains('TAMAT') && upper.contains('SD')) {
    return 'TAMAT SD/SEDERAJAT';
  }
  if ((upper.contains('BELUM') || upper.contains('TIDAK')) &&
      (upper.contains('SEKOLAH') || upper.contains('TAMAT'))) {
    if (upper.contains('TAMAT')) return 'BELUM TAMAT SD/SEDERAJAT';
    return 'TIDAK/BELUM SEKOLAH';
  }

  // Fuzzy match
  final compact = upper.replaceAll(RegExp(r'[\s/]+'), '');
  return _fuzzyMatchPendidikan(compact) ?? '';
}

/// Extract pekerjaan from context (text after NIK)
String _extractPekerjaanFromContext(String context) {
  final upper = context.toUpperCase();

  if (upper.contains('WIRASWASTA')) return 'WIRASWASTA';
  if (upper.contains('KARYAWAN') && upper.contains('SWASTA')) {
    return 'KARYAWAN SWASTA';
  }
  if (upper.contains('KARYAWAN')) return 'KARYAWAN SWASTA';
  if (upper.contains('PELAJAR') || upper.contains('MAHASISWA')) {
    return 'PELAJAR/MAHASISWA';
  }
  if ((upper.contains('BELUM') || upper.contains('TIDAK')) &&
      upper.contains('BEKERJA')) {
    return 'BELUM/TIDAK BEKERJA';
  }
  if (upper.contains('MENGURUS') && upper.contains('RUMAH')) {
    return 'MENGURUS RUMAH TANGGA';
  }
  if (upper.contains('PNS')) return 'PNS';
  if (upper.contains('PETANI')) return 'PETANI';
  if (upper.contains('PEDAGANG')) return 'PEDAGANG';
  if (upper.contains('BURUH')) return 'BURUH';
  if (upper.contains('NELAYAN')) return 'NELAYAN';
  if (upper.contains('PENSIUNAN')) return 'PENSIUNAN';

  // Fuzzy match
  final compact = upper.replaceAll(RegExp(r'[\s/]+'), '');
  return _fuzzyMatchPekerjaanWeb(compact) ?? '';
}

// ═══════════════════════════════════════════════════════════════════════════
// COMPREHENSIVE PREPROCESSING PIPELINE FOR OCR
// Pipeline: Grayscale → Contrast Enhancement → Binarization → Noise Removal →
//           Grid Line Removal → Text Sharpening
// ═══════════════════════════════════════════════════════════════════════════

/// Main preprocessing function with full pipeline
String _cropAndPreprocessForOcr({
  required html.ImageElement image,
  required int sx,
  required int sy,
  required int sw,
  required int sh,
  int scale = 3,
  bool removeGridLines = false,
}) {
  final canvas = html.CanvasElement(width: sw * scale, height: sh * scale);
  final ctx = canvas.context2D;

  // Draw scaled image
  ctx.drawImageScaledFromSource(
    image,
    sx.toDouble(),
    sy.toDouble(),
    sw.toDouble(),
    sh.toDouble(),
    0,
    0,
    (sw * scale).toDouble(),
    (sh * scale).toDouble(),
  );

  final imageData = ctx.getImageData(0, 0, canvas.width!, canvas.height!);
  final data = imageData.data;
  final w = canvas.width!;
  final h = canvas.height!;

  // ═══════════════════════════════════════════════════════════════════════
  // STEP 1: Convert to Grayscale
  // ═══════════════════════════════════════════════════════════════════════
  final gray = List<int>.filled(w * h, 0);
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final i = (y * w + x) * 4;
      final g = (0.299 * data[i] + 0.587 * data[i + 1] + 0.114 * data[i + 2])
          .round()
          .clamp(0, 255);
      gray[y * w + x] = g;
    }
  }

  // ═══════════════════════════════════════════════════════════════════════
  // STEP 2: Contrast Enhancement (CLAHE-like adaptive contrast)
  // ═══════════════════════════════════════════════════════════════════════
  _applyAdaptiveContrast(gray, w, h);

  // ═══════════════════════════════════════════════════════════════════════
  // STEP 3: Adaptive Threshold Binarization (Sauvola-like)
  // ═══════════════════════════════════════════════════════════════════════
  final binary = _applyAdaptiveThreshold(gray, w, h);

  // ═══════════════════════════════════════════════════════════════════════
  // STEP 4: Noise Removal (Morphological Opening)
  // ═══════════════════════════════════════════════════════════════════════
  _removeSmallNoise(binary, w, h, minSize: 3);

  // ═══════════════════════════════════════════════════════════════════════
  // STEP 5: Grid Line Removal
  // ═══════════════════════════════════════════════════════════════════════
  if (removeGridLines) {
    _removeGridLines(binary, w, h, scale: scale);
  }

  // ═══════════════════════════════════════════════════════════════════════
  // STEP 6: Text Sharpening (Dilation then Erosion for text enhancement)
  // ═══════════════════════════════════════════════════════════════════════
  _sharpenText(binary, w, h);

  // Write back to image data
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final i = (y * w + x) * 4;
      final v = binary[y * w + x];
      data[i] = v;
      data[i + 1] = v;
      data[i + 2] = v;
      data[i + 3] = 255;
    }
  }

  ctx.putImageData(imageData, 0, 0);
  return canvas.toDataUrl('image/png', 1.0); // Use PNG for lossless
}

/// Apply adaptive contrast enhancement (simplified CLAHE)
void _applyAdaptiveContrast(List<int> gray, int w, int h) {
  // Compute global histogram
  final histogram = List<int>.filled(256, 0);
  for (final g in gray) {
    histogram[g]++;
  }

  // Compute cumulative distribution function (CDF)
  final cdf = List<int>.filled(256, 0);
  cdf[0] = histogram[0];
  for (var i = 1; i < 256; i++) {
    cdf[i] = cdf[i - 1] + histogram[i];
  }

  // Find min non-zero CDF value
  var cdfMin = 0;
  for (var i = 0; i < 256; i++) {
    if (cdf[i] > 0) {
      cdfMin = cdf[i];
      break;
    }
  }

  // Histogram equalization
  final totalPixels = w * h;
  final lookup = List<int>.filled(256, 0);
  for (var i = 0; i < 256; i++) {
    if (cdf[i] > 0) {
      lookup[i] = (((cdf[i] - cdfMin) / (totalPixels - cdfMin)) * 255)
          .round()
          .clamp(0, 255);
    }
  }

  // Apply lookup table
  for (var i = 0; i < gray.length; i++) {
    gray[i] = lookup[gray[i]];
  }
}

/// Apply adaptive threshold (Sauvola-like method)
List<int> _applyAdaptiveThreshold(List<int> gray, int w, int h) {
  final binary = List<int>.filled(w * h, 255);

  // Window size for local threshold (should be odd)
  final windowSize = 15;
  final halfWindow = windowSize ~/ 2;
  final k = 0.2; // Sauvola parameter
  final r = 128.0; // Dynamic range of standard deviation

  // Compute integral image and integral of squares for fast mean/variance
  final integral = List<int>.filled((w + 1) * (h + 1), 0);
  final integralSq = List<int>.filled((w + 1) * (h + 1), 0);

  for (var y = 0; y < h; y++) {
    var rowSum = 0;
    var rowSumSq = 0;
    for (var x = 0; x < w; x++) {
      final g = gray[y * w + x];
      rowSum += g;
      rowSumSq += g * g;
      integral[(y + 1) * (w + 1) + (x + 1)] =
          integral[y * (w + 1) + (x + 1)] + rowSum;
      integralSq[(y + 1) * (w + 1) + (x + 1)] =
          integralSq[y * (w + 1) + (x + 1)] + rowSumSq;
    }
  }

  // Apply local threshold
  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      // Define window bounds
      final x1 = (x - halfWindow).clamp(0, w - 1);
      final y1 = (y - halfWindow).clamp(0, h - 1);
      final x2 = (x + halfWindow).clamp(0, w - 1);
      final y2 = (y + halfWindow).clamp(0, h - 1);
      final count = (x2 - x1 + 1) * (y2 - y1 + 1);

      // Compute sum and sum of squares in window using integral images
      final sum =
          integral[(y2 + 1) * (w + 1) + (x2 + 1)] -
          integral[(y1) * (w + 1) + (x2 + 1)] -
          integral[(y2 + 1) * (w + 1) + (x1)] +
          integral[(y1) * (w + 1) + (x1)];
      final sumSq =
          integralSq[(y2 + 1) * (w + 1) + (x2 + 1)] -
          integralSq[(y1) * (w + 1) + (x2 + 1)] -
          integralSq[(y2 + 1) * (w + 1) + (x1)] +
          integralSq[(y1) * (w + 1) + (x1)];

      final mean = sum / count;
      final variance = (sumSq / count) - (mean * mean);
      final stdDev = variance > 0 ? _sqrt(variance) : 0.0;

      // Sauvola threshold
      final threshold = mean * (1 + k * ((stdDev / r) - 1));

      final pixel = gray[y * w + x];
      binary[y * w + x] = pixel > threshold ? 255 : 0;
    }
  }

  return binary;
}

/// Simple square root approximation
double _sqrt(double x) {
  if (x <= 0) return 0;
  var guess = x / 2;
  for (var i = 0; i < 10; i++) {
    guess = (guess + x / guess) / 2;
  }
  return guess;
}

/// Remove small noise artifacts
void _removeSmallNoise(List<int> binary, int w, int h, {int minSize = 3}) {
  // Mark small connected components for removal
  final visited = List<bool>.filled(w * h, false);

  for (var y = 0; y < h; y++) {
    for (var x = 0; x < w; x++) {
      final idx = y * w + x;
      if (binary[idx] == 0 && !visited[idx]) {
        // Flood fill to find connected component
        final component = <int>[];
        final stack = <int>[idx];

        while (stack.isNotEmpty) {
          final curr = stack.removeLast();
          if (visited[curr]) continue;
          visited[curr] = true;

          if (binary[curr] == 0) {
            component.add(curr);
            final cy = curr ~/ w;
            final cx = curr % w;

            // 4-connectivity neighbors
            if (cx > 0) stack.add(cy * w + cx - 1);
            if (cx < w - 1) stack.add(cy * w + cx + 1);
            if (cy > 0) stack.add((cy - 1) * w + cx);
            if (cy < h - 1) stack.add((cy + 1) * w + cx);
          }
        }

        // Remove small components (noise)
        if (component.length < minSize * minSize) {
          for (final idx in component) {
            binary[idx] = 255;
          }
        }
      }
    }
  }
}

/// Remove horizontal and vertical grid lines
void _removeGridLines(List<int> binary, int w, int h, {int scale = 3}) {
  final maxLineThickness = 5 * scale;
  final minLineLength = 20 * scale;

  // Detect and remove horizontal lines
  for (var y = 0; y < h; y++) {
    var runStart = -1;
    var linePixels = <int>[];

    for (var x = 0; x <= w; x++) {
      final isBlack = x < w && binary[y * w + x] == 0;

      if (isBlack) {
        if (runStart < 0) runStart = x;
        linePixels.add(y * w + x);
      } else {
        if (runStart >= 0) {
          final runLen = x - runStart;
          // Check if this is a horizontal line (long and thin)
          if (runLen >= minLineLength) {
            // Check thickness by looking at nearby rows
            var avgThickness = 0;
            for (var dx = runStart; dx < x; dx += runLen ~/ 10 + 1) {
              var thickness = 0;
              for (var dy = -maxLineThickness; dy <= maxLineThickness; dy++) {
                final ny = y + dy;
                if (ny >= 0 && ny < h && binary[ny * w + dx] == 0) {
                  thickness++;
                }
              }
              avgThickness += thickness;
            }
            avgThickness ~/= (runLen ~/ (runLen ~/ 10 + 1)) + 1;

            // Remove if it's a thin line
            if (avgThickness <= maxLineThickness) {
              for (final idx in linePixels) {
                binary[idx] = 255;
              }
            }
          }
        }
        runStart = -1;
        linePixels = [];
      }
    }
  }

  // Detect and remove vertical lines
  for (var x = 0; x < w; x++) {
    var runStart = -1;
    var linePixels = <int>[];

    for (var y = 0; y <= h; y++) {
      final isBlack = y < h && binary[y * w + x] == 0;

      if (isBlack) {
        if (runStart < 0) runStart = y;
        linePixels.add(y * w + x);
      } else {
        if (runStart >= 0) {
          final runLen = y - runStart;
          // Check if this is a vertical line (long and thin)
          if (runLen >= minLineLength) {
            // Check thickness by looking at nearby columns
            var avgThickness = 0;
            for (var dy = runStart; dy < y; dy += runLen ~/ 10 + 1) {
              var thickness = 0;
              for (var dx = -maxLineThickness; dx <= maxLineThickness; dx++) {
                final nx = x + dx;
                if (nx >= 0 && nx < w && binary[dy * w + nx] == 0) {
                  thickness++;
                }
              }
              avgThickness += thickness;
            }
            avgThickness ~/= (runLen ~/ (runLen ~/ 10 + 1)) + 1;

            // Remove if it's a thin line
            if (avgThickness <= maxLineThickness) {
              for (final idx in linePixels) {
                binary[idx] = 255;
              }
            }
          }
        }
        runStart = -1;
        linePixels = [];
      }
    }
  }
}

/// Sharpen text using morphological closing (dilate then erode)
void _sharpenText(List<int> binary, int w, int h) {
  // Make a copy
  final temp = List<int>.from(binary);

  // Slight dilation (3x3 kernel) to fill small gaps in text
  for (var y = 1; y < h - 1; y++) {
    for (var x = 1; x < w - 1; x++) {
      if (temp[y * w + x] == 0) {
        // Already black, keep it
        continue;
      }
      // Check 3x3 neighborhood - if any neighbor is black, check pattern
      var blackCount = 0;
      for (var dy = -1; dy <= 1; dy++) {
        for (var dx = -1; dx <= 1; dx++) {
          if (temp[(y + dy) * w + (x + dx)] == 0) {
            blackCount++;
          }
        }
      }
      // Only fill if it's surrounded by enough black pixels (part of text)
      if (blackCount >= 4) {
        binary[y * w + x] = 0;
      }
    }
  }
}

Future<String?> _createMemberTableCropDataUrl(String objectUrl) async {
  try {
    final image = html.ImageElement(src: objectUrl);
    await image.onLoad.first;
    final width = image.naturalWidth;
    final height = image.naturalHeight;
    if (width <= 0 || height <= 0) return null;

    final sx = (width * 0.015).round();
    final sy = (height * 0.165).round();
    final sw = (width * 0.97).round();
    final sh = (height * 0.275).round();
    if (sw <= 0 || sh <= 0) return null;

    final safeX = sx.clamp(0, width - 1);
    final safeY = sy.clamp(0, height - 1);
    final safeW = sw.clamp(1, width - safeX);
    final safeH = sh.clamp(1, height - safeY);

    final canvas = html.CanvasElement(width: safeW * 2, height: safeH * 2);
    final ctx = canvas.context2D;
    ctx.drawImageScaledFromSource(
      image,
      safeX.toDouble(),
      safeY.toDouble(),
      safeW.toDouble(),
      safeH.toDouble(),
      0,
      0,
      (safeW * 2).toDouble(),
      (safeH * 2).toDouble(),
    );
    return canvas.toDataUrl('image/jpeg', 0.98);
  } catch (_) {
    return null;
  }
}

Future<String> _extractStructuredMemberRows({
  required String objectUrl,
  required JSObject tesseract,
  required String lang,
}) async {
  try {
    final image = html.ImageElement(src: objectUrl);
    await image.onLoad.first;
    final width = image.naturalWidth;
    final height = image.naturalHeight;
    if (width <= 0 || height <= 0) return '';

    final rows = <String>[];
    var emptyStreak = 0;

    for (var rowIndex = 0; rowIndex < 10; rowIndex++) {
      final rowRect = _memberRowRect(
        imageWidth: width,
        imageHeight: height,
        rowIndex: rowIndex,
      );
      if (rowRect == null) continue;

      Future<String> readColumn({
        required double startRatio,
        required double widthRatio,
        int scale = 3,
        bool binarize = true,
        String? forceLang,
      }) async {
        final colRect = _columnRectInRow(
          rowRect: rowRect,
          startRatio: startRatio,
          widthRatio: widthRatio,
          imageWidth: width,
          imageHeight: height,
        );
        if (colRect == null) return '';
        final dataUrl = _cropDataUrlFromImage(
          image: image,
          sx: colRect.$1,
          sy: colRect.$2,
          sw: colRect.$3,
          sh: colRect.$4,
          scale: scale,
          binarize: binarize,
        );
        final text = await _recognizeText(
          tesseract: tesseract,
          source: dataUrl,
          lang: forceLang ?? lang,
        );
        return text
            .replaceAll('\n', ' ')
            .replaceAll(RegExp(r'\s+'), ' ')
            .trim();
      }

      // Read the full row first for fallback data
      final rowRaw = await readColumn(
        startRatio: 0.0,
        widthRatio: 1.0,
        scale: 3,
        binarize: true,
      );

      // Column ratios adjusted to match typical KK layout:
      // Nama Lengkap: ~0-20% of table width
      // NIK: ~20-35%
      // Jenis Kelamin: ~35-43%
      // Tempat Lahir: ~43-53%
      // Tanggal Lahir: ~53-61%
      // Agama: ~61-68%
      // Pendidikan: ~68-80%
      // Pekerjaan: ~80-92%
      // Golongan Darah: ~92-100%
      final nameRaw = await readColumn(
        startRatio: 0.01,
        widthRatio: 0.20,
        scale: 4,
        binarize: true,
      );
      final nikRaw = await readColumn(
        startRatio: 0.20,
        widthRatio: 0.16,
        scale: 4,
        binarize: true,
        forceLang: 'eng',
      );
      final jkRaw = await readColumn(
        startRatio: 0.35,
        widthRatio: 0.08,
        scale: 4,
        binarize: true,
      );
      final tempatRaw = await readColumn(
        startRatio: 0.43,
        widthRatio: 0.10,
        scale: 3,
        binarize: true,
      );
      final tglRaw = await readColumn(
        startRatio: 0.53,
        widthRatio: 0.08,
        scale: 4,
        binarize: true,
        forceLang: 'eng',
      );
      final agamaRaw = await readColumn(
        startRatio: 0.61,
        widthRatio: 0.07,
        scale: 3,
        binarize: true,
      );

      final nik = _normalizeNikCandidate('$nikRaw $rowRaw');
      var nama = _normalizeNameCandidate(nameRaw);
      if (nama.isEmpty) {
        nama = _extractNameFromRowRaw(rowRaw);
      }
      // If still empty, try extracting the name from the beginning of the full row
      if (nama.isEmpty) {
        nama = _extractNameBeforeDigits(rowRaw);
      }
      final jenisKelamin = _normalizeGenderCandidate('$jkRaw $rowRaw');
      final tempatLahir = _normalizeTempatLahirCandidate(tempatRaw);
      // Prefer date from dedicated column; fallback to rowRaw only if column fails
      var tanggalLahir = _normalizeDateCandidate(tglRaw);
      if (tanggalLahir.isEmpty) {
        tanggalLahir = _normalizeDateCandidate(rowRaw);
      }
      // Prefer agama from dedicated column; fallback to rowRaw
      var agama = _normalizeAgamaCandidate(agamaRaw);
      if (agama.isEmpty) {
        agama = _normalizeAgamaCandidate(rowRaw);
      }
      // Also try to read pendidikan and pekerjaan columns
      final pendidikanRaw = await readColumn(
        startRatio: 0.68,
        widthRatio: 0.13,
        scale: 3,
        binarize: true,
      );
      final pekerjaanRaw = await readColumn(
        startRatio: 0.81,
        widthRatio: 0.11,
        scale: 3,
        binarize: true,
      );
      final goldarRaw = await readColumn(
        startRatio: 0.92,
        widthRatio: 0.08,
        scale: 3,
        binarize: true,
      );
      final pendidikan = _normalizePendidikanCandidate(pendidikanRaw);
      final pekerjaan = _normalizePekerjaanCandidate(pekerjaanRaw);
      final goldar = _normalizeGolDarahCandidate('$goldarRaw $rowRaw');

      // Stricter validation: need a meaningful name (>= 4 alpha chars)
      // OR a valid-looking 16-digit NIK. Reject short noise names.
      final nameAlphaLen = nama.replaceAll(RegExp(r'[^A-Za-z]'), '').length;
      final hasGoodName = nama.isNotEmpty && nameAlphaLen >= 4;
      final hasGoodNik = nik.length == 16 && _looksLikeNik(nik);
      final hasData = hasGoodName || hasGoodNik;
      if (kDebugMode) {
        debugPrint(
          '[KK OCR WEB] MEMBER STRUCT[$rowIndex] => nama=$nama, nik=$nik, '
          'jk=$jenisKelamin, tempat=$tempatLahir, tgl=$tanggalLahir, '
          'agama=$agama, pendidikan=$pendidikan, pekerjaan=$pekerjaan, goldar=$goldar',
        );
      }

      if (hasData) {
        rows.add(
          '$_memberStructPrefix$nama|$nik|$jenisKelamin|$tempatLahir|$tanggalLahir|'
          '$agama|$pendidikan|$pekerjaan|$goldar',
        );
        emptyStreak = 0;
      } else {
        emptyStreak += 1;
      }

      if (rowIndex >= 4 && emptyStreak >= 2) break;
    }

    return rows.join('\n');
  } catch (_) {
    return '';
  }
}

Future<String> _extractMemberRowsText({
  required String objectUrl,
  required JSObject tesseract,
  required String lang,
}) async {
  try {
    final image = html.ImageElement(src: objectUrl);
    await image.onLoad.first;
    final width = image.naturalWidth;
    final height = image.naturalHeight;
    if (width <= 0 || height <= 0) return '';

    final rowTexts = <String>[];
    var emptyStreak = 0;
    for (var rowIndex = 0; rowIndex < 10; rowIndex++) {
      final rect = _memberRowRect(
        imageWidth: width,
        imageHeight: height,
        rowIndex: rowIndex,
      );
      if (rect == null) continue;

      final rowDataUrl = _cropDataUrlFromImage(
        image: image,
        sx: rect.$1,
        sy: rect.$2,
        sw: rect.$3,
        sh: rect.$4,
        scale: 3,
        binarize: true,
      );
      final rowText = (await _recognizeText(
        tesseract: tesseract,
        source: rowDataUrl,
        lang: lang,
      )).replaceAll('\n', ' ').replaceAll(RegExp(r'\s+'), ' ').trim();
      if (kDebugMode) {
        debugPrint('[KK OCR WEB] MEMBER ROW[$rowIndex] => $rowText');
      }

      final digitsCount = RegExp(r'\d').allMatches(rowText).length;
      final hasLikelyName = RegExp(
        r'[A-Z]{3,}',
      ).hasMatch(rowText.toUpperCase());
      final hasData =
          digitsCount >= 8 || (hasLikelyName && rowText.length > 12);
      if (hasData) {
        rowTexts.add(rowText);
        emptyStreak = 0;
      } else {
        emptyStreak += 1;
      }

      if (rowIndex >= 3 && emptyStreak >= 3) {
        break;
      }
    }

    return rowTexts.join('\n');
  } catch (_) {
    return '';
  }
}

(int, int, int, int)? _columnRectInRow({
  required (int, int, int, int) rowRect,
  required double startRatio,
  required double widthRatio,
  required int imageWidth,
  required int imageHeight,
}) {
  final rowX = rowRect.$1;
  final rowY = rowRect.$2;
  final rowW = rowRect.$3;
  final rowH = rowRect.$4;
  if (rowW <= 0 || rowH <= 0) return null;
  if (widthRatio <= 0) return null;

  final colX = rowX + (rowW * startRatio).round();
  final colW = (rowW * widthRatio).round();
  if (colW <= 0) return null;

  final safeX = colX.clamp(0, imageWidth - 1);
  final safeY = rowY.clamp(0, imageHeight - 1);
  final safeW = colW.clamp(1, imageWidth - safeX);
  final safeH = rowH.clamp(1, imageHeight - safeY);
  return (safeX, safeY, safeW, safeH);
}

(int, int, int, int)? _memberTableRect({
  required int imageWidth,
  required int imageHeight,
}) {
  // KK member data table analysis:
  // - KK header (logo, No KK, alamat): 0-12% of image height
  // - Member table starts at: ~12-13% of image height
  // - Member table ends at: ~55-58% of image height (extended for safety)
  // - Table header row (No, Nama Lengkap, NIK...): ~4-5% of table
  // - Each data row: ~7-8% of table
  // Extended to 45% height to ensure we capture all rows including
  // families with 5+ members
  final x = (imageWidth * 0.005).round();
  final y = (imageHeight * 0.125).round(); // Start at 12.5%
  final w = (imageWidth * 0.99).round();
  final h = (imageHeight * 0.45).round(); // End at ~57.5% - extended
  if (w <= 0 || h <= 0) return null;
  final safeX = x.clamp(0, imageWidth - 1);
  final safeY = y.clamp(0, imageHeight - 1);
  final safeW = w.clamp(1, imageWidth - safeX);
  final safeH = h.clamp(1, imageHeight - safeY);
  return (safeX, safeY, safeW, safeH);
}

(int, int, int, int)? _memberRowRect({
  required int imageWidth,
  required int imageHeight,
  required int rowIndex,
}) {
  final table = _memberTableRect(
    imageWidth: imageWidth,
    imageHeight: imageHeight,
  );
  if (table == null) return null;

  final tableX = table.$1;
  final tableY = table.$2;
  final tableW = table.$3;
  final tableH = table.$4;

  // Skip the header rows:
  // - Row 0: "Jenis Kelamin, Tempat Lahir..." labels (~5%)
  // - Row 1: "(1) (2) (3)..." numbers (~3%)
  // Total header = ~8% of table height
  final dataX = tableX + (tableW * 0.005).round();
  final dataW = (tableW * 0.99).round();
  final headerHeight = (tableH * 0.085).round(); // 8.5% for header rows
  final dataStartY = tableY + headerHeight;

  // Each data row is about 8.5% of table height
  // Standard KK has 10 data rows visible, 10 * 8.5% = 85% + 8.5% header ≈ 93.5%
  // Using 8.5% gives more overlap between rows which helps capture text
  // that might span row boundaries
  final rowHeight = (tableH * 0.085).round();

  // Add small vertical offset to center text within capture area
  final rowOffset = (rowIndex * rowHeight * 0.95).round();
  final dataY = dataStartY + rowOffset;

  if (dataW <= 0 || rowHeight <= 0) return null;

  final safeX = dataX.clamp(0, imageWidth - 1);
  final safeY = dataY.clamp(0, imageHeight - 1);
  final safeW = dataW.clamp(1, imageWidth - safeX);
  // Add padding to ensure full row capture - use 10% extra height
  final safeH = (rowHeight * 1.1).round().clamp(1, imageHeight - safeY);
  return (safeX, safeY, safeW, safeH);
}

String _normalizeTextField(String input) {
  return input
      .toUpperCase()
      .replaceAll(RegExp(r'[^A-Z0-9/\-\s]'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
}

/// Normalize tempat lahir from OCR column crop.
/// Filters out garbled text like "22091", "G 2505 1", "J DARA IU MIA 18-08-2"
String _normalizeTempatLahirCandidate(String input) {
  var cleaned = _normalizeTextField(input);
  if (cleaned.isEmpty) return '';

  // Remove embedded dates
  cleaned = cleaned
      .replaceAll(RegExp(r'\b\d{1,2}[-/.]\d{1,2}[-/.]\d{1,4}\b'), '')
      .trim();

  // If purely numeric, it's garbled
  if (RegExp(r'^[\d\s]+$').hasMatch(cleaned)) return '';

  // Filter noise tokens
  const noise = {
    'IU',
    'MIA',
    'DD',
    'RR',
    'OW',
    'RE',
    'OL',
    'EF',
    'FR',
    'SE',
    'AP',
    'FE',
    'AW',
    'EV',
    'AN',
    'OO',
    'HE',
    'DE',
    'BII',
    'BI',
    'BH',
    'CE',
    'NP',
    'SS',
    'WS',
    'SO',
    'WA',
    'WN',
    'WNI',
  };
  final words = cleaned.split(' ').where((w) {
    if (w.isEmpty) return false;
    if (RegExp(r'^[\d]+$').hasMatch(w)) return false;
    if (w.length <= 1) return false;
    if (w.length <= 2 && RegExp(r'\d').hasMatch(w)) return false;
    if (noise.contains(w)) return false;
    return true;
  }).toList();

  if (words.isEmpty) return '';
  final result = words.join(' ').trim();
  if (result.length < 3) return '';
  final alphaCount = result.replaceAll(RegExp(r'[^A-Z]'), '').length;
  if (alphaCount < 3) return '';

  // Strip leading single-character noise
  final resultClean = result.replaceFirst(RegExp(r'^[A-Z]\s+'), '').trim();
  if (resultClean.isEmpty || resultClean.length < 3) return '';

  // Try fuzzy matching against common Indonesian city/regency names
  final fuzzyResult = _fuzzyMatchTempatLahirWeb(resultClean);
  if (fuzzyResult != null) return fuzzyResult;

  // If the remaining text is very short (< 5 chars) and didn't fuzzy-match,
  // it's likely OCR noise like "DARA", "BARAT" fragments, etc.
  if (resultClean.length <= 4) return '';

  return resultClean;
}

String _normalizeNameCandidate(String input) {
  var cleaned = _normalizeTextField(input);
  if (cleaned.isEmpty) return '';

  // Strip leading digits and row numbers (OCR may capture "No" column)
  cleaned = cleaned.replaceFirst(RegExp(r'^\d+\s*'), '').trim();
  // Strip leading single character noise (e.g., "J ARINI" → "ARINI")
  // This happens when OCR captures grid borders as a letter
  cleaned = cleaned.replaceFirst(RegExp(r'^[A-Z]\s+'), '').trim();

  const blocked = {
    'WNI',
    'ISLAM',
    'LAKI',
    'PEREMPUAN',
    'KARYAWAN',
    'SWASTA',
    'WIRASWASTA',
    'ANAK',
    'KEPALA',
    'KELUARGA',
    'STATUS',
    'HUBUNGAN',
    'NAMA',
    'LENGKAP',
    'NIK',
    'JENIS',
    'KELAMIN',
    'TEMPAT',
    'LAHIR',
    'AGAMA',
    'PENDIDIKAN',
    'PEKERJAAN',
    'GOLONGAN',
    'DARAH',
    'TANGGAL',
  };
  // Also filter out short OCR noise fragments
  const ocrNoise = {
    'YE',
    'EL',
    'EE',
    'WS',
    'SO',
    'CE',
    'NP',
    'SS',
    'FOO',
    'DIN',
    'MAL',
    'TNVAU',
    'TOMA',
    'IU',
    'MIA',
    'DD',
    'RR',
    'OW',
    'RE',
    'OL',
    'EF',
    'FR',
    'RV',
    'SE',
    'AP',
    'FE',
    'AW',
    'EV',
    'AN',
    'OO',
    'HE',
    'DE',
    'WA',
    'WN',
    'WNI',
    'II',
    'TT',
    'PP',
    'NW',
    'RI',
    'BH',
    'BI',
    'BII',
    'IVIUT',
    'IAIVHIIVI',
    'ALYOTNAL',
    'IVAU',
    'OMANTET',
    'IVA',
    'IVI',
    'OMA',
    'OMT',
  };
  final words = cleaned
      .split(' ')
      .where(
        (w) =>
            w.length >= 2 &&
            !blocked.contains(w) &&
            !ocrNoise.contains(w) &&
            !(w.length <= 3 && RegExp(r'^(.)\1+$').hasMatch(w)) &&
            !(w.length >= 4 && !_hasReasonableVowelRatio(w)),
      )
      .toList();
  if (words.isEmpty) return '';
  if (words.length == 1 && words.first.length < 3) return '';
  // If total character count is too low, it's noise
  final totalChars = words.join('').length;
  if (totalChars < 4) return '';
  // If too many short noise words, skip
  final shortCount = words.where((w) => w.length <= 2).length;
  if (words.length >= 3 && shortCount / words.length > 0.6) return '';
  // Merge fragmented words: "FARDIANS YAH" → "FARDIANSYAH"
  final merged = _mergeFragmentedNameWords(words);
  return merged.take(6).join(' ');
}

String _extractNameFromRowRaw(String rowRaw) {
  final upper = _normalizeTextField(rowRaw);
  if (upper.isEmpty) return '';
  final beforeDigits = upper.split(RegExp(r'\d')).first.trim();
  return _normalizeNameCandidate(beforeDigits);
}

/// Merge OCR-fragmented words back together.
/// E.g. ['FARDIANS', 'YAH'] → ['FARDIANSYAH']
List<String> _mergeFragmentedNameWords(List<String> words) {
  if (words.length <= 1) return words;
  final result = <String>[words.first];
  for (var i = 1; i < words.length; i++) {
    final current = words[i];
    final prev = result.last;
    // Merge if current fragment is short (<=3 chars) and prev is longer
    if (current.length <= 3 && prev.length >= 3) {
      result[result.length - 1] = '$prev$current';
    } else if (prev.length <= 3 && current.length >= 3) {
      result[result.length - 1] = '$prev$current';
    } else {
      result.add(current);
    }
  }
  return result;
}

String _extractNameBeforeDigits(String rowRaw) {
  final upper = _normalizeTextField(rowRaw);
  if (upper.isEmpty) return '';
  // Extract text before the first long sequence of digits (NIK)
  final match = RegExp(r'^([A-Z\s]{3,}?)(?=\s*\d{6,})').firstMatch(upper);
  if (match != null) {
    return _normalizeNameCandidate(match.group(1) ?? '');
  }
  return '';
}

String _normalizeNikCandidate(String input) {
  final normalized = _normalizeOcrDigits(input.toUpperCase());
  final exact = RegExp(r'([0-9](?:\s*[0-9]){15})').allMatches(normalized);
  for (final match in exact) {
    final digits = match.group(0)!.replaceAll(RegExp(r'\s+'), '');
    if (digits.length == 16 && _looksLikeNik(digits)) {
      return digits;
    }
  }
  final digitsOnly = normalized.replaceAll(RegExp(r'[^0-9]'), '');
  if (digitsOnly.length < 16) return digitsOnly;
  for (var i = 0; i <= digitsOnly.length - 16; i++) {
    final candidate = digitsOnly.substring(i, i + 16);
    if (_looksLikeNik(candidate)) return candidate;
  }
  return digitsOnly.substring(0, 16);
}

String _normalizeOcrDigits(String input) {
  final buf = StringBuffer();
  for (final ch in input.split('')) {
    switch (ch.toUpperCase()) {
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
      case 'R': // R is sometimes OCR'd from 2 due to font style
        buf.write('2');
        break;
      case 'E':
        buf.write('3');
        break;
      case 'A':
      case 'H': // H is sometimes OCR'd from 4 due to horizontal stroke
        buf.write('4');
        break;
      case 'S':
        buf.write('5');
        break;
      case 'G':
        buf.write('6');
        break;
      case 'T':
      case 'F': // F is sometimes read as 7 due to stylized fonts
      case 'Y': // Y is sometimes read as 7 due to top branching
        buf.write('7');
        break;
      case 'B':
        buf.write('8');
        break;
      case 'P': // P is sometimes read as 9 due to rounded top
        buf.write('9');
        break;
      default:
        buf.write(ch);
    }
  }
  return buf.toString();
}

bool _looksLikeNik(String nik) {
  if (nik.length != 16) return false;
  if (RegExp(r'^0+$').hasMatch(nik)) return false;
  if (RegExp(r'^(\d)\1{15}$').hasMatch(nik)) return false;
  var day = int.tryParse(nik.substring(6, 8)) ?? 0;
  final month = int.tryParse(nik.substring(8, 10)) ?? 0;
  if (day > 40) day -= 40;
  if (day < 1 || day > 31) return false;
  if (month < 1 || month > 12) return false;
  return true;
}

/// Truncate string to max length for debug display
String _truncate(String text, int maxLen) {
  if (text.length <= maxLen) return text;
  return text.substring(0, maxLen);
}

/// Check if row text looks like a header row (not data)
bool _looksLikeHeaderRow(String rowText) {
  final upper = rowText.toUpperCase();

  // Header rows typically contain column labels
  const headerKeywords = [
    'JENIS KELAMIN',
    'TEMPAT LAHIR',
    'TANGGAL LAHIR',
    'AGAMA',
    'PENDIDIKAN',
    'PEKERJAAN',
    'GOLONGAN DARAH',
    'HUBUNGAN DALAM KELUARGA',
    'NAMA LENGKAP',
    'NOMOR INDUK KEPENDUDUKAN',
    'KEWARGANEGARAAN',
    'STATUS PERKAWINAN',
  ];

  var matchCount = 0;
  for (final kw in headerKeywords) {
    if (upper.contains(kw)) matchCount++;
  }

  // If 2+ header keywords found, likely a header row
  if (matchCount >= 2) return true;

  // Check for column number pattern like "(1) (2) (3)" or "1 2 3 4"
  final numberPattern = RegExp(r'\(?\d\)?\s*\(?\d\)?\s*\(?\d\)?\s*\(?\d\)?');
  if (numberPattern.hasMatch(upper)) {
    // Count how many isolated single digits (likely column numbers)
    final singleDigits = RegExp(r'(?<!\d)\d(?!\d)').allMatches(upper);
    if (singleDigits.length >= 5) return true;
  }

  return false;
}

String _normalizeGenderCandidate(String input) {
  final upper = input.toUpperCase();
  if (upper.contains('PEREMPUAN') || upper.contains(' PR ')) {
    return 'PEREMPUAN';
  }
  if (upper.contains('LAKI') || upper.contains(' LK ')) {
    return 'LAKI-LAKI';
  }
  return '';
}

String _normalizeDateCandidate(String input) {
  final upper = _normalizeOcrDigits(input.toUpperCase());
  final match = RegExp(
    r'([0-3]?\d)[\-/\. ]([0-1]?\d)[\-/\. ](\d{2,4})',
  ).firstMatch(upper);
  if (match == null) {
    return '';
  }
  final dd = (int.tryParse(match.group(1) ?? '') ?? 0).toString().padLeft(
    2,
    '0',
  );
  final mm = (int.tryParse(match.group(2) ?? '') ?? 0).toString().padLeft(
    2,
    '0',
  );
  final yyRaw = int.tryParse(match.group(3) ?? '') ?? 0;
  if (dd == '00' || mm == '00') return '';
  final yyyy = yyRaw < 100
      ? (yyRaw <= 30 ? 2000 + yyRaw : 1900 + yyRaw)
      : yyRaw;
  return '$dd-$mm-${yyyy.toString().padLeft(4, '0')}';
}

String _normalizeAgamaCandidate(String input) {
  final upper = input.toUpperCase();
  if (upper.contains('ISLAM')) return 'ISLAM';
  if (upper.contains('KRISTEN')) return 'KRISTEN';
  if (upper.contains('KATOLIK') ||
      upper.contains('KATHOLIK') ||
      upper.contains('KHATOLIK')) {
    return 'KHATOLIK';
  }
  if (upper.contains('BUDDHA') || upper.contains('BUDHA')) return 'BUDHA';
  if (upper.contains('HINDU')) return 'ISLAM';
  if (upper.contains('KONGHUCU') || upper.contains('KONGHUCHU')) {
    return 'ISLAM';
  }
  return '';
}

String _normalizeGolDarahCandidate(String input) {
  final upper = input.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9+-]'), '');
  if (upper.isEmpty) return '';
  if (upper.contains('TIDAKTAHU')) return 'TIDAK TAHU';
  // Check for blood type patterns
  for (final bt in [
    'AB+',
    'AB-',
    'AB',
    'A+',
    'A-',
    'B+',
    'B-',
    'O+',
    'O-',
    'A',
    'B',
    'O',
  ]) {
    if (upper == bt) return bt;
  }
  return '';
}

String _normalizePendidikanCandidate(String input) {
  final upper = _normalizeTextField(input);
  if (upper.isEmpty) return '';

  // Compact form: remove spaces/slashes for fuzzy matching
  final compact = upper.replaceAll(RegExp(r'[\s/]+'), '');

  const knownPendidikan = [
    'TIDAK/BELUM SEKOLAH',
    'BELUM TAMAT SD/SEDERAJAT',
    'TAMAT SD/SEDERAJAT',
    'SLTP/SEDERAJAT',
    'SLTA/SEDERAJAT',
    'DIPLOMA I/II',
    'AKADEMI/DIPLOMA III/SARJANA MUDA',
    'DIPLOMA IV/STRATA I',
    'STRATA II',
    'STRATA III',
  ];
  for (final p in knownPendidikan) {
    if (compact.contains(p.replaceAll('/', '').replaceAll(' ', ''))) return p;
    // Fuzzy: check if most words match
    final words = p.split(RegExp(r'[\s/]+'));
    final matchCount = words.where((w) => upper.contains(w)).length;
    if (matchCount >= words.length - 1 && words.length >= 2) return p;
  }

  // Partial keyword matches
  if (upper.contains('AKADEMI') ||
      upper.contains('DIPLOMA III') ||
      upper.contains('SARJANA MUDA') ||
      upper.contains('SARJANA') ||
      compact.contains('DIPLOMAIII') ||
      compact.contains('SARJANAMUDA')) {
    return 'AKADEMI/DIPLOMA III/SARJANA MUDA';
  }
  if (upper.contains('SLTA') || compact.contains('SLTA')) {
    return 'SLTA/SEDERAJAT';
  }
  if (upper.contains('SLTP') || compact.contains('SLTP')) {
    return 'SLTP/SEDERAJAT';
  }
  if (upper.contains('BELUM') && upper.contains('SEKOLAH')) {
    return 'TIDAK/BELUM SEKOLAH';
  }
  if (upper.contains('STRATA I') || upper.contains('DIPLOMA IV')) {
    return 'DIPLOMA IV/STRATA I';
  }
  if (upper.contains('STRATA II')) return 'STRATA II';
  if (upper.contains('STRATA III')) return 'STRATA III';

  // ──────────────────────────────────────────────────────────────
  // Aggressive OCR garble recovery:
  // Tesseract often misreads KK pendidikan in bizarre ways.
  // Build a "letter soup" from the OCR output and try to match
  // against known values using character-level similarity.
  // ──────────────────────────────────────────────────────────────
  final bestMatch = _fuzzyMatchPendidikan(compact);
  if (bestMatch != null) return bestMatch;

  // If it's short garbage, clear it
  final alphaCount = compact.replaceAll(RegExp(r'[^A-Z]'), '').length;
  if (alphaCount < 4) return '';

  return upper;
}

String _normalizePekerjaanCandidate(String input) {
  final upper = _normalizeTextField(input);
  if (upper.isEmpty) return '';

  final compact = upper.replaceAll(RegExp(r'[\s/]+'), '');

  const knownPekerjaan = [
    'WIRASWASTA',
    'KARYAWAN SWASTA',
    'BELUM/TIDAK BEKERJA',
    'PELAJAR/MAHASISWA',
    'PNS',
    'PETANI',
    'PEDAGANG',
    'BURUH',
    'NELAYAN',
    'PENSIUNAN',
    'MENGURUS RUMAH TANGGA',
  ];
  for (final p in knownPekerjaan) {
    if (compact.contains(p.replaceAll('/', '').replaceAll(' ', ''))) return p;
    final words = p.split(RegExp(r'[\s/]+'));
    final matchCount = words.where((w) => upper.contains(w)).length;
    if (matchCount >= words.length - 1 && words.length >= 2) return p;
  }
  if (upper.contains('WIRASWASTA')) return 'WIRASWASTA';
  if (upper.contains('KARYAWAN')) return 'KARYAWAN SWASTA';
  if (upper.contains('BELUM') && upper.contains('BEKERJA')) {
    return 'BELUM/TIDAK BEKERJA';
  }
  if (upper.contains('TIDAK') && upper.contains('BEKERJA')) {
    return 'BELUM/TIDAK BEKERJA';
  }
  if (upper.contains('PELAJAR')) return 'PELAJAR/MAHASISWA';

  // Fuzzy match
  final bestMatch = _fuzzyMatchPekerjaanWeb(compact);
  if (bestMatch != null) return bestMatch;

  return upper;
}

/// Fuzzy-match garbled pekerjaan from OCR.
String? _fuzzyMatchPekerjaanWeb(String compact) {
  const knownPekerjaan = [
    'WIRASWASTA',
    'KARYAWAN SWASTA',
    'BELUM/TIDAK BEKERJA',
    'PELAJAR/MAHASISWA',
    'PNS',
    'PETANI',
    'PEDAGANG',
    'BURUH',
    'NELAYAN',
    'PENSIUNAN',
    'MENGURUS RUMAH TANGGA',
  ];

  final inputAlpha = compact.replaceAll(RegExp(r'[^A-Z]'), '');
  if (inputAlpha.length < 3) return null;

  String? bestMatch;
  var bestScore = 0.0;

  for (final p in knownPekerjaan) {
    final pAlpha = p.replaceAll(RegExp(r'[^A-Z]'), '');
    final score = _bigramSimilarity(inputAlpha, pAlpha);
    if (score > bestScore) {
      bestScore = score;
      bestMatch = p;
    }
  }

  if (bestScore >= 0.35 && bestMatch != null) {
    return bestMatch;
  }
  return null;
}

String _cropDataUrlFromImage({
  required html.ImageElement image,
  required int sx,
  required int sy,
  required int sw,
  required int sh,
  int scale = 1,
  bool binarize = false,
}) {
  // Use the comprehensive preprocessing pipeline for better OCR results
  if (binarize) {
    return _cropAndPreprocessForOcr(
      image: image,
      sx: sx,
      sy: sy,
      sw: sw,
      sh: sh,
      scale: scale,
      removeGridLines: true, // Always remove grid lines for table cells
    );
  }

  // Non-binarized: just scale and return
  final canvas = html.CanvasElement(width: sw * scale, height: sh * scale);
  final ctx = canvas.context2D;
  ctx.drawImageScaledFromSource(
    image,
    sx.toDouble(),
    sy.toDouble(),
    sw.toDouble(),
    sh.toDouble(),
    0,
    0,
    (sw * scale).toDouble(),
    (sh * scale).toDouble(),
  );

  return canvas.toDataUrl('image/png', 1.0);
}

/// Check if a word has a reasonable vowel-to-consonant ratio for a name.
bool _hasReasonableVowelRatio(String word) {
  if (word.length < 4) return true;
  const vowels = {'A', 'E', 'I', 'O', 'U'};
  final upper = word.toUpperCase();
  final vowelCount = upper.split('').where((c) => vowels.contains(c)).length;
  final ratio = vowelCount / upper.length;
  if (ratio < 0.15) return false;
  if (RegExp(r'[^AEIOU]{5,}').hasMatch(upper)) return false;
  return true;
}

/// Fuzzy-match garbled OCR text against known pendidikan values.
/// Uses bigram similarity (Dice coefficient) to find the best match.
String? _fuzzyMatchPendidikan(String compact) {
  const knownPendidikan = [
    'TIDAK/BELUM SEKOLAH',
    'BELUM TAMAT SD/SEDERAJAT',
    'TAMAT SD/SEDERAJAT',
    'SLTP/SEDERAJAT',
    'SLTA/SEDERAJAT',
    'DIPLOMA I/II',
    'AKADEMI/DIPLOMA III/SARJANA MUDA',
    'DIPLOMA IV/STRATA I',
    'STRATA II',
    'STRATA III',
  ];

  final inputAlpha = compact.replaceAll(RegExp(r'[^A-Z]'), '');
  if (inputAlpha.length < 3) return null;

  String? bestMatch;
  var bestScore = 0.0;

  for (final p in knownPendidikan) {
    final pAlpha = p.replaceAll(RegExp(r'[^A-Z]'), '');
    final score = _bigramSimilarity(inputAlpha, pAlpha);
    if (score > bestScore) {
      bestScore = score;
      bestMatch = p;
    }
  }

  // Require a reasonable similarity threshold
  // Lower threshold for short inputs (they have fewer bigrams to match)
  final threshold = inputAlpha.length <= 6 ? 0.25 : 0.30;
  if (bestScore >= threshold && bestMatch != null) {
    return bestMatch;
  }
  return null;
}

/// Compute Dice coefficient (bigram similarity) between two strings.
double _bigramSimilarity(String a, String b) {
  if (a.isEmpty || b.isEmpty) return 0.0;
  if (a.length < 2 || b.length < 2) {
    return a == b ? 1.0 : 0.0;
  }
  final bigramsA = <String>{};
  for (var i = 0; i < a.length - 1; i++) {
    bigramsA.add(a.substring(i, i + 2));
  }
  final bigramsB = <String>{};
  for (var i = 0; i < b.length - 1; i++) {
    bigramsB.add(b.substring(i, i + 2));
  }
  final intersection = bigramsA.intersection(bigramsB).length;
  return (2.0 * intersection) / (bigramsA.length + bigramsB.length);
}

/// Fuzzy-match garbled tempat lahir against common Indonesian cities.
String? _fuzzyMatchTempatLahirWeb(String input) {
  const commonPlaces = [
    'BANDUNG',
    'BANDUNG BARAT',
    'CIMAHI',
    'GARUT',
    'SUMEDANG',
    'SUBANG',
    'PURWAKARTA',
    'KARAWANG',
    'BEKASI',
    'BOGOR',
    'DEPOK',
    'CIANJUR',
    'SUKABUMI',
    'TASIKMALAYA',
    'CIAMIS',
    'KUNINGAN',
    'MAJALENGKA',
    'INDRAMAYU',
    'CIREBON',
    'JAKARTA',
    'TANGERANG',
    'SEMARANG',
    'SURABAYA',
    'YOGYAKARTA',
    'MEDAN',
    'PALEMBANG',
    'MAKASSAR',
    'MALANG',
    'SOLO',
  ];

  final inputAlpha = input.replaceAll(RegExp(r'[^A-Z]'), '');
  if (inputAlpha.length < 3) return null;

  // If input is very short or very long, probably noise
  if (inputAlpha.length < 4 || inputAlpha.length > 20) return null;

  String? bestMatch;
  var bestScore = 0.0;

  for (final place in commonPlaces) {
    final placeAlpha = place.replaceAll(RegExp(r'[^A-Z]'), '');
    final score = _bigramSimilarity(inputAlpha, placeAlpha);
    if (score > bestScore) {
      bestScore = score;
      bestMatch = place;
    }
  }

  // Increased threshold to reduce false positives
  // Short inputs need higher threshold
  final threshold = inputAlpha.length <= 5 ? 0.6 : 0.5;
  if (bestScore >= threshold && bestMatch != null) {
    return bestMatch;
  }
  return null;
}
