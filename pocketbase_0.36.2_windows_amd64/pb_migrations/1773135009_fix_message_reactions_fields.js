/// <reference path="../pb_data/types.d.ts" />

migrate(
  (app) => {
    ensureMessageReactionsCollection(app);
  },
  (app) => {
    const collection = findCollection(app, "message_reactions");
    if (!collection) {
      return;
    }

    removeFieldIfExists(collection, "message");
    removeFieldIfExists(collection, "user");
    removeFieldIfExists(collection, "emoji");
    removeFieldIfExists(collection, "created");
    removeFieldIfExists(collection, "updated");
    app.save(collection);
  },
);

function ensureMessageReactionsCollection(app) {
  const messages = findCollection(app, "messages");
  const users = findCollection(app, "users");
  if (!messages || !users) {
    return;
  }

  let collection = findCollection(app, "message_reactions");
  if (!collection) {
    collection = new Collection({
      type: "base",
      name: "message_reactions",
      fields: [],
    });
  }

  collection.listRule = "@request.auth.id != ''";
  collection.viewRule = "@request.auth.id != ''";
  collection.createRule = "@request.auth.id != ''";
  collection.updateRule = "@request.auth.id != ''";
  collection.deleteRule = "@request.auth.id != ''";

  addFieldIfMissing(
    collection,
    new RelationField({
      name: "message",
      collectionId: messages.id,
      maxSelect: 1,
      required: true,
    }),
  );
  addFieldIfMissing(
    collection,
    new RelationField({
      name: "user",
      collectionId: users.id,
      maxSelect: 1,
      required: true,
    }),
  );
  addFieldIfMissing(
    collection,
    new TextField({
      name: "emoji",
      required: true,
    }),
  );
  addFieldIfMissing(
    collection,
    new AutodateField({
      name: "created",
      onCreate: true,
      onUpdate: false,
    }),
  );
  addFieldIfMissing(
    collection,
    new AutodateField({
      name: "updated",
      onCreate: true,
      onUpdate: true,
    }),
  );

  app.save(collection);
}

function findCollection(app, name) {
  try {
    return app.findCollectionByNameOrId(name);
  } catch (_) {
    return null;
  }
}

function addFieldIfMissing(collection, field) {
  if (!collection.fields.getByName(field.name)) {
    collection.fields.add(field);
  }
}

function removeFieldIfExists(collection, fieldName) {
  if (collection.fields.getByName(fieldName)) {
    collection.fields.removeByName(fieldName);
  }
}
