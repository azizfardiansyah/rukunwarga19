/// <reference path="../pb_data/types.d.ts" />

migrate((app) => {
  ensureConversationsCollection(app);
  ensureConversationMembersCollection(app);
  ensureMessagesCollection(app);
  ensureMessageReadsCollection(app);
  ensureAnnouncementsCollection(app);
}, (app) => {
  deleteIfExists(app, "message_reads");
  deleteIfExists(app, "messages");
  deleteIfExists(app, "conversation_members");
  deleteIfExists(app, "conversations");
  deleteIfExists(app, "announcements");
});

function ensureConversationsCollection(app) {
  if (findCollection(app, "conversations")) {
    return;
  }

  const users = findCollection(app, "users");
  if (!users) {
    return;
  }

  const collection = new Collection({
    type: "base",
    name: "conversations",
    listRule: null,
    viewRule: null,
    createRule: null,
    updateRule: null,
    deleteRule: null,
    fields: [
      new TextField({ name: "key", required: true }),
      new SelectField({
        name: "type",
        maxSelect: 1,
        values: ["private", "group_rt", "group_rw"],
        required: true,
      }),
      new TextField({ name: "name", required: true }),
      new RelationField({
        name: "owner",
        collectionId: users.id,
        maxSelect: 1,
      }),
      new RelationField({
        name: "created_by",
        collectionId: users.id,
        maxSelect: 1,
      }),
      new NumberField({ name: "rt", onlyInt: true, min: 0 }),
      new NumberField({ name: "rw", onlyInt: true, min: 0 }),
      new TextField({ name: "desa_code" }),
      new TextField({ name: "kecamatan_code" }),
      new TextField({ name: "kabupaten_code" }),
      new TextField({ name: "provinsi_code" }),
      new TextField({ name: "desa_kelurahan" }),
      new TextField({ name: "kecamatan" }),
      new TextField({ name: "kabupaten_kota" }),
      new TextField({ name: "provinsi" }),
      new BoolField({ name: "is_readonly" }),
      new TextField({ name: "last_message" }),
      new DateField({ name: "last_message_at" }),
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

function ensureConversationMembersCollection(app) {
  if (findCollection(app, "conversation_members")) {
    return;
  }

  const conversations = findCollection(app, "conversations");
  const users = findCollection(app, "users");
  if (!conversations || !users) {
    return;
  }

  const collection = new Collection({
    type: "base",
    name: "conversation_members",
    listRule: null,
    viewRule: null,
    createRule: null,
    updateRule: null,
    deleteRule: null,
    fields: [
      new RelationField({
        name: "conversation",
        collectionId: conversations.id,
        maxSelect: 1,
        required: true,
      }),
      new RelationField({
        name: "user",
        collectionId: users.id,
        maxSelect: 1,
        required: true,
      }),
      new SelectField({
        name: "member_role",
        maxSelect: 1,
        values: ["participant", "moderator"],
        required: true,
      }),
      new DateField({ name: "last_read_at" }),
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

function ensureMessagesCollection(app) {
  if (findCollection(app, "messages")) {
    return;
  }

  const conversations = findCollection(app, "conversations");
  const users = findCollection(app, "users");
  if (!conversations || !users) {
    return;
  }

  const collection = new Collection({
    type: "base",
    name: "messages",
    listRule: null,
    viewRule: null,
    createRule: null,
    updateRule: null,
    deleteRule: null,
    fields: [
      new RelationField({
        name: "conversation",
        collectionId: conversations.id,
        maxSelect: 1,
        required: true,
      }),
      new RelationField({
        name: "sender",
        collectionId: users.id,
        maxSelect: 1,
        required: true,
      }),
      new TextField({ name: "text" }),
      new FileField({
        name: "attachment",
        maxSelect: 1,
        maxSize: 10 * 1024 * 1024,
        mimeTypes: [],
        thumbs: [],
        protected: false,
      }),
      new SelectField({
        name: "message_type",
        maxSelect: 1,
        values: ["text", "file", "system"],
        required: true,
      }),
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

function ensureMessageReadsCollection(app) {
  if (findCollection(app, "message_reads")) {
    return;
  }

  const messages = findCollection(app, "messages");
  const users = findCollection(app, "users");
  if (!messages || !users) {
    return;
  }

  const collection = new Collection({
    type: "base",
    name: "message_reads",
    listRule: null,
    viewRule: null,
    createRule: null,
    updateRule: null,
    deleteRule: null,
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
      new DateField({ name: "read_at" }),
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

function ensureAnnouncementsCollection(app) {
  if (findCollection(app, "announcements")) {
    return;
  }

  const users = findCollection(app, "users");
  if (!users) {
    return;
  }

  const collection = new Collection({
    type: "base",
    name: "announcements",
    listRule: null,
    viewRule: null,
    createRule: null,
    updateRule: null,
    deleteRule: null,
    fields: [
      new RelationField({
        name: "author",
        collectionId: users.id,
        maxSelect: 1,
        required: true,
      }),
      new TextField({ name: "title", required: true }),
      new TextField({ name: "content", required: true }),
      new SelectField({
        name: "target_type",
        maxSelect: 1,
        values: ["rt", "rw"],
        required: true,
      }),
      new NumberField({ name: "rt", onlyInt: true, min: 0 }),
      new NumberField({ name: "rw", onlyInt: true, min: 0 }),
      new TextField({ name: "desa_code" }),
      new TextField({ name: "kecamatan_code" }),
      new TextField({ name: "kabupaten_code" }),
      new TextField({ name: "provinsi_code" }),
      new TextField({ name: "desa_kelurahan" }),
      new TextField({ name: "kecamatan" }),
      new TextField({ name: "kabupaten_kota" }),
      new TextField({ name: "provinsi" }),
      new BoolField({ name: "is_published" }),
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

function findCollection(app, name) {
  try {
    return app.findCollectionByNameOrId(name);
  } catch (_) {
    return null;
  }
}

function deleteIfExists(app, name) {
  const collection = findCollection(app, name);
  if (collection) {
    app.delete(collection);
  }
}
