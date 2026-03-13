/// <reference path="../pb_data/types.d.ts" />

migrate((app) => {
  const collection = app.findCollectionByNameOrId("announcements");
  if (!collection) {
    return;
  }

  const field = collection.fields.find((item) => item.name === "source_module");
  if (!field || !Array.isArray(field.values)) {
    return;
  }

  if (!field.values.includes("iuran")) {
    field.values.push("iuran");
    app.save(collection);
  }
}, (app) => {
  const collection = app.findCollectionByNameOrId("announcements");
  if (!collection) {
    return;
  }

  const field = collection.fields.find((item) => item.name === "source_module");
  if (!field || !Array.isArray(field.values)) {
    return;
  }

  field.values = field.values.filter((value) => value !== "iuran");
  app.save(collection);
});
