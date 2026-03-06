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
      // Nama Lengkap: ~0-18% of table width
      // NIK: ~18-33%
      // Jenis Kelamin: ~33-42%
      // Tempat Lahir: ~42-52%
      // Tanggal Lahir: ~52-60%
      // Agama: ~60-68%
      // Pendidikan: ~68-78%
      // Pekerjaan: ~78-90%
      // Golongan Darah: ~90-100%
      final nameRaw = await readColumn(
        startRatio: 0.00,
        widthRatio: 0.18,
        scale: 4,
        binarize: true,
      );
      final nikRaw = await readColumn(
        startRatio: 0.17,
        widthRatio: 0.16,
        scale: 4,
        binarize: true,
        forceLang: 'eng',
      );
      final jkRaw = await readColumn(
        startRatio: 0.33,
        widthRatio: 0.09,
        scale: 4,
        binarize: true,
      );
      final tempatRaw = await readColumn(
        startRatio: 0.42,
        widthRatio: 0.10,
        scale: 3,
        binarize: true,
      );
      final tglRaw = await readColumn(
        startRatio: 0.52,
        widthRatio: 0.08,
        scale: 4,
        binarize: true,
        forceLang: 'eng',
      );
      final agamaRaw = await readColumn(
        startRatio: 0.60,
        widthRatio: 0.08,
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
      final tempatLahir = _normalizeTextField(tempatRaw);
      final tanggalLahir = _normalizeDateCandidate('$tglRaw $rowRaw');
      final agama = _normalizeAgamaCandidate('$agamaRaw $rowRaw');
      // Also try to read pendidikan and pekerjaan columns
      final pendidikanRaw = await readColumn(
        startRatio: 0.68,
        widthRatio: 0.10,
        scale: 3,
        binarize: true,
      );
      final pekerjaanRaw = await readColumn(
        startRatio: 0.78,
        widthRatio: 0.12,
        scale: 3,
        binarize: true,
      );
      final goldarRaw = await readColumn(
        startRatio: 0.90,
        widthRatio: 0.10,
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
  // KK member data table typically occupies ~16.5% to ~46% of image height
  // Widened to capture more of the table
  final x = (imageWidth * 0.01).round();
  final y = (imageHeight * 0.155).round();
  final w = (imageWidth * 0.98).round();
  final h = (imageHeight * 0.32).round();
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

  // Skip the header row (Nama Lengkap, NIK, etc) which takes ~18% of table height
  final dataX = tableX + (tableW * 0.02).round();
  final dataW = (tableW * 0.97).round();
  final dataStartY = tableY + (tableH * 0.18).round();
  // Each data row is about 7.5% of table height (slightly smaller to avoid overlap)
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

String _normalizeNameCandidate(String input) {
  final cleaned = _normalizeTextField(input);
  if (cleaned.isEmpty) return '';
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
    'YE', 'EL', 'EE', 'WS', 'SO', 'CE', 'NP', 'SS', 'FOO', 'DIN', 'MAL',
    'TNVAU', 'TOMA', 'IU', 'MIA', 'DD', 'RR', 'OW', 'RE', 'OL', 'EF',
    'FR', 'RV', 'SE', 'AP', 'FE', 'AW', 'EV', 'AN', 'OO', 'HE', 'DE',
    'WA', 'WN', 'WNI', 'II', 'TT', 'PP', 'NW', 'RI',
  };
  final words = cleaned
      .split(' ')
      .where(
        (w) => w.length >= 2 && !blocked.contains(w) && !ocrNoise.contains(w),
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
  for (final bt in ['AB+', 'AB-', 'AB', 'A+', 'A-', 'B+', 'B-', 'O+', 'O-', 'A', 'B', 'O']) {
    if (upper == bt) return bt;
  }
  return '';
}

String _normalizePendidikanCandidate(String input) {
  final upper = _normalizeTextField(input);
  if (upper.isEmpty) return '';
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
    if (upper.contains(p.replaceAll('/', '').replaceAll(' ', ''))) return p;
    // Fuzzy: check if most words match
    final words = p.split(RegExp(r'[\s/]+'));
    final matchCount = words.where((w) => upper.contains(w)).length;
    if (matchCount >= words.length - 1 && words.length >= 2) return p;
  }
  // Partial matches
  if (upper.contains('AKADEMI') || upper.contains('DIPLOMA III') || upper.contains('SARJANA MUDA')) {
    return 'AKADEMI/DIPLOMA III/SARJANA MUDA';
  }
  if (upper.contains('SLTA')) return 'SLTA/SEDERAJAT';
  if (upper.contains('SLTP')) return 'SLTP/SEDERAJAT';
  if (upper.contains('BELUM') && upper.contains('SEKOLAH')) return 'TIDAK/BELUM SEKOLAH';
  return upper;
}

String _normalizePekerjaanCandidate(String input) {
  final upper = _normalizeTextField(input);
  if (upper.isEmpty) return '';
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
    if (upper.contains(p.replaceAll('/', '').replaceAll(' ', ''))) return p;
    final words = p.split(RegExp(r'[\s/]+'));
    final matchCount = words.where((w) => upper.contains(w)).length;
    if (matchCount >= words.length - 1 && words.length >= 2) return p;
  }
  if (upper.contains('WIRASWASTA')) return 'WIRASWASTA';
  if (upper.contains('KARYAWAN')) return 'KARYAWAN SWASTA';
  if (upper.contains('BELUM') && upper.contains('BEKERJA')) return 'BELUM/TIDAK BEKERJA';
  if (upper.contains('TIDAK') && upper.contains('BEKERJA')) return 'BELUM/TIDAK BEKERJA';
  if (upper.contains('PELAJAR')) return 'PELAJAR/MAHASISWA';
  return upper;
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
