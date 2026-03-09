/// <reference path="../pb_data/types.d.ts" />

migrate((app) => {
  const collection = new Collection({
    type: "base",
    name: "subscription_transactions",
    listRule: null,
    viewRule: null,
    createRule: null,
    updateRule: null,
    deleteRule: null,
    fields: [
      new RelationField({
        name: "subscriber",
        collectionId: "_pb_users_auth_",
        maxSelect: 1,
        required: true,
      }),
      new TextField({
        name: "subscriber_name",
      }),
      new TextField({
        name: "subscriber_email",
      }),
      new TextField({
        name: "plan_code",
        required: true,
      }),
      new TextField({
        name: "plan_name",
        required: true,
      }),
      new NumberField({
        name: "period_days",
        onlyInt: true,
      }),
      new NumberField({
        name: "gross_amount",
        onlyInt: true,
        required: true,
      }),
      new TextField({
        name: "currency",
      }),
      new TextField({
        name: "order_id",
        required: true,
      }),
      new TextField({
        name: "snap_token",
      }),
      new TextField({
        name: "redirect_url",
      }),
      new TextField({
        name: "payment_state",
      }),
      new TextField({
        name: "transaction_status",
      }),
      new TextField({
        name: "transaction_id",
      }),
      new TextField({
        name: "payment_type",
      }),
      new TextField({
        name: "status_code",
      }),
      new TextField({
        name: "status_message",
      }),
      new BoolField({
        name: "subscription_applied",
      }),
      new TextField({
        name: "subscription_started",
      }),
      new TextField({
        name: "subscription_expired",
      }),
      new TextField({
        name: "raw_midtrans_response",
      }),
      new TextField({
        name: "raw_notification",
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
  const collection = app.findCollectionByNameOrId("subscription_transactions");

  return app.delete(collection);
});
