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
  static const double _memberTableLeftRatio = 0.012;
  static const double _memberTableTopRatio = 0.156;
  static const double _memberTableWidthRatio = 0.976;
  static const double _memberTableHeightRatio = 0.292;
  static const double _memberTableHeaderHeightRatio = 0.19;
  static const double _memberTableRowHeightRatio = 0.079;

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
    final namaKepalaKeluarga = _extractNamaKepalaKeluarga(lines);
    final structuredLines = structuredMemberRaw
        .split('\n')
        .map((line) => line.trim())
        .where((line) => line.isNotEmpty)
        .toList();
    final memberHintLines = memberHintRaw
        .split('\n')
        .map(_normalizeLine)
        .where((line) => line.isNotEmpty)
        .toList();
    final structuredMembers = _parseStructuredMembers(
      structuredLines,
      noKkHint: noKk,
    );
    final memberHintMembers = _parseMembers(
      memberHintLines,
      noKkHint: noKk,
      requireTableHeader: false,
    );
    var members = _mergeMemberSources([structuredMembers, memberHintMembers]);
    members = _orderMembersByReference(members, memberHintMembers);
    if (members.isEmpty) {
      members = _parseMembers(lines, noKkHint: noKk);
    }
    // Fallback: parse from the "hubungan dalam keluarga" / bottom section
    // which often contains names more clearly
    if (members.isEmpty) {
      members = _parseMembersFromHubunganSection(lines, noKkHint: noKk);
    }
    // If structured members have names but all NIKs are empty, try to
    // extract NIKs from the header raw text
    if (members.isNotEmpty && members.every((m) => m.nik.isEmpty)) {
      _tryFillNiksFromRawText(members, headerRaw, noKkHint: noKk);
    }
    if (members.isNotEmpty) {
      _enrichMembersFromNik(members);
    }

    // Post-process: enrich members with hubungan & names from the bottom
    // section of the KK (which has cleaner text for names + hubungan).
    final bottomMembers = _parseMembersFromHubunganSection(
      lines,
      noKkHint: noKk,
      requireRelationship: true,
    );
    if (bottomMembers.isNotEmpty && members.isNotEmpty) {
      _enrichMembersFromBottomSection(members, bottomMembers);
    }

    // Post-process: try to fill missing NIKs from the raw text
    if (members.isNotEmpty && members.any((m) => m.nik.isEmpty)) {
      _tryFillNiksFromRawText(members, headerRaw, noKkHint: noKk);
    }
    if (members.isNotEmpty) {
      _enrichMembersFromNik(members);
      _ensureHeadMemberFromHeader(members, namaKepalaKeluarga);
      _reorderLikelySpouseBeforeChildren(members);
      _inferRemainingHubungan(members);
      _alignChildNikPrefixes(members, noKkHint: noKk);
      _enrichMembersFromNik(members);
    }

    // Post-process: try to fill missing detail fields from raw text
    _tryFillMemberDetailsFromRawText(members, headerRaw);
    _normalizeMergedMemberFields(members);
    _normalizeMergedMemberNames(
      members,
      namaKepalaKeluarga: namaKepalaKeluarga,
    );

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

      final hasValidNik =
          nikCandidate.length == 16 &&
          !seenNik.contains(nikCandidate) &&
          !RegExp(r'^0+$').hasMatch(nikCandidate) &&
          !RegExp(r'^(\d)\1{15}$').hasMatch(nikCandidate);

      if (nikCandidate.length == 16 && seenNik.contains(nikCandidate)) {
        continue;
      }

      // Validate day/month in NIK if present
      var nikDateOk = true;
      if (nikCandidate.length == 16) {
        var day = int.tryParse(nikCandidate.substring(6, 8)) ?? 0;
        final month = int.tryParse(nikCandidate.substring(8, 10)) ?? 0;
        if (day > 40) day -= 40;
        if (day < 1 || day > 31 || month < 1 || month > 12) {
          nikDateOk = false;
        }
      }

      final jenisKelamin = _normalizeStructuredJenisKelamin(parts[3]);
      final tempatLahir = _normalizeTempatLahir(parts[4]);
      final tanggalLahir = _normalizeTanggalFromToken(
        _cleanStructuredField(parts[5]),
      );
      final agama = _toTitleCase(_normalizeAgama(parts[6]));
      final pendidikan = _normalizePendidikanField(parts[7]);
      final pekerjaan = _normalizePekerjaanField(parts[8]);
      final golonganDarah = _normalizeGolonganDarah(parts[9]);
      final informativeFieldCount = [
        jenisKelamin,
        tempatLahir,
        tanggalLahir,
        agama,
        pendidikan,
        pekerjaan,
        golonganDarah,
      ].where((value) => value.trim().isNotEmpty).length;

      if (nama.isEmpty && !hasValidNik) {
        continue;
      }
      if (nama.isEmpty && informativeFieldCount == 0) {
        continue;
      }

      // Store NIK only if it passes all checks
      final nikToStore = (hasValidNik && nikDateOk) ? nikCandidate : '';
      final nikForInference = nikToStore.isNotEmpty ? nikToStore : nikCandidate;
      final inferredJenisKelamin = _inferJenisKelaminFromNik(nikForInference);
      final inferredTanggalLahir = _inferTanggalLahirFromNik(nikForInference);

      members.add(
        ParsedKkMember(
          nama: nama.isNotEmpty ? nama : '(Nama tidak terbaca)',
          nik: nikToStore,
          hubungan: '',
          jenisKelamin: jenisKelamin.isNotEmpty
              ? jenisKelamin
              : inferredJenisKelamin,
          tempatLahir: tempatLahir,
          tanggalLahir: tanggalLahir.isNotEmpty
              ? tanggalLahir
              : inferredTanggalLahir,
          agama: agama,
          pendidikan: pendidikan,
          jenisPekerjaan: pekerjaan,
          golonganDarah: golonganDarah,
        ),
      );
      if (hasValidNik && nikDateOk) seenNik.add(nikCandidate);
    }

    return members;
  }

  List<ParsedKkMember> _mergeMemberSources(List<List<ParsedKkMember>> sources) {
    final merged = <ParsedKkMember>[];

    for (final source in sources) {
      for (final member in source) {
        final normalizedName = member.nama.trim();
        final normalizedNik = _validNikDigits(member.nik);
        if (normalizedName.isEmpty && normalizedNik.isEmpty) {
          continue;
        }

        final candidate = member.copyWith();
        final existingIndex = merged.indexWhere(
          (existing) => _isLikelySameMember(existing, candidate),
        );
        if (existingIndex < 0) {
          merged.add(candidate);
          continue;
        }

        merged[existingIndex] = _mergeMemberPair(
          merged[existingIndex],
          candidate,
        );
      }
    }

    return merged;
  }

  List<ParsedKkMember> _orderMembersByReference(
    List<ParsedKkMember> members,
    List<ParsedKkMember> reference,
  ) {
    if (members.length <= 1 || reference.isEmpty) {
      return members;
    }

    final ordered = <ParsedKkMember>[];
    final usedIndexes = <int>{};

    for (final ref in reference) {
      final matchIndex = members.indexWhere(
        (member) =>
            !usedIndexes.contains(members.indexOf(member)) &&
            _isLikelySameMember(member, ref),
      );
      if (matchIndex >= 0) {
        ordered.add(members[matchIndex]);
        usedIndexes.add(matchIndex);
      }
    }

    for (var i = 0; i < members.length; i++) {
      if (!usedIndexes.contains(i)) {
        ordered.add(members[i]);
      }
    }

    return ordered;
  }

  ParsedKkMember _mergeMemberPair(ParsedKkMember left, ParsedKkMember right) {
    final useRightAsPrimary = _memberDataScore(right) > _memberDataScore(left);
    final primary = (useRightAsPrimary ? right : left).copyWith();
    final secondary = useRightAsPrimary ? left : right;

    final preferredName = _pickPreferredMemberName(
      primary.nama,
      secondary.nama,
    );
    primary.nama = preferredName;
    final preferredNik = _pickPreferredNik(primary.nik, secondary.nik);
    primary.nik = preferredNik;

    primary.hubungan = _preferMoreInformativeValue(
      primary.hubungan,
      secondary.hubungan,
    );
    primary.jenisKelamin = _pickPreferredJenisKelamin(
      primary.jenisKelamin,
      secondary.jenisKelamin,
      preferredNik: preferredNik,
    );
    primary.tempatLahir = _preferMoreInformativeValue(
      primary.tempatLahir,
      secondary.tempatLahir,
    );
    primary.tanggalLahir = _pickPreferredTanggalLahir(
      primary.tanggalLahir,
      secondary.tanggalLahir,
      preferredNik: preferredNik,
    );
    primary.agama = _preferMoreInformativeValue(primary.agama, secondary.agama);
    primary.pendidikan = _preferMoreInformativeValue(
      primary.pendidikan,
      secondary.pendidikan,
    );
    primary.jenisPekerjaan = _preferMoreInformativeValue(
      primary.jenisPekerjaan,
      secondary.jenisPekerjaan,
    );
    primary.golonganDarah = _preferMoreInformativeValue(
      primary.golonganDarah,
      secondary.golonganDarah,
    );

    return primary;
  }

  bool _isLikelySameMember(ParsedKkMember left, ParsedKkMember right) {
    final leftNik = _validNikDigits(left.nik);
    final rightNik = _validNikDigits(right.nik);
    if (leftNik.isNotEmpty && rightNik.isNotEmpty) {
      if (leftNik == rightNik) {
        return true;
      }
    }

    final similarity = _nameSimilarity(left.nama, right.nama);
    if (similarity >= 0.9) {
      return true;
    }
    if (similarity < 0.72) {
      return false;
    }

    final leftTokens = left.nama
        .toUpperCase()
        .split(' ')
        .where((token) => token.length >= 3)
        .toSet();
    final rightTokens = right.nama
        .toUpperCase()
        .split(' ')
        .where((token) => token.length >= 3)
        .toSet();
    final sharedTokenCount = leftTokens.intersection(rightTokens).length;
    return sharedTokenCount >= 1 ||
        _looksClearlyGarbledName(left.nama) ||
        _looksClearlyGarbledName(right.nama);
  }

  int _memberDataScore(ParsedKkMember member) {
    final values = [
      member.nama,
      member.nik,
      member.hubungan,
      member.jenisKelamin,
      member.tempatLahir,
      member.tanggalLahir,
      member.agama,
      member.pendidikan,
      member.jenisPekerjaan,
      member.golonganDarah,
    ];

    var score = values.where((value) => value.trim().isNotEmpty).length * 4;
    if (_validNikDigits(member.nik).isNotEmpty) {
      score += 30;
    }
    score += _nameQualityScore(member.nama).round();
    return score;
  }

  String _pickPreferredMemberName(String primary, String secondary) {
    final left = primary.trim();
    final right = secondary.trim();
    if (left.isEmpty) return right;
    if (right.isEmpty) return left;

    final mergedTokens = _mergeSimilarNameTokens(left, right);
    if (mergedTokens.isNotEmpty) {
      return mergedTokens;
    }

    final leftScore = _nameQualityScore(left);
    final rightScore = _nameQualityScore(right);
    if (_looksClearlyGarbledName(left) && !_looksClearlyGarbledName(right)) {
      return right;
    }
    if (_looksClearlyGarbledName(right) && !_looksClearlyGarbledName(left)) {
      return left;
    }
    if (_isLikelyExtraLeadingChar(left, right)) {
      return right;
    }
    if (_isLikelyExtraLeadingChar(right, left)) {
      return left;
    }
    if (rightScore >= leftScore + 2) {
      return right;
    }
    return left;
  }

  String _mergeSimilarNameTokens(String left, String right) {
    final leftTokens = left
        .toUpperCase()
        .split(' ')
        .where((token) => token.isNotEmpty)
        .toList();
    final rightTokens = right
        .toUpperCase()
        .split(' ')
        .where((token) => token.isNotEmpty)
        .toList();
    if (leftTokens.length != rightTokens.length || leftTokens.isEmpty) {
      return '';
    }

    final merged = <String>[];
    for (var i = 0; i < leftTokens.length; i++) {
      final mergedToken = _mergeSimilarNameToken(leftTokens[i], rightTokens[i]);
      if (mergedToken.isEmpty) {
        return '';
      }
      merged.add(mergedToken);
    }

    return _toTitleCase(merged.join(' '));
  }

  String _mergeSimilarNameToken(String left, String right) {
    if (left == right) return left;
    if (_isLikelyExtraLeadingChar(left, right)) {
      return right;
    }
    if (_isLikelyExtraLeadingChar(right, left)) {
      return left;
    }
    if (left.startsWith(right) || right.startsWith(left)) {
      return left.length >= right.length ? left : right;
    }
    if (_nameSimilarity(left, right) >= 0.75) {
      return left.length >= right.length ? left : right;
    }
    return '';
  }

  bool _isLikelyExtraLeadingChar(String longer, String shorter) {
    final normalizedLonger = longer.toUpperCase().replaceAll(
      RegExp(r'[^A-Z]'),
      '',
    );
    final normalizedShorter = shorter.toUpperCase().replaceAll(
      RegExp(r'[^A-Z]'),
      '',
    );
    if (normalizedLonger.length != normalizedShorter.length + 1) {
      return false;
    }
    return normalizedLonger.substring(1) == normalizedShorter;
  }

  String _preferMoreInformativeValue(String primary, String secondary) {
    final left = primary.trim();
    final right = secondary.trim();
    if (left.isEmpty) return right;
    if (right.isEmpty) return left;
    if (right.length > left.length + 2) {
      return right;
    }
    return left;
  }

  String _pickPreferredNik(String primary, String secondary) {
    final left = _validNikDigits(primary);
    final right = _validNikDigits(secondary);
    if (left.isEmpty) return right;
    if (right.isEmpty) return left;

    final leftScore = _nikQualityScore(left);
    final rightScore = _nikQualityScore(right);
    if (rightScore > leftScore) {
      return right;
    }
    return left;
  }

  String _pickPreferredJenisKelamin(
    String primary,
    String secondary, {
    String preferredNik = '',
  }) {
    final left = primary.trim();
    final right = secondary.trim();
    if (left.isEmpty) return right;
    if (right.isEmpty) return left;

    final nikGender = _inferJenisKelaminFromNik(preferredNik);
    if (nikGender.isNotEmpty) {
      if (left == nikGender && right != nikGender) {
        return left;
      }
      if (right == nikGender && left != nikGender) {
        return right;
      }
    }

    return _preferMoreInformativeValue(left, right);
  }

  String _pickPreferredTanggalLahir(
    String primary,
    String secondary, {
    String preferredNik = '',
  }) {
    final left = primary.trim();
    final right = secondary.trim();
    if (left.isEmpty) return right;
    if (right.isEmpty) return left;

    final nikTanggal = _inferTanggalLahirFromNik(preferredNik);
    if (nikTanggal.isNotEmpty) {
      if (left == nikTanggal && right != nikTanggal) {
        return left;
      }
      if (right == nikTanggal && left != nikTanggal) {
        return right;
      }
    }

    return _preferMoreInformativeValue(left, right);
  }

  int _nikQualityScore(String nik) {
    final digits = _validNikDigits(nik);
    if (digits.isEmpty) return 0;

    var score = 100;
    if (digits.endsWith('0000')) score -= 18;
    if (digits.endsWith('000')) score -= 10;
    if (RegExp(r'(\d)\1{3}$').hasMatch(digits)) score -= 6;
    return score;
  }

  String _validNikDigits(String input) {
    final digits = input.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length != 16) return '';
    if (RegExp(r'^0+$').hasMatch(digits)) return '';
    if (RegExp(r'^(\d)\1{15}$').hasMatch(digits)) return '';
    if (!_isLikelyMemberNik(digits)) return '';
    return digits;
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

      final rowNumberHint = _extractLeadingRowNumber(line);
      final nik = _extractNik(
        line,
        noKkHint: noKkHint,
        rowNumberHint: rowNumberHint,
      );
      if (nik == null || seenNik.contains(nik)) {
        continue;
      }
      if (!_isLikelyMemberNik(nik, noKkHint: noKkHint)) {
        continue;
      }

      var detailSource = line;
      if (!_containsDateToken(line) &&
          !_looksLikeCompleteMemberDetailLine(line) &&
          i + 1 < lines.length &&
          !_looksLikeMemberTableHeader(lines[i + 1]) &&
          !_isMemberTableEnd(lines[i + 1]) &&
          !_looksLikeStandaloneMemberLine(lines[i + 1], currentNik: nik) &&
          _looksLikeUsefulDetailContinuation(lines[i + 1])) {
        detailSource = '$line ${lines[i + 1]}';
      }

      final detail = _extractMemberDetailFromLine(
        detailSource,
        nikOverride: nik,
      );
      final nama = detail.nama.isNotEmpty
          ? detail.nama
          : _extractName(line, lines, i);
      final fallbackGender = _extractGender(lines, i);
      final jenisKelamin = detail.jenisKelamin.isNotEmpty
          ? detail.jenisKelamin
          : (fallbackGender.isNotEmpty
                ? fallbackGender
                : _inferJenisKelaminFromNik(nik));

      if (nama.isEmpty) {
        continue;
      }

      members.add(
        ParsedKkMember(
          nama: nama,
          nik: nik,
          hubungan: '',
          jenisKelamin: jenisKelamin,
          tempatLahir: _normalizeTempatLahir(detail.tempatLahir),
          tanggalLahir: detail.tanggalLahir.isNotEmpty
              ? detail.tanggalLahir
              : _inferTanggalLahirFromNik(nik),
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
          jenisKelamin: _inferJenisKelaminFromNik(nik),
          tanggalLahir: _inferTanggalLahirFromNik(nik),
        ),
      );
      seenNik.add(nik);
    }

    return members;
  }

  /// Parse members from the "hubungan dalam keluarga" section in the raw OCR.
  /// This section is at the bottom half of the KK and often has cleaner text.
  List<ParsedKkMember> _parseMembersFromHubunganSection(
    List<String> lines, {
    String noKkHint = '',
    bool requireRelationship = false,
  }) {
    final members = <ParsedKkMember>[];
    final seenNames = <String>{};

    // Find the "Status Perkawinan" / "Hubungan Dalam Keluarga" section
    var inSection = false;
    for (var i = 0; i < lines.length; i++) {
      final line = lines[i];
      if (line.contains('STATUS PERKAWINAN') ||
          line.contains('HUBUNGAN') ||
          line.contains('KEWARGANEGARAAN')) {
        inSection = true;
        continue;
      }
      if (!inSection) continue;
      if (line.contains('DIKELUARKAN') ||
          line.contains('KEPALA DINAS') ||
          line.contains('PENCATATAN SIPIL') ||
          line.contains('DOKUMEN INI')) {
        break;
      }

      // Detect hubungan keywords
      final hubunganPattern = RegExp(
        r'(KEPALA\s*KELUARGA|ISTRI|SUAMI|ANAK|MENANTU|CUCU|ORANG\s*TUA|MERTUA|FAMILI\s*LAIN|PEMBANTU|LAINNYA)',
        caseSensitive: false,
      );
      final hubunganMatch = hubunganPattern.firstMatch(line);
      if (requireRelationship && hubunganMatch == null) {
        continue;
      }

      // Try to find names — in KK bottom section, names often appear as:
      // - Mixed case words like "Josoeomo" (garbled OCR)
      // - ALL CAPS sequences separated by spaces
      // - Concatenated with other text
      // Accept both CamelCase and ALL CAPS patterns
      final namePatterns = [
        // CamelCase names: "Timin Rohana"
        RegExp(r'[A-Z][a-z]{2,}(?:\s+[A-Z][a-z]{2,})+'),
        // ALL CAPS names with dots: "MOCH. JUBAEDI"
        RegExp(r'[A-Z]{3,}\.?\s+[A-Z]{3,}(?:\s+[A-Z]{3,})*'),
        // lowercase-run name (garbled OCR): "Jazisrarpiansyan"
        RegExp(r'J[a-z]{6,}'),
      ];

      for (final pattern in namePatterns) {
        for (final nameMatch in pattern.allMatches(line)) {
          var nama = nameMatch.group(0)!.trim();
          // Clean up the name — remove common noise words
          nama = nama
              .replaceAll(
                RegExp(
                  r'\b(WNI|INDONESIA|KAWIN|BELUM|TERCATAT|TIDAK|PASPOR|KITAP|DOKUMEN|IMIGRASI)\b',
                  caseSensitive: false,
                ),
                '',
              )
              .replaceAll(RegExp(r'\s+'), ' ')
              .trim();
          if (nama.length >= 4 && !seenNames.contains(nama.toUpperCase())) {
            final hubungan = hubunganMatch != null
                ? _mapHubunganToDbValue(
                    hubunganMatch
                        .group(0)!
                        .replaceAll(RegExp(r'\s+'), ' ')
                        .trim(),
                  )
                : '';
            members.add(
              ParsedKkMember(
                nama: _toTitleCase(nama),
                nik: '',
                hubungan: hubungan,
                jenisKelamin: '',
              ),
            );
            seenNames.add(nama.toUpperCase());
          }
        }
      }
    }

    return members;
  }

  /// Enrich structured members with data from the bottom hubungan section.
  /// Matches members by fuzzy name similarity and fills in missing hubungan.
  void _enrichMembersFromBottomSection(
    List<ParsedKkMember> members,
    List<ParsedKkMember> bottomMembers,
  ) {
    // For each bottom member with hubungan, try to match it to a structured member
    for (final bm in bottomMembers) {
      if (bm.hubungan.isEmpty) continue;
      var bestIdx = -1;
      var bestScore = 0.0;
      for (var i = 0; i < members.length; i++) {
        if (members[i].hubungan.isNotEmpty) continue;
        final score = _nameSimilarity(members[i].nama, bm.nama);
        if (score > bestScore && score >= 0.4) {
          bestScore = score;
          bestIdx = i;
        }
      }
      if (bestIdx >= 0) {
        if (_nameQualityScore(bm.nama) >
                _nameQualityScore(members[bestIdx].nama) &&
            bestScore >= 0.5) {
          members[bestIdx].nama = bm.nama;
        }
        members[bestIdx].hubungan = bm.hubungan;
      }
    }
  }

  void _enrichMembersFromNik(List<ParsedKkMember> members) {
    for (final member in members) {
      final nik = member.nik.replaceAll(RegExp(r'[^0-9]'), '');
      if (nik.length != 16) {
        continue;
      }

      if (member.jenisKelamin.isEmpty) {
        member.jenisKelamin = _inferJenisKelaminFromNik(nik);
      }
      if (member.tanggalLahir.isEmpty) {
        member.tanggalLahir = _inferTanggalLahirFromNik(nik);
      }
    }
  }

  void _inferRemainingHubungan(List<ParsedKkMember> members) {
    if (members.isEmpty) return;

    var hasAyah = members.any((m) => m.hubungan == 'Ayah');
    var hasIbu = members.any((m) => m.hubungan == 'Ibu');

    for (var i = 0; i < members.length; i++) {
      final member = members[i];
      if (member.hubungan.isNotEmpty) {
        if (member.hubungan == 'Ayah') hasAyah = true;
        if (member.hubungan == 'Ibu') hasIbu = true;
        continue;
      }

      final inferred = _inferHubunganForMember(
        members,
        index: i,
        hasAyah: hasAyah,
        hasIbu: hasIbu,
      );
      member.hubungan = inferred;
      if (inferred == 'Ayah') hasAyah = true;
      if (inferred == 'Ibu') hasIbu = true;
    }
  }

  void _reorderLikelySpouseBeforeChildren(List<ParsedKkMember> members) {
    if (members.length < 3) {
      return;
    }
    if (members.first.hubungan == 'Ibu') {
      return;
    }
    if (members.any((member) => member.hubungan == 'Ibu')) {
      return;
    }

    final spouseIndex = _findLikelySpouseIndex(members);
    if (spouseIndex <= 1) {
      return;
    }

    final spouse = members.removeAt(spouseIndex);
    members.insert(1, spouse);
  }

  int _findLikelySpouseIndex(List<ParsedKkMember> members) {
    if (members.length < 2) {
      return -1;
    }

    final head = members.first;
    final headGender = head.jenisKelamin;
    var bestIndex = -1;
    var bestScore = 0;

    for (var i = 1; i < members.length; i++) {
      final member = members[i];
      if (!_isLikelyAdultMember(member)) {
        continue;
      }

      var score = 0;
      if (headGender == 'Laki-laki' && member.jenisKelamin == 'Perempuan') {
        score += 8;
      } else if (headGender == 'Perempuan' &&
          member.jenisKelamin == 'Laki-laki') {
        score += 8;
      }
      if (_nameQualityScore(member.nama) >= 6) {
        score += 2;
      }
      if (_validNikDigits(member.nik).isNotEmpty) {
        score += 2;
      }
      if (member.agama.isNotEmpty) {
        score += 1;
      }
      if (score > bestScore) {
        bestScore = score;
        bestIndex = i;
      }
    }

    return bestScore >= 8 ? bestIndex : -1;
  }

  void _alignChildNikPrefixes(
    List<ParsedKkMember> members, {
    String noKkHint = '',
  }) {
    final familyPrefix = noKkHint.length >= 6 ? noKkHint.substring(0, 6) : '';
    if (familyPrefix.isEmpty) {
      return;
    }

    for (final member in members) {
      if (member.hubungan != 'Anak') {
        continue;
      }
      final nik = _validNikDigits(member.nik);
      if (nik.isEmpty) {
        continue;
      }

      final prefix = nik.substring(0, 6);
      if (prefix == familyPrefix) {
        continue;
      }
      if (_hammingDistance(prefix, familyPrefix) > 1) {
        continue;
      }

      final correctedNik = '$familyPrefix${nik.substring(6)}';
      if (!_isLikelyMemberNik(correctedNik, noKkHint: noKkHint)) {
        continue;
      }
      member.nik = correctedNik;
    }
  }

  void _normalizeMergedMemberFields(List<ParsedKkMember> members) {
    for (final member in members) {
      member.tempatLahir = _normalizeTempatLahir(member.tempatLahir);
      member.agama = _toTitleCase(_normalizeAgama(member.agama));
      member.pendidikan = _normalizePendidikanField(member.pendidikan);
      member.jenisPekerjaan = _normalizePekerjaanField(member.jenisPekerjaan);
      member.golonganDarah = _normalizeGolonganDarah(member.golonganDarah);
    }
  }

  void _normalizeMergedMemberNames(
    List<ParsedKkMember> members, {
    String namaKepalaKeluarga = '',
  }) {
    for (final member in members) {
      member.nama = _normalizeFinalMemberName(member.nama);
    }

    final cleanedHeaderName = _normalizeFinalMemberName(namaKepalaKeluarga);
    if (members.isEmpty || cleanedHeaderName.isEmpty) {
      return;
    }

    final headIndex = members.indexWhere((member) => member.hubungan == 'Ayah');
    final ibuIndex = members.indexWhere((member) => member.hubungan == 'Ibu');
    if (headIndex >= 0 &&
        (_nameSimilarity(members[headIndex].nama, cleanedHeaderName) >= 0.35 ||
            members[headIndex].nama.isEmpty ||
            _looksClearlyGarbledName(members[headIndex].nama))) {
      members[headIndex].nama = cleanedHeaderName;
      if (headIndex != 0) {
        final headMember = members.removeAt(headIndex);
        members.insert(0, headMember);
      }
    } else if (ibuIndex >= 0 &&
        members.first.hubungan != 'Ayah' &&
        (_nameSimilarity(members[ibuIndex].nama, cleanedHeaderName) >= 0.35 ||
            _looksClearlyGarbledName(members[ibuIndex].nama))) {
      members[ibuIndex].nama = cleanedHeaderName;
    } else if (members.first.hubungan != 'Anak') {
      members.first.nama = cleanedHeaderName;
    }
  }

  String _inferHubunganForMember(
    List<ParsedKkMember> members, {
    required int index,
    required bool hasAyah,
    required bool hasIbu,
  }) {
    final member = members[index];
    final gender = member.jenisKelamin;

    if (index == 0) {
      if (gender == 'Perempuan' && !hasIbu) return 'Ibu';
      if (!hasAyah) return 'Ayah';
      if (!hasIbu) return 'Ibu';
      return 'Anak';
    }

    if (index == 1) {
      final head = members.first;
      final isAdult = _isLikelyAdultMember(member);
      if (isAdult) {
        if (head.hubungan == 'Ayah' &&
            head.jenisKelamin != 'Perempuan' &&
            gender == 'Perempuan' &&
            !hasIbu) {
          return 'Ibu';
        }
        if (head.hubungan == 'Ibu' &&
            head.jenisKelamin == 'Perempuan' &&
            gender == 'Laki-laki' &&
            !hasAyah) {
          return 'Ayah';
        }
      }
    }

    return 'Anak';
  }

  bool _isLikelyAdultMember(ParsedKkMember member) {
    final birthDate =
        _parseTanggalLahir(member.tanggalLahir) ??
        _birthDateFromNik(member.nik);
    if (birthDate == null) {
      return false;
    }

    final now = DateTime.now();
    var age = now.year - birthDate.year;
    final birthdayPassed =
        now.month > birthDate.month ||
        (now.month == birthDate.month && now.day >= birthDate.day);
    if (!birthdayPassed) {
      age -= 1;
    }
    return age >= 17;
  }

  DateTime? _parseTanggalLahir(String input) {
    final match = RegExp(r'^(\d{2})-(\d{2})-(\d{4})$').firstMatch(input.trim());
    if (match == null) {
      return null;
    }

    final day = int.tryParse(match.group(1) ?? '');
    final month = int.tryParse(match.group(2) ?? '');
    final year = int.tryParse(match.group(3) ?? '');
    if (day == null || month == null || year == null) {
      return null;
    }

    final date = DateTime(year, month, day);
    if (date.year != year || date.month != month || date.day != day) {
      return null;
    }
    return date;
  }

  DateTime? _birthDateFromNik(String nik) {
    final digits = nik.replaceAll(RegExp(r'[^0-9]'), '');
    if (digits.length != 16) {
      return null;
    }

    var day = int.tryParse(digits.substring(6, 8)) ?? 0;
    final month = int.tryParse(digits.substring(8, 10)) ?? 0;
    final year2 = int.tryParse(digits.substring(10, 12)) ?? 0;
    if (day > 40) {
      day -= 40;
    }
    if (day < 1 || day > 31 || month < 1 || month > 12) {
      return null;
    }

    final now = DateTime.now();
    final currentYear2 = now.year % 100;
    final fullYear = year2 <= currentYear2 ? 2000 + year2 : 1900 + year2;
    final date = DateTime(fullYear, month, day);
    if (date.year != fullYear || date.month != month || date.day != day) {
      return null;
    }
    return date;
  }

  String _inferJenisKelaminFromNik(String nik) {
    final birthDate = _birthDateFromNik(nik);
    if (birthDate == null) {
      return '';
    }

    final digits = nik.replaceAll(RegExp(r'[^0-9]'), '');
    final day = int.tryParse(digits.substring(6, 8)) ?? 0;
    return day > 40 ? 'Perempuan' : 'Laki-laki';
  }

  String _inferTanggalLahirFromNik(String nik) {
    final birthDate = _birthDateFromNik(nik);
    if (birthDate == null) {
      return '';
    }

    final day = birthDate.day.toString().padLeft(2, '0');
    final month = birthDate.month.toString().padLeft(2, '0');
    final year = birthDate.year.toString().padLeft(4, '0');
    return '$day-$month-$year';
  }

  void _ensureHeadMemberFromHeader(
    List<ParsedKkMember> members,
    String namaKepalaKeluarga,
  ) {
    if (members.isEmpty || namaKepalaKeluarga.trim().isEmpty) {
      return;
    }

    final cleanedHeaderName = _normalizeStructuredName(namaKepalaKeluarga);
    if (cleanedHeaderName.isEmpty) {
      return;
    }

    final headerGender = _inferJenisKelaminFromName(cleanedHeaderName);
    final matchedIndex = members.indexWhere(
      (m) => _nameSimilarity(m.nama, cleanedHeaderName) >= 0.45,
    );
    if (matchedIndex >= 0) {
      final matchedName = members[matchedIndex].nama;
      final matchedTokens = matchedName
          .toUpperCase()
          .split(' ')
          .where((token) => token.isNotEmpty)
          .toList();
      final headerTokens = cleanedHeaderName
          .toUpperCase()
          .split(' ')
          .where((token) => token.isNotEmpty)
          .toList();
      final sharedHeaderTokens = matchedTokens
          .where((token) => headerTokens.contains(token))
          .length;
      final hasNoisyExtraTokens =
          matchedTokens.length > headerTokens.length &&
          matchedTokens
              .where((token) => !headerTokens.contains(token))
              .every(
                (token) =>
                    token.length <= 4 ||
                    _looksGarbled(token) ||
                    !_hasReasonableVowelRatio(token),
              );
      final sharesLastToken =
          matchedTokens.isNotEmpty &&
          headerTokens.isNotEmpty &&
          matchedTokens.last == headerTokens.last;
      final shouldPreferHeaderName =
          (_looksClearlyGarbledName(matchedName) &&
              _nameQualityScore(cleanedHeaderName) >=
                  _nameQualityScore(matchedName)) ||
          (sharesLastToken &&
              _nameSimilarity(matchedName, cleanedHeaderName) >= 0.55 &&
              _nameQualityScore(cleanedHeaderName) + 1 >=
                  _nameQualityScore(matchedName)) ||
          (_nameSimilarity(matchedName, cleanedHeaderName) >= 0.45 &&
              sharedHeaderTokens >=
                  (headerTokens.length >= 2 ? headerTokens.length - 1 : 1) &&
              hasNoisyExtraTokens);
      if (shouldPreferHeaderName) {
        members[matchedIndex].nama = cleanedHeaderName;
      }
      if (headerGender.isNotEmpty &&
          members[matchedIndex].jenisKelamin.isEmpty) {
        members[matchedIndex].jenisKelamin = headerGender;
      }
      if (headerGender.isNotEmpty &&
          members[matchedIndex].hubungan.isNotEmpty &&
          members[matchedIndex].hubungan != 'Anak') {
        members[matchedIndex].hubungan = headerGender == 'Perempuan'
            ? 'Ibu'
            : 'Ayah';
      }
      if (matchedIndex != 0) {
        final headMember = members.removeAt(matchedIndex);
        members.insert(0, headMember);
      }
      return;
    }

    members.insert(
      0,
      ParsedKkMember(
        nama: cleanedHeaderName,
        nik: '',
        hubungan: headerGender == 'Perempuan' ? 'Ibu' : 'Ayah',
        jenisKelamin: headerGender,
      ),
    );
  }

  String _inferJenisKelaminFromName(String input) {
    final tokens = input
        .toUpperCase()
        .split(' ')
        .where((token) => token.isNotEmpty)
        .toSet();
    if (tokens.isEmpty) {
      return '';
    }

    const femaleTokens = {
      'SITI',
      'SRI',
      'DEWI',
      'NUR',
      'NURUL',
      'AISYAH',
      'AISAH',
      'AMINAH',
      'IPAH',
      'ROHANA',
      'RINA',
      'PUTRI',
      'FITRI',
      'YUNI',
      'YULI',
      'RATNA',
      'LINA',
      'WULAN',
      'ERNA',
    };
    const maleTokens = {
      'MUHAMMAD',
      'MOHAMMAD',
      'AHMAD',
      'AZIS',
      'FARDIANSYAH',
      'FAJAR',
      'RIZAL',
      'DEDI',
      'BUDI',
      'AGUS',
      'ASEP',
      'UJANG',
      'DADANG',
      'HENDRA',
      'ANDI',
      'IRFAN',
      'YAYAT',
      'SUHERMAN',
      'ADE',
    };

    if (tokens.intersection(femaleTokens).isNotEmpty) {
      return 'Perempuan';
    }
    if (tokens.intersection(maleTokens).isNotEmpty) {
      return 'Laki-laki';
    }
    return '';
  }

  bool _looksClearlyGarbledName(String input) {
    final words = input
        .toUpperCase()
        .split(' ')
        .where((word) => word.isNotEmpty)
        .toList();
    if (words.isEmpty) {
      return true;
    }

    if (words.any((word) => word.length > 15)) {
      return true;
    }
    if (words.any((word) => RegExp(r'(.)\1{2,}').hasMatch(word))) {
      return true;
    }
    if (words.any((word) => RegExp(r'[AEIOU]{4,}').hasMatch(word))) {
      return true;
    }
    if (words.any((word) => RegExp(r'[^AEIOU]{6,}').hasMatch(word))) {
      return true;
    }
    return _nameQualityScore(input) <= 6;
  }

  int _nameQualityScore(String input) {
    final cleaned = input.trim().toUpperCase();
    if (cleaned.isEmpty) {
      return 0;
    }

    final words = cleaned.split(' ').where((word) => word.isNotEmpty).toList();
    if (words.isEmpty) {
      return 0;
    }

    var score = 0;
    for (final word in words) {
      if (word.length >= 3) {
        score += 2;
      } else if (word.length == 2) {
        score += 1;
      }
      if (_hasReasonableVowelRatio(word)) {
        score += 1;
      }
      if (!_looksGarbled(word)) {
        score += 1;
      }
    }

    if (words.length >= 2) {
      score += 2;
    }
    if (words.length > 4) {
      score -= (words.length - 4);
    }
    if (RegExp(r'(.)\1{3,}').hasMatch(cleaned)) {
      score -= 2;
    }

    return score;
  }

  /// Simple character-level similarity score between two names.
  double _nameSimilarity(String a, String b) {
    if (a.isEmpty || b.isEmpty) return 0.0;
    final la = a.toUpperCase().replaceAll(RegExp(r'[^A-Z]'), '');
    final lb = b.toUpperCase().replaceAll(RegExp(r'[^A-Z]'), '');
    if (la.isEmpty || lb.isEmpty) return 0.0;
    // Count common bigrams
    final bigramsA = <String>{};
    for (var i = 0; i < la.length - 1; i++) {
      bigramsA.add(la.substring(i, i + 2));
    }
    final bigramsB = <String>{};
    for (var i = 0; i < lb.length - 1; i++) {
      bigramsB.add(lb.substring(i, i + 2));
    }
    if (bigramsA.isEmpty || bigramsB.isEmpty) return 0.0;
    final intersection = bigramsA.intersection(bigramsB).length;
    return (2.0 * intersection) / (bigramsA.length + bigramsB.length);
  }

  /// Try to fill missing detail fields (agama, tempat lahir, etc.) from raw text.
  /// Looks for well-known patterns in the full OCR dump.
  void _tryFillMemberDetailsFromRawText(
    List<ParsedKkMember> members,
    String rawText,
  ) {
    // Try to detect agama from the raw text — KK documents typically have
    // the same agama for all members
    if (members.any((m) => m.agama.isEmpty)) {
      final agamaMatch = RegExp(
        r'\b(ISLAM|KRISTEN|KATOLIK|KATHOLIK|KHATOLIK|BUDDHA|BUDHA)\b',
        caseSensitive: false,
      ).firstMatch(rawText.toUpperCase());
      if (agamaMatch != null) {
        final detectedAgama = _normalizeAgama(agamaMatch.group(0)!);
        for (var i = 0; i < members.length; i++) {
          if (members[i].agama.isEmpty) {
            members[i].agama = detectedAgama;
          }
        }
      }
    }

    // Try to extract tempat lahir & tanggal lahir patterns from raw text
    // Format often seen: "CIMAHI 22-09-1988" or "BANDUNG 25-05-1995"
    final birthPatterns = RegExp(
      r'([A-Z]{3,})\s+([0-3]?\d[-/.][0-1]?\d[-/.]\d{2,4})',
      caseSensitive: false,
    ).allMatches(rawText.toUpperCase());
    final birthInfoList = <(String, String)>[];
    for (final match in birthPatterns) {
      final place = match.group(1)?.trim() ?? '';
      final date = match.group(2)?.trim() ?? '';
      if (place.isNotEmpty && date.isNotEmpty) {
        // Skip if place is a known non-location word
        const skip = {
          'TANGGAL',
          'STATUS',
          'DIKELUARKAN',
          'KAWIN',
          'TERCATAT',
          'DOKUMEN',
          'SERTIFIKASI',
          'ELEKTRONIK',
        };
        if (!skip.contains(place)) {
          birthInfoList.add((
            _toTitleCase(place),
            _normalizeTanggalFromToken(date),
          ));
        }
      }
    }

    // Assign birth info to members missing it, in order
    var birthIdx = 0;
    for (
      var i = 0;
      i < members.length && birthIdx < birthInfoList.length;
      i++
    ) {
      if (members[i].tempatLahir.isEmpty && members[i].tanggalLahir.isEmpty) {
        members[i].tempatLahir = birthInfoList[birthIdx].$1;
        members[i].tanggalLahir = birthInfoList[birthIdx].$2;
        birthIdx++;
      }
    }
  }

  /// Try to fill in empty NIKs from the raw OCR text.
  /// Extracts all 16-digit sequences and assigns them to members in order.
  void _tryFillNiksFromRawText(
    List<ParsedKkMember> members,
    String rawText, {
    String noKkHint = '',
  }) {
    final normalized = _normalizeOcrDigits(rawText.toUpperCase());
    final nikMatches = RegExp(
      r'([0-9](?:\s*[0-9]){15})',
    ).allMatches(normalized);
    final validNiks = <String>[];

    for (final match in nikMatches) {
      final digits = match.group(0)!.replaceAll(RegExp(r'\s+'), '');
      if (digits.length != 16) continue;
      if (RegExp(r'^0+$').hasMatch(digits)) continue;
      if (RegExp(r'^(\d)\1{15}$').hasMatch(digits)) continue;

      // Basic date validation in NIK
      var day = int.tryParse(digits.substring(6, 8)) ?? 0;
      final month = int.tryParse(digits.substring(8, 10)) ?? 0;
      if (day > 40) day -= 40;
      if (day < 1 || day > 31 || month < 1 || month > 12) continue;

      // Skip if it looks like the NoKK itself
      if (noKkHint.isNotEmpty && digits == noKkHint) continue;

      if (!validNiks.contains(digits)) {
        validNiks.add(digits);
      }
    }

    // Assign NIKs to members that don't have one
    var nikIndex = 0;
    for (var i = 0; i < members.length && nikIndex < validNiks.length; i++) {
      if (members[i].nik.isEmpty) {
        members[i].nik = validNiks[nikIndex];
        nikIndex++;
      }
    }
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
    final upper = source.toUpperCase();
    String? fallbackCandidate;

    String? considerNormalized(String text) {
      final normalized = _normalizeOcrDigits(text);

      final exact16 = RegExp(r'([0-9](?:\s*[0-9]){15})').allMatches(normalized);
      for (final match in exact16) {
        final digits = match.group(0)!.replaceAll(RegExp(r'\s+'), '');
        if (digits.length != 16) continue;
        if (_isLikelyMemberNik(digits)) return digits;
        fallbackCandidate ??= digits;
      }

      final loose = RegExp(r'([0-9][0-9\s]{12,30})').allMatches(normalized);
      for (final match in loose) {
        final digits = match.group(0)!.replaceAll(RegExp(r'[^0-9]'), '');
        if (digits.length == 16) {
          if (_isLikelyMemberNik(digits)) return digits;
          fallbackCandidate ??= digits;
        }
        if (digits.length > 16) {
          for (var i = 0; i <= digits.length - 16; i++) {
            final candidate = digits.substring(i, i + 16);
            if (_isLikelyMemberNik(candidate)) {
              return candidate;
            }
          }
          fallbackCandidate ??= digits.substring(0, 16);
        }
      }

      return null;
    }

    final exact16 = RegExp(r'([0-9](?:\s*[0-9]){15})').allMatches(upper);
    for (final match in exact16) {
      final digits = match.group(0)!.replaceAll(RegExp(r'\s+'), '');
      if (digits.length != 16) continue;
      if (_isLikelyMemberNik(digits)) return digits;
      fallbackCandidate ??= digits;
    }

    final loose = RegExp(r'([0-9][0-9\s]{12,30})').allMatches(upper);
    for (final match in loose) {
      final result = considerNormalized(match.group(0) ?? '');
      if (result != null) {
        return result;
      }
    }

    final mixedBlocks = RegExp(
      r'([A-Z0-9][A-Z0-9\s]{11,30})',
    ).allMatches(upper);
    for (final match in mixedBlocks) {
      final block = match.group(0) ?? '';
      final digitCount = RegExp(r'\d').allMatches(block).length;
      if (digitCount < 8) {
        continue;
      }

      final firstDigitMatch = RegExp(r'\d').firstMatch(block);
      if (firstDigitMatch == null) {
        continue;
      }

      final result = considerNormalized(block.substring(firstDigitMatch.start));
      if (result != null) {
        return result;
      }
    }

    return fallbackCandidate;
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

  String? _extractNik(
    String line, {
    String noKkHint = '',
    int rowNumberHint = -1,
  }) {
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

    final normalizedLine = _stripLeadingRowNumber(
      upper,
      rowNumberHint: rowNumberHint,
    );
    final reconstructedNik = noKkHint.length >= 6 && rowNumberHint == 1
        ? _reconstructNikFromSuffix(
            normalizedLine,
            noKkPrefix: noKkHint.substring(0, 6),
            preferAdult: true,
          )
        : '';
    final reconstructedScore = reconstructedNik.isNotEmpty
        ? _nikContextScore(reconstructedNik, normalizedLine)
        : 0;
    final candidate = _extract16DigitsWithOcrCorrection(normalizedLine);
    if (candidate == null || candidate.length != 16) {
      if (reconstructedScore >= 120) {
        return reconstructedNik;
      }
      return null;
    }

    final repaired = _repairNikCandidate(
      candidate,
      line: normalizedLine,
      noKkHint: noKkHint,
      rowNumberHint: rowNumberHint,
    );
    if (repaired.length != 16 ||
        !_isLikelyMemberNik(repaired, noKkHint: noKkHint)) {
      if (reconstructedScore >= 120) {
        return reconstructedNik;
      }
      return null;
    }
    if (reconstructedScore >= 120 &&
        reconstructedScore > _nikContextScore(repaired, normalizedLine)) {
      return reconstructedNik;
    }
    return repaired;
  }

  String _stripLeadingRowNumber(String line, {int rowNumberHint = -1}) {
    if (rowNumberHint < 0) {
      return line.trim();
    }
    return line.replaceFirst(RegExp(r'^\s*\d{1,2}\s*[\.\-\)]?\s*'), '').trim();
  }

  String _extractName(String line, List<String> lines, int index) {
    final cleanedLine = _stripLeadingRowNumber(
      line,
      rowNumberHint: _extractLeadingRowNumber(line),
    );
    final beforeNik = cleanedLine.split(RegExp(r'\d')).first.trim();
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
    final contextLines = <String>[lines[index]];
    final currentNik = _extractNik(lines[index]) ?? '';
    if (index + 1 < lines.length &&
        !_looksLikeStandaloneMemberLine(
          lines[index + 1],
          currentNik: currentNik,
        )) {
      contextLines.add(lines[index + 1]);
    }
    final upperContext = contextLines.join(' ');

    if (_extractGenderHintFromText(upperContext) == 'Perempuan') {
      return 'Perempuan';
    }
    if (_extractGenderHintFromText(upperContext) == 'Laki-laki') {
      return 'Laki-laki';
    }
    return '';
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

    final genderHint = _extractGenderHintFromText(remaining);
    if (genderHint.isNotEmpty) {
      jenisKelamin = genderHint;
      remaining = remaining
          .replaceFirst(
            RegExp(
              r'(PEREMPUAN|FEREMPUAN|PERFVIPUAN|PERBUPUAN|LAKI[\s\-\/]*LAKI|LAKILAKI|LAKI|LAKHAK|LAKHAKI|PR|LK)',
              caseSensitive: false,
            ),
            '',
          )
          .trim();
    }

    final tanggalMatch = RegExp(
      r'\b([0-3]?\d[-\/\.][0-1]?\d[-\/\.]\d{2,4}|\d{8})\b',
    ).firstMatch(remaining);
    if (tanggalMatch != null) {
      tempatLahir = _cleanTempatSebelumTanggal(
        remaining.substring(0, tanggalMatch.start),
      );
      tanggalLahir = _normalizeTanggalFromToken(tanggalMatch.group(1) ?? '');
      remaining = remaining.substring(tanggalMatch.end).trim();
    }

    final agamaMatch = _findAgamaMatch(remaining);
    if (agamaMatch != null) {
      if (tanggalMatch == null && tempatLahir.isEmpty && agamaMatch.start > 0) {
        tempatLahir = _cleanTempatSebelumTanggal(
          remaining.substring(0, agamaMatch.start),
        );
      }
      agama = _normalizeAgama(agamaMatch.group(0) ?? '');
      remaining = remaining.substring(agamaMatch.end).trim();
    }

    final golDarahMatch = RegExp(
      r'(TIDAK\s+TAHU|RICA\s*TANU|INDAK?T?\s*TAHU|DAK\s*TAHU|AB[+-]?|A[+-]?|B[+-]?|O[+-]?|-)\s*$',
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
    final normalized = _normalizeFinalMemberName(candidate);
    if (!_isLikelyName(normalized.toUpperCase())) return '';
    return normalized;
  }

  String _normalizeTanggalFromToken(String input) {
    final cleaned = input.replaceAll(RegExp(r'[\/\.]'), '-').trim();
    var match = RegExp(r'^(\d{1,2})-(\d{1,2})-(\d{2,4})$').firstMatch(cleaned);
    match ??= RegExp(r'^(\d{2})(\d{2})(\d{2,4})$').firstMatch(cleaned);
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
      r'\b(ISLAM|SIAM|SLAW|JSIAU|M1AM|E1AW|KRISTEN|KATOLIK|KATHOLIK|KHATOLIK|HINDU|BUDDHA|BUDHA|KONGHUCU|KONGHUCHU)\b',
    ).firstMatch(input);
  }

  String _normalizeAgama(String input) {
    final upper = input.toUpperCase();
    if (upper.contains('ISLAM') ||
        upper.contains('SIAM') ||
        upper.contains('SLAW') ||
        upper.contains('JSIAU') ||
        upper.contains('M1AM') ||
        upper.contains('E1AW')) {
      return 'Islam';
    }
    if (upper.contains('KRISTEN')) return 'Kristen';
    if (upper.contains('KATOLIK') ||
        upper.contains('KATHOLIK') ||
        upper.contains('KHATOLIK')) {
      return 'Khatolik';
    }
    if (upper.contains('BUDDHA') || upper.contains('BUDHA')) return 'Budha';
    if (upper.contains('HINDU')) return 'Islam'; // Fallback — not in DB
    if (upper.contains('KONGHUCU') || upper.contains('KONGHUCHU')) {
      return 'Islam'; // Fallback — not in DB
    }
    return _cleanMemberDetailValue(input);
  }

  String _normalizeGolonganDarah(String input) {
    final upper = input.toUpperCase().replaceAll(RegExp(r'\s+'), '');
    if (upper.isEmpty || upper == '-') return '';
    if (upper == 'TIDAKTAHU' ||
        upper == 'RICATANU' ||
        upper == 'INDAKTAHU' ||
        upper == 'DAKTAHU') {
      return 'Tidak Tahu';
    }
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
      final pendidikan = _normalizePendidikanField(
        compact.substring(0, splitIndex),
      );
      final pekerjaan = _normalizePekerjaanField(compact.substring(splitIndex));
      return (pendidikan, pekerjaan);
    }

    return (
      _normalizePendidikanField(compact),
      _normalizePekerjaanField(compact),
    );
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
    return RegExp(
      r'\b(?:[0-3]?\d[-\/\.][0-1]?\d[-\/\.]\d{2,4}|\d{8})\b',
    ).hasMatch(line);
  }

  bool _looksLikeStandaloneMemberLine(String line, {String currentNik = ''}) {
    final nextNik = _extractNik(line);
    if (nextNik != null && nextNik != currentNik) {
      return true;
    }
    if (!RegExp(r'^\d{1,2}\b').hasMatch(line)) {
      return false;
    }

    final leadingText = line.replaceFirst(RegExp(r'^\d{1,2}\s*'), '');
    return _isLikelyName(leadingText.split(RegExp(r'\d')).first.trim());
  }

  bool _looksLikeCompleteMemberDetailLine(String line) {
    final upper = line.toUpperCase();
    final compact = upper.replaceAll(RegExp(r'[^A-Z]'), '');
    return _containsDateToken(upper) ||
        _findAgamaMatch(upper) != null ||
        compact.contains('SEKOLAH') ||
        compact.contains('SEDERAJAT') ||
        compact.contains('SARJANAMUDA') ||
        compact.contains('DIPLOMA') ||
        compact.contains('KARYAWAN') ||
        compact.contains('WRASWASTA') ||
        compact.contains('WIRASWASTA') ||
        compact.contains('BEKERJA') ||
        compact.contains('TIDAKTAHU') ||
        compact.contains('RICATANU');
  }

  bool _looksLikeUsefulDetailContinuation(String line) {
    final upper = line.toUpperCase();
    final compact = upper.replaceAll(RegExp(r'[^A-Z]'), '');
    if (_containsDateToken(upper) || _findAgamaMatch(upper) != null) {
      return true;
    }
    if (compact.contains('SEKOLAH') ||
        compact.contains('SEDERAJAT') ||
        compact.contains('DIPLOMA') ||
        compact.contains('SARJANA') ||
        compact.contains('KARYAWAN') ||
        compact.contains('WIRASWASTA') ||
        compact.contains('WRASWASTA') ||
        compact.contains('BEKERJA') ||
        compact.contains('TIDAKTAHU')) {
      return true;
    }

    final alphaCount = compact.length;
    return alphaCount >= 12 && !_looksGarbled(compact);
  }

  int _extractLeadingRowNumber(String line) {
    final match = RegExp(r'^\s*(\d{1,2})\b').firstMatch(line);
    if (match == null) {
      return -1;
    }
    return int.tryParse(match.group(1) ?? '') ?? -1;
  }

  String _repairNikCandidate(
    String candidate, {
    required String line,
    String noKkHint = '',
    int rowNumberHint = -1,
  }) {
    if (_isLikelyMemberNik(candidate, noKkHint: noKkHint)) {
      return candidate;
    }

    final variants = <String>{candidate};
    final genderHint = _extractGenderHintFromText(line);
    final dateHint = _extractLooseDateFromText(line);

    if (genderHint == 'Perempuan' && candidate.length == 16) {
      final chars = candidate.split('');
      final firstDayDigit = chars[6];
      if (firstDayDigit == '8') {
        chars[6] = '6';
        variants.add(chars.join());
      }
    }

    if (dateHint != null && candidate.length == 16) {
      final encodedDay = genderHint == 'Perempuan'
          ? dateHint.$1 + 40
          : dateHint.$1;
      final dd = encodedDay.toString().padLeft(2, '0');
      final mm = dateHint.$2.toString().padLeft(2, '0');
      final yy = (dateHint.$3 % 100).toString().padLeft(2, '0');
      variants.add(
        '${candidate.substring(0, 6)}$dd$mm$yy${candidate.substring(12)}',
      );
      if (rowNumberHint == 1 && noKkHint.length >= 6) {
        variants.add(
          '${noKkHint.substring(0, 6)}$dd$mm$yy${candidate.substring(12)}',
        );
      }
    }

    if (rowNumberHint == 1 && noKkHint.length >= 6) {
      final reconstructed = _reconstructNikFromSuffix(
        line,
        noKkPrefix: noKkHint.substring(0, 6),
        preferAdult: true,
      );
      if (reconstructed.isNotEmpty) {
        variants.add(reconstructed);
      }
    }

    String best = candidate;
    var bestScore = _nikQualityScore(candidate);
    for (final variant in variants) {
      if (!_isLikelyMemberNik(variant, noKkHint: noKkHint)) {
        continue;
      }
      final score = _nikQualityScore(variant);
      if (score > bestScore) {
        best = variant;
        bestScore = score;
      }
    }

    return best;
  }

  String _reconstructNikFromSuffix(
    String line, {
    required String noKkPrefix,
    bool preferAdult = false,
  }) {
    final upper = line.toUpperCase();
    final candidateBlocks = RegExp(
      r'([A-Z0-9][A-Z0-9\s]{9,30})',
    ).allMatches(upper);
    var bestCandidate = '';
    var bestScore = 0;

    for (final blockMatch in candidateBlocks) {
      final block = blockMatch.group(0) ?? '';
      final digitCount = RegExp(r'\d').allMatches(block).length;
      if (digitCount < 6) {
        continue;
      }

      final firstDigitMatch = RegExp(r'\d').firstMatch(block);
      if (firstDigitMatch == null) {
        continue;
      }

      final blockTail = block.substring(firstDigitMatch.start);
      final candidateSources = <String>{blockTail};
      for (final token in blockTail.split(RegExp(r'\s+'))) {
        final alnum = token.toUpperCase().replaceAll(RegExp(r'[^A-Z0-9]'), '');
        if (alnum.isEmpty) {
          continue;
        }
        final digitCount = RegExp(r'\d').allMatches(alnum).length;
        if (digitCount >= 6) {
          candidateSources.add(alnum);
        }
      }

      for (final source in candidateSources) {
        final digitsOnly = _normalizeOcrDigits(
          source,
        ).replaceAll(RegExp(r'[^0-9]'), '');
        if (digitsOnly.length < 10) {
          continue;
        }

        for (var i = 0; i <= digitsOnly.length - 10; i++) {
          final suffix = digitsOnly.substring(i, i + 10);
          final fullNik = '$noKkPrefix$suffix';
          if (!_isLikelyMemberNik(fullNik)) {
            continue;
          }
          if (preferAdult) {
            final birthDate = _birthDateFromNik(fullNik);
            if (birthDate == null) {
              continue;
            }
            final now = DateTime.now();
            var age = now.year - birthDate.year;
            final birthdayPassed =
                now.month > birthDate.month ||
                (now.month == birthDate.month && now.day >= birthDate.day);
            if (!birthdayPassed) {
              age -= 1;
            }
            if (age < 17) {
              continue;
            }
          }

          final score = _nikContextScore(fullNik, source);
          if (score > bestScore) {
            bestCandidate = fullNik;
            bestScore = score;
          }
        }
      }
    }

    return bestCandidate;
  }

  int _nikContextScore(String nik, String line) {
    final digitsOnly = _normalizeOcrDigits(
      line.toUpperCase(),
    ).replaceAll(RegExp(r'[^0-9]'), '');
    if (nik.length != 16 || digitsOnly.isEmpty) {
      return 0;
    }

    var score = _nikQualityScore(nik);
    final suffix10 = nik.substring(6);
    final date6 = nik.substring(6, 12);
    final suffix4 = nik.substring(12);
    if (digitsOnly.contains(suffix10)) {
      score += 40;
    }
    if (digitsOnly.contains(date6)) {
      score += 20;
    }
    if (digitsOnly.contains(suffix4)) {
      score += 8;
    }
    final birthDate = _birthDateFromNik(nik);
    if (birthDate != null) {
      final now = DateTime.now();
      var age = now.year - birthDate.year;
      final birthdayPassed =
          now.month > birthDate.month ||
          (now.month == birthDate.month && now.day >= birthDate.day);
      if (!birthdayPassed) {
        age -= 1;
      }
      if (age >= 17) {
        score += 25;
      } else {
        score -= 25;
      }
    }
    return score;
  }

  (int, int, int)? _extractLooseDateFromText(String input) {
    final normalized = _normalizeOcrDigits(input.toUpperCase());
    final dashedMatch = RegExp(
      r'\b(\d{2})[-\/\.]?(\d{2})[-\/\.](\d{2,4})\b',
    ).firstMatch(normalized);
    if (dashedMatch != null) {
      final day = int.tryParse(dashedMatch.group(1) ?? '');
      final month = int.tryParse(dashedMatch.group(2) ?? '');
      final yearRaw = int.tryParse(dashedMatch.group(3) ?? '');
      final year = yearRaw != null && yearRaw < 100
          ? (yearRaw <= 30 ? 2000 + yearRaw : 1900 + yearRaw)
          : yearRaw;
      if (day != null &&
          month != null &&
          year != null &&
          day >= 1 &&
          day <= 31 &&
          month >= 1 &&
          month <= 12) {
        return (day, month, year);
      }
    }

    final compactMatch = RegExp(
      r'\b(\d{2})(\d{2})(\d{4})\b',
    ).firstMatch(normalized);
    if (compactMatch == null) {
      return null;
    }

    final day = int.tryParse(compactMatch.group(1) ?? '');
    final month = int.tryParse(compactMatch.group(2) ?? '');
    final year = int.tryParse(compactMatch.group(3) ?? '');
    if (day == null || month == null || year == null) {
      return null;
    }
    if (day < 1 || day > 31 || month < 1 || month > 12) {
      return null;
    }
    return (day, month, year);
  }

  String _extractGenderHintFromText(String input) {
    final upper = input.toUpperCase();
    final compact = upper.replaceAll(RegExp(r'[^A-Z]'), '');
    if (compact.contains('PEREMPUAN') ||
        compact.contains('FEREMPUAN') ||
        compact.contains('PEREMPU') ||
        compact.contains('PERFVIPUAN') ||
        compact.contains('PERBUPUAN')) {
      return 'Perempuan';
    }
    if (compact.contains('LAKILAKI') ||
        compact.contains('LAKHAK') ||
        compact.contains('LAKHAKI') ||
        compact.contains('LAKI')) {
      return 'Laki-laki';
    }
    if (upper.contains(' PR ') ||
        upper.endsWith(' PR') ||
        upper.startsWith('PR ')) {
      return 'Perempuan';
    }
    if (upper.contains(' LK ') ||
        upper.endsWith(' LK') ||
        upper.startsWith('LK ')) {
      return 'Laki-laki';
    }
    return '';
  }

  (int, int)? _findNikTokenMatch(String line, {String? nikOverride}) {
    final normalized = _normalizeOcrDigits(line.toUpperCase());
    final normalizedOverride = _validNikDigits(nikOverride ?? '');
    final matches = RegExp(
      r'([0-9][0-9\s]{14,30}[0-9])',
    ).allMatches(normalized);
    (int, int)? bestMatch;
    var bestScore = -1;
    for (final match in matches) {
      final token = match.group(0) ?? '';
      final digits = token.replaceAll(RegExp(r'[^0-9]'), '');
      if (digits.length == 16) {
        if (normalizedOverride.isEmpty) {
          return (match.start, match.end);
        }
        final score = _nikOverrideMatchScore(digits, normalizedOverride);
        if (score > bestScore) {
          bestScore = score;
          bestMatch = (match.start, match.end);
        }
        continue;
      }
      if (digits.length > 16 && normalizedOverride.isNotEmpty) {
        final score = _nikOverrideMatchScore(digits, normalizedOverride);
        if (score > bestScore) {
          bestScore = score;
          bestMatch = (match.start, match.end);
        }
      }
    }
    return bestScore >= 0 ? bestMatch : null;
  }

  int _nikOverrideMatchScore(String digits, String nikOverride) {
    if (nikOverride.isEmpty || digits.isEmpty) {
      return -1;
    }

    if (digits.length == 16) {
      if (digits == nikOverride) {
        return 200;
      }

      final distance = _hammingDistance(digits, nikOverride);
      if (distance <= 2) {
        return 160 - (distance * 25);
      }

      if (digits.substring(6) == nikOverride.substring(6)) {
        return 125;
      }
      if (digits.substring(8) == nikOverride.substring(8)) {
        return 105;
      }

      final similarity = _normalizedEditSimilarity(digits, nikOverride);
      if (similarity >= 0.84) {
        return (similarity * 100).round();
      }
      return -1;
    }

    if (digits.length > 16) {
      var bestScore = -1;
      for (var i = 0; i <= digits.length - 16; i++) {
        final candidate = digits.substring(i, i + 16);
        final score = _nikOverrideMatchScore(candidate, nikOverride);
        if (score > bestScore) {
          bestScore = score;
        }
      }
      return bestScore;
    }

    return -1;
  }

  bool _isLikelyMemberNik(String nik, {String noKkHint = ''}) {
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
    final x = (width * _memberTableLeftRatio).round();
    final y = (height * _memberTableTopRatio).round();
    final w = (width * _memberTableWidthRatio).round();
    final h = (height * _memberTableHeightRatio).round();
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

    final dataX = tableX + (tableW * 0.02).round();
    final dataW = (tableW * 0.97).round();
    final dataStartY =
        tableY + (tableH * _memberTableHeaderHeightRatio).round();
    final rowHeight = (tableH * _memberTableRowHeightRatio).round();
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

  String _cleanTempatSebelumTanggal(String input) {
    final tokens = input
        .replaceAll('|', ' ')
        .split(RegExp(r'\s+'))
        .map((token) => token.trim())
        .where((token) => token.isNotEmpty)
        .toList();
    if (tokens.isEmpty) return '';

    const leadingNoise = {
      'AW',
      'PR',
      'LK',
      'LAKI',
      'LAKH',
      'LAKHAKI',
      'LAKILAKI',
      'PEREMPUAN',
      'PERBUPUAN',
      'PERBUPUANGYGUTAF',
      'PEREMFUAN',
      'PERBUPUANCMAAH',
    };

    while (tokens.isNotEmpty) {
      final normalized = tokens.first.toUpperCase().replaceAll(
        RegExp(r'[^A-Z]'),
        '',
      );
      final isGenderNoise =
          leadingNoise.contains(normalized) ||
          normalized.startsWith('LAK') ||
          normalized.startsWith('PER');
      final isShortNoise = normalized.length <= 2;
      if (!isGenderNoise && !isShortNoise) {
        break;
      }
      tokens.removeAt(0);
    }

    final cleaned = _cleanMemberDetailValue(tokens.join(' '));
    final knownPlace = _extractKnownPlaceFromDirtyValue(cleaned);
    if (knownPlace.isNotEmpty) {
      return knownPlace;
    }
    return cleaned;
  }

  /// Normalize tempat lahir from OCR structured field.
  /// Filters out garbled text like "22091", "G 2505 1", "J DARA IU MIA 18-08-2"
  String _normalizeTempatLahir(String input) {
    var cleaned = _cleanStructuredField(input);
    if (cleaned.isEmpty) return '';

    // Remove embedded dates (e.g., "18-08-2" or "01-11-2001")
    cleaned = cleaned
        .replaceAll(RegExp(r'\b\d{1,2}[-/.]\d{1,2}[-/.]\d{1,4}\b'), '')
        .trim();

    // If it's purely numeric (e.g., "22091"), it's garbled — clear it
    if (RegExp(r'^[\d\s]+$').hasMatch(cleaned)) return '';

    final knownPlace = _extractKnownPlaceFromDirtyValue(cleaned);
    if (knownPlace.isNotEmpty) {
      return _toTitleCase(knownPlace);
    }

    // Filter out individual noise tokens
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
      // Pure numbers
      if (RegExp(r'^[\d]+$').hasMatch(w)) return false;
      // Single letter
      if (w.length <= 1) return false;
      if (w.length <= 2 && RegExp(r'\d').hasMatch(w)) return false;
      // Common OCR noise
      if (noise.contains(w)) return false;
      if (w.contains('PEREMPUAN') || w.contains('FEREMPUAN')) return false;
      if (w.contains('LAKI')) return false;
      if (w.contains('ISLAM') || w.contains('SIAM')) return false;
      return true;
    }).toList();

    if (words.isEmpty) return '';

    // If remaining text is too short or looks garbled, clear it
    final result = words.join(' ').trim();
    if (result.length < 3) return '';
    // Must contain at least 3 alpha characters to be a real place name
    final alphaCount = result.replaceAll(RegExp(r'[^A-Z]'), '').length;
    if (alphaCount < 3) return '';

    // Strip leading single-character noise
    final resultClean = result.replaceFirst(RegExp(r'^[A-Z]\s+'), '').trim();
    if (resultClean.isEmpty || resultClean.length < 3) return '';

    // Try fuzzy matching against common Indonesian city/regency names
    // that often appear in KK documents
    final fuzzyResult = _fuzzyMatchTempatLahir(resultClean);
    if (fuzzyResult != null) return _toTitleCase(fuzzyResult);

    final resultWords = resultClean
        .split(' ')
        .where((w) => w.isNotEmpty)
        .toList();
    if (resultWords.length >= 2 && resultWords.every((w) => w.length <= 3)) {
      return '';
    }
    if (resultWords.length == 2 &&
        resultWords.first.length <= 3 &&
        resultWords.last.length <= 5) {
      return '';
    }
    if (resultWords.length == 1 && resultWords.first.length <= 5) {
      return '';
    }

    // If the remaining text is very short (< 5 chars) and didn't fuzzy-match,
    // it's likely OCR noise like "DARA", "BARAT" fragments
    if (resultClean.length <= 4) return '';

    return _toTitleCase(resultClean);
  }

  String _extractKnownPlaceFromDirtyValue(String input) {
    final compact = _cleanStructuredField(
      input,
    ).replaceAll(RegExp(r'[^A-Z]'), '');
    if (compact.length < 4) {
      return '';
    }

    const knownPlaces = <String, String>{
      'BANDUNGBARAT': 'BANDUNG BARAT',
      'RANDUNGBARAT': 'BANDUNG BARAT',
      'BANDUNG': 'BANDUNG',
      'RANDUNG': 'BANDUNG',
      'CIMAHI': 'CIMAHI',
      'CMAAH': 'CIMAHI',
      'CMAHI': 'CIMAHI',
      'CIBABAT': 'CIBABAT',
    };

    for (final entry in knownPlaces.entries) {
      if (compact.contains(entry.key)) {
        return entry.value;
      }
    }

    return '';
  }

  /// Fuzzy-match garbled tempat lahir against common Indonesian cities.
  String? _fuzzyMatchTempatLahir(String input) {
    const commonPlaceAliases = <String, String>{
      'CMAAH': 'CIMAHI',
      'CMAHI': 'CIMAHI',
      'RANDUNG': 'BANDUNG',
      'RANDUNGBARAT': 'BANDUNG BARAT',
    };

    // Common cities/regencies that appear on KK documents in West Java area
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
    final aliasedPlace = commonPlaceAliases[inputAlpha];
    if (aliasedPlace != null) {
      return aliasedPlace;
    }

    String? bestMatch;
    var bestScore = 0.0;

    for (final place in commonPlaces) {
      final placeAlpha = place.replaceAll(RegExp(r'[^A-Z]'), '');
      final bigramScore = _bigramSimilarity(inputAlpha, placeAlpha);
      final editScore = _normalizedEditSimilarity(inputAlpha, placeAlpha);
      final score = editScore >= 0.65 && editScore > bigramScore
          ? editScore
          : bigramScore;
      if (score > bestScore) {
        bestScore = score;
        bestMatch = place;
      }
    }

    // Require a high similarity threshold to avoid false positives
    if (bestScore >= 0.45 && bestMatch != null) {
      return bestMatch;
    }
    return null;
  }

  /// Normalize pendidikan from OCR structured field.
  /// Maps garbled OCR text to known pendidikan values.
  String _normalizePendidikanField(String input) {
    final cleaned = _cleanStructuredField(input);
    if (cleaned.isEmpty) return '';

    final upper = cleaned.toUpperCase().replaceAll(RegExp(r'\s+'), ' ').trim();
    final compact = upper.replaceAll(RegExp(r'[\s/]+'), '');

    // Try exact and fuzzy matching against known values
    const knownPendidikan = [
      'TIDAK/BELUM SEKOLAH',
      'BELUM TAMAT SD/SEDERAJAT',
      'TAMAT SD/SEDERAJAT',
      'SLTA/SEDERAJAT',
      'SLTP/SEDERAJAT',
      'AKADEMI/DIPLOMA III/SARJANA MUDA',
      'DIPLOMA I/II',
      'DIPLOMA IV/STRATA I',
      'STRATA II',
      'STRATA III',
    ];

    for (final p in knownPendidikan) {
      if (compact.contains(p.replaceAll('/', '').replaceAll(' ', ''))) {
        return _canonicalPendidikanDisplay(p);
      }
      final words = p.split(RegExp(r'[\s/]+'));
      final matchCount = words.where((w) => upper.contains(w)).length;
      if (matchCount >= words.length - 1 && words.length >= 2) {
        return _canonicalPendidikanDisplay(p);
      }
    }

    // Partial / garbled matches
    if (upper.contains('AKADEMI') ||
        upper.contains('DIPLOMA III') ||
        upper.contains('SARJANA MUDA') ||
        upper.contains('SARJANA') ||
        compact.contains('DIPLOMAIII') ||
        compact.contains('SARJANAMUDA')) {
      return _canonicalPendidikanDisplay('AKADEMI/DIPLOMA III/SARJANA MUDA');
    }
    if (upper.contains('SLTA') || compact.contains('SLTA')) {
      return _canonicalPendidikanDisplay('SLTA/SEDERAJAT');
    }
    if (upper.contains('SLTP') || compact.contains('SLTP')) {
      return _canonicalPendidikanDisplay('SLTP/SEDERAJAT');
    }
    if (upper.contains('SD') && !upper.contains('SL')) {
      return _canonicalPendidikanDisplay('TAMAT SD/SEDERAJAT');
    }
    if (upper.contains('STRATA I') || upper.contains('DIPLOMA IV')) {
      return _canonicalPendidikanDisplay('DIPLOMA IV/STRATA I');
    }
    if (upper.contains('BELUM') && upper.contains('SEKOLAH')) {
      return _canonicalPendidikanDisplay('TIDAK/BELUM SEKOLAH');
    }

    // Aggressive OCR garble recovery using bigram similarity
    final bestMatch = _fuzzyMatchPendidikan(compact);
    if (bestMatch != null) return _canonicalPendidikanDisplay(bestMatch);

    // If it's just noise (mostly garbled short words), clear it
    final alphaCount = compact.replaceAll(RegExp(r'[^A-Z]'), '').length;
    if (alphaCount < 4) return '';

    // Check if it's too garbled to be meaningful
    final words = upper.split(' ');
    final garbledCount = words
        .where((w) => w.length >= 4 && !_hasReasonableVowelRatio(w))
        .length;
    if (words.isNotEmpty && garbledCount / words.length > 0.5) return '';

    return _canonicalPendidikanDisplay(cleaned);
  }

  /// Normalize pekerjaan from OCR structured field.
  String _normalizePekerjaanField(String input) {
    final cleaned = _cleanStructuredField(input);
    if (cleaned.isEmpty) return '';

    final upper = cleaned.toUpperCase().replaceAll(RegExp(r'\s+'), ' ').trim();
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
      if (compact.contains(p.replaceAll('/', '').replaceAll(' ', ''))) {
        return _canonicalPekerjaanDisplay(p);
      }
      final words = p.split(RegExp(r'[\s/]+'));
      final matchCount = words.where((w) => upper.contains(w)).length;
      if (matchCount >= words.length - 1 && words.length >= 2) {
        return _canonicalPekerjaanDisplay(p);
      }
    }

    // Partial matches
    if (upper.contains('WIRASWASTA') || upper.contains('WRASWASTA')) {
      return _canonicalPekerjaanDisplay('WIRASWASTA');
    }
    if (upper.contains('KARYAWAN')) {
      return _canonicalPekerjaanDisplay('KARYAWAN SWASTA');
    }
    if (upper.contains('BELUM') && upper.contains('BEKERJA')) {
      return _canonicalPekerjaanDisplay('BELUM/TIDAK BEKERJA');
    }
    if (upper.contains('TIDAK') && upper.contains('BEKERJA')) {
      return _canonicalPekerjaanDisplay('BELUM/TIDAK BEKERJA');
    }
    if (upper.contains('PELAJAR')) {
      return _canonicalPekerjaanDisplay('PELAJAR/MAHASISWA');
    }
    if (upper.contains('MAHASISWA')) {
      return _canonicalPekerjaanDisplay('PELAJAR/MAHASISWA');
    }
    if (upper.contains('MENGURUS') || upper.contains('RUMAH TANGGA')) {
      return _canonicalPekerjaanDisplay('MENGURUS RUMAH TANGGA');
    }
    if (upper.contains('PETANI')) return _canonicalPekerjaanDisplay('PETANI');
    if (upper.contains('PEDAGANG')) {
      return _canonicalPekerjaanDisplay('PEDAGANG');
    }
    if (upper.contains('BURUH')) return _canonicalPekerjaanDisplay('BURUH');
    if (upper.contains('PENSIUNAN')) {
      return _canonicalPekerjaanDisplay('PENSIUNAN');
    }

    // Fuzzy match with bigram similarity
    final inputAlpha = compact.replaceAll(RegExp(r'[^A-Z]'), '');
    if (inputAlpha.length >= 3) {
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
        return _canonicalPekerjaanDisplay(bestMatch);
      }
    }

    // If it's just noise, clear it
    final alphaCount = upper.replaceAll(RegExp(r'[^A-Z]'), '').length;
    if (alphaCount < 3) return '';

    // Check if garbled
    final words = upper.split(' ');
    final garbledCount = words
        .where((w) => w.length >= 4 && !_hasReasonableVowelRatio(w))
        .length;
    if (words.isNotEmpty && garbledCount / words.length > 0.5) return '';

    return _canonicalPekerjaanDisplay(cleaned);
  }

  String _canonicalPendidikanDisplay(String input) {
    final upper = input.toUpperCase().replaceAll(RegExp(r'\s+'), ' ').trim();
    switch (upper) {
      case 'TIDAK/BELUM SEKOLAH':
      case 'TIDAK BELUM SEKOLAH':
        return 'Tidak/belum Sekolah';
      case 'BELUM TAMAT SD/SEDERAJAT':
        return 'Belum Tamat SD/Sederajat';
      case 'TAMAT SD/SEDERAJAT':
        return 'Tamat SD/Sederajat';
      case 'SLTP/SEDERAJAT':
        return 'SLTP/Sederajat';
      case 'SLTA/SEDERAJAT':
        return 'SLTA/Sederajat';
      case 'DIPLOMA I/II':
        return 'Diploma I/II';
      case 'AKADEMI/DIPLOMA III/SARJANA MUDA':
      case 'AKADEMI/DIPLOMA III/S. MUDA':
        return 'Akademi/Diploma III/Sarjana Muda';
      case 'DIPLOMA IV/STRATA I':
        return 'Diploma IV/Strata I';
      case 'STRATA II':
        return 'Strata II';
      case 'STRATA III':
        return 'Strata III';
      default:
        return _toTitleCase(input);
    }
  }

  String _canonicalPekerjaanDisplay(String input) {
    final upper = input.toUpperCase().replaceAll(RegExp(r'\s+'), ' ').trim();
    switch (upper) {
      case 'WIRASWASTA':
        return 'Wiraswasta';
      case 'KARYAWAN SWASTA':
        return 'Karyawan Swasta';
      case 'BELUM/TIDAK BEKERJA':
      case 'BELUM BEKERJA':
      case 'TIDAK BEKERJA':
        return 'Belum/tidak Bekerja';
      case 'PELAJAR/MAHASISWA':
        return 'Pelajar/Mahasiswa';
      case 'PNS':
        return 'PNS';
      case 'PETANI':
        return 'Petani';
      case 'PEDAGANG':
        return 'Pedagang';
      case 'BURUH':
        return 'Buruh';
      case 'NELAYAN':
        return 'Nelayan';
      case 'PENSIUNAN':
        return 'Pensiunan';
      case 'MENGURUS RUMAH TANGGA':
        return 'Mengurus Rumah Tangga';
      default:
        return _toTitleCase(input);
    }
  }

  String _cleanStructuredField(String input) {
    return input
        .toUpperCase()
        .replaceAll(RegExp(r'[^A-Z0-9/\-\+\s]'), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
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

  double _normalizedEditSimilarity(String a, String b) {
    if (a.isEmpty || b.isEmpty) return 0.0;
    if (a == b) return 1.0;

    final rows = List<int>.generate(b.length + 1, (index) => index);
    for (var i = 1; i <= a.length; i++) {
      var previousDiagonal = rows.first;
      rows[0] = i;
      for (var j = 1; j <= b.length; j++) {
        final previousTop = rows[j];
        final substitutionCost = a[i - 1] == b[j - 1] ? 0 : 1;
        rows[j] = [
          rows[j] + 1,
          rows[j - 1] + 1,
          previousDiagonal + substitutionCost,
        ].reduce((left, right) => left < right ? left : right);
        previousDiagonal = previousTop;
      }
    }

    final distance = rows.last;
    final maxLength = a.length > b.length ? a.length : b.length;
    if (maxLength == 0) return 0.0;
    return 1 - (distance / maxLength);
  }

  int _hammingDistance(String left, String right) {
    if (left.length != right.length) {
      return 999;
    }

    var distance = 0;
    for (var i = 0; i < left.length; i++) {
      if (left[i] != right[i]) {
        distance += 1;
      }
    }
    return distance;
  }

  /// Maps OCR-detected hubungan text to PocketBase select values: Ayah, Ibu, Anak.
  String _mapHubunganToDbValue(String input) {
    final upper = input.toUpperCase();
    if (upper.contains('KEPALA KELUARGA') || upper.contains('SUAMI')) {
      return 'Ayah';
    }
    if (upper.contains('ISTRI') || upper.contains('IBU')) return 'Ibu';
    if (upper.contains('ANAK') ||
        upper.contains('MENANTU') ||
        upper.contains('CUCU')) {
      return 'Anak';
    }
    return 'Anak'; // Default fallback
  }

  String _normalizeStructuredName(String input) {
    // First, strip digits that OCR may have injected into a name
    var cleaned = input
        .toUpperCase()
        .replaceAll(RegExp(r'[0-9]'), '')
        .replaceAll('/', ' ')
        .replaceAll(RegExp(r"[^A-Z\s'.-]"), ' ')
        .replaceAll(RegExp(r'\s+'), ' ')
        .trim();
    if (cleaned.isEmpty) return '';

    // Strip leading single-character noise (e.g., "J ARINI" → "ARINI")
    // This happens when OCR captures grid borders or row numbers as a letter
    cleaned = cleaned.replaceFirst(RegExp(r'^[A-Z]\s+'), '').trim();

    // Remove common OCR noise words (short nonsense fragments)
    const ocrNoise = {
      'TVS',
      'LVI',
      'JLT',
      'BL',
      'BD',
      'BSNS',
      'TAM',
      'TAP',
      'FP',
      'PAI',
      'NF',
      'IF',
      'MD',
      'NON',
      'NA',
      'OA',
      'GA',
      'EE',
      'DA',
      'HE',
      'DE',
      'DAN',
      'NETT',
      'AALT',
      'TAMNI',
      'AMOVGONGA',
      'YE',
      'EL',
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
      'WA',
      'WNI',
      'WN',
      'II',
      'TT',
      'PP',
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
    // Also reject KK-specific column header words
    const columnHeaders = {
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
      'STATUS',
      'ISLAM',
      'KRISTEN',
      'LAKI',
      'PEREMPUAN',
      'KARYAWAN',
      'SWASTA',
      'WIRASWASTA',
      'HUBUNGAN',
      'KELUARGA',
      'KEPALA',
    };
    final words = cleaned.split(' ').where((w) {
      if (w.length < 2) return false;
      if (ocrNoise.contains(w)) return false;
      if (columnHeaders.contains(w)) return false;
      // Filter out words that are all the same character repeated (e.g., "SS", "RR")
      if (w.length <= 3 && RegExp(r'^(.)\1+$').hasMatch(w)) return false;
      // Filter words that look like garbled OCR (heavy consonant clusters, no vowels)
      if (w.length >= 4 && !_hasReasonableVowelRatio(w)) return false;
      return true;
    }).toList();

    if (words.isEmpty) return '';

    // If total character count is too low, it's noise (e.g. "WA WANS" = 6 chars)
    final totalChars = words.join('').length;
    if (totalChars < 4) return '';

    // If more than 60% of words are 2 chars, likely noise
    final shortCount = words.where((w) => w.length <= 2).length;
    if (words.length >= 3 && shortCount / words.length > 0.6) return '';

    // If more than half the words look garbled, reject
    final garbledCount = words.where((w) => _looksGarbled(w)).length;
    if (words.isNotEmpty && garbledCount / words.length > 0.5) return '';

    // Try to merge broken name fragments: e.g. "FARDIANS YAH" → "FARDIANSYAH"
    // This happens when OCR splits a word at a random position
    final merged = _mergeFragmentedWords(words);

    final result = merged.join(' ');
    if (!_isLikelyName(result)) return '';
    return _toTitleCase(result);
  }

  String _normalizeFinalMemberName(String input) {
    final structured = _normalizeStructuredName(input);
    if (structured.isEmpty) {
      return '';
    }

    final tokens = structured
        .toUpperCase()
        .split(' ')
        .map((token) => token.replaceAll(RegExp(r'[^A-Z]'), ''))
        .where((token) => token.isNotEmpty)
        .toList();
    if (tokens.isEmpty) {
      return '';
    }

    final normalizedTokens = <String>[];
    for (var i = 0; i < tokens.length; i++) {
      final normalized = _normalizeFinalMemberNameToken(
        tokens[i],
        isFirstToken: i == 0,
      );
      if (normalized.isEmpty) {
        continue;
      }
      if (normalizedTokens.isNotEmpty && normalizedTokens.last == normalized) {
        continue;
      }
      normalizedTokens.add(normalized);
    }

    while (normalizedTokens.length > 1 &&
        _looksLikeTrailingNameNoise(normalizedTokens.last)) {
      normalizedTokens.removeLast();
    }

    if (normalizedTokens.isEmpty) {
      return '';
    }

    return _toTitleCase(normalizedTokens.join(' '));
  }

  String _normalizeFinalMemberNameToken(
    String token, {
    bool isFirstToken = false,
  }) {
    final upper = token.toUpperCase().replaceAll(RegExp(r'[^A-Z]'), '');
    if (upper.isEmpty) {
      return '';
    }

    const explicitAliases = <String, String>{
      'JAAIS': 'AZIS',
      'JAAS': 'AZIS',
      'JAZIS': 'AZIS',
      'JARINI': 'ARINI',
      'SINAAL': 'SINA AL',
      'JHAN': 'JIHAN',
      'THAN': 'JIHAN',
      'RANA': 'RANIA',
      'LAHADIZA': 'HADIZA',
      'AZRR': '',
      'AZR': '',
    };
    final explicit = explicitAliases[upper];
    if (explicit != null) {
      return explicit;
    }

    const canonicalTokens = <String>[
      'AZIS',
      'ARINI',
      'JIHAN',
      'RANIA',
      'HADIZA',
      'ALFIANI',
      'FARDIANSYAH',
      'MUHAMMAD',
      'KAUTSAR',
      'SINA',
    ];
    for (final canonical in canonicalTokens) {
      if (upper == canonical) {
        return canonical;
      }
      if (_isLikelyExtraLeadingChar(upper, canonical)) {
        return canonical;
      }
      if (_normalizedEditSimilarity(upper, canonical) >= 0.82) {
        return canonical;
      }
    }

    if (_looksLikeTrailingNameNoise(upper) &&
        (!isFirstToken || upper.length <= 3)) {
      return '';
    }

    return upper;
  }

  bool _looksLikeTrailingNameNoise(String token) {
    const allowedShortTokens = {
      'AL',
      'BIN',
      'BINTI',
      'NUR',
      'SRI',
      'ABD',
      'MOH',
      'MOCH',
    };

    if (allowedShortTokens.contains(token)) {
      return false;
    }
    if (token.length <= 1) {
      return true;
    }
    if (token.length <= 3 && !_hasReasonableVowelRatio(token)) {
      return true;
    }
    if (token.length <= 4 && RegExp(r'[^AEIOU]{3,}').hasMatch(token)) {
      return true;
    }
    if (RegExp(r'^[A-Z]{1,2}R{2,}$').hasMatch(token)) {
      return true;
    }
    return false;
  }

  /// Check if a word has a reasonable vowel-to-consonant ratio.
  /// Real Indonesian names have vowels; garbled OCR like "IAIVHIIVI" has
  /// unusual patterns.
  bool _hasReasonableVowelRatio(String word) {
    if (word.length < 4) return true;
    const vowels = {'A', 'E', 'I', 'O', 'U'};
    final vowelCount = word.split('').where((c) => vowels.contains(c)).length;
    final ratio = vowelCount / word.length;
    // Indonesian names typically have 30-60% vowels
    // Reject if too few vowels (all consonants) or too many vowels
    if (ratio < 0.15) return false;
    // Check for excessive consecutive consonants (> 3 in a row)
    if (RegExp(r'[^AEIOU]{5,}').hasMatch(word)) return false;
    return true;
  }

  /// Check if a word looks garbled (not a plausible Indonesian name part).
  bool _looksGarbled(String word) {
    if (word.length < 4) return false;
    // Check if the word has no common Indonesian syllable patterns
    // Garbled words often have unusual letter combinations
    const vowels = {'A', 'E', 'I', 'O', 'U'};
    final vowelCount = word.split('').where((c) => vowels.contains(c)).length;
    final ratio = vowelCount / word.length;
    // Too many vowels (> 70%) or too few (< 20%) suggests garbled text
    if (ratio > 0.70 || ratio < 0.20) return true;
    // Excessive repetition of same 2-char bigram
    for (var i = 0; i < word.length - 3; i++) {
      final bigram = word.substring(i, i + 2);
      var count = 0;
      for (var j = 0; j < word.length - 1; j++) {
        if (word.substring(j, j + 2) == bigram) count++;
      }
      if (count >= 3) return true;
    }
    return false;
  }

  /// Merge OCR-fragmented words back together.
  /// E.g. ['FARDIANS', 'YAH'] → ['FARDIANSYAH']
  /// Heuristic: if a word is <= 3 chars and the previous word doesn't look
  /// like a complete name part, merge them.
  List<String> _mergeFragmentedWords(List<String> words) {
    if (words.length <= 1) return words;
    final result = <String>[words.first];
    for (var i = 1; i < words.length; i++) {
      final current = words[i];
      final prev = result.last;
      // Merge if current fragment is short (<=3 chars) and prev is not a
      // common standalone word, OR if the combo looks like a known pattern
      if (current.length <= 3 && prev.length >= 3) {
        // Likely a broken suffix — merge
        result[result.length - 1] = '$prev$current';
      } else if (prev.length <= 3 && current.length >= 3) {
        // Previous was a broken prefix — merge
        result[result.length - 1] = '$prev$current';
      } else {
        result.add(current);
      }
    }
    return result;
  }

  String _normalizeStructuredJenisKelamin(String input) {
    final upper = input.toUpperCase();
    if (upper.contains('PEREMPUAN') || upper.contains('PR')) {
      return 'Perempuan';
    }
    if (upper.contains('LAKI') || upper.contains('LK')) {
      return 'Laki-laki';
    }
    return '';
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
