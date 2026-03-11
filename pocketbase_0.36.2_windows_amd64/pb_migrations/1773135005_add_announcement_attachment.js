/// <reference path="../pb_data/types.d.ts" />
migrate(
  (app) => {
    const collection = findCollection(app, "announcements");
    if (!collection) {
      return;
    }

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

    app.save(collection);
  },
  (app) => {
    const collection = findCollection(app, "announcements");
    if (!collection) {
      return;
    }

    removeFieldIfPresent(collection, "attachment");
    app.save(collection);
  },
);

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

function removeFieldIfPresent(collection, name) {
  if (!collection.fields.getByName(name)) {
    return;
  }
  collection.fields.removeByName(name);
}
