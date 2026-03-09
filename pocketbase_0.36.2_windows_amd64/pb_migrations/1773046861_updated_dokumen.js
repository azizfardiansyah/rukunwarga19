/// <reference path="../pb_data/types.d.ts" />
migrate((app) => {
  const collection = app.findCollectionByNameOrId("pbc_3404261585")

  // update collection data
  unmarshal({
    "createRule": "",
    "deleteRule": "",
    "listRule": "",
    "updateRule": "",
    "viewRule": ""
  }, collection)

  return app.save(collection)
}, (app) => {
  const collection = app.findCollectionByNameOrId("pbc_3404261585")

  // update collection data
  unmarshal({
    "createRule": "@request.auth.id != ''",
    "deleteRule": "@request.auth.id != ''",
    "listRule": "@request.auth.id != ''",
    "updateRule": "@request.auth.id != '' && (@request.auth.role = 'admin_rt' || @request.auth.role = 'admin_rw' || @request.auth.role = 'admin_rw_pro' || @request.auth.role = 'sysadmin')",
    "viewRule": "@request.auth.id != ''"
  }, collection)

  return app.save(collection)
})
