/// <reference path="../pb_data/types.d.ts" />

migrate((app) => {
  const collection = findCollection(app, "messages");
  if (!collection) {
    return;
  }

  addFieldIfMissing(collection, new DateField({ name: "pinned_until" }));

  app.save(collection);
}, (app) => {
  const collection = findCollection(app, "messages");
  if (!collection) {
    return;
  }

  removeFieldIfExists(collection, "pinned_until");

  app.save(collection);
});

function findCollection(app, name) {
  try {
    return app.findCollectionByNameOrId(name);
  } catch (_) {
    return null;
  }
}

function addFieldIfMissing(collection, field) {
  const exists = collection.fields.getByName(field.name);
  if (!exists) {
    collection.fields.add(field);
  }
}

function removeFieldIfExists(collection, fieldName) {
  if (collection.fields.getByName(fieldName)) {
    collection.fields.removeByName(fieldName);
  }
}
