/// <reference path="../pb_data/types.d.ts" />

migrate((app) => {
  repairDokumenCollection(app);
}, (app) => {
  rollbackDokumenCollection(app);
});

function repairDokumenCollection(app) {
  let collection = null;

  try {
    collection = app.findCollectionByNameOrId("dokumen");
  } catch (_) {
    return;
  }

  const authRule = "@request.auth.id != ''";
  const adminRule =
    "@request.auth.role = 'admin_rt' || @request.auth.role = 'admin_rw' || @request.auth.role = 'admin_rw_pro' || @request.auth.role = 'sysadmin'";

  collection.listRule = authRule;
  collection.viewRule = authRule;
  collection.createRule = authRule;
  collection.updateRule = `${authRule} && (${adminRule})`;
  collection.deleteRule = authRule;

  addFieldIfMissing(
    collection,
    new RelationField({
      name: "warga",
      collectionId: "pbc_2188441055",
      maxSelect: 1,
      required: true,
    }),
  );
  addFieldIfMissing(
    collection,
    new SelectField({
      name: "jenis",
      maxSelect: 1,
      values: [
        "KTP",
        "Kartu Keluarga",
        "Akta Kelahiran",
        "Akta Kematian",
        "Akta Nikah",
        "Ijazah",
        "BPJS",
        "Lainnya",
      ],
      required: true,
    }),
  );
  addFieldIfMissing(
    collection,
    new FileField({
      name: "file",
      maxSelect: 1,
      maxSize: 10 * 1024 * 1024,
      required: true,
      mimeTypes: [],
      thumbs: [],
      protected: false,
    }),
  );
  addFieldIfMissing(
    collection,
    new SelectField({
      name: "status_verifikasi",
      maxSelect: 1,
      values: ["pending", "need_revision", "verified", "rejected"],
      required: true,
    }),
  );
  addFieldIfMissing(
    collection,
    new TextField({
      name: "catatan",
    }),
  );
  addFieldIfMissing(
    collection,
    new RelationField({
      name: "diverifikasi_oleh",
      collectionId: "_pb_users_auth_",
      maxSelect: 1,
    }),
  );
  addFieldIfMissing(
    collection,
    new DateField({
      name: "tanggal_verifikasi",
    }),
  );
  addFieldIfMissing(
    collection,
    new AutodateField({
      name: "created",
      onCreate: true,
      onUpdate: false,
    }),
  );
  addFieldIfMissing(
    collection,
    new AutodateField({
      name: "updated",
      onCreate: true,
      onUpdate: true,
    }),
  );

  app.save(collection);
}

function rollbackDokumenCollection(app) {
  let collection = null;

  try {
    collection = app.findCollectionByNameOrId("dokumen");
  } catch (_) {
    return;
  }

  removeKnownFields(collection, [
    "warga",
    "jenis",
    "file",
    "status_verifikasi",
    "catatan",
    "diverifikasi_oleh",
    "tanggal_verifikasi",
    "created",
    "updated",
  ]);

  app.save(collection);
}

function addFieldIfMissing(collection, field) {
  if (collection.fields.getByName(field.name)) {
    return;
  }

  collection.fields.add(field);
}

function removeKnownFields(collection, names) {
  for (const name of names) {
    if (collection.fields.getByName(name)) {
      collection.fields.removeByName(name);
    }
  }
}
