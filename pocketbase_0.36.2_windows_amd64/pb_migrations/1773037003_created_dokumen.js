/// <reference path="../pb_data/types.d.ts" />

migrate((app) => {
  let existing = null;

  try {
    existing = app.findCollectionByNameOrId("dokumen");
  } catch (_) {}

  if (existing) {
    return app.save(existing);
  }

  const authRule = "@request.auth.id != ''";
  const adminRule =
    "@request.auth.role = 'admin_rt' || @request.auth.role = 'admin_rw' || @request.auth.role = 'admin_rw_pro' || @request.auth.role = 'sysadmin'";

  const collection = new Collection({
    type: "base",
    name: "dokumen",
    listRule: authRule,
    viewRule: authRule,
    createRule: authRule,
    updateRule: `${authRule} && (${adminRule})`,
    deleteRule: authRule,
    fields: [
      new RelationField({
        name: "warga",
        collectionId: "pbc_2188441055",
        maxSelect: 1,
        required: true,
      }),
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
      new FileField({
        name: "file",
        maxSelect: 1,
        maxSize: 10 * 1024 * 1024,
        required: true,
        mimeTypes: [],
        thumbs: [],
        protected: false,
      }),
      new SelectField({
        name: "status_verifikasi",
        maxSelect: 1,
        values: ["pending", "need_revision", "verified", "rejected"],
        required: true,
      }),
      new TextField({
        name: "catatan",
      }),
      new RelationField({
        name: "diverifikasi_oleh",
        collectionId: "_pb_users_auth_",
        maxSelect: 1,
      }),
      new DateField({
        name: "tanggal_verifikasi",
      }),
      new AutodateField({
        name: "created",
        onCreate: true,
        onUpdate: false,
      }),
      new AutodateField({
        name: "updated",
        onCreate: true,
        onUpdate: true,
      }),
    ],
  });

  return app.save(collection);
}, (app) => {
  let collection = null;

  try {
    collection = app.findCollectionByNameOrId("dokumen");
  } catch (_) {
    return;
  }

  return app.delete(collection);
});
