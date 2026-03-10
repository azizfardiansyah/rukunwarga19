/// <reference path="../pb_data/types.d.ts" />

migrate((app) => {
  repairConversations(app);
  repairConversationMembers(app);
  repairMessages(app);
  repairMessageReads(app);
  repairAnnouncements(app);
}, (app) => {
  rollbackConversations(app);
  rollbackConversationMembers(app);
  rollbackMessages(app);
  rollbackMessageReads(app);
  rollbackAnnouncements(app);
});

function repairConversations(app) {
  const collection = findCollection(app, "conversations");
  const users = findCollection(app, "users");
  if (!collection || !users) {
    return;
  }

  addFieldIfMissing(
    collection,
    new TextField({
      name: "key",
      required: true,
    }),
  );
  addFieldIfMissing(
    collection,
    new SelectField({
      name: "type",
      maxSelect: 1,
      values: ["private", "group_rt", "group_rw"],
      required: true,
    }),
  );
  addFieldIfMissing(
    collection,
    new TextField({
      name: "name",
      required: true,
    }),
  );
  addFieldIfMissing(
    collection,
    new RelationField({
      name: "owner",
      collectionId: users.id,
      maxSelect: 1,
    }),
  );
  addFieldIfMissing(
    collection,
    new RelationField({
      name: "created_by",
      collectionId: users.id,
      maxSelect: 1,
    }),
  );
  addFieldIfMissing(
    collection,
    new NumberField({
      name: "rt",
      onlyInt: true,
      min: 0,
    }),
  );
  addFieldIfMissing(
    collection,
    new NumberField({
      name: "rw",
      onlyInt: true,
      min: 0,
    }),
  );
  addFieldIfMissing(collection, new TextField({ name: "desa_code" }));
  addFieldIfMissing(collection, new TextField({ name: "kecamatan_code" }));
  addFieldIfMissing(collection, new TextField({ name: "kabupaten_code" }));
  addFieldIfMissing(collection, new TextField({ name: "provinsi_code" }));
  addFieldIfMissing(collection, new TextField({ name: "desa_kelurahan" }));
  addFieldIfMissing(collection, new TextField({ name: "kecamatan" }));
  addFieldIfMissing(collection, new TextField({ name: "kabupaten_kota" }));
  addFieldIfMissing(collection, new TextField({ name: "provinsi" }));
  addFieldIfMissing(collection, new BoolField({ name: "is_readonly" }));
  addFieldIfMissing(collection, new TextField({ name: "last_message" }));
  addFieldIfMissing(collection, new DateField({ name: "last_message_at" }));
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

function repairConversationMembers(app) {
  const collection = findCollection(app, "conversation_members");
  const conversations = findCollection(app, "conversations");
  const users = findCollection(app, "users");
  if (!collection || !conversations || !users) {
    return;
  }

  addFieldIfMissing(
    collection,
    new RelationField({
      name: "conversation",
      collectionId: conversations.id,
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
    new SelectField({
      name: "member_role",
      maxSelect: 1,
      values: ["participant", "moderator"],
      required: true,
    }),
  );
  addFieldIfMissing(collection, new DateField({ name: "last_read_at" }));
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

function repairMessages(app) {
  const collection = findCollection(app, "messages");
  const conversations = findCollection(app, "conversations");
  const users = findCollection(app, "users");
  if (!collection || !conversations || !users) {
    return;
  }

  addFieldIfMissing(
    collection,
    new RelationField({
      name: "conversation",
      collectionId: conversations.id,
      maxSelect: 1,
      required: true,
    }),
  );
  addFieldIfMissing(
    collection,
    new RelationField({
      name: "sender",
      collectionId: users.id,
      maxSelect: 1,
      required: true,
    }),
  );
  addFieldIfMissing(collection, new TextField({ name: "text" }));
  addFieldIfMissing(
    collection,
    new FileField({
      name: "attachment",
      maxSelect: 1,
      maxSize: 10 * 1024 * 1024,
      mimeTypes: [],
      thumbs: [],
      protected: false,
    }),
  );
  addFieldIfMissing(
    collection,
    new SelectField({
      name: "message_type",
      maxSelect: 1,
      values: ["text", "file", "system"],
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

function repairMessageReads(app) {
  const collection = findCollection(app, "message_reads");
  const messages = findCollection(app, "messages");
  const users = findCollection(app, "users");
  if (!collection || !messages || !users) {
    return;
  }

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
  addFieldIfMissing(collection, new DateField({ name: "read_at" }));
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

function repairAnnouncements(app) {
  const collection = findCollection(app, "announcements");
  const users = findCollection(app, "users");
  if (!collection || !users) {
    return;
  }

  addFieldIfMissing(
    collection,
    new RelationField({
      name: "author",
      collectionId: users.id,
      maxSelect: 1,
      required: true,
    }),
  );
  addFieldIfMissing(
    collection,
    new TextField({
      name: "title",
      required: true,
    }),
  );
  addFieldIfMissing(
    collection,
    new TextField({
      name: "content",
      required: true,
    }),
  );
  addFieldIfMissing(
    collection,
    new SelectField({
      name: "target_type",
      maxSelect: 1,
      values: ["rt", "rw"],
      required: true,
    }),
  );
  addFieldIfMissing(
    collection,
    new NumberField({
      name: "rt",
      onlyInt: true,
      min: 0,
    }),
  );
  addFieldIfMissing(
    collection,
    new NumberField({
      name: "rw",
      onlyInt: true,
      min: 0,
    }),
  );
  addFieldIfMissing(collection, new TextField({ name: "desa_code" }));
  addFieldIfMissing(collection, new TextField({ name: "kecamatan_code" }));
  addFieldIfMissing(collection, new TextField({ name: "kabupaten_code" }));
  addFieldIfMissing(collection, new TextField({ name: "provinsi_code" }));
  addFieldIfMissing(collection, new TextField({ name: "desa_kelurahan" }));
  addFieldIfMissing(collection, new TextField({ name: "kecamatan" }));
  addFieldIfMissing(collection, new TextField({ name: "kabupaten_kota" }));
  addFieldIfMissing(collection, new TextField({ name: "provinsi" }));
  addFieldIfMissing(collection, new BoolField({ name: "is_published" }));
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

function rollbackConversations(app) {
  const collection = findCollection(app, "conversations");
  if (!collection) {
    return;
  }
  removeKnownFields(collection, [
    "key",
    "type",
    "name",
    "owner",
    "created_by",
    "rt",
    "rw",
    "desa_code",
    "kecamatan_code",
    "kabupaten_code",
    "provinsi_code",
    "desa_kelurahan",
    "kecamatan",
    "kabupaten_kota",
    "provinsi",
    "is_readonly",
    "last_message",
    "last_message_at",
    "created",
    "updated",
  ]);
  app.save(collection);
}

function rollbackConversationMembers(app) {
  const collection = findCollection(app, "conversation_members");
  if (!collection) {
    return;
  }
  removeKnownFields(collection, [
    "conversation",
    "user",
    "member_role",
    "last_read_at",
    "created",
    "updated",
  ]);
  app.save(collection);
}

function rollbackMessages(app) {
  const collection = findCollection(app, "messages");
  if (!collection) {
    return;
  }
  removeKnownFields(collection, [
    "conversation",
    "sender",
    "text",
    "attachment",
    "message_type",
    "created",
    "updated",
  ]);
  app.save(collection);
}

function rollbackMessageReads(app) {
  const collection = findCollection(app, "message_reads");
  if (!collection) {
    return;
  }
  removeKnownFields(collection, [
    "message",
    "user",
    "read_at",
    "created",
    "updated",
  ]);
  app.save(collection);
}

function rollbackAnnouncements(app) {
  const collection = findCollection(app, "announcements");
  if (!collection) {
    return;
  }
  removeKnownFields(collection, [
    "author",
    "title",
    "content",
    "target_type",
    "rt",
    "rw",
    "desa_code",
    "kecamatan_code",
    "kabupaten_code",
    "provinsi_code",
    "desa_kelurahan",
    "kecamatan",
    "kabupaten_kota",
    "provinsi",
    "is_published",
    "created",
    "updated",
  ]);
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
  if (collection.fields.getByName(field.name)) {
    return;
  }
  collection.fields.add(field);
}

function removeKnownFields(collection, names) {
  for (const name of names) {
    if (collection.fields.getByName(name)) {
      collection.fields.removeByName(name);
    }
  }
}
