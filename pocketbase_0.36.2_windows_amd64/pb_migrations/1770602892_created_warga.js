/// <reference path="../pb_data/types.d.ts" />
migrate((app) => {
  const collection = new Collection({
    "createRule": null,
    "deleteRule": null,
    "fields": [
      {
        "autogeneratePattern": "[a-z0-9]{15}",
        "hidden": false,
        "id": "text3208210256",
        "max": 15,
        "min": 15,
        "name": "id",
        "pattern": "^[a-z0-9]+$",
        "presentable": false,
        "primaryKey": true,
        "required": true,
        "system": true,
        "type": "text"
      },
      {
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
      },
      {
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
      },
      {
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
      },
      {
        "hidden": false,
        "id": "date4050801271",
        "max": "",
        "min": "",
        "name": "tanggal_lahir",
        "presentable": false,
        "required": false,
        "system": false,
        "type": "date"
      },
      {
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
      },
      {
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
      },
      {
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
      },
      {
        "autogeneratePattern": "",
        "hidden": false,
        "id": "text391769140",
        "max": 0,
        "min": 0,
        "name": "pekerjaan",
        "pattern": "",
        "presentable": false,
        "primaryKey": false,
        "required": false,
        "system": false,
        "type": "text"
      },
      {
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
      },
      {
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
      },
      {
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
      },
      {
        "hidden": false,
        "id": "number430186618",
        "max": null,
        "min": null,
        "name": "no_hp",
        "onlyInt": false,
        "presentable": false,
        "required": false,
        "system": false,
        "type": "number"
      },
      {
        "exceptDomains": null,
        "hidden": false,
        "id": "email3885137012",
        "name": "email",
        "onlyDomains": null,
        "presentable": false,
        "required": false,
        "system": false,
        "type": "email"
      },
      {
        "cascadeDelete": false,
        "collectionId": "_pb_users_auth_",
        "hidden": false,
        "id": "relation2809058197",
        "maxSelect": 1,
        "minSelect": 0,
        "name": "user_id",
        "presentable": false,
        "required": false,
        "system": false,
        "type": "relation"
      },
      {
        "hidden": false,
        "id": "file1228084201",
        "maxSelect": 1,
        "maxSize": 0,
        "mimeTypes": [],
        "name": "foto_ktp",
        "presentable": false,
        "protected": false,
        "required": false,
        "system": false,
        "thumbs": [],
        "type": "file"
      },
      {
        "hidden": false,
        "id": "file2608985945",
        "maxSelect": 1,
        "maxSize": 0,
        "mimeTypes": [],
        "name": "foto_warga",
        "presentable": false,
        "protected": false,
        "required": false,
        "system": false,
        "thumbs": [],
        "type": "file"
      },
      {
        "hidden": false,
        "id": "autodate2990389176",
        "name": "created",
        "onCreate": true,
        "onUpdate": false,
        "presentable": false,
        "system": false,
        "type": "autodate"
      },
      {
        "hidden": false,
        "id": "autodate3332085495",
        "name": "updated",
        "onCreate": true,
        "onUpdate": true,
        "presentable": false,
        "system": false,
        "type": "autodate"
      }
    ],
    "id": "pbc_2188441055",
    "indexes": [],
    "listRule": null,
    "name": "warga",
    "system": false,
    "type": "base",
    "updateRule": null,
    "viewRule": null
  });

  return app.save(collection);
}, (app) => {
  const collection = app.findCollectionByNameOrId("pbc_2188441055");

  return app.delete(collection);
})
