/// <reference path="../pb_data/types.d.ts" />

migrate((app) => {
  const collection = findCollection(app, "surat_templates");
  if (!collection) {
    return;
  }

  addFieldIfMissing(collection, new TextField({ name: "template_body" }));
  app.save(collection);

  const bodyByCode = {
    domisili:
      "Yang bertanda tangan di bawah ini menerangkan bahwa {{nama_warga}} benar merupakan warga RT {{rt}} / RW {{rw}}, {{desa_kelurahan}}, {{kecamatan}}, {{kabupaten_kota}}, {{provinsi}}. Surat ini dipergunakan untuk keperluan {{purpose}}.",
    pengantar_ktp:
      "Dengan ini kami menerangkan bahwa {{nama_warga}} adalah warga yang berdomisili di lingkungan kami dan memerlukan pengantar untuk keperluan {{purpose}}.",
    pengantar_kia:
      "Dengan ini kami menerangkan bahwa {{nama_warga}} merupakan warga yang mengajukan pengantar KIA untuk keperluan {{purpose}}.",
    pengantar_skck:
      "Dengan ini kami menerangkan bahwa {{nama_warga}} mengajukan surat pengantar SKCK untuk keperluan {{purpose}}.",
    pengantar_pindah_keluar:
      "Dengan ini kami menerangkan bahwa {{nama_warga}} mengajukan pindah keluar dari wilayah kami dengan tujuan {{alamat_tujuan}} untuk keperluan {{purpose}}.",
    pengantar_pindah_datang:
      "Dengan ini kami menerangkan bahwa {{nama_warga}} mengajukan pindah datang ke wilayah kami dari alamat asal {{alamat_asal}}.",
    pengantar_kelahiran:
      "Dengan ini kami menerangkan kelahiran anak bernama {{nama_bayi}} pada {{tanggal_lahir_bayi}} di {{tempat_lahir_bayi}} dari pasangan {{nama_ayah}} dan {{nama_ibu}}.",
    pengantar_tambah_anggota_kk:
      "Dengan ini kami menerangkan penambahan anggota keluarga bernama {{nama_anggota_baru}} sebagai {{hubungan_keluarga}} ke dalam KK pemohon.",
    pengantar_perubahan_kk:
      "Dengan ini kami menerangkan adanya permohonan perubahan data KK dengan alasan {{alasan_perubahan}}.",
    pengantar_pecah_kk:
      "Dengan ini kami menerangkan permohonan pecah KK dari nomor KK {{kk_asal}} dengan alasan {{alasan}}.",
    pengantar_gabung_kk:
      "Dengan ini kami menerangkan permohonan gabung KK ke nomor KK {{kk_tujuan}} dengan alasan {{alasan}}.",
    pengantar_nikah:
      "Dengan ini kami menerangkan bahwa {{nama_warga}} bermaksud melangsungkan pernikahan dengan {{nama_pasangan}} pada {{tanggal_rencana_nikah}} di {{lokasi_kua_atau_tempat}}.",
    sktm_pendidikan:
      "Dengan ini kami menerangkan bahwa {{nama_warga}} mengajukan SKTM pendidikan untuk keperluan {{purpose}} di {{institusi_tujuan}}.",
    sktm_kesehatan:
      "Dengan ini kami menerangkan bahwa {{nama_warga}} mengajukan SKTM kesehatan untuk keperluan {{purpose}} di {{fasilitas_kesehatan_tujuan}}.",
    sktm_umum:
      "Dengan ini kami menerangkan bahwa {{nama_warga}} mengajukan SKTM umum untuk keperluan {{tujuan_sktm}}.",
    keterangan_usaha:
      "Dengan ini kami menerangkan bahwa {{nama_warga}} memiliki usaha {{nama_usaha}} yang beralamat di {{alamat_usaha}} dengan jenis usaha {{jenis_usaha}}.",
    domisili_usaha:
      "Dengan ini kami menerangkan bahwa usaha {{nama_usaha}} milik {{nama_warga}} berdomisili di {{alamat_usaha}} untuk keperluan {{purpose}}.",
    pengantar_kematian:
      "Dengan ini kami menerangkan bahwa {{nama_almarhum}} telah meninggal dunia pada {{tanggal_meninggal}} di {{tempat_meninggal}}.",
    keterangan_kematian_lingkungan:
      "Dengan ini kami menerangkan bahwa benar telah terjadi peristiwa kematian atas nama {{nama_almarhum}} pada {{tanggal_meninggal}} di lingkungan kami.",
    pengantar_pemakaman:
      "Dengan ini kami menerangkan bahwa pengantar pemakaman diberikan untuk almarhum/almarhumah {{nama_almarhum}} di {{lokasi_pemakaman}} pada {{tanggal_pemakaman}}.",
    pengantar_ahli_waris:
      "Dengan ini kami menerangkan pengantar ahli waris atas almarhum/almarhumah {{nama_almarhum}} dengan daftar ahli waris {{daftar_ahli_waris}}.",
    domisili_sementara:
      "Dengan ini kami menerangkan bahwa {{nama_warga}} berdomisili sementara di {{alamat_domisili}} selama {{lama_tinggal}}.",
    keterangan_tinggal_lingkungan:
      "Dengan ini kami menerangkan bahwa {{nama_warga}} benar tinggal di lingkungan kami di alamat {{alamat_domisili}} selama {{lama_tinggal}}.",
    keterangan_belum_menikah:
      "Dengan ini kami menerangkan bahwa {{nama_warga}} menurut pengetahuan kami berstatus belum menikah untuk keperluan {{purpose}}.",
    keterangan_janda_duda:
      "Dengan ini kami menerangkan bahwa {{nama_warga}} berstatus {{status_perkawinan}} untuk keperluan {{purpose}}.",
  };

  const records = app.findAllRecords(collection);
  for (const record of records) {
    const code = asString(record.getString("code"));
    if (!code || !bodyByCode[code]) {
      continue;
    }
    record.set("template_body", bodyByCode[code]);
    app.save(record);
  }
}, (_) => {});

function findCollection(app, name) {
  try {
    return app.findCollectionByNameOrId(name);
  } catch (_) {
    return null;
  }
}

function addFieldIfMissing(collection, field) {
  if (collection.fields.getByName(field.name)) {
    return;
  }
  collection.fields.add(field);
}

function asString(value) {
  return `${value ?? ""}`.trim();
}
