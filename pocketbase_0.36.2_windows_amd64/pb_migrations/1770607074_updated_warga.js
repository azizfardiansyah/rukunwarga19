/// <reference path="../pb_data/types.d.ts" />
migrate((app) => {
  const collection = app.findCollectionByNameOrId("pbc_2188441055")

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
  collection.fields.addAt(7, new Field({
    "hidden": false,
    "id": "select3845351519",
    "maxSelect": 1,
    "name": "status_pernikahan",
    "presentable": false,
    "required": false,
    "system": false,
    "type": "select",
    "values": [
      "Menikah",
      "Belum Menikah",
      "Cerai Mati",
      "Cerai Hidup"
    ]
  }))

  return app.save(collection)
}, (app) => {
  const collection = app.findCollectionByNameOrId("pbc_2188441055")

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
      "laki-laki",
      "perempuan"
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
      "islam"
    ]
  }))

  // update field
  collection.fields.addAt(7, new Field({
    "hidden": false,
    "id": "select3845351519",
    "maxSelect": 1,
    "name": "status_pernikahan",
    "presentable": false,
    "required": false,
    "system": false,
    "type": "select",
    "values": [
      "belum menikah",
      "menikah",
      "cerai mati",
      "cerai hidup"
    ]
  }))

  return app.save(collection)
})
