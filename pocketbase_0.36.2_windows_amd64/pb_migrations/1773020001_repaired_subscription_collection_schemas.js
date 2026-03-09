/// <reference path="../pb_data/types.d.ts" />

migrate((app) => {
  repairRoleRequests(app);
  repairSubscriptionPlans(app);
  repairSubscriptionTransactions(app);
}, (app) => {
  rollbackRoleRequests(app);
  rollbackSubscriptionPlans(app);
  rollbackSubscriptionTransactions(app);
});

function repairRoleRequests(app) {
  const collection = app.findCollectionByNameOrId("role_requests");

  addFieldIfMissing(
    collection,
    new RelationField({
      name: "requester",
      collectionId: "_pb_users_auth_",
      maxSelect: 1,
      required: true,
    }),
  );
  addFieldIfMissing(
    collection,
    new SelectField({
      name: "requested_role",
      maxSelect: 1,
      values: ["admin_rt", "admin_rw", "admin_rw_pro"],
      required: true,
    }),
  );
  addFieldIfMissing(
    collection,
    new TextField({
      name: "current_role",
      required: true,
    }),
  );
  addFieldIfMissing(
    collection,
    new TextField({
      name: "reason",
      required: true,
    }),
  );
  addFieldIfMissing(
    collection,
    new SelectField({
      name: "status",
      maxSelect: 1,
      values: ["pending", "approved", "rejected"],
      required: true,
    }),
  );
  addFieldIfMissing(
    collection,
    new RelationField({
      name: "reviewer",
      collectionId: "_pb_users_auth_",
      maxSelect: 1,
    }),
  );
  addFieldIfMissing(
    collection,
    new TextField({
      name: "review_note",
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

function repairSubscriptionPlans(app) {
  const collection = app.findCollectionByNameOrId("subscription_plans");

  addFieldIfMissing(
    collection,
    new TextField({
      name: "code",
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
    new TextField({
      name: "description",
    }),
  );
  addFieldIfMissing(
    collection,
    new SelectField({
      name: "target_role",
      maxSelect: 1,
      values: ["admin_rt", "admin_rw", "admin_rw_pro"],
      required: true,
    }),
  );
  addFieldIfMissing(
    collection,
    new NumberField({
      name: "amount",
      onlyInt: true,
      required: true,
      min: 0,
    }),
  );
  addFieldIfMissing(
    collection,
    new NumberField({
      name: "duration_days",
      onlyInt: true,
      required: true,
      min: 1,
    }),
  );
  addFieldIfMissing(
    collection,
    new SelectField({
      name: "currency",
      maxSelect: 1,
      values: ["IDR"],
      required: true,
    }),
  );
  addFieldIfMissing(
    collection,
    new BoolField({
      name: "is_active",
    }),
  );
  addFieldIfMissing(
    collection,
    new NumberField({
      name: "sort_order",
      onlyInt: true,
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
  reseedSubscriptionPlans(app, collection);
}

function repairSubscriptionTransactions(app) {
  const collection = app.findCollectionByNameOrId("subscription_transactions");

  addFieldIfMissing(
    collection,
    new RelationField({
      name: "subscriber",
      collectionId: "_pb_users_auth_",
      maxSelect: 1,
      required: true,
    }),
  );
  addFieldIfMissing(
    collection,
    new TextField({
      name: "subscriber_name",
    }),
  );
  addFieldIfMissing(
    collection,
    new TextField({
      name: "subscriber_email",
    }),
  );
  addFieldIfMissing(
    collection,
    new TextField({
      name: "plan_code",
      required: true,
    }),
  );
  addFieldIfMissing(
    collection,
    new TextField({
      name: "plan_name",
      required: true,
    }),
  );
  addFieldIfMissing(
    collection,
    new NumberField({
      name: "period_days",
      onlyInt: true,
    }),
  );
  addFieldIfMissing(
    collection,
    new NumberField({
      name: "gross_amount",
      onlyInt: true,
      required: true,
    }),
  );
  addFieldIfMissing(
    collection,
    new SelectField({
      name: "currency",
      maxSelect: 1,
      values: ["IDR"],
      required: false,
    }),
  );
  addFieldIfMissing(
    collection,
    new TextField({
      name: "order_id",
      required: true,
    }),
  );
  addFieldIfMissing(
    collection,
    new TextField({
      name: "snap_token",
    }),
  );
  addFieldIfMissing(
    collection,
    new URLField({
      name: "redirect_url",
    }),
  );
  addFieldIfMissing(
    collection,
    new TextField({
      name: "payment_state",
    }),
  );
  addFieldIfMissing(
    collection,
    new TextField({
      name: "transaction_status",
    }),
  );
  addFieldIfMissing(
    collection,
    new TextField({
      name: "transaction_id",
    }),
  );
  addFieldIfMissing(
    collection,
    new TextField({
      name: "payment_type",
    }),
  );
  addFieldIfMissing(
    collection,
    new TextField({
      name: "status_code",
    }),
  );
  addFieldIfMissing(
    collection,
    new TextField({
      name: "status_message",
    }),
  );
  addFieldIfMissing(
    collection,
    new BoolField({
      name: "subscription_applied",
    }),
  );
  addFieldIfMissing(
    collection,
    new DateField({
      name: "subscription_started",
    }),
  );
  addFieldIfMissing(
    collection,
    new DateField({
      name: "subscription_expired",
    }),
  );
  addFieldIfMissing(
    collection,
    new TextField({
      name: "raw_midtrans_response",
    }),
  );
  addFieldIfMissing(
    collection,
    new TextField({
      name: "raw_notification",
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

function rollbackRoleRequests(app) {
  const collection = app.findCollectionByNameOrId("role_requests");
  removeKnownFields(collection, [
    "requester",
    "requested_role",
    "current_role",
    "reason",
    "status",
    "reviewer",
    "review_note",
    "created",
    "updated",
  ]);
  app.save(collection);
}

function rollbackSubscriptionPlans(app) {
  const collection = app.findCollectionByNameOrId("subscription_plans");
  clearCollectionRecords(app, collection);
  removeKnownFields(collection, [
    "code",
    "name",
    "description",
    "target_role",
    "amount",
    "duration_days",
    "currency",
    "is_active",
    "sort_order",
    "created",
    "updated",
  ]);
  app.save(collection);
}

function rollbackSubscriptionTransactions(app) {
  const collection = app.findCollectionByNameOrId("subscription_transactions");
  removeKnownFields(collection, [
    "subscriber",
    "subscriber_name",
    "subscriber_email",
    "plan_code",
    "plan_name",
    "period_days",
    "gross_amount",
    "currency",
    "order_id",
    "snap_token",
    "redirect_url",
    "payment_state",
    "transaction_status",
    "transaction_id",
    "payment_type",
    "status_code",
    "status_message",
    "subscription_applied",
    "subscription_started",
    "subscription_expired",
    "raw_midtrans_response",
    "raw_notification",
    "created",
    "updated",
  ]);
  app.save(collection);
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

function clearCollectionRecords(app, collection) {
  const records = app.findRecordsByFilter(collection.name, "", "", 500, 0);
  for (const record of records) {
    if (record) {
      app.delete(record);
    }
  }
}

function reseedSubscriptionPlans(app, collection) {
  clearCollectionRecords(app, collection);

  const plans = [
    {
      code: "admin_rt_monthly",
      name: "Admin RT Bulanan",
      description: "Langganan dashboard dan operasional Admin RT selama 30 hari.",
      target_role: "admin_rt",
      amount: 30000,
      duration_days: 30,
      currency: "IDR",
      is_active: true,
      sort_order: 10,
    },
    {
      code: "admin_rw_monthly",
      name: "Admin RW Bulanan",
      description: "Langganan dashboard RW dan akses lintas wilayah selama 30 hari.",
      target_role: "admin_rw",
      amount: 100000,
      duration_days: 30,
      currency: "IDR",
      is_active: true,
      sort_order: 20,
    },
    {
      code: "admin_rw_pro_monthly",
      name: "Admin RW Pro Bulanan",
      description: "Langganan Admin RW Pro dengan OCR dan integrasi pembayaran selama 30 hari.",
      target_role: "admin_rw_pro",
      amount: 250000,
      duration_days: 30,
      currency: "IDR",
      is_active: true,
      sort_order: 30,
    },
  ];

  for (const plan of plans) {
    app.save(new Record(collection, plan));
  }
}
