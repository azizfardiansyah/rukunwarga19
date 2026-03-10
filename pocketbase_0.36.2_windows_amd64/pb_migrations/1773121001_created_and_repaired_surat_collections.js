/// <reference path="../pb_data/types.d.ts" />

migrate((app) => {
  ensureSuratCollection(app);
  ensureSuratAttachmentsCollection(app);
  ensureSuratLogsCollection(app);
  ensureSuratTemplatesCollection(app);
  seedSuratTemplates(app);
}, (app) => {
  // No destructive rollback for surat workflow collections.
});

function ensureSuratCollection(app) {
  const users = findCollection(app, "users");
  const warga = findCollection(app, "warga");
  const kartuKeluarga = findCollection(app, "kartu_keluarga");
  if (!users || !warga || !kartuKeluarga) {
    return;
  }

  let collection = findCollection(app, "surat");
  if (!collection) {
    collection = new Collection({
      type: "base",
      name: "surat",
      fields: [],
    });
  }

  applyCommonAuthRules(collection);

  addFieldIfMissing(
    collection,
    new RelationField({
      name: "warga",
      collectionId: warga.id,
      maxSelect: 1,
      required: true,
    }),
  );
  addFieldIfMissing(
    collection,
    new RelationField({
      name: "kk",
      collectionId: kartuKeluarga.id,
      maxSelect: 1,
    }),
  );
  addFieldIfMissing(
    collection,
    new SelectField({
      name: "jenis_surat",
      maxSelect: 1,
      required: true,
      values: [
        "domisili",
        "pengantar_ktp",
        "pengantar_kia",
        "pengantar_skck",
        "pengantar_pindah_keluar",
        "pengantar_pindah_datang",
        "pengantar_kelahiran",
        "pengantar_tambah_anggota_kk",
        "pengantar_perubahan_kk",
        "pengantar_pecah_kk",
        "pengantar_gabung_kk",
        "pengantar_nikah",
        "sktm_pendidikan",
        "sktm_kesehatan",
        "sktm_umum",
        "keterangan_usaha",
        "domisili_usaha",
        "pengantar_kematian",
        "keterangan_kematian_lingkungan",
        "pengantar_pemakaman",
        "pengantar_ahli_waris",
        "domisili_sementara",
        "keterangan_tinggal_lingkungan",
        "keterangan_belum_menikah",
        "keterangan_janda_duda",
      ],
    }),
  );
  addFieldIfMissing(
    collection,
    new SelectField({
      name: "category",
      maxSelect: 1,
      required: true,
      values: [
        "kependudukan",
        "keluarga",
        "sosial",
        "usaha",
        "kematian",
        "lingkungan",
      ],
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
      name: "purpose",
      required: true,
    }),
  );
  addFieldIfMissing(collection, new TextField({ name: "applicant_note" }));
  addFieldIfMissing(
    collection,
    new SelectField({
      name: "status",
      maxSelect: 1,
      required: true,
      values: [
        "draft",
        "submitted",
        "need_revision",
        "approved_rt",
        "forwarded_to_rw",
        "approved_rw",
        "completed",
        "rejected",
      ],
    }),
  );
  addFieldIfMissing(
    collection,
    new SelectField({
      name: "approval_level",
      maxSelect: 1,
      required: true,
      values: ["rt", "rw"],
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
    new TextField({
      name: "request_payload",
      required: true,
    }),
  );
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
  addFieldIfMissing(collection, new DateField({ name: "submitted_at" }));
  addFieldIfMissing(
    collection,
    new RelationField({
      name: "reviewed_by_rt",
      collectionId: users.id,
      maxSelect: 1,
    }),
  );
  addFieldIfMissing(collection, new DateField({ name: "reviewed_at_rt" }));
  addFieldIfMissing(collection, new TextField({ name: "review_note_rt" }));
  addFieldIfMissing(
    collection,
    new RelationField({
      name: "reviewed_by_rw",
      collectionId: users.id,
      maxSelect: 1,
    }),
  );
  addFieldIfMissing(collection, new DateField({ name: "reviewed_at_rw" }));
  addFieldIfMissing(collection, new TextField({ name: "review_note_rw" }));
  addFieldIfMissing(collection, new TextField({ name: "output_number" }));
  addFieldIfMissing(
    collection,
    new FileField({
      name: "output_file",
      maxSelect: 1,
      maxSize: 10 * 1024 * 1024,
      mimeTypes: [],
      thumbs: [],
      protected: false,
    }),
  );
  addFieldIfMissing(collection, new DateField({ name: "finalized_at" }));
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

function ensureSuratAttachmentsCollection(app) {
  const surat = findCollection(app, "surat");
  if (!surat) {
    return;
  }

  let collection = findCollection(app, "surat_attachments");
  if (!collection) {
    collection = new Collection({
      type: "base",
      name: "surat_attachments",
      fields: [],
    });
  }

  applyCommonAuthRules(collection);

  addFieldIfMissing(
    collection,
    new RelationField({
      name: "request",
      collectionId: surat.id,
      maxSelect: 1,
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
  addFieldIfMissing(collection, new TextField({ name: "label" }));
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

function ensureSuratLogsCollection(app) {
  const surat = findCollection(app, "surat");
  const users = findCollection(app, "users");
  if (!surat || !users) {
    return;
  }

  let collection = findCollection(app, "surat_logs");
  if (!collection) {
    collection = new Collection({
      type: "base",
      name: "surat_logs",
      fields: [],
    });
  }

  applyCommonAuthRules(collection);

  addFieldIfMissing(
    collection,
    new RelationField({
      name: "request",
      collectionId: surat.id,
      maxSelect: 1,
      required: true,
    }),
  );
  addFieldIfMissing(
    collection,
    new RelationField({
      name: "actor",
      collectionId: users.id,
      maxSelect: 1,
      required: true,
    }),
  );
  addFieldIfMissing(
    collection,
    new TextField({
      name: "action",
      required: true,
    }),
  );
  addFieldIfMissing(
    collection,
    new TextField({
      name: "description",
      required: true,
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

function ensureSuratTemplatesCollection(app) {
  let collection = findCollection(app, "surat_templates");
  if (!collection) {
    collection = new Collection({
      type: "base",
      name: "surat_templates",
      fields: [],
    });
  }

  const authRule = "@request.auth.id != ''";
  const adminRule =
    "@request.auth.role = 'sysadmin' || @request.auth.role = 'admin_rw_pro'";
  collection.listRule = authRule;
  collection.viewRule = authRule;
  collection.createRule = adminRule;
  collection.updateRule = adminRule;
  collection.deleteRule = adminRule;

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
  addFieldIfMissing(
    collection,
    new SelectField({
      name: "category",
      maxSelect: 1,
      required: true,
      values: [
        "kependudukan",
        "keluarga",
        "sosial",
        "usaha",
        "kematian",
        "lingkungan",
      ],
    }),
  );
  addFieldIfMissing(
    collection,
    new SelectField({
      name: "approval_level",
      maxSelect: 1,
      required: true,
      values: ["rt", "rw"],
    }),
  );
  addFieldIfMissing(collection, new TextField({ name: "description" }));
  addFieldIfMissing(collection, new TextField({ name: "required_fields" }));
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

function seedSuratTemplates(app) {
  const collection = findCollection(app, "surat_templates");
  if (!collection) {
    return;
  }

  const templates = [
    seedTemplate("domisili", "Surat Keterangan Domisili", "kependudukan", "rw", ["alamat_domisili", "lama_tinggal"]),
    seedTemplate("pengantar_ktp", "Surat Pengantar KTP", "kependudukan", "rw", ["keperluan"]),
    seedTemplate("pengantar_kia", "Surat Pengantar KIA", "kependudukan", "rw", ["keperluan"]),
    seedTemplate("pengantar_skck", "Surat Pengantar SKCK", "kependudukan", "rw", ["keperluan_skck", "institusi_tujuan"]),
    seedTemplate("pengantar_pindah_keluar", "Surat Pengantar Pindah Keluar", "kependudukan", "rw", ["alamat_tujuan", "jumlah_pengikut", "alasan_pindah"]),
    seedTemplate("pengantar_pindah_datang", "Surat Pengantar Pindah Datang", "kependudukan", "rw", ["alamat_asal", "jumlah_pengikut"]),
    seedTemplate("pengantar_kelahiran", "Surat Pengantar Kelahiran", "keluarga", "rw", ["nama_bayi", "tanggal_lahir_bayi", "tempat_lahir_bayi", "nama_ayah", "nama_ibu"]),
    seedTemplate("pengantar_tambah_anggota_kk", "Surat Pengantar Tambah Anggota KK", "keluarga", "rw", ["nama_anggota_baru", "hubungan_keluarga"]),
    seedTemplate("pengantar_perubahan_kk", "Surat Pengantar Perubahan KK", "keluarga", "rw", ["alasan_perubahan"]),
    seedTemplate("pengantar_pecah_kk", "Surat Pengantar Pecah KK", "keluarga", "rw", ["kk_asal", "alasan"]),
    seedTemplate("pengantar_gabung_kk", "Surat Pengantar Gabung KK", "keluarga", "rw", ["kk_tujuan", "alasan"]),
    seedTemplate("pengantar_nikah", "Surat Pengantar Nikah", "keluarga", "rw", ["nama_pasangan", "tanggal_rencana_nikah", "lokasi_kua_atau_tempat"]),
    seedTemplate("sktm_pendidikan", "SKTM Pendidikan", "sosial", "rw", ["institusi_tujuan", "alasan_permohonan"]),
    seedTemplate("sktm_kesehatan", "SKTM Kesehatan", "sosial", "rw", ["fasilitas_kesehatan_tujuan", "alasan_permohonan"]),
    seedTemplate("sktm_umum", "SKTM Umum", "sosial", "rw", ["tujuan_sktm", "alasan_permohonan"]),
    seedTemplate("keterangan_usaha", "Surat Keterangan Usaha", "usaha", "rt", ["nama_usaha", "alamat_usaha", "jenis_usaha"]),
    seedTemplate("domisili_usaha", "Surat Domisili Usaha", "usaha", "rw", ["nama_usaha", "alamat_usaha", "jenis_usaha"]),
    seedTemplate("pengantar_kematian", "Surat Pengantar Kematian", "kematian", "rw", ["nama_almarhum", "tanggal_meninggal", "tempat_meninggal", "hubungan_pelapor"]),
    seedTemplate("keterangan_kematian_lingkungan", "Surat Keterangan Kematian Lingkungan", "kematian", "rt", ["nama_almarhum", "tanggal_meninggal", "tempat_meninggal"]),
    seedTemplate("pengantar_pemakaman", "Surat Pengantar Pemakaman", "kematian", "rt", ["nama_almarhum", "lokasi_pemakaman", "tanggal_pemakaman"]),
    seedTemplate("pengantar_ahli_waris", "Surat Pengantar Ahli Waris", "kematian", "rw", ["nama_almarhum", "tanggal_meninggal", "daftar_ahli_waris"]),
    seedTemplate("domisili_sementara", "Surat Keterangan Domisili Sementara", "lingkungan", "rt", ["alamat_domisili", "lama_tinggal"]),
    seedTemplate("keterangan_tinggal_lingkungan", "Surat Keterangan Tinggal Lingkungan", "lingkungan", "rt", ["alamat_domisili", "lama_tinggal"]),
    seedTemplate("keterangan_belum_menikah", "Surat Keterangan Belum Menikah", "lingkungan", "rt", ["keperluan"]),
    seedTemplate("keterangan_janda_duda", "Surat Keterangan Janda / Duda", "lingkungan", "rt", ["status_perkawinan", "keperluan"]),
  ];

  for (let index = 0; index < templates.length; index += 1) {
    const template = templates[index];
    upsertTemplate(app, collection, {
      code: template.code,
      label: template.label,
      category: template.category,
      approval_level: template.approvalLevel,
      description: template.description,
      required_fields: JSON.stringify(template.requiredFields),
      is_active: true,
      sort_order: (index + 1) * 10,
    });
  }
}

function seedTemplate(code, label, category, approvalLevel, requiredFields) {
  return {
    code,
    label,
    category,
    approvalLevel,
    description: `Template workflow untuk ${label.toLowerCase()}.`,
    requiredFields,
  };
}

function upsertTemplate(app, collection, data) {
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

function applyCommonAuthRules(collection) {
  const authRule = "@request.auth.id != ''";
  const adminRule =
    "@request.auth.role = 'admin_rt' || @request.auth.role = 'admin_rw' || @request.auth.role = 'admin_rw_pro' || @request.auth.role = 'sysadmin'";
  collection.listRule = authRule;
  collection.viewRule = authRule;
  collection.createRule = authRule;
  collection.updateRule = authRule;
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
