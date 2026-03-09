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

  const statusField = collection.fields.getByName("status_verifikasi");

  collection.fields.addAt(
    3,
    new SelectField({
      id: fieldId(statusField) || "select_status_verifikasi",
      name: "status_verifikasi",
      maxSelect: 1,
      values: values,
      required: true,
    }),
  );

  app.save(collection);
}

function fieldId(field) {
  if (!field) {
    return "";
  }

  if (typeof field.getId === "function") {
    return field.getId();
  }

  return field.id || "";
}
