/// <reference path="../pb_data/types.d.ts" />
migrate(
  (app) => {
    const collection = findCollection(app, "finance_transactions");
    if (!collection) {
      return;
    }

    addFieldIfMissing(collection, new TextField({ name: "source_reference" }));
    app.save(collection);
  },
  (app) => {
    const collection = findCollection(app, "finance_transactions");
    if (!collection) {
      return;
    }

    removeFieldIfPresent(collection, "source_reference");
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
