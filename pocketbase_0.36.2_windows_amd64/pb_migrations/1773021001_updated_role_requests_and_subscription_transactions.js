/// <reference path="../pb_data/types.d.ts" />

migrate((app) => {
  const roleRequests = app.findCollectionByNameOrId("role_requests");
  const requestedRoleField = roleRequests.fields.getByName("requested_role");

  roleRequests.fields.addAt(
    2,
    new SelectField({
      id: fieldId(requestedRoleField),
      name: "requested_role",
      maxSelect: 1,
      values: ["user", "admin_rt", "admin_rw", "admin_rw_pro"],
      required: true,
    }),
  );
  app.save(roleRequests);

  const transactions = app.findCollectionByNameOrId("subscription_transactions");
  if (!transactions.fields.getByName("target_role")) {
    transactions.fields.addAt(
      4,
      new SelectField({
        name: "target_role",
        maxSelect: 1,
        values: ["admin_rt", "admin_rw", "admin_rw_pro"],
      }),
    );
  }
  app.save(transactions);

  const records = app.findRecordsByFilter(
    "subscription_transactions",
    "",
    "created",
    500,
    0,
  );

  for (const record of records) {
    if (!record) {
      continue;
    }

    if (!record.getString("target_role")) {
      record.set("target_role", inferTargetRole(record.getString("plan_code")));
      app.save(record);
    }
  }
}, (app) => {
  const roleRequests = app.findCollectionByNameOrId("role_requests");
  const requestedRoleField = roleRequests.fields.getByName("requested_role");

  roleRequests.fields.addAt(
    2,
    new SelectField({
      id: fieldId(requestedRoleField),
      name: "requested_role",
      maxSelect: 1,
      values: ["admin_rt", "admin_rw", "admin_rw_pro"],
      required: true,
    }),
  );
  app.save(roleRequests);

  const transactions = app.findCollectionByNameOrId("subscription_transactions");
  if (transactions.fields.getByName("target_role")) {
    transactions.fields.removeByName("target_role");
  }

  return app.save(transactions);
});

function fieldId(field) {
  if (!field) {
    return "";
  }

  if (typeof field.getId === "function") {
    return field.getId();
  }

  return field.id || "";
}

function inferTargetRole(planCode) {
  switch (String(planCode || "").trim().toLowerCase()) {
    case "admin_rt_monthly":
      return "admin_rt";
    case "admin_rw_monthly":
      return "admin_rw";
    case "admin_rw_pro_monthly":
      return "admin_rw_pro";
    default:
      return "";
  }
}
