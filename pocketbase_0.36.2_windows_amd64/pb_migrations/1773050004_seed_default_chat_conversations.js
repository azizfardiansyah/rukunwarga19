/// <reference path="../pb_data/types.d.ts" />

migrate((app) => {
  const conversations = findCollection(app, "conversations");
  const wargaCollection = findCollection(app, "warga");
  const kkCollection = findCollection(app, "kartu_keluarga");
  const users = findCollection(app, "users");
  if (!conversations || !wargaCollection || !kkCollection || !users) {
    return;
  }

  const kkCache = {};
  const wargaRecords = app.findAllRecords(wargaCollection);

  for (const warga of wargaRecords) {
    const userId = asString(warga.getString("user_id"));
    const kkId = asString(warga.getString("no_kk"));
    const rt = warga.getInt("rt");
    const rw = warga.getInt("rw");

    if (!userId || !kkId || rt <= 0 || rw <= 0) {
      continue;
    }

    let kk = kkCache[kkId];
    if (kk === undefined) {
      try {
        kk = app.findRecordById(kkCollection, kkId);
      } catch (_) {
        kk = null;
      }
      kkCache[kkId] = kk;
    }

    if (!kk) {
      continue;
    }

    const scope = buildScope(warga, kk);
    if (!scope.hasArea) {
      continue;
    }

    ensureConversation(app, conversations, {
      key:
        "private:" +
        userId +
        ":" +
        scope.provinsiCodeOrName +
        ":" +
        scope.kabupatenCodeOrName,
      type: "private",
      name: "Layanan - " + scope.displayName,
      owner: userId,
      createdBy: userId,
      scope,
    });

    ensureConversation(app, conversations, {
      key:
        "group_rt:" +
        rw +
        ":" +
        rt +
        ":" +
        scope.provinsiCodeOrName +
        ":" +
        scope.kabupatenCodeOrName +
        ":" +
        scope.kecamatanCodeOrName +
        ":" +
        scope.desaCodeOrName,
      type: "group_rt",
      name:
        "Grup RT " + pad2(rt) + " / RW " + pad2(rw),
      owner: "",
      createdBy: userId,
      scope,
    });

    ensureConversation(app, conversations, {
      key:
        "group_rw:" +
        rw +
        ":" +
        scope.provinsiCodeOrName +
        ":" +
        scope.kabupatenCodeOrName +
        ":" +
        scope.kecamatanCodeOrName +
        ":" +
        scope.desaCodeOrName,
      type: "group_rw",
      name: "Forum RW " + pad2(rw),
      owner: "",
      createdBy: userId,
      scope,
    });
  }
}, (_) => {});

function ensureConversation(app, collection, config) {
  try {
    app.findFirstRecordByFilter(
      collection,
      'key = "' + escapeFilterValue(config.key) + '"',
    );
    return;
  } catch (_) {}

  const record = new Record(collection);
  record.set("key", config.key);
  record.set("type", config.type);
  record.set("name", config.name);
  if (config.owner) {
    record.set("owner", config.owner);
  }
  if (config.createdBy) {
    record.set("created_by", config.createdBy);
  }
  record.set("rt", config.scope.rt);
  record.set("rw", config.scope.rw);
  record.set("desa_code", config.scope.desaCode);
  record.set("kecamatan_code", config.scope.kecamatanCode);
  record.set("kabupaten_code", config.scope.kabupatenCode);
  record.set("provinsi_code", config.scope.provinsiCode);
  record.set("desa_kelurahan", config.scope.desaKelurahan);
  record.set("kecamatan", config.scope.kecamatan);
  record.set("kabupaten_kota", config.scope.kabupatenKota);
  record.set("provinsi", config.scope.provinsi);
  record.set("is_readonly", false);
  record.set("last_message", "");
  app.save(record);
}

function buildScope(warga, kk) {
  const desaCode = asString(kk.getString("desa_code"));
  const kecamatanCode = asString(kk.getString("kecamatan_code"));
  const kabupatenCode = asString(kk.getString("kabupaten_code"));
  const provinsiCode = asString(kk.getString("provinsi_code"));
  const desaKelurahan = firstNonEmpty([
    kk.getString("desa_kelurahan"),
    kk.getString("kelurahan"),
  ]);
  const kecamatan = asString(kk.getString("kecamatan"));
  const kabupatenKota = firstNonEmpty([
    kk.getString("kabupaten_kota"),
    kk.getString("kota"),
  ]);
  const provinsi = asString(kk.getString("provinsi"));

  return {
    displayName:
      firstNonEmpty([warga.getString("nama_lengkap"), warga.getString("email")]) ||
      "Warga",
    rt: warga.getInt("rt"),
    rw: warga.getInt("rw"),
    desaCode,
    kecamatanCode,
    kabupatenCode,
    provinsiCode,
    desaKelurahan,
    kecamatan,
    kabupatenKota,
    provinsi,
    hasArea: warga.getInt("rt") > 0 && warga.getInt("rw") > 0,
    desaCodeOrName: desaCode || normalizeAreaValue(desaKelurahan),
    kecamatanCodeOrName: kecamatanCode || normalizeAreaValue(kecamatan),
    kabupatenCodeOrName: kabupatenCode || normalizeAreaValue(kabupatenKota),
    provinsiCodeOrName: provinsiCode || normalizeAreaValue(provinsi),
  };
}

function findCollection(app, name) {
  try {
    return app.findCollectionByNameOrId(name);
  } catch (_) {
    return null;
  }
}

function asString(value) {
  if (value === null || value === undefined) {
    return "";
  }
  return String(value).trim();
}

function firstNonEmpty(values) {
  for (const value of values) {
    const normalized = asString(value);
    if (normalized) {
      return normalized;
    }
  }
  return "";
}

function normalizeAreaValue(value) {
  return asString(value).toLowerCase();
}

function escapeFilterValue(value) {
  return asString(value).replaceAll("\\", "\\\\").replaceAll('"', '\\"');
}

function pad2(value) {
  return String(value).padStart(2, "0");
}
