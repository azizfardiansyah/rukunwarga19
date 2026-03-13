/// <reference path="../pb_data/types.d.ts" />

migrate((app) => {
  const conversations = findCollection(app, "conversations");
  if (!conversations) {
    return;
  }

  if (!conversations.fields.getByName("avatar")) {
    conversations.fields.add(
      new FileField({
        name: "avatar",
        maxSelect: 1,
        maxSize: 5 * 1024 * 1024,
        mimeTypes: ["image/jpeg", "image/png", "image/webp"],
        thumbs: [],
        protected: false,
      }),
    );
    app.save(conversations);
  }
}, (app) => {
  // Non-destructive rollback. Existing avatar files can remain.
});

function findCollection(app, name) {
  try {
    return app.findCollectionByNameOrId(name);
  } catch (_) {
    return null;
  }
}
