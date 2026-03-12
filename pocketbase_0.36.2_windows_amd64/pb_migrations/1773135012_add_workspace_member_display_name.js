/// <reference path="../pb_data/types.d.ts" />

migrate((app) => {
  const members = findCollection(app, "workspace_members");
  const users = findCollection(app, "_pb_users_auth_");
  if (!members || !users) {
    return;
  }

  if (!members.fields.getByName("display_name")) {
    members.fields.add(new TextField({ name: "display_name" }));
    app.save(members);
  }

  const records = app.findAllRecords(members);
  for (const record of records) {
    const userId = record.getString("user");
    const displayName = resolveUserDisplayName(
      app,
      users,
      userId,
      record.getString("display_name"),
    );
    record.set("display_name", displayName);
    app.save(record);
  }
}, (app) => {
  // Intentionally non-destructive. Existing workspace member labels should
  // remain available even if this migration is rolled back in code.
});

function resolveUserDisplayName(app, users, userId, fallbackDisplayName) {
  const user = findRecord(app, users, userId);
  const candidates = [
    user?.getString("name"),
    user?.getString("nama"),
    user?.getString("username"),
  ];

  for (const candidate of candidates) {
    const normalized = asString(candidate).trim();
    if (normalized) {
      return normalized;
    }
  }

  const email = asString(user?.getString("email")).trim();
  if (email) {
    return email.split("@")[0];
  }

  const fallback = asString(fallbackDisplayName).trim();
  if (fallback) {
    return fallback;
  }

  return asString(userId).trim();
}

function findCollection(app, name) {
  try {
    return app.findCollectionByNameOrId(name);
  } catch (_) {
    return null;
  }
}

function findRecord(app, collection, id) {
  const normalizedId = asString(id).trim();
  if (!collection || !normalizedId) {
    return null;
  }
  try {
    return app.findRecordById(collection, normalizedId);
  } catch (_) {
    return null;
  }
}

function asString(value) {
  if (value === null || value === undefined) {
    return "";
  }
  return String(value);
}
