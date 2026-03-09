/// <reference path="../pb_data/types.d.ts" />

migrate((app) => {
  syncUsersRoleSchema(app, ["warga", "admin_rt", "admin_rw", "admin_rw_pro", "sysadmin"]);
  syncRoleRequestsSchema(app, ["warga", "admin_rt", "admin_rw", "admin_rw_pro"]);
  migrateUserRoles(app, "user", "warga");
  migrateRoleRequestRoles(app, "user", "warga");
}, (app) => {
  syncUsersRoleSchema(app, ["user", "admin_rt", "admin_rw", "admin_rw_pro", "sysadmin"]);
  syncRoleRequestsSchema(app, ["user", "admin_rt", "admin_rw", "admin_rw_pro"]);
  migrateUserRoles(app, "warga", "user");
  migrateRoleRequestRoles(app, "warga", "user");
});

function syncUsersRoleSchema(app, values) {
  const collection = app.findCollectionByNameOrId("_pb_users_auth_");
  const roleField = collection.fields.getByName("role");

  collection.fields.addAt(
    8,
    new SelectField({
      id: fieldId(roleField),
      name: "role",
      maxSelect: 1,
      values: values,
      required: false,
    }),
  );

  app.save(collection);
}

function syncRoleRequestsSchema(app, values) {
  let collection = null;

  try {
    collection = app.findCollectionByNameOrId("role_requests");
  } catch (_) {
    return;
  }

  const requestedRoleField = collection.fields.getByName("requested_role");
  if (!requestedRoleField) {
    return;
  }

  collection.fields.addAt(
    2,
    new SelectField({
      id: fieldId(requestedRoleField),
      name: "requested_role",
      maxSelect: 1,
      values: values,
      required: true,
    }),
  );

  app.save(collection);
}

function migrateUserRoles(app, fromRole, toRole) {
  const users = app.findRecordsByFilter("_pb_users_auth_", "", "created", 5000, 0);

  for (const user of users) {
    if (!user || user.getString("role") !== fromRole) {
      continue;
    }

    user.set("role", toRole);
    app.save(user);
  }
}

function migrateRoleRequestRoles(app, fromRole, toRole) {
  let records = [];

  try {
    records = app.findRecordsByFilter("role_requests", "", "created", 5000, 0);
  } catch (_) {
    return;
  }

  for (const record of records) {
    if (!record) {
      continue;
    }

    let dirty = false;

    if (record.getString("requested_role") === fromRole) {
      record.set("requested_role", toRole);
      dirty = true;
    }

    if (record.getString("current_role") === fromRole) {
      record.set("current_role", toRole);
      dirty = true;
    }

    if (dirty) {
      app.save(record);
    }
  }
}

function fieldId(field) {
  if (!field) {
    return "";
  }

  if (typeof field.getId === "function") {
    return field.getId();
  }

  return field.id || "";
}
