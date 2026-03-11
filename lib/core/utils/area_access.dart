import 'package:pocketbase/pocketbase.dart';

import '../../features/auth/providers/auth_provider.dart';
import '../../shared/models/iuran_model.dart';
import '../../shared/models/kartu_keluarga_model.dart';
import '../../shared/models/surat_model.dart';
import '../../shared/models/warga_model.dart';
import '../constants/app_constants.dart';
import '../services/pocketbase_service.dart';

class AreaAccessContext {
  const AreaAccessContext({
    this.rt,
    this.rw,
    this.desaCode,
    this.kecamatanCode,
    this.kabupatenCode,
    this.provinsiCode,
    this.desaKelurahan,
    this.kecamatan,
    this.kabupatenKota,
    this.provinsi,
    this.wargaId,
    this.kkId,
  });

  final int? rt;
  final int? rw;
  final String? desaCode;
  final String? kecamatanCode;
  final String? kabupatenCode;
  final String? provinsiCode;
  final String? desaKelurahan;
  final String? kecamatan;
  final String? kabupatenKota;
  final String? provinsi;
  final String? wargaId;
  final String? kkId;

  bool get hasArea => rt != null && rw != null && rt! > 0 && rw! > 0;
  bool get hasRegionalCodes =>
      hasArea &&
      (desaCode ?? '').trim().isNotEmpty &&
      (kecamatanCode ?? '').trim().isNotEmpty &&
      (kabupatenCode ?? '').trim().isNotEmpty &&
      (provinsiCode ?? '').trim().isNotEmpty;
  bool get hasRegionalNames =>
      hasArea &&
      (desaKelurahan ?? '').trim().isNotEmpty &&
      (kecamatan ?? '').trim().isNotEmpty &&
      (kabupatenKota ?? '').trim().isNotEmpty &&
      (provinsi ?? '').trim().isNotEmpty;
  bool get hasRegionalScope => hasRegionalCodes || hasRegionalNames;
}

int? recordNumericField(RecordModel record, String field) {
  final raw = record.data[field];
  if (raw is int) return raw;
  return int.tryParse(record.getStringValue(field));
}

String recordTextField(RecordModel record, String field) {
  final fromGetter = record.getStringValue(field).trim();
  if (fromGetter.isNotEmpty) {
    return fromGetter;
  }
  final raw = record.data[field];
  return raw?.toString().trim() ?? '';
}

String _escapeFilterValue(String value) {
  return value.replaceAll(r'\', r'\\').replaceAll('"', r'\"');
}

String _normalizeAreaValue(String? value) {
  return (value ?? '').trim().toLowerCase();
}

bool _isWarga(AuthState auth) {
  return !auth.isOperator && !auth.isSysadmin;
}

bool _hasRwWideAccess(AuthState auth) {
  return auth.isSysadmin || auth.hasRwWideAccess;
}

bool _matchesScopedCode(String? expected, String? actual) {
  final normalizedExpected = (expected ?? '').trim();
  final normalizedActual = (actual ?? '').trim();
  if (normalizedExpected.isEmpty || normalizedActual.isEmpty) {
    return false;
  }
  return normalizedExpected == normalizedActual;
}

bool _matchesScopedArea(String? expected, String? actual) {
  final normalizedExpected = _normalizeAreaValue(expected);
  final normalizedActual = _normalizeAreaValue(actual);
  if (normalizedExpected.isEmpty || normalizedActual.isEmpty) {
    return false;
  }
  return normalizedExpected == normalizedActual;
}

String _buildRegionFilter({
  required String prefix,
  required AreaAccessContext context,
}) {
  final sanitizedPrefix = prefix.isEmpty ? '' : '$prefix.';
  if (context.hasRegionalCodes) {
    return [
      '${sanitizedPrefix}desa_code = "${_escapeFilterValue(context.desaCode!)}"',
      '${sanitizedPrefix}kecamatan_code = "${_escapeFilterValue(context.kecamatanCode!)}"',
      '${sanitizedPrefix}kabupaten_code = "${_escapeFilterValue(context.kabupatenCode!)}"',
      '${sanitizedPrefix}provinsi_code = "${_escapeFilterValue(context.provinsiCode!)}"',
    ].join(' && ');
  }

  return [
    '${sanitizedPrefix}desa_kelurahan ~ "${_escapeFilterValue(context.desaKelurahan!)}"',
    '${sanitizedPrefix}kecamatan ~ "${_escapeFilterValue(context.kecamatan!)}"',
    '${sanitizedPrefix}kabupaten_kota ~ "${_escapeFilterValue(context.kabupatenKota!)}"',
    '${sanitizedPrefix}provinsi ~ "${_escapeFilterValue(context.provinsi!)}"',
  ].join(' && ');
}

Future<AreaAccessContext> resolveAreaAccessContext(AuthState auth) async {
  if (auth.user == null) {
    return const AreaAccessContext();
  }

  int? rt = recordNumericField(auth.user!, 'rt');
  int? rw = recordNumericField(auth.user!, 'rw');
  String? desaCode = recordTextField(auth.user!, 'desa_code');
  String? kecamatanCode = recordTextField(auth.user!, 'kecamatan_code');
  String? kabupatenCode = recordTextField(auth.user!, 'kabupaten_code');
  String? provinsiCode = recordTextField(auth.user!, 'provinsi_code');
  String? desaKelurahan = recordTextField(auth.user!, 'desa_kelurahan');
  String? kecamatan = recordTextField(auth.user!, 'kecamatan');
  String? kabupatenKota = recordTextField(auth.user!, 'kabupaten_kota');
  String? provinsi = recordTextField(auth.user!, 'provinsi');
  String? wargaId;
  String? kkId;

  try {
    final warga = await pb
        .collection(AppConstants.colWarga)
        .getFirstListItem('user_id = "${auth.user!.id}"');
    wargaId = warga.id;
    kkId = warga.getStringValue('no_kk');
    rt ??= recordNumericField(warga, 'rt');
    rw ??= recordNumericField(warga, 'rw');

    if (kkId.isNotEmpty) {
      try {
        final kk = await pb
            .collection(AppConstants.colKartuKeluarga)
            .getOne(kkId);
        final kkDesa = recordTextField(kk, 'desa_kelurahan').isNotEmpty
            ? recordTextField(kk, 'desa_kelurahan')
            : recordTextField(kk, 'kelurahan');
        final kkKabupaten = recordTextField(kk, 'kabupaten_kota').isNotEmpty
            ? recordTextField(kk, 'kabupaten_kota')
            : recordTextField(kk, 'kota');

        if (desaKelurahan.trim().isEmpty) {
          desaKelurahan = kkDesa;
        }
        if (desaCode.trim().isEmpty) {
          desaCode = recordTextField(kk, 'desa_code');
        }
        if (kecamatan.trim().isEmpty) {
          kecamatan = recordTextField(kk, 'kecamatan');
        }
        if (kecamatanCode.trim().isEmpty) {
          kecamatanCode = recordTextField(kk, 'kecamatan_code');
        }
        if (kabupatenKota.trim().isEmpty) {
          kabupatenKota = kkKabupaten;
        }
        if (kabupatenCode.trim().isEmpty) {
          kabupatenCode = recordTextField(kk, 'kabupaten_code');
        }
        if (provinsi.trim().isEmpty) {
          provinsi = recordTextField(kk, 'provinsi');
        }
        if (provinsiCode.trim().isEmpty) {
          provinsiCode = recordTextField(kk, 'provinsi_code');
        }
      } catch (_) {}
    }
  } catch (_) {}

  return AreaAccessContext(
    rt: rt,
    rw: rw,
    desaCode: desaCode,
    kecamatanCode: kecamatanCode,
    kabupatenCode: kabupatenCode,
    provinsiCode: provinsiCode,
    desaKelurahan: desaKelurahan,
    kecamatan: kecamatan,
    kabupatenKota: kabupatenKota,
    provinsi: provinsi,
    wargaId: wargaId,
    kkId: kkId,
  );
}

String buildWargaScopeFilter(
  AuthState auth, {
  required AreaAccessContext context,
}) {
  if (auth.user == null) {
    return 'id = ""';
  }

  if (auth.isSysadmin) {
    return '';
  }

  if (_isWarga(auth)) {
    return 'user_id = "${auth.user!.id}"';
  }

  if (!context.hasRegionalScope) {
    return 'id = ""';
  }

  final baseConditions = <String>[];
  if (_hasRwWideAccess(auth)) {
    baseConditions.add('rw = ${context.rw}');
  } else {
    baseConditions.add('rt = ${context.rt}');
    baseConditions.add('rw = ${context.rw}');
  }

  baseConditions.add(_buildRegionFilter(prefix: 'no_kk', context: context));
  return baseConditions.join(' && ');
}

String buildKkScopeFilter(
  AuthState auth, {
  required AreaAccessContext context,
}) {
  if (auth.user == null) {
    return 'id = ""';
  }

  if (auth.isSysadmin) {
    return '';
  }

  if (_isWarga(auth)) {
    if ((context.kkId ?? '').isNotEmpty) {
      return 'id = "${context.kkId}"';
    }
    return 'user_id = "${auth.user!.id}"';
  }

  if (!context.hasRegionalScope) {
    return 'id = ""';
  }

  final baseConditions = <String>[];
  if (_hasRwWideAccess(auth)) {
    baseConditions.add('rw = ${context.rw}');
  } else {
    baseConditions.add('rt = ${context.rt}');
    baseConditions.add('rw = ${context.rw}');
  }

  baseConditions.add(_buildRegionFilter(prefix: '', context: context));
  return baseConditions.join(' && ');
}

String buildSuratScopeFilter(
  AuthState auth, {
  required AreaAccessContext context,
}) {
  if (auth.user == null) {
    return 'id = ""';
  }

  if (auth.isSysadmin) {
    return '';
  }

  if (_isWarga(auth)) {
    return 'submitted_by = "${auth.user!.id}"';
  }

  if (!context.hasRegionalScope) {
    return 'id = ""';
  }

  final baseConditions = <String>[];
  if (_hasRwWideAccess(auth)) {
    baseConditions.add('rw = ${context.rw}');
  } else {
    baseConditions.add('rt = ${context.rt}');
    baseConditions.add('rw = ${context.rw}');
  }

  baseConditions.add(_buildRegionFilter(prefix: '', context: context));
  return baseConditions.join(' && ');
}

String buildIuranPeriodScopeFilter(
  AuthState auth, {
  required AreaAccessContext context,
}) {
  if (auth.user == null) {
    return 'id = ""';
  }

  if (auth.isSysadmin) {
    return '';
  }

  if (!context.hasRegionalScope) {
    return 'id = ""';
  }

  final baseConditions = <String>[];
  if (_hasRwWideAccess(auth)) {
    baseConditions.add('rw = ${context.rw}');
  } else {
    baseConditions.add('rt = ${context.rt}');
    baseConditions.add('rw = ${context.rw}');
  }

  baseConditions.add(_buildRegionFilter(prefix: '', context: context));
  return baseConditions.join(' && ');
}

String buildIuranBillScopeFilter(
  AuthState auth, {
  required AreaAccessContext context,
}) {
  if (auth.user == null) {
    return 'id = ""';
  }

  if (auth.isSysadmin) {
    return '';
  }

  if (_isWarga(auth)) {
    if ((context.kkId ?? '').isNotEmpty) {
      return 'kk = "${context.kkId}"';
    }
    return 'id = ""';
  }

  if (!context.hasRegionalScope) {
    return 'id = ""';
  }

  final baseConditions = <String>[];
  if (_hasRwWideAccess(auth)) {
    baseConditions.add('rw = ${context.rw}');
  } else {
    baseConditions.add('rt = ${context.rt}');
    baseConditions.add('rw = ${context.rw}');
  }

  baseConditions.add(_buildRegionFilter(prefix: '', context: context));
  return baseConditions.join(' && ');
}

bool canAccessWargaRecord(
  AuthState auth,
  WargaModel warga, {
  required AreaAccessContext context,
  KartuKeluargaModel? linkedKk,
}) {
  if (auth.user == null) {
    return false;
  }

  if (auth.isSysadmin) {
    return true;
  }

  if (_isWarga(auth)) {
    return warga.userId == auth.user!.id;
  }

  if (!context.hasRegionalScope) {
    return false;
  }

  if (linkedKk == null) {
    return false;
  }

  final matchesRegion = context.hasRegionalCodes
      ? _matchesScopedCode(context.desaCode, linkedKk.desaCode) &&
            _matchesScopedCode(context.kecamatanCode, linkedKk.kecamatanCode) &&
            _matchesScopedCode(context.kabupatenCode, linkedKk.kabupatenCode) &&
            _matchesScopedCode(context.provinsiCode, linkedKk.provinsiCode)
      : _matchesScopedArea(context.desaKelurahan, linkedKk.desaKelurahan) &&
            _matchesScopedArea(context.kecamatan, linkedKk.kecamatan) &&
            _matchesScopedArea(context.kabupatenKota, linkedKk.kabupatenKota) &&
            _matchesScopedArea(context.provinsi, linkedKk.provinsi);

  if (!matchesRegion) {
    return false;
  }

  if (_hasRwWideAccess(auth)) {
    return warga.rw == '${context.rw}';
  }

  return warga.rt == '${context.rt}' && warga.rw == '${context.rw}';
}

bool canAccessKkRecord(
  AuthState auth,
  KartuKeluargaModel kk, {
  required AreaAccessContext context,
  String? ownerUserId,
}) {
  if (auth.user == null) {
    return false;
  }

  if (auth.isSysadmin) {
    return true;
  }

  if (_isWarga(auth)) {
    if ((context.kkId ?? '').isNotEmpty) {
      return context.kkId == kk.id;
    }
    return ownerUserId == auth.user!.id;
  }

  if (!context.hasRegionalScope) {
    return false;
  }

  final matchesRegion = context.hasRegionalCodes
      ? _matchesScopedCode(context.desaCode, kk.desaCode) &&
            _matchesScopedCode(context.kecamatanCode, kk.kecamatanCode) &&
            _matchesScopedCode(context.kabupatenCode, kk.kabupatenCode) &&
            _matchesScopedCode(context.provinsiCode, kk.provinsiCode)
      : _matchesScopedArea(context.desaKelurahan, kk.desaKelurahan) &&
            _matchesScopedArea(context.kecamatan, kk.kecamatan) &&
            _matchesScopedArea(context.kabupatenKota, kk.kabupatenKota) &&
            _matchesScopedArea(context.provinsi, kk.provinsi);

  if (!matchesRegion) {
    return false;
  }

  if (_hasRwWideAccess(auth)) {
    return kk.rw == '${context.rw}';
  }

  return kk.rt == '${context.rt}' && kk.rw == '${context.rw}';
}

bool canAccessSuratRecord(
  AuthState auth,
  SuratModel surat, {
  required AreaAccessContext context,
}) {
  if (auth.user == null) {
    return false;
  }

  if (auth.isSysadmin) {
    return true;
  }

  if (_isWarga(auth)) {
    return surat.submittedBy == auth.user!.id ||
        surat.wargaId == context.wargaId;
  }

  if (!context.hasRegionalScope) {
    return false;
  }

  final matchesRegion = context.hasRegionalCodes
      ? _matchesScopedCode(context.desaCode, surat.desaCode) &&
            _matchesScopedCode(context.kecamatanCode, surat.kecamatanCode) &&
            _matchesScopedCode(context.kabupatenCode, surat.kabupatenCode) &&
            _matchesScopedCode(context.provinsiCode, surat.provinsiCode)
      : _matchesScopedArea(context.desaKelurahan, surat.desaKelurahan) &&
            _matchesScopedArea(context.kecamatan, surat.kecamatan) &&
            _matchesScopedArea(context.kabupatenKota, surat.kabupatenKota) &&
            _matchesScopedArea(context.provinsi, surat.provinsi);

  if (!matchesRegion) {
    return false;
  }

  if (_hasRwWideAccess(auth)) {
    return surat.rw == context.rw;
  }

  return surat.rt == context.rt && surat.rw == context.rw;
}

bool canAccessIuranBillRecord(
  AuthState auth,
  IuranBillModel bill, {
  required AreaAccessContext context,
}) {
  if (auth.user == null) {
    return false;
  }

  if (auth.isSysadmin) {
    return true;
  }

  if (_isWarga(auth)) {
    return (context.kkId ?? '').isNotEmpty && context.kkId == bill.kkId;
  }

  if (!context.hasRegionalScope) {
    return false;
  }

  final matchesRegion = context.hasRegionalCodes
      ? _matchesScopedCode(context.desaCode, bill.desaCode) &&
            _matchesScopedCode(context.kecamatanCode, bill.kecamatanCode) &&
            _matchesScopedCode(context.kabupatenCode, bill.kabupatenCode) &&
            _matchesScopedCode(context.provinsiCode, bill.provinsiCode)
      : _matchesScopedArea(context.desaKelurahan, bill.desaKelurahan) &&
            _matchesScopedArea(context.kecamatan, bill.kecamatan) &&
            _matchesScopedArea(context.kabupatenKota, bill.kabupatenKota) &&
            _matchesScopedArea(context.provinsi, bill.provinsi);

  if (!matchesRegion) {
    return false;
  }

  if (_hasRwWideAccess(auth)) {
    return bill.rw == context.rw;
  }

  return bill.rt == context.rt && bill.rw == context.rw;
}
