/// <reference path="../pb_data/types.d.ts" />

migrate(
  (app) => {
    ensureAnnouncementsCollection(app);
    ensureAnnouncementViewsCollection(app);
  },
  (app) => {
    const views = findCollection(app, "announcement_views");
    if (views) {
      app.delete(views);
    }

    const announcements = findCollection(app, "announcements");
    if (!announcements) {
      return;
    }

    removeFieldIfExists(announcements, "published_at");
    removeFieldIfExists(announcements, "view_count");
    const targetType = announcements.fields.getByName("target_type");
    if (targetType) {
      targetType.values = ["rt", "rw"];
    }
    app.save(announcements);
  },
);

function ensureAnnouncementsCollection(app) {
  const collection = findCollection(app, "announcements");
  const users = findCollection(app, "users");
  if (!collection || !users) {
    return;
  }

  collection.listRule = "@request.auth.id != ''";
  collection.viewRule = "@request.auth.id != ''";
  collection.createRule = "@request.auth.id != ''";
  collection.updateRule =
    "author = @request.auth.id || @request.auth.role = 'admin_rw' || @request.auth.role = 'superuser' || @request.auth.system_role = 'operator'";
  collection.deleteRule =
    "author = @request.auth.id || @request.auth.role = 'superuser'";

  ensureField(
    collection,
    "author",
    () =>
      new RelationField({
        name: "author",
        collectionId: users.id,
        maxSelect: 1,
        required: true,
      }),
    (field) => {
      field.collectionId = users.id;
      field.maxSelect = 1;
      field.required = true;
    },
  );
  ensureField(
    collection,
    "title",
    () =>
      new TextField({
        name: "title",
        required: true,
        min: 5,
        max: 100,
      }),
    (field) => {
      field.required = true;
      field.min = 5;
      field.max = 100;
    },
  );
  ensureField(
    collection,
    "content",
    () =>
      new TextField({
        name: "content",
        required: true,
        min: 10,
        max: 1000,
      }),
    (field) => {
      field.required = true;
      field.min = 10;
      field.max = 1000;
    },
  );
  ensureField(
    collection,
    "target_type",
    () =>
      new SelectField({
        name: "target_type",
        maxSelect: 1,
        values: ["rt", "rw", "all"],
        required: true,
      }),
    (field) => {
      field.maxSelect = 1;
      field.values = ["rt", "rw", "all"];
      field.required = true;
    },
  );
  ensureField(
    collection,
    "rt",
    () =>
      new NumberField({
        name: "rt",
        onlyInt: true,
        min: 0,
      }),
    (field) => {
      field.onlyInt = true;
      field.min = 0;
    },
  );
  ensureField(
    collection,
    "rw",
    () =>
      new NumberField({
        name: "rw",
        onlyInt: true,
        min: 0,
        required: true,
      }),
    (field) => {
      field.onlyInt = true;
      field.min = 0;
      field.required = true;
    },
  );
  ensureField(
    collection,
    "attachment",
    () =>
      new FileField({
        name: "attachment",
        maxSelect: 1,
        maxSize: 5 * 1024 * 1024,
        mimeTypes: ["image/jpeg", "image/png", "application/pdf"],
        thumbs: [],
        protected: false,
      }),
    (field) => {
      field.maxSelect = 1;
      field.maxSize = 5 * 1024 * 1024;
      field.mimeTypes = ["image/jpeg", "image/png", "application/pdf"];
      field.protected = false;
    },
  );
  addFieldIfMissing(collection, new DateField({ name: "published_at" }));
  addFieldIfMissing(
    collection,
    new NumberField({
      name: "view_count",
      onlyInt: true,
      min: 0,
    }),
  );

  collection.indexes = [
    "CREATE INDEX IF NOT EXISTS idx_announcements_author ON announcements (author)",
    "CREATE INDEX IF NOT EXISTS idx_announcements_created ON announcements (created)",
    "CREATE INDEX IF NOT EXISTS idx_announcements_scope ON announcements (rw, rt, is_published)",
  ];

  app.save(collection);
}

function ensureAnnouncementViewsCollection(app) {
  const announcements = findCollection(app, "announcements");
  const users = findCollection(app, "users");
  if (!announcements || !users) {
    return;
  }

  let collection = findCollection(app, "announcement_views");
  if (!collection) {
    collection = new Collection({
      type: "base",
      name: "announcement_views",
      fields: [],
    });
  }

  collection.listRule =
    "user = @request.auth.id || announcement.author = @request.auth.id || @request.auth.system_role = 'operator' || @request.auth.role = 'admin_rw' || @request.auth.role = 'superuser'";
  collection.viewRule = collection.listRule;
  collection.createRule = "user = @request.auth.id";
  collection.updateRule = "user = @request.auth.id";
  collection.deleteRule =
    "user = @request.auth.id || announcement.author = @request.auth.id || @request.auth.role = 'superuser'";

  addFieldIfMissing(
    collection,
    new RelationField({
      name: "announcement",
      collectionId: announcements.id,
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
  addFieldIfMissing(collection, new DateField({ name: "viewed_at" }));
  addFieldIfMissing(collection, new TextField({ name: "ip_address" }));
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

  collection.indexes = [
    "CREATE UNIQUE INDEX IF NOT EXISTS idx_announcement_views_unique ON announcement_views (announcement, user)",
    "CREATE INDEX IF NOT EXISTS idx_announcement_views_announcement ON announcement_views (announcement)",
    "CREATE INDEX IF NOT EXISTS idx_announcement_views_user ON announcement_views (user)",
  ];

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

function ensureField(collection, name, createField, updateField) {
  const field = collection.fields.getByName(name);
  if (!field) {
    collection.fields.add(createField());
    return;
  }
  updateField(field);
}

function removeFieldIfExists(collection, fieldName) {
  if (collection.fields.getByName(fieldName)) {
    collection.fields.removeByName(fieldName);
  }
}
