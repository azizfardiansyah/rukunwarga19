/// <reference path="../pb_data/types.d.ts" />
migrate((app) => {
  const collection = app.findCollectionByNameOrId("pbc_1851965056")

  // update field
  collection.fields.addAt(3, new Field({
    "hidden": false,
    "id": "select1804125333",
    "maxSelect": 1,
    "name": "hubungan",
    "presentable": false,
    "required": false,
    "system": false,
    "type": "select",
    "values": [
      "Ayah",
      "Ibu",
      "Anak"
    ]
  }))

  return app.save(collection)
}, (app) => {
  const collection = app.findCollectionByNameOrId("pbc_1851965056")

  // update field
  collection.fields.addAt(3, new Field({
    "hidden": false,
    "id": "select1804125333",
    "maxSelect": 1,
    "name": "hubungan_",
    "presentable": false,
    "required": false,
    "system": false,
    "type": "select",
    "values": [
      "Ayah",
      "Ibu",
      "Anak"
    ]
  }))

  return app.save(collection)
})
