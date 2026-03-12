/// <reference path="../pb_data/types.d.ts" />

migrate((app) => {
  ensureMessageEditingFields(app);
  ensureMessageReadDeliveryFields(app);
  ensureConversationPresenceFields(app);
  ensureMessageReactionsCollection(app);
}, (app) => {
  removeMessageEditingFields(app);
  removeMessageReadDeliveryFields(app);
  removeConversationPresenceFields(app);
  deleteCollectionIfExists(app, "message_reactions");
});

function ensureMessageEditingFields(app) {
  const collection = findCollection(app, "messages");
  const users = findCollection(app, "users");
  if (!collection || !users) {
    return;
  }

  addFieldIfMissing(collection, new DateField({ name: "edited_at" }));
  addFieldIfMissing(
    collection,
    new RelationField({
      name: "edited_by",
      collectionId: users.id,
      maxSelect: 1,
    }),
  );

  app.save(collection);
}

function removeMessageEditingFields(app) {
  const collection = findCollection(app, "messages");
  if (!collection) {
    return;
  }

  removeFieldIfExists(collection, "edited_at");
  removeFieldIfExists(collection, "edited_by");
  app.save(collection);
}

function ensureMessageReadDeliveryFields(app) {
  const collection = findCollection(app, "message_reads");
  if (!collection) {
    return;
  }

  addFieldIfMissing(collection, new DateField({ name: "delivered_at" }));
  app.save(collection);
}

function removeMessageReadDeliveryFields(app) {
  const collection = findCollection(app, "message_reads");
  if (!collection) {
    return;
  }

  removeFieldIfExists(collection, "delivered_at");
  app.save(collection);
}

function ensureConversationPresenceFields(app) {
  const collection = findCollection(app, "conversation_members");
  if (!collection) {
    return;
  }

  addFieldIfMissing(collection, new DateField({ name: "last_seen_at" }));
  addFieldIfMissing(collection, new DateField({ name: "typing_at" }));
  app.save(collection);
}

function removeConversationPresenceFields(app) {
  const collection = findCollection(app, "conversation_members");
  if (!collection) {
    return;
  }

  removeFieldIfExists(collection, "last_seen_at");
  removeFieldIfExists(collection, "typing_at");
  app.save(collection);
}

function ensureMessageReactionsCollection(app) {
  if (findCollection(app, "message_reactions")) {
    return;
  }

  const messages = findCollection(app, "messages");
  const users = findCollection(app, "users");
  if (!messages || !users) {
    return;
  }

  const collection = new Collection({
    type: "base",
    name: "message_reactions",
    listRule: "@request.auth.id != ''",
    viewRule: "@request.auth.id != ''",
    createRule: "@request.auth.id != ''",
    updateRule: "@request.auth.id != ''",
    deleteRule: "@request.auth.id != ''",
    fields: [
      new RelationField({
        name: "message",
        collectionId: messages.id,
        maxSelect: 1,
        required: true,
      }),
      new RelationField({
        name: "user",
        collectionId: users.id,
        maxSelect: 1,
        required: true,
      }),
      new TextField({ name: "emoji", required: true }),
      new AutodateField({
        name: "created",
        onCreate: true,
        onUpdate: false,
      }),
      new AutodateField({
        name: "updated",
        onCreate: true,
        onUpdate: true,
      }),
    ],
  });

  app.save(collection);
}

function deleteCollectionIfExists(app, name) {
  const collection = findCollection(app, name);
  if (collection) {
    app.delete(collection);
  }
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
