/// <reference path="../pb_data/types.d.ts" />

migrate((app) => {
  const collection = new Collection({
    type: "base",
    name: "role_requests",
    listRule: null,
    viewRule: null,
    createRule: null,
    updateRule: null,
    deleteRule: null,
    fields: [
      new RelationField({
        name: "requester",
        collectionId: "_pb_users_auth_",
        maxSelect: 1,
        required: true,
      }),
      new SelectField({
        name: "requested_role",
        maxSelect: 1,
        values: ["admin_rt", "admin_rw", "admin_rw_pro"],
        required: true,
      }),
      new TextField({
        name: "current_role",
        required: true,
      }),
      new TextField({
        name: "reason",
        required: true,
      }),
      new SelectField({
        name: "status",
        maxSelect: 1,
        values: ["pending", "approved", "rejected"],
        required: true,
      }),
      new RelationField({
        name: "reviewer",
        collectionId: "_pb_users_auth_",
        maxSelect: 1,
      }),
      new TextField({
        name: "review_note",
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

  return app.save(collection);
}, (app) => {
  const collection = app.findCollectionByNameOrId("role_requests");

  return app.delete(collection);
});
