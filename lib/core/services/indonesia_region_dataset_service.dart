import 'dart:convert';

import 'package:flutter/services.dart';

class RegionEntry {
  const RegionEntry({required this.id, required this.name});

  final String id;
  final String name;

  factory RegionEntry.fromJson(Map<String, dynamic> json) {
    return RegionEntry(
      id: json['id']?.toString() ?? '',
      name: json['name']?.toString() ?? '',
    );
  }
}

class IndonesiaRegionDataset {
  IndonesiaRegionDataset({
    required this.provinces,
    required this.regenciesByProvince,
    required this.districtsByRegency,
    required this.villagesByDistrict,
  }) : _allRegencies = regenciesByProvince.values.expand((e) => e).toList(),
       _allDistricts = districtsByRegency.values.expand((e) => e).toList(),
       _allVillages = villagesByDistrict.values.expand((e) => e).toList();

  final List<RegionEntry> provinces;
  final Map<String, List<RegionEntry>> regenciesByProvince;
  final Map<String, List<RegionEntry>> districtsByRegency;
  final Map<String, List<RegionEntry>> villagesByDistrict;
  final List<RegionEntry> _allRegencies;
  final List<RegionEntry> _allDistricts;
  final List<RegionEntry> _allVillages;

  factory IndonesiaRegionDataset.fromJson(Map<String, dynamic> json) {
    List<RegionEntry> parseList(dynamic raw) {
      if (raw is! List) {
        return const [];
      }
      return raw
          .whereType<Map>()
          .map((item) => RegionEntry.fromJson(Map<String, dynamic>.from(item)))
          .toList(growable: false);
    }

    Map<String, List<RegionEntry>> parseGrouped(dynamic raw) {
      if (raw is! Map) {
        return const {};
      }
      final result = <String, List<RegionEntry>>{};
      for (final entry in raw.entries) {
        result[entry.key.toString()] = parseList(entry.value);
      }
      return result;
    }

    return IndonesiaRegionDataset(
      provinces: parseList(json['provinces']),
      regenciesByProvince: parseGrouped(json['regenciesByProvince']),
      districtsByRegency: parseGrouped(json['districtsByRegency']),
      villagesByDistrict: parseGrouped(json['villagesByDistrict']),
    );
  }

  List<String> provinceNames() => _sortedNames(provinces);

  RegionEntry? findProvince(String value) {
    return _findEntry(provinces, value);
  }

  List<String> regencyNames({String? provinceName}) {
    final provinceId = findProvinceIdByName(provinceName ?? '');
    if (provinceId != null) {
      return _sortedNames(regenciesByProvince[provinceId] ?? const []);
    }
    return _sortedNames(_allRegencies);
  }

  List<String> districtNames({String? provinceName, String? regencyName}) {
    final regencyId = findRegencyIdByName(
      regencyName ?? '',
      provinceName: provinceName,
    );
    if (regencyId != null) {
      return _sortedNames(districtsByRegency[regencyId] ?? const []);
    }

    final provinceId = findProvinceIdByName(provinceName ?? '');
    if (provinceId != null) {
      final names = <RegionEntry>[];
      for (final regency in regenciesByProvince[provinceId] ?? const []) {
        names.addAll(districtsByRegency[regency.id] ?? const []);
      }
      return _sortedNames(names);
    }

    return _sortedNames(_allDistricts);
  }

  List<String> villageNames({
    String? provinceName,
    String? regencyName,
    String? districtName,
  }) {
    final districtId = findDistrictIdByName(
      districtName ?? '',
      provinceName: provinceName,
      regencyName: regencyName,
    );
    if (districtId != null) {
      return _sortedNames(villagesByDistrict[districtId] ?? const []);
    }

    final regencyId = findRegencyIdByName(
      regencyName ?? '',
      provinceName: provinceName,
    );
    if (regencyId != null) {
      final names = <RegionEntry>[];
      for (final district in districtsByRegency[regencyId] ?? const []) {
        names.addAll(villagesByDistrict[district.id] ?? const []);
      }
      return _sortedNames(names);
    }

    final provinceId = findProvinceIdByName(provinceName ?? '');
    if (provinceId != null) {
      final names = <RegionEntry>[];
      for (final regency in regenciesByProvince[provinceId] ?? const []) {
        for (final district in districtsByRegency[regency.id] ?? const []) {
          names.addAll(villagesByDistrict[district.id] ?? const []);
        }
      }
      return _sortedNames(names);
    }

    return _sortedNames(_allVillages);
  }

  String? findProvinceIdByName(String value) {
    return findProvince(value)?.id;
  }

  RegionEntry? findRegency(String value, {String? provinceName}) {
    final provinceId = findProvinceIdByName(provinceName ?? '');
    final candidates = provinceId != null
        ? regenciesByProvince[provinceId] ?? const <RegionEntry>[]
        : _allRegencies;
    return _findEntry(candidates, value);
  }

  String? findRegencyIdByName(String value, {String? provinceName}) {
    return findRegency(value, provinceName: provinceName)?.id;
  }

  RegionEntry? findDistrict(
    String value, {
    String? provinceName,
    String? regencyName,
  }) {
    final regencyId = findRegencyIdByName(
      regencyName ?? '',
      provinceName: provinceName,
    );
    final candidates = regencyId != null
        ? districtsByRegency[regencyId] ?? const <RegionEntry>[]
        : _allDistricts;
    return _findEntry(candidates, value);
  }

  String? findDistrictIdByName(
    String value, {
    String? provinceName,
    String? regencyName,
  }) {
    return findDistrict(
      value,
      provinceName: provinceName,
      regencyName: regencyName,
    )?.id;
  }

  RegionEntry? findVillage({
    required String villageName,
    String? provinceName,
    String? regencyName,
    String? districtName,
  }) {
    final districtId = findDistrictIdByName(
      districtName ?? '',
      provinceName: provinceName,
      regencyName: regencyName,
    );
    final candidates = districtId != null
        ? villagesByDistrict[districtId] ?? const <RegionEntry>[]
        : _allVillages;
    return _findEntry(candidates, villageName);
  }

  bool isValidVillage({
    required String villageName,
    String? provinceName,
    String? regencyName,
    String? districtName,
  }) {
    return findVillage(
          villageName: villageName,
          provinceName: provinceName,
          regencyName: regencyName,
          districtName: districtName,
        ) !=
        null;
  }

  String? findVillageIdByName({
    required String villageName,
    String? provinceName,
    String? regencyName,
    String? districtName,
  }) {
    return findVillage(
      villageName: villageName,
      provinceName: provinceName,
      regencyName: regencyName,
      districtName: districtName,
    )?.id;
  }

  List<String> _sortedNames(List<RegionEntry> entries) {
    final values = entries.map((entry) => entry.name).toSet().toList();
    values.sort((a, b) => a.toLowerCase().compareTo(b.toLowerCase()));
    return values;
  }

  RegionEntry? _findEntry(List<RegionEntry> entries, String value) {
    final query = _normalizeKey(value);
    if (query.isEmpty) {
      return null;
    }

    for (final entry in entries) {
      if (_normalizeKey(entry.name) == query) {
        return entry;
      }
    }

    return null;
  }

  static String _normalizeKey(String value) {
    return value
        .toLowerCase()
        .replaceAll(
          RegExp(r'\b(kabupaten|kab\.|kota|desa|kelurahan|provinsi)\b'),
          ' ',
        )
        .replaceAll(RegExp(r'[^a-z0-9]+'), ' ')
        .trim();
  }
}

class IndonesiaRegionDatasetService {
  IndonesiaRegionDatasetService._();

  static IndonesiaRegionDataset? _cache;

  static Future<IndonesiaRegionDataset> load() async {
    if (_cache != null) {
      return _cache!;
    }

    final raw = await rootBundle.loadString(
      'assets/datasets/indonesia_regions.json',
    );
    _cache = IndonesiaRegionDataset.fromJson(
      Map<String, dynamic>.from(jsonDecode(raw) as Map),
    );
    return _cache!;
  }
}
