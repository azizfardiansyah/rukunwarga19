/// <reference path="../pb_data/types.d.ts" />

migrate(
  (app) => {
    const collection = app.findCollectionByNameOrId("jabatan_master");

    addFieldIfMissing(collection, new BoolField({ name: "can_manage_workspace" }));
    addFieldIfMissing(collection, new BoolField({ name: "can_manage_unit" }));
    addFieldIfMissing(collection, new BoolField({ name: "can_manage_membership" }));
    addFieldIfMissing(collection, new BoolField({ name: "can_publish_finance" }));
    addFieldIfMissing(collection, new BoolField({ name: "can_manage_iuran" }));
    addFieldIfMissing(collection, new BoolField({ name: "can_verify_iuran_payment" }));
    app.save(collection);

    const presets = [
      preset("ketua_rw", {
        can_manage_workspace: true,
        can_manage_unit: true,
        can_manage_membership: true,
        can_publish_finance: true,
        can_manage_iuran: true,
        can_verify_iuran_payment: true,
      }),
      preset("wakil_ketua_rw", {
        can_manage_workspace: true,
        can_manage_unit: true,
        can_manage_membership: true,
        can_publish_finance: true,
        can_manage_iuran: true,
        can_verify_iuran_payment: true,
      }),
      preset("sekretaris_rw", {
        can_manage_unit: true,
        can_manage_membership: true,
      }),
      preset("bendahara_rw", {
        can_manage_iuran: true,
        can_verify_iuran_payment: true,
      }),
      preset("ketua_rt", {
        can_manage_unit: true,
        can_manage_membership: true,
        can_publish_finance: true,
        can_manage_iuran: true,
        can_verify_iuran_payment: true,
      }),
      preset("wakil_ketua_rt", {
        can_manage_unit: true,
        can_manage_membership: true,
        can_publish_finance: true,
        can_manage_iuran: true,
        can_verify_iuran_payment: true,
      }),
      preset("sekretaris_rt", {
        can_manage_membership: true,
      }),
      preset("bendahara_rt", {
        can_manage_iuran: true,
        can_verify_iuran_payment: true,
      }),
      preset("ketua_dkm", {
        can_manage_unit: true,
        can_manage_membership: true,
        can_publish_finance: true,
      }),
      preset("wakil_ketua_dkm", {
        can_manage_unit: true,
        can_manage_membership: true,
        can_publish_finance: true,
      }),
      preset("ketua_posyandu", {
        can_manage_unit: true,
        can_manage_membership: true,
        can_publish_finance: true,
      }),
      preset("wakil_ketua_posyandu", {
        can_manage_unit: true,
        can_manage_membership: true,
        can_publish_finance: true,
      }),
    ];

    const records = app.findAllRecords(collection);
    const byCode = {};
    for (const record of records) {
      byCode[record.getString("code")] = record;
    }

    for (const presetRecord of presets) {
      const record = byCode[presetRecord.code];
      if (!record) {
        continue;
      }
      Object.entries(presetRecord.values).forEach(([key, value]) => {
        record.set(key, value);
      });
      app.save(record);
    }
  },
  (app) => {
    const collection = app.findCollectionByNameOrId("jabatan_master");
    removeFieldIfPresent(collection, "can_manage_workspace");
    removeFieldIfPresent(collection, "can_manage_unit");
    removeFieldIfPresent(collection, "can_manage_membership");
    removeFieldIfPresent(collection, "can_publish_finance");
    removeFieldIfPresent(collection, "can_manage_iuran");
    removeFieldIfPresent(collection, "can_verify_iuran_payment");
    return app.save(collection);
  },
);

function preset(code, values) {
  return { code, values };
}

function addFieldIfMissing(collection, field) {
  if (collection.fields.getByName(field.name)) {
    return;
  }
  collection.fields.add(field);
}

function removeFieldIfPresent(collection, fieldName) {
  if (!collection.fields.getByName(fieldName)) {
    return;
  }
  collection.fields.removeByName(fieldName);
}
