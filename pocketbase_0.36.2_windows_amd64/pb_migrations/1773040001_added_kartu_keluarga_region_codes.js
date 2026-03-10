/// <reference path="../pb_data/types.d.ts" />

migrate((app) => {
  let collection = null;

  try {
    collection = app.findCollectionByNameOrId("kartu_keluarga");
  } catch (_) {
    return;
  }

  addFieldIfMissing(
    collection,
    new TextField({
      name: "desa_code",
    }),
  );
  addFieldIfMissing(
    collection,
    new TextField({
      name: "kecamatan_code",
    }),
  );
  addFieldIfMissing(
    collection,
    new TextField({
      name: "kabupaten_code",
    }),
  );
  addFieldIfMissing(
    collection,
    new TextField({
      name: "provinsi_code",
    }),
  );

  return app.save(collection);
}, (app) => {
  let collection = null;

  try {
    collection = app.findCollectionByNameOrId("kartu_keluarga");
  } catch (_) {
    return;
  }

  removeKnownFields(collection, [
    "desa_code",
    "kecamatan_code",
    "kabupaten_code",
    "provinsi_code",
  ]);

  return app.save(collection);
});

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
