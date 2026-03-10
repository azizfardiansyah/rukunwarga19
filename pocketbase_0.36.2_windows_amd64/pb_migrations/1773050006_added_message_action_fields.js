/// <reference path="../pb_data/types.d.ts" />

migrate((app) => {
  const collection = findCollection(app, "messages");
  const users = findCollection(app, "users");
  if (!collection || !users) {
    return;
  }

  addFieldIfMissing(
    collection,
    new RelationField({
      name: "reply_to",
      collectionId: collection.id,
      maxSelect: 1,
    }),
  );
  addFieldIfMissing(
    collection,
    new RelationField({
      name: "forwarded_from",
      collectionId: collection.id,
      maxSelect: 1,
    }),
  );
  addFieldIfMissing(collection, new BoolField({ name: "is_starred" }));
  addFieldIfMissing(collection, new BoolField({ name: "is_pinned" }));
  addFieldIfMissing(collection, new DateField({ name: "deleted_at" }));
  addFieldIfMissing(
    collection,
    new RelationField({
      name: "deleted_by",
      collectionId: users.id,
      maxSelect: 1,
    }),
  );

  app.save(collection);
}, (app) => {
  const collection = findCollection(app, "messages");
  if (!collection) {
    return;
  }

  removeFieldIfExists(collection, "reply_to");
  removeFieldIfExists(collection, "forwarded_from");
  removeFieldIfExists(collection, "is_starred");
  removeFieldIfExists(collection, "is_pinned");
  removeFieldIfExists(collection, "deleted_at");
  removeFieldIfExists(collection, "deleted_by");

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
