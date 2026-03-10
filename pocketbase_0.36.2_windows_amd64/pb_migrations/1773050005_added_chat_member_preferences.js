/// <reference path="../pb_data/types.d.ts" />

migrate((app) => {
  const collection = findCollection(app, "conversation_members");
  if (!collection) {
    return;
  }

  addFieldIfMissing(collection, new BoolField({ name: "is_muted" }));
  addFieldIfMissing(collection, new BoolField({ name: "is_pinned" }));
  addFieldIfMissing(collection, new BoolField({ name: "is_archived" }));

  app.save(collection);
}, (app) => {
  const collection = findCollection(app, "conversation_members");
  if (!collection) {
    return;
  }

  removeFieldIfExists(collection, "is_muted");
  removeFieldIfExists(collection, "is_pinned");
  removeFieldIfExists(collection, "is_archived");

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
