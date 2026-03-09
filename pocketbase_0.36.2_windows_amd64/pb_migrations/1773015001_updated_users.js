/// <reference path="../pb_data/types.d.ts" />

migrate((app) => {
  const collection = app.findCollectionByNameOrId("_pb_users_auth_");

  collection.fields.add(
    new TextField({
      name: "subscription_plan",
      required: false,
    }),
    new TextField({
      name: "subscription_status",
      required: false,
    }),
    new TextField({
      name: "subscription_started",
      required: false,
    }),
    new TextField({
      name: "subscription_expired",
      required: false,
    }),
  );

  return app.save(collection);
}, (app) => {
  const collection = app.findCollectionByNameOrId("_pb_users_auth_");

  collection.fields.removeByName("subscription_plan");
  collection.fields.removeByName("subscription_status");
  collection.fields.removeByName("subscription_started");
  collection.fields.removeByName("subscription_expired");

  return app.save(collection);
});
