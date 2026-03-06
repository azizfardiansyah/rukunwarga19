/// <reference path="../pb_data/types.d.ts" />
migrate((app) => {
  const collection = app.findCollectionByNameOrId("pbc_2188441055")

  // add field
  collection.fields.addAt(19, new Field({
    "cascadeDelete": false,
    "collectionId": "pbc_54311657",
    "hidden": false,
    "id": "relation3102521941",
    "maxSelect": 1,
    "minSelect": 0,
    "name": "no_kk",
    "presentable": false,
    "required": false,
    "system": false,
    "type": "relation"
  }))

  return app.save(collection)
}, (app) => {
  const collection = app.findCollectionByNameOrId("pbc_2188441055")

  // remove field
  collection.fields.removeById("relation3102521941")

  return app.save(collection)
})
