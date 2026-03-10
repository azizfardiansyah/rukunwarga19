/// <reference path="../pb_data/types.d.ts" />

migrate((app) => {
  const users = findCollection(app, "users");
  const conversations = findCollection(app, "conversations");
  const messages = findCollection(app, "messages");

  if (!users || !conversations || !messages) {
    return;
  }

  fixRelationField(
    app,
    conversations,
    "owner",
    new RelationField({
      name: "owner",
      collectionId: users.id,
      maxSelect: 1,
    }),
  );
  fixRelationField(
    app,
    conversations,
    "created_by",
    new RelationField({
      name: "created_by",
      collectionId: users.id,
      maxSelect: 1,
    }),
  );

  const conversationMembers = findCollection(app, "conversation_members");
  if (conversationMembers) {
    fixRelationField(
      app,
      conversationMembers,
      "user",
      new RelationField({
        name: "user",
        collectionId: users.id,
        maxSelect: 1,
        required: true,
      }),
    );
  }

  fixRelationField(
    app,
    messages,
    "sender",
    new RelationField({
      name: "sender",
      collectionId: users.id,
      maxSelect: 1,
      required: true,
    }),
  );

  const messageReads = findCollection(app, "message_reads");
  if (messageReads) {
    fixRelationField(
      app,
      messageReads,
      "user",
      new RelationField({
        name: "user",
        collectionId: users.id,
        maxSelect: 1,
        required: true,
      }),
    );
  }

  const announcements = findCollection(app, "announcements");
  if (announcements) {
    fixRelationField(
      app,
      announcements,
      "author",
      new RelationField({
        name: "author",
        collectionId: users.id,
        maxSelect: 1,
        required: true,
      }),
    );
  }
}, (app) => {
  const legacyAuth = "_pb_users_auth_";
  const conversations = findCollection(app, "conversations");
  const messages = findCollection(app, "messages");

  if (conversations) {
    fixRelationField(
      app,
      conversations,
      "owner",
      new RelationField({
        name: "owner",
        collectionId: legacyAuth,
        maxSelect: 1,
      }),
    );
    fixRelationField(
      app,
      conversations,
      "created_by",
      new RelationField({
        name: "created_by",
        collectionId: legacyAuth,
        maxSelect: 1,
      }),
    );
  }

  const conversationMembers = findCollection(app, "conversation_members");
  if (conversationMembers) {
    fixRelationField(
      app,
      conversationMembers,
      "user",
      new RelationField({
        name: "user",
        collectionId: legacyAuth,
        maxSelect: 1,
        required: true,
      }),
    );
  }

  if (messages) {
    fixRelationField(
      app,
      messages,
      "sender",
      new RelationField({
        name: "sender",
        collectionId: legacyAuth,
        maxSelect: 1,
        required: true,
      }),
    );
  }

  const messageReads = findCollection(app, "message_reads");
  if (messageReads) {
    fixRelationField(
      app,
      messageReads,
      "user",
      new RelationField({
        name: "user",
        collectionId: legacyAuth,
        maxSelect: 1,
        required: true,
      }),
    );
  }

  const announcements = findCollection(app, "announcements");
  if (announcements) {
    fixRelationField(
      app,
      announcements,
      "author",
      new RelationField({
        name: "author",
        collectionId: legacyAuth,
        maxSelect: 1,
        required: true,
      }),
    );
  }
});

function fixRelationField(app, collection, fieldName, nextField) {
  const field = collection.fields.getByName(fieldName);
  if (!field) {
    collection.fields.add(nextField);
    app.save(collection);
    return;
  }

  if (field.collectionId === nextField.collectionId) {
    return;
  }

  collection.fields.removeByName(fieldName);
  collection.fields.add(nextField);
  app.save(collection);
}

function findCollection(app, name) {
  try {
    return app.findCollectionByNameOrId(name);
  } catch (_) {
    return null;
  }
}
