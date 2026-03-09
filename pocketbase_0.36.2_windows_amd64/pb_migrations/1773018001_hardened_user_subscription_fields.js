/// <reference path="../pb_data/types.d.ts" />

migrate((app) => {
  const collection = app.findCollectionByNameOrId("_pb_users_auth_");
  const snapshots = snapshotUsers(app);

  collection.fields.removeByName("role");
  collection.fields.removeByName("subscription_plan");
  collection.fields.removeByName("subscription_status");
  collection.fields.removeByName("subscription_started");
  collection.fields.removeByName("subscription_expired");

  collection.fields.addAt(
    8,
    new SelectField({
      name: "role",
      maxSelect: 1,
      values: ["user", "admin_rt", "admin_rw", "admin_rw_pro", "sysadmin"],
      required: false,
    }),
  );

  collection.fields.addAt(
    11,
    new SelectField({
      name: "subscription_plan",
      maxSelect: 1,
      values: ["admin_rt_monthly", "admin_rw_monthly", "admin_rw_pro_monthly"],
      required: false,
    }),
  );

  collection.fields.addAt(
    12,
    new SelectField({
      name: "subscription_status",
      maxSelect: 1,
      values: ["inactive", "active", "expired"],
      required: false,
    }),
  );

  collection.fields.addAt(
    13,
    new DateField({
      name: "subscription_started",
      required: false,
    }),
  );

  collection.fields.addAt(
    14,
    new DateField({
      name: "subscription_expired",
      required: false,
    }),
  );

  app.save(collection);
  restoreUsers(app, snapshots);

  return app.save(collection);
}, (app) => {
  const collection = app.findCollectionByNameOrId("_pb_users_auth_");
  const snapshots = snapshotUsers(app);

  collection.fields.removeByName("role");
  collection.fields.removeByName("subscription_plan");
  collection.fields.removeByName("subscription_status");
  collection.fields.removeByName("subscription_started");
  collection.fields.removeByName("subscription_expired");

  collection.fields.addAt(
    8,
    new TextField({
      name: "role",
      required: false,
    }),
  );

  collection.fields.addAt(
    11,
    new TextField({
      name: "subscription_plan",
      required: false,
    }),
  );

  collection.fields.addAt(
    12,
    new TextField({
      name: "subscription_status",
      required: false,
    }),
  );

  collection.fields.addAt(
    13,
    new TextField({
      name: "subscription_started",
      required: false,
    }),
  );

  collection.fields.addAt(
    14,
    new TextField({
      name: "subscription_expired",
      required: false,
    }),
  );

  app.save(collection);
  restoreUsers(app, snapshots);

  return app.save(collection);
});

function snapshotUsers(app) {
  const users = app.findRecordsByFilter("_pb_users_auth_", "", "created", 2000, 0);
  const snapshots = [];

  for (const user of users) {
    if (!user) {
      continue;
    }

    const role = normalizeRole(user.getString("role"));
    const requiresSubscription = role === "admin_rt" || role === "admin_rw" || role === "admin_rw_pro";

    let plan = normalizeSubscriptionPlan(user.getString("subscription_plan"));
    let status = normalizeSubscriptionStatus(user.getString("subscription_status"));
    let startedAt = normalizeNullableDate(user.getString("subscription_started"));
    let expiredAt = normalizeNullableDate(user.getString("subscription_expired"));

    if (!requiresSubscription) {
      plan = "";
      status = "inactive";
      startedAt = null;
      expiredAt = null;
    } else if (!plan) {
      plan = defaultPlanForRole(role);
    }

    snapshots.push({
      id: user.id,
      role: role,
      subscriptionPlan: plan,
      subscriptionStatus: status,
      subscriptionStarted: startedAt,
      subscriptionExpired: expiredAt,
    });
  }

  return snapshots;
}

function restoreUsers(app, snapshots) {
  for (const snapshot of snapshots) {
    const user = app.findRecordById("_pb_users_auth_", snapshot.id);

    user.set("role", snapshot.role);
    user.set("subscription_plan", snapshot.subscriptionPlan);
    user.set("subscription_status", snapshot.subscriptionStatus);
    user.set("subscription_started", snapshot.subscriptionStarted);
    user.set("subscription_expired", snapshot.subscriptionExpired);

    app.save(user);
  }
}

function normalizeRole(role) {
  const normalized = String(role || "").trim().toLowerCase();

  switch (normalized) {
    case "admin":
      return "admin_rw";
    case "superuser":
      return "sysadmin";
    case "admin_rt":
    case "admin_rw":
    case "admin_rw_pro":
    case "sysadmin":
    case "user":
      return normalized;
    default:
      return "user";
  }
}

function normalizeSubscriptionPlan(plan) {
  const normalized = String(plan || "").trim().toLowerCase();

  switch (normalized) {
    case "admin_rt_monthly":
    case "admin_rw_monthly":
    case "admin_rw_pro_monthly":
      return normalized;
    default:
      return "";
  }
}

function normalizeSubscriptionStatus(status) {
  const normalized = String(status || "").trim().toLowerCase();

  switch (normalized) {
    case "active":
    case "inactive":
    case "expired":
      return normalized;
    default:
      return "inactive";
  }
}

function normalizeNullableDate(value) {
  const normalized = String(value || "").trim();
  if (!normalized) {
    return null;
  }

  const parsed = new Date(normalized);
  if (isNaN(parsed.getTime())) {
    return null;
  }

  return parsed.toISOString();
}

function defaultPlanForRole(role) {
  switch (role) {
    case "admin_rt":
      return "admin_rt_monthly";
    case "admin_rw":
      return "admin_rw_monthly";
    case "admin_rw_pro":
      return "admin_rw_pro_monthly";
    default:
      return "";
  }
}
