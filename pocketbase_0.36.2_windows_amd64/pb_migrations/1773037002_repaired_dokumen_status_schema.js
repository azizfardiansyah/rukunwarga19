/// <reference path="../pb_data/types.d.ts" />

migrate((app) => {
  syncDokumenStatusSchema(app, [
    "pending",
    "need_revision",
    "verified",
    "rejected",
  ]);
}, (app) => {
  syncDokumenStatusSchema(app, [
    "pending",
    "verified",
    "rejected",
  ]);
});

function syncDokumenStatusSchema(app, values) {
  let collection = null;

  try {
    collection = app.findCollectionByNameOrId("dokumen");
  } catch (_) {
    return;
  }

  const snapshots = snapshotDokumenStatuses(app);

  if (collection.fields.getByName("status_verifikasi")) {
    collection.fields.removeByName("status_verifikasi");
  }

  collection.fields.addAt(
    3,
    new SelectField({
      name: "status_verifikasi",
      maxSelect: 1,
      values: values,
      required: true,
    }),
  );

  app.save(collection);
  restoreDokumenStatuses(app, snapshots, values);
  return app.save(collection);
}

function snapshotDokumenStatuses(app) {
  let records = [];

  try {
    records = app.findRecordsByFilter("dokumen", "", "created", 5000, 0);
  } catch (_) {
    return [];
  }

  return records.map((record) => ({
    id: record.id,
    status: record.getString("status_verifikasi"),
  }));
}

function restoreDokumenStatuses(app, snapshots, allowedValues) {
  if (!snapshots.length) {
    return;
  }

  const fallbackStatus = allowedValues.includes("pending")
    ? "pending"
    : allowedValues[0] || "";

  for (const snapshot of snapshots) {
    if (!snapshot?.id) {
      continue;
    }

    let record = null;

    try {
      record = app.findRecordById("dokumen", snapshot.id);
    } catch (_) {
      continue;
    }

    if (!record) {
      continue;
    }

    const normalized = normalizeStatus(snapshot.status, allowedValues, fallbackStatus);
    record.set("status_verifikasi", normalized);
    app.save(record);
  }
}

function normalizeStatus(rawValue, allowedValues, fallbackStatus) {
  const value = (rawValue || "").trim().toLowerCase();
  if (allowedValues.includes(value)) {
    return value;
  }

  if (value === "need revision" || value === "perlu_revisi" || value === "revisi") {
    return allowedValues.includes("need_revision")
      ? "need_revision"
      : fallbackStatus;
  }

  return fallbackStatus;
}
