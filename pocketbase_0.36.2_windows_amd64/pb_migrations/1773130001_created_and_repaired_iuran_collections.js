/// <reference path="../pb_data/types.d.ts" />

migrate((app) => {
  ensureIuranTypesCollection(app);
  ensureIuranPeriodsCollection(app);
  ensureIuranBillsCollection(app);
  ensureIuranPaymentsCollection(app);
  seedIuranTypes(app);
}, (app) => {
  // No destructive rollback for iuran workflow collections.
});

function ensureIuranTypesCollection(app) {
  let collection = findCollection(app, "iuran_types");
  if (!collection) {
    collection = new Collection({
      type: "base",
      name: "iuran_types",
      fields: [],
    });
  }

  applyAdminManagedRules(collection);

  addFieldIfMissing(
    collection,
    new TextField({
      name: "code",
      required: true,
    }),
  );
  addFieldIfMissing(
    collection,
    new TextField({
      name: "label",
      required: true,
    }),
  );
  addFieldIfMissing(collection, new TextField({ name: "description" }));
  addFieldIfMissing(
    collection,
    new NumberField({
      name: "default_amount",
      onlyInt: true,
      min: 0,
    }),
  );
  addFieldIfMissing(
    collection,
    new SelectField({
      name: "default_frequency",
      maxSelect: 1,
      required: true,
      values: ["mingguan", "bulanan", "tahunan", "insidental"],
    }),
  );
  addFieldIfMissing(collection, new BoolField({ name: "is_active" }));
  addFieldIfMissing(
    collection,
    new NumberField({
      name: "sort_order",
      onlyInt: true,
      min: 0,
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

function ensureIuranPeriodsCollection(app) {
  const users = findCollection(app, "users");
  const types = findCollection(app, "iuran_types");
  if (!users || !types) {
    return;
  }

  let collection = findCollection(app, "iuran_periods");
  if (!collection) {
    collection = new Collection({
      type: "base",
      name: "iuran_periods",
      fields: [],
    });
  }

  applyAdminManagedRules(collection);

  addFieldIfMissing(
    collection,
    new RelationField({
      name: "iuran_type",
      collectionId: types.id,
      maxSelect: 1,
      required: true,
    }),
  );
  addFieldIfMissing(
    collection,
    new TextField({
      name: "type_label",
      required: true,
    }),
  );
  addFieldIfMissing(
    collection,
    new TextField({
      name: "title",
      required: true,
    }),
  );
  addFieldIfMissing(collection, new TextField({ name: "description" }));
  addFieldIfMissing(
    collection,
    new SelectField({
      name: "frequency",
      maxSelect: 1,
      required: true,
      values: ["mingguan", "bulanan", "tahunan", "insidental"],
    }),
  );
  addFieldIfMissing(
    collection,
    new NumberField({
      name: "default_amount",
      onlyInt: true,
      min: 0,
      required: true,
    }),
  );
  addFieldIfMissing(collection, new DateField({ name: "due_date" }));
  addFieldIfMissing(
    collection,
    new SelectField({
      name: "status",
      maxSelect: 1,
      required: true,
      values: ["draft", "published", "closed"],
    }),
  );
  addFieldIfMissing(
    collection,
    new SelectField({
      name: "target_mode",
      maxSelect: 1,
      required: true,
      values: ["all_scope", "custom_targets"],
    }),
  );
  addFieldIfMissing(
    collection,
    new RelationField({
      name: "created_by",
      collectionId: users.id,
      maxSelect: 1,
      required: true,
    }),
  );
  addFieldIfMissing(collection, new DateField({ name: "published_at" }));
  addFieldIfMissing(
    collection,
    new NumberField({
      name: "rt",
      onlyInt: true,
      min: 0,
    }),
  );
  addFieldIfMissing(
    collection,
    new NumberField({
      name: "rw",
      onlyInt: true,
      min: 0,
    }),
  );
  addFieldIfMissing(collection, new TextField({ name: "desa_code" }));
  addFieldIfMissing(collection, new TextField({ name: "kecamatan_code" }));
  addFieldIfMissing(collection, new TextField({ name: "kabupaten_code" }));
  addFieldIfMissing(collection, new TextField({ name: "provinsi_code" }));
  addFieldIfMissing(collection, new TextField({ name: "desa_kelurahan" }));
  addFieldIfMissing(collection, new TextField({ name: "kecamatan" }));
  addFieldIfMissing(collection, new TextField({ name: "kabupaten_kota" }));
  addFieldIfMissing(collection, new TextField({ name: "provinsi" }));
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

function ensureIuranBillsCollection(app) {
  const users = findCollection(app, "users");
  const periods = findCollection(app, "iuran_periods");
  const types = findCollection(app, "iuran_types");
  const kk = findCollection(app, "kartu_keluarga");
  if (!users || !periods || !types || !kk) {
    return;
  }

  let collection = findCollection(app, "iuran_bills");
  if (!collection) {
    collection = new Collection({
      type: "base",
      name: "iuran_bills",
      fields: [],
    });
  }

  applyAdminManagedRules(collection);

  addFieldIfMissing(
    collection,
    new RelationField({
      name: "period",
      collectionId: periods.id,
      maxSelect: 1,
      required: true,
    }),
  );
  addFieldIfMissing(
    collection,
    new RelationField({
      name: "iuran_type",
      collectionId: types.id,
      maxSelect: 1,
      required: true,
    }),
  );
  addFieldIfMissing(
    collection,
    new RelationField({
      name: "kk",
      collectionId: kk.id,
      maxSelect: 1,
      required: true,
    }),
  );
  addFieldIfMissing(
    collection,
    new TextField({
      name: "bill_number",
      required: true,
    }),
  );
  addFieldIfMissing(
    collection,
    new TextField({
      name: "title",
      required: true,
    }),
  );
  addFieldIfMissing(
    collection,
    new TextField({
      name: "type_label",
      required: true,
    }),
  );
  addFieldIfMissing(
    collection,
    new TextField({
      name: "kk_number",
      required: true,
    }),
  );
  addFieldIfMissing(collection, new TextField({ name: "kk_holder_name" }));
  addFieldIfMissing(collection, new TextField({ name: "frequency" }));
  addFieldIfMissing(
    collection,
    new NumberField({
      name: "amount",
      onlyInt: true,
      min: 0,
      required: true,
    }),
  );
  addFieldIfMissing(
    collection,
    new SelectField({
      name: "status",
      maxSelect: 1,
      required: true,
      values: [
        "unpaid",
        "submitted_verification",
        "paid",
        "rejected_payment",
      ],
    }),
  );
  addFieldIfMissing(collection, new DateField({ name: "due_date" }));
  addFieldIfMissing(
    collection,
    new SelectField({
      name: "payment_method",
      maxSelect: 1,
      values: ["cash", "transfer"],
    }),
  );
  addFieldIfMissing(collection, new TextField({ name: "payer_note" }));
  addFieldIfMissing(
    collection,
    new RelationField({
      name: "submitted_by",
      collectionId: users.id,
      maxSelect: 1,
    }),
  );
  addFieldIfMissing(collection, new DateField({ name: "submitted_at" }));
  addFieldIfMissing(
    collection,
    new RelationField({
      name: "verified_by",
      collectionId: users.id,
      maxSelect: 1,
    }),
  );
  addFieldIfMissing(collection, new DateField({ name: "verified_at" }));
  addFieldIfMissing(collection, new TextField({ name: "rejection_note" }));
  addFieldIfMissing(collection, new DateField({ name: "paid_at" }));
  addFieldIfMissing(
    collection,
    new NumberField({
      name: "rt",
      onlyInt: true,
      min: 0,
    }),
  );
  addFieldIfMissing(
    collection,
    new NumberField({
      name: "rw",
      onlyInt: true,
      min: 0,
    }),
  );
  addFieldIfMissing(collection, new TextField({ name: "desa_code" }));
  addFieldIfMissing(collection, new TextField({ name: "kecamatan_code" }));
  addFieldIfMissing(collection, new TextField({ name: "kabupaten_code" }));
  addFieldIfMissing(collection, new TextField({ name: "provinsi_code" }));
  addFieldIfMissing(collection, new TextField({ name: "desa_kelurahan" }));
  addFieldIfMissing(collection, new TextField({ name: "kecamatan" }));
  addFieldIfMissing(collection, new TextField({ name: "kabupaten_kota" }));
  addFieldIfMissing(collection, new TextField({ name: "provinsi" }));
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

function ensureIuranPaymentsCollection(app) {
  const users = findCollection(app, "users");
  const kk = findCollection(app, "kartu_keluarga");
  const bills = findCollection(app, "iuran_bills");
  if (!users || !kk || !bills) {
    return;
  }

  let collection = findCollection(app, "iuran_payments");
  if (!collection) {
    collection = new Collection({
      type: "base",
      name: "iuran_payments",
      fields: [],
    });
  }

  const authRule = "@request.auth.id != ''";
  const adminRule =
    "@request.auth.role = 'admin_rt' || @request.auth.role = 'admin_rw' || @request.auth.role = 'admin_rw_pro' || @request.auth.role = 'sysadmin'";
  collection.listRule = authRule;
  collection.viewRule = authRule;
  collection.createRule = authRule;
  collection.updateRule = adminRule;
  collection.deleteRule = adminRule;

  addFieldIfMissing(
    collection,
    new RelationField({
      name: "bill",
      collectionId: bills.id,
      maxSelect: 1,
      required: true,
    }),
  );
  addFieldIfMissing(
    collection,
    new RelationField({
      name: "kk",
      collectionId: kk.id,
      maxSelect: 1,
      required: true,
    }),
  );
  addFieldIfMissing(
    collection,
    new RelationField({
      name: "submitted_by",
      collectionId: users.id,
      maxSelect: 1,
      required: true,
    }),
  );
  addFieldIfMissing(
    collection,
    new SelectField({
      name: "method",
      maxSelect: 1,
      required: true,
      values: ["cash", "transfer"],
    }),
  );
  addFieldIfMissing(
    collection,
    new NumberField({
      name: "amount",
      onlyInt: true,
      min: 0,
      required: true,
    }),
  );
  addFieldIfMissing(
    collection,
    new FileField({
      name: "proof_file",
      maxSelect: 1,
      maxSize: 10 * 1024 * 1024,
      mimeTypes: [],
      thumbs: [],
      protected: false,
    }),
  );
  addFieldIfMissing(collection, new TextField({ name: "note" }));
  addFieldIfMissing(collection, new TextField({ name: "review_note" }));
  addFieldIfMissing(
    collection,
    new SelectField({
      name: "status",
      maxSelect: 1,
      required: true,
      values: ["submitted", "verified", "rejected"],
    }),
  );
  addFieldIfMissing(collection, new DateField({ name: "submitted_at" }));
  addFieldIfMissing(
    collection,
    new RelationField({
      name: "verified_by",
      collectionId: users.id,
      maxSelect: 1,
    }),
  );
  addFieldIfMissing(collection, new DateField({ name: "verified_at" }));
  addFieldIfMissing(collection, new TextField({ name: "rejection_note" }));
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

function seedIuranTypes(app) {
  const collection = findCollection(app, "iuran_types");
  if (!collection) {
    return;
  }

  const seeds = [
    {
      code: "kebersihan",
      label: "Iuran Kebersihan",
      description: "Tagihan kebersihan lingkungan per periode.",
      default_amount: 0,
      default_frequency: "bulanan",
      is_active: true,
      sort_order: 10,
    },
    {
      code: "keamanan",
      label: "Iuran Keamanan",
      description: "Tagihan keamanan atau ronda warga.",
      default_amount: 0,
      default_frequency: "bulanan",
      is_active: true,
      sort_order: 20,
    },
    {
      code: "kas_sosial",
      label: "Kas Sosial",
      description: "Iuran sosial untuk kebutuhan warga dan kegiatan bersama.",
      default_amount: 0,
      default_frequency: "bulanan",
      is_active: true,
      sort_order: 30,
    },
    {
      code: "kegiatan_warga",
      label: "Kegiatan Warga",
      description: "Iuran untuk kegiatan bersama atau agenda lingkungan.",
      default_amount: 0,
      default_frequency: "insidental",
      is_active: true,
      sort_order: 40,
    },
    {
      code: "tahunan_lingkungan",
      label: "Iuran Tahunan Lingkungan",
      description: "Tagihan tahunan untuk kebutuhan lingkungan tertentu.",
      default_amount: 0,
      default_frequency: "tahunan",
      is_active: true,
      sort_order: 50,
    },
  ];

  for (const seed of seeds) {
    upsertByCode(app, collection, seed);
  }
}

function upsertByCode(app, collection, data) {
  let existing = null;
  try {
    existing = app.findFirstRecordByFilter(
      collection,
      `code = "${escapeFilterValue(data.code)}"`,
    );
  } catch (_) {}

  if (existing) {
    for (const [key, value] of Object.entries(data)) {
      existing.set(key, value);
    }
    app.save(existing);
    return;
  }

  const record = new Record(collection);
  for (const [key, value] of Object.entries(data)) {
    record.set(key, value);
  }
  app.save(record);
}

function applyAdminManagedRules(collection) {
  const authRule = "@request.auth.id != ''";
  const adminRule =
    "@request.auth.role = 'admin_rt' || @request.auth.role = 'admin_rw' || @request.auth.role = 'admin_rw_pro' || @request.auth.role = 'sysadmin'";
  collection.listRule = authRule;
  collection.viewRule = authRule;
  collection.createRule = adminRule;
  collection.updateRule = adminRule;
  collection.deleteRule = adminRule;
}

function addFieldIfMissing(collection, field) {
  if (collection.fields.getByName(field.name)) {
    return;
  }
  collection.fields.add(field);
}

function findCollection(app, name) {
  try {
    return app.findCollectionByNameOrId(name);
  } catch (_) {
    return null;
  }
}

function escapeFilterValue(value) {
  return `${value ?? ""}`.replaceAll("\\", "\\\\").replaceAll("\"", "\\\"");
}
