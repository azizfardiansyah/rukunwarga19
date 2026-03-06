// ignore_for_file: deprecated_member_use, avoid_web_libraries_in_flutter

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
    final structuredMemberRows = await _extractStructuredMemberRows(
      objectUrl: objectUrl,
      tesseract: tesseract,
      lang: lang,
    );
    if (structuredMemberRows.trim().isNotEmpty) {
      return '${fullText.trim()}\n$_memberStructMarker\n${structuredMemberRows.trim()}';
    }

    final memberRowText = await _extractMemberRowsText(
      objectUrl: objectUrl,
      tesseract: tesseract,
      lang: lang,
    );
    if (memberRowText.trim().isNotEmpty) {
      return '${fullText.trim()}\n$_memberTableMarker\n${memberRowText.trim()}';
    }

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
  // KK member data table typically occupies ~15.5% to ~50% of image height
  // Widened to capture more of the table and all member rows
  final x = (imageWidth * 0.01).round();
  final y = (imageHeight * 0.150).round();
  final w = (imageWidth * 0.98).round();
  final h = (imageHeight * 0.36).round();
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

  // Skip the header row (Nama Lengkap, NIK, etc) which takes ~14% of table height
  final dataX = tableX + (tableW * 0.02).round();
  final dataW = (tableW * 0.97).round();
  final dataStartY = tableY + (tableH * 0.14).round();
  // Each data row is about 7.5% of table height
  final rowHeight = (tableH * 0.075).round();
  final dataY = dataStartY + (rowIndex * rowHeight);
  if (dataW <= 0 || rowHeight <= 0) return null;

  final safeX = dataX.clamp(0, imageWidth - 1);
  final safeY = dataY.clamp(0, imageHeight - 1);
  final safeW = dataW.clamp(1, imageWidth - safeX);
  final safeH = rowHeight.clamp(1, imageHeight - safeY);
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

  if (binarize) {
    final imageData = ctx.getImageData(0, 0, canvas.width!, canvas.height!);
    final data = imageData.data;
    // Use adaptive-style binarization: compute local average and apply Otsu-like threshold
    // First pass: compute histogram
    final histogram = List<int>.filled(256, 0);
    for (var i = 0; i < data.length; i += 4) {
      final r = data[i];
      final g = data[i + 1];
      final b = data[i + 2];
      final gray = (0.299 * r + 0.587 * g + 0.114 * b).round().clamp(0, 255);
      histogram[gray]++;
    }
    // Otsu's method to find optimal threshold
    final totalPixels = data.length ~/ 4;
    var sumAll = 0.0;
    for (var i = 0; i < 256; i++) {
      sumAll += i * histogram[i];
    }
    var sumBg = 0.0;
    var weightBg = 0;
    var maxVariance = 0.0;
    var bestThreshold = 128;
    for (var t = 0; t < 256; t++) {
      weightBg += histogram[t];
      if (weightBg == 0) continue;
      final weightFg = totalPixels - weightBg;
      if (weightFg == 0) break;
      sumBg += t * histogram[t];
      final meanBg = sumBg / weightBg;
      final meanFg = (sumAll - sumBg) / weightFg;
      final variance =
          weightBg * weightFg * (meanBg - meanFg) * (meanBg - meanFg);
      if (variance > maxVariance) {
        maxVariance = variance;
        bestThreshold = t;
      }
    }

    // Apply binarization with the computed threshold
    for (var i = 0; i < data.length; i += 4) {
      final r = data[i];
      final g = data[i + 1];
      final b = data[i + 2];
      final gray = (0.299 * r + 0.587 * g + 0.114 * b).round().clamp(0, 255);
      final bw = gray > bestThreshold ? 255 : 0;
      data[i] = bw;
      data[i + 1] = bw;
      data[i + 2] = bw;
      data[i + 3] = 255;
    }
    ctx.putImageData(imageData, 0, 0);
  }

  return canvas.toDataUrl('image/jpeg', 0.98);
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

  if (bestScore >= 0.45 && bestMatch != null) {
    return bestMatch;
  }
  return null;
}
