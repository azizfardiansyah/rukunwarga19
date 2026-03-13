/// <reference path="../pb_data/types.d.ts" />

migrate((app) => {
  const members = findCollection(app, "workspace_members");
  const users = findCollection(app, "_pb_users_auth_");
  const warga = findCollection(app, "warga");
  if (!members) {
    return;
  }

  if (!members.fields.getByName("avatar_path")) {
    members.fields.add(new TextField({ name: "avatar_path" }));
    app.save(members);
  }

  const records = app.findAllRecords(members);
  for (const record of records) {
    const userId = record.getString("user");
    const user = findRecord(app, users, userId);
    const wargaRecord = findFirstRecord(
      app,
      warga,
      `user_id = "${escapeFilterValue(userId)}"`,
    );
    const avatarPath = resolveAvatarPath(user, wargaRecord);
    record.set("avatar_path", avatarPath);
    app.save(record);
  }
}, (app) => {
  // Non-destructive rollback. Avatar snapshot can remain on workspace members.
});

function resolveAvatarPath(user, warga) {
  const userAvatar = asString(user?.getString("avatar")).trim();
  if (user && userAvatar) {
    return `/api/files/users/${user.id}/${userAvatar}`;
  }

  const wargaAvatar = asString(warga?.getString("foto_warga")).trim();
  if (warga && wargaAvatar) {
    return `/api/files/warga/${warga.id}/${wargaAvatar}`;
  }

  return "";
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

function findFirstRecord(app, collection, filter) {
  if (!collection || !asString(filter).trim()) {
    return null;
  }
  try {
    return app.findFirstRecordByFilter(collection, filter);
  } catch (_) {
    return null;
  }
}

function escapeFilterValue(value) {
  return asString(value).replaceAll("\\", "\\\\").replaceAll('"', '\\"');
}

function asString(value) {
  if (value === null || value === undefined) {
    return "";
  }
  return String(value);
}
