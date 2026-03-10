/// <reference path="../pb_data/types.d.ts" />

migrate((app) => {
  backfillKartuKeluargaRegionCodes(app);
}, (_) => {
  // Data backfill rollback is intentionally a no-op.
});

function backfillKartuKeluargaRegionCodes(app) {
  try {
    app.findCollectionByNameOrId("kartu_keluarga");
  } catch (_) {
    return;
  }

  const dataset = loadRegionDataset();
  if (!dataset) {
    return;
  }

  const index = buildRegionIndex(dataset);
  const records = fetchAllRecords(app, "kartu_keluarga");

  for (const record of records) {
    if (!record) {
      continue;
    }

    const province = resolveProvince(index, readRegionValue(record, [
      "provinsi",
    ]));
    const regency = resolveRegency(
      index,
      readRegionValue(record, ["kabupaten_kota", "kota"]),
      province,
    );
    const district = resolveDistrict(
      index,
      readRegionValue(record, ["kecamatan"]),
      regency,
      province,
    );
    const village = resolveVillage(
      index,
      readRegionValue(record, ["desa_kelurahan", "kelurahan"]),
      district,
      regency,
      province,
    );

    let changed = false;

    if (province) {
      changed = setIfDifferent(record, "provinsi", province.name) || changed;
      changed =
        setIfDifferent(record, "provinsi_code", province.id) || changed;
    }

    if (regency) {
      changed =
        setIfDifferent(record, "kabupaten_kota", regency.name) || changed;
      changed =
        setIfDifferent(record, "kabupaten_code", regency.id) || changed;
    }

    if (district) {
      changed = setIfDifferent(record, "kecamatan", district.name) || changed;
      changed =
        setIfDifferent(record, "kecamatan_code", district.id) || changed;
    }

    if (village) {
      changed =
        setIfDifferent(record, "desa_kelurahan", village.name) || changed;
      changed = setIfDifferent(record, "desa_code", village.id) || changed;
    }

    if (changed) {
      app.save(record);
    }
  }
}

function fetchAllRecords(app, collectionName) {
  const limit = 500;
  const all = [];
  let offset = 0;

  while (true) {
    const batch = app.findRecordsByFilter(
      collectionName,
      "",
      "created",
      limit,
      offset,
    );
    if (!batch.length) {
      break;
    }

    for (const record of batch) {
      all.push(record);
    }

    if (batch.length < limit) {
      break;
    }
    offset += limit;
  }

  return all;
}

function loadRegionDataset() {
  const cwd = safeString($os.getwd());
  const candidates = [
    joinPath(cwd, "..", "assets", "datasets", "indonesia_regions.json"),
    joinPath(cwd, "assets", "datasets", "indonesia_regions.json"),
    "../assets/datasets/indonesia_regions.json",
    "assets/datasets/indonesia_regions.json",
  ];

  for (const path of candidates) {
    try {
      const raw = $os.readFile(path);
      const text = typeof raw === "string" ? raw : bytesToString(raw);
      const parsed = JSON.parse(text);
      if (parsed && parsed.provinces) {
        return parsed;
      }
    } catch (_) {}
  }

  return null;
}

function buildRegionIndex(dataset) {
  const index = {
    provinces: {},
    regenciesByProvince: {},
    regenciesGlobal: {},
    districtsByRegency: {},
    districtsByProvince: {},
    districtsGlobal: {},
    villagesByDistrict: {},
    villagesByRegency: {},
    villagesByProvince: {},
    villagesGlobal: {},
  };

  const provinces = Array.isArray(dataset.provinces) ? dataset.provinces : [];
  const regenciesByProvince = dataset.regenciesByProvince || {};
  const districtsByRegency = dataset.districtsByRegency || {};
  const villagesByDistrict = dataset.villagesByDistrict || {};

  for (const province of provinces) {
    addUnique(index.provinces, normalizeRegionKey(province.name), province);
  }

  for (const province of provinces) {
    const provinceId = safeString(province.id);
    const regencies = Array.isArray(regenciesByProvince[provinceId])
      ? regenciesByProvince[provinceId]
      : [];

    if (!index.regenciesByProvince[provinceId]) {
      index.regenciesByProvince[provinceId] = {};
    }
    if (!index.districtsByProvince[provinceId]) {
      index.districtsByProvince[provinceId] = {};
    }
    if (!index.villagesByProvince[provinceId]) {
      index.villagesByProvince[provinceId] = {};
    }

    for (const regency of regencies) {
      addUnique(
        index.regenciesByProvince[provinceId],
        normalizeRegionKey(regency.name),
        regency,
      );
      addUnique(index.regenciesGlobal, normalizeRegionKey(regency.name), regency);

      const regencyId = safeString(regency.id);
      const districts = Array.isArray(districtsByRegency[regencyId])
        ? districtsByRegency[regencyId]
        : [];

      if (!index.districtsByRegency[regencyId]) {
        index.districtsByRegency[regencyId] = {};
      }
      if (!index.villagesByRegency[regencyId]) {
        index.villagesByRegency[regencyId] = {};
      }

      for (const district of districts) {
        addUnique(
          index.districtsByRegency[regencyId],
          normalizeRegionKey(district.name),
          district,
        );
        addUnique(
          index.districtsByProvince[provinceId],
          normalizeRegionKey(district.name),
          district,
        );
        addUnique(
          index.districtsGlobal,
          normalizeRegionKey(district.name),
          district,
        );

        const districtId = safeString(district.id);
        const villages = Array.isArray(villagesByDistrict[districtId])
          ? villagesByDistrict[districtId]
          : [];

        if (!index.villagesByDistrict[districtId]) {
          index.villagesByDistrict[districtId] = {};
        }

        for (const village of villages) {
          addUnique(
            index.villagesByDistrict[districtId],
            normalizeRegionKey(village.name),
            village,
          );
          addUnique(
            index.villagesByRegency[regencyId],
            normalizeRegionKey(village.name),
            village,
          );
          addUnique(
            index.villagesByProvince[provinceId],
            normalizeRegionKey(village.name),
            village,
          );
          addUnique(
            index.villagesGlobal,
            normalizeRegionKey(village.name),
            village,
          );
        }
      }
    }
  }

  return index;
}

function resolveProvince(index, value) {
  return findIndexedValue(index.provinces, value);
}

function resolveRegency(index, value, province) {
  if (province) {
    const local = findIndexedValue(
      index.regenciesByProvince[safeString(province.id)],
      value,
    );
    if (local) {
      return local;
    }
  }

  return findIndexedValue(index.regenciesGlobal, value);
}

function resolveDistrict(index, value, regency, province) {
  if (regency) {
    const local = findIndexedValue(
      index.districtsByRegency[safeString(regency.id)],
      value,
    );
    if (local) {
      return local;
    }
  }

  if (province) {
    const scoped = findIndexedValue(
      index.districtsByProvince[safeString(province.id)],
      value,
    );
    if (scoped) {
      return scoped;
    }
  }

  return findIndexedValue(index.districtsGlobal, value);
}

function resolveVillage(index, value, district, regency, province) {
  if (district) {
    const local = findIndexedValue(
      index.villagesByDistrict[safeString(district.id)],
      value,
    );
    if (local) {
      return local;
    }
  }

  if (regency) {
    const scoped = findIndexedValue(
      index.villagesByRegency[safeString(regency.id)],
      value,
    );
    if (scoped) {
      return scoped;
    }
  }

  if (province) {
    const broader = findIndexedValue(
      index.villagesByProvince[safeString(province.id)],
      value,
    );
    if (broader) {
      return broader;
    }
  }

  return findIndexedValue(index.villagesGlobal, value);
}

function findIndexedValue(bucket, value) {
  if (!bucket) {
    return null;
  }

  const key = normalizeRegionKey(value);
  if (!key) {
    return null;
  }

  const match = bucket[key];
  return match || null;
}

function addUnique(bucket, key, entry) {
  if (!bucket || !key || !entry) {
    return;
  }

  if (!(key in bucket)) {
    bucket[key] = entry;
    return;
  }

  const existing = bucket[key];
  if (existing && safeString(existing.id) === safeString(entry.id)) {
    return;
  }

  bucket[key] = null;
}

function readRegionValue(record, fields) {
  for (const field of fields) {
    try {
      const value = safeString(record.getString(field));
      if (value) {
        return value;
      }
    } catch (_) {}
  }

  return "";
}

function setIfDifferent(record, field, value) {
  const normalizedValue = safeString(value);
  if (!normalizedValue) {
    return false;
  }

  const current = readRegionValue(record, [field]);
  if (current === normalizedValue) {
    return false;
  }

  record.set(field, normalizedValue);
  return true;
}

function normalizeRegionKey(value) {
  return safeString(value)
    .toLowerCase()
    .replace(
      /\b(provinsi|kabupaten|kab\.?|kota|kecamatan|kec\.?|desa|kelurahan|kel\.?)\b/g,
      " ",
    )
    .replace(/[^a-z0-9]+/g, " ")
    .trim();
}

function safeString(value) {
  return (value || "").toString().trim();
}

function bytesToString(raw) {
  if (!Array.isArray(raw) || raw.length === 0) {
    return "";
  }

  const chunkSize = 8192;
  let output = "";
  for (let i = 0; i < raw.length; i += chunkSize) {
    const chunk = raw.slice(i, i + chunkSize);
    output += String.fromCharCode.apply(null, chunk);
  }
  return output;
}

function joinPath() {
  const parts = [];
  for (let i = 0; i < arguments.length; i++) {
    const part = safeString(arguments[i]);
    if (!part) {
      continue;
    }
    parts.push(part.replace(/[\\/]+/g, "/"));
  }

  let path = parts.join("/");
  path = path.replace(/\/{2,}/g, "/");
  path = path.replace(/\/\.\//g, "/");
  return path;
}
