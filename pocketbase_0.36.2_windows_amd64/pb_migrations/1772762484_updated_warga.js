/// <reference path="../pb_data/types.d.ts" />
migrate((app) => {
  const collection = app.findCollectionByNameOrId("pbc_2188441055")

  // add field
  collection.fields.addAt(17, new Field({
    "autogeneratePattern": "",
    "hidden": false,
    "id": "text782694036",
    "max": 0,
    "min": 0,
    "name": "pendidikan",
    "pattern": "",
    "presentable": false,
    "primaryKey": false,
    "required": false,
    "system": false,
    "type": "text"
  }))

  // add field
  collection.fields.addAt(18, new Field({
    "autogeneratePattern": "",
    "hidden": false,
    "id": "text3048385402",
    "max": 0,
    "min": 0,
    "name": "golongan_darah",
    "pattern": "",
    "presentable": false,
    "primaryKey": false,
    "required": true,
    "system": false,
    "type": "text"
  }))

  // update field
  collection.fields.addAt(1, new Field({
    "autogeneratePattern": "",
    "hidden": false,
    "id": "text3545716486",
    "max": 0,
    "min": 0,
    "name": "nik",
    "pattern": "",
    "presentable": false,
    "primaryKey": false,
    "required": true,
    "system": false,
    "type": "text"
  }))

  // update field
  collection.fields.addAt(2, new Field({
    "autogeneratePattern": "",
    "hidden": false,
    "id": "text878082617",
    "max": 0,
    "min": 0,
    "name": "nama_lengkap",
    "pattern": "",
    "presentable": false,
    "primaryKey": false,
    "required": true,
    "system": false,
    "type": "text"
  }))

  // update field
  collection.fields.addAt(3, new Field({
    "autogeneratePattern": "",
    "hidden": false,
    "id": "text3283531000",
    "max": 0,
    "min": 0,
    "name": "tempat_lahir",
    "pattern": "",
    "presentable": false,
    "primaryKey": false,
    "required": true,
    "system": false,
    "type": "text"
  }))

  // update field
  collection.fields.addAt(4, new Field({
    "hidden": false,
    "id": "date4050801271",
    "max": "",
    "min": "",
    "name": "tanggal_lahir",
    "presentable": false,
    "required": true,
    "system": false,
    "type": "date"
  }))

  // update field
  collection.fields.addAt(5, new Field({
    "hidden": false,
    "id": "select2981831938",
    "maxSelect": 1,
    "name": "jenis_kelamin",
    "presentable": false,
    "required": true,
    "system": false,
    "type": "select",
    "values": [
      "Laki-laki",
      "Perempuan"
    ]
  }))

  // update field
  collection.fields.addAt(6, new Field({
    "hidden": false,
    "id": "select1735557993",
    "maxSelect": 1,
    "name": "agama",
    "presentable": false,
    "required": true,
    "system": false,
    "type": "select",
    "values": [
      "Islam",
      "Kristen",
      "Budha",
      "Khatolik"
    ]
  }))

  // update field
  collection.fields.addAt(9, new Field({
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
  collection.fields.addAt(10, new Field({
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
  collection.fields.addAt(11, new Field({
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

  return app.save(collection)
}, (app) => {
  const collection = app.findCollectionByNameOrId("pbc_2188441055")

  // remove field
  collection.fields.removeById("text782694036")

  // remove field
  collection.fields.removeById("text3048385402")

  // update field
  collection.fields.addAt(1, new Field({
    "autogeneratePattern": "",
    "hidden": false,
    "id": "text3545716486",
    "max": 0,
    "min": 0,
    "name": "nik",
    "pattern": "",
    "presentable": false,
    "primaryKey": false,
    "required": false,
    "system": false,
    "type": "text"
  }))

  // update field
  collection.fields.addAt(2, new Field({
    "autogeneratePattern": "",
    "hidden": false,
    "id": "text878082617",
    "max": 0,
    "min": 0,
    "name": "nama_lengkap",
    "pattern": "",
    "presentable": false,
    "primaryKey": false,
    "required": false,
    "system": false,
    "type": "text"
  }))

  // update field
  collection.fields.addAt(3, new Field({
    "autogeneratePattern": "",
    "hidden": false,
    "id": "text3283531000",
    "max": 0,
    "min": 0,
    "name": "tempat_lahir",
    "pattern": "",
    "presentable": false,
    "primaryKey": false,
    "required": false,
    "system": false,
    "type": "text"
  }))

  // update field
  collection.fields.addAt(4, new Field({
    "hidden": false,
    "id": "date4050801271",
    "max": "",
    "min": "",
    "name": "tanggal_lahir",
    "presentable": false,
    "required": false,
    "system": false,
    "type": "date"
  }))

  // update field
  collection.fields.addAt(5, new Field({
    "hidden": false,
    "id": "select2981831938",
    "maxSelect": 1,
    "name": "jenis_kelamin",
    "presentable": false,
    "required": false,
    "system": false,
    "type": "select",
    "values": [
      "Laki-laki",
      "Perempuan"
    ]
  }))

  // update field
  collection.fields.addAt(6, new Field({
    "hidden": false,
    "id": "select1735557993",
    "maxSelect": 1,
    "name": "agama",
    "presentable": false,
    "required": false,
    "system": false,
    "type": "select",
    "values": [
      "Islam",
      "Kristen",
      "Budha",
      "Khatolik"
    ]
  }))

  // update field
  collection.fields.addAt(9, new Field({
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
  collection.fields.addAt(10, new Field({
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
  collection.fields.addAt(11, new Field({
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

  return app.save(collection)
})
