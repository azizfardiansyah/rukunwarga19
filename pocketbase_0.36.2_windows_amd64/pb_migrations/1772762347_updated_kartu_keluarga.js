/// <reference path="../pb_data/types.d.ts" />
migrate((app) => {
  const collection = app.findCollectionByNameOrId("pbc_54311657")

  // add field
  collection.fields.addAt(7, new Field({
    "autogeneratePattern": "",
    "hidden": false,
    "id": "text484668204",
    "max": 0,
    "min": 0,
    "name": "desa_kelurahan",
    "pattern": "",
    "presentable": false,
    "primaryKey": false,
    "required": true,
    "system": false,
    "type": "text"
  }))

  // add field
  collection.fields.addAt(8, new Field({
    "autogeneratePattern": "",
    "hidden": false,
    "id": "text3203324448",
    "max": 0,
    "min": 0,
    "name": "kecamatan",
    "pattern": "",
    "presentable": false,
    "primaryKey": false,
    "required": true,
    "system": false,
    "type": "text"
  }))

  // add field
  collection.fields.addAt(9, new Field({
    "autogeneratePattern": "",
    "hidden": false,
    "id": "text2417297850",
    "max": 0,
    "min": 0,
    "name": "kabupaten_kota",
    "pattern": "",
    "presentable": false,
    "primaryKey": false,
    "required": true,
    "system": false,
    "type": "text"
  }))

  // add field
  collection.fields.addAt(10, new Field({
    "autogeneratePattern": "",
    "hidden": false,
    "id": "text162433649",
    "max": 0,
    "min": 0,
    "name": "provinsi",
    "pattern": "",
    "presentable": false,
    "primaryKey": false,
    "required": true,
    "system": false,
    "type": "text"
  }))

  // add field
  collection.fields.addAt(11, new Field({
    "cascadeDelete": false,
    "collectionId": "pbc_2188441055",
    "hidden": false,
    "id": "relation1569277836",
    "maxSelect": 1,
    "minSelect": 0,
    "name": "kepala_keluarga",
    "presentable": false,
    "required": false,
    "system": false,
    "type": "relation"
  }))

  // update field
  collection.fields.addAt(1, new Field({
    "hidden": false,
    "id": "number3102521941",
    "max": null,
    "min": null,
    "name": "no_kk",
    "onlyInt": true,
    "presentable": false,
    "required": true,
    "system": false,
    "type": "number"
  }))

  // update field
  collection.fields.addAt(2, new Field({
    "autogeneratePattern": "",
    "hidden": false,
    "id": "text3333669062",
    "max": 0,
    "min": 0,
    "name": "alamat",
    "pattern": "",
    "presentable": false,
    "primaryKey": false,
    "required": true,
    "system": false,
    "type": "text"
  }))

  // update field
  collection.fields.addAt(3, new Field({
    "hidden": false,
    "id": "number196656302",
    "max": null,
    "min": null,
    "name": "rt",
    "onlyInt": true,
    "presentable": false,
    "required": true,
    "system": false,
    "type": "number"
  }))

  // update field
  collection.fields.addAt(4, new Field({
    "hidden": false,
    "id": "number2461134100",
    "max": null,
    "min": null,
    "name": "rw",
    "onlyInt": true,
    "presentable": false,
    "required": true,
    "system": false,
    "type": "number"
  }))

  // update field
  collection.fields.addAt(6, new Field({
    "hidden": false,
    "id": "file2326713792",
    "maxSelect": 1,
    "maxSize": 0,
    "mimeTypes": [],
    "name": "scan_kk",
    "presentable": false,
    "protected": false,
    "required": true,
    "system": false,
    "thumbs": [],
    "type": "file"
  }))

  return app.save(collection)
}, (app) => {
  const collection = app.findCollectionByNameOrId("pbc_54311657")

  // remove field
  collection.fields.removeById("text484668204")

  // remove field
  collection.fields.removeById("text3203324448")

  // remove field
  collection.fields.removeById("text2417297850")

  // remove field
  collection.fields.removeById("text162433649")

  // remove field
  collection.fields.removeById("relation1569277836")

  // update field
  collection.fields.addAt(1, new Field({
    "hidden": false,
    "id": "number3102521941",
    "max": null,
    "min": null,
    "name": "no_kk",
    "onlyInt": false,
    "presentable": false,
    "required": false,
    "system": false,
    "type": "number"
  }))

  // update field
  collection.fields.addAt(2, new Field({
    "autogeneratePattern": "",
    "hidden": false,
    "id": "text3333669062",
    "max": 0,
    "min": 0,
    "name": "alamat",
    "pattern": "",
    "presentable": false,
    "primaryKey": false,
    "required": false,
    "system": false,
    "type": "text"
  }))

  // update field
  collection.fields.addAt(3, new Field({
    "hidden": false,
    "id": "number196656302",
    "max": null,
    "min": null,
    "name": "rt",
    "onlyInt": false,
    "presentable": false,
    "required": false,
    "system": false,
    "type": "number"
  }))

  // update field
  collection.fields.addAt(4, new Field({
    "hidden": false,
    "id": "number2461134100",
    "max": null,
    "min": null,
    "name": "rw",
    "onlyInt": false,
    "presentable": false,
    "required": false,
    "system": false,
    "type": "number"
  }))

  // update field
  collection.fields.addAt(6, new Field({
    "hidden": false,
    "id": "file2326713792",
    "maxSelect": 1,
    "maxSize": 0,
    "mimeTypes": [],
    "name": "scan_kk",
    "presentable": false,
    "protected": false,
    "required": false,
    "system": false,
    "thumbs": [],
    "type": "file"
  }))

  return app.save(collection)
})
