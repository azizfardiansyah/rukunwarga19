/// <reference path="../pb_data/types.d.ts" />

migrate((app) => {
  const records = app.findRecordsByFilter(
    "users",
    "role = 'admin' || role = 'superuser'",
    "",
    500,
    0,
  );

  for (const record of records) {
    const role = record.getString("role");

    if (role === "admin") {
      record.set("role", "admin_rw");
    } else if (role === "superuser") {
      record.set("role", "sysadmin");
    }

    app.save(record);
  }
}, (app) => {
  const records = app.findRecordsByFilter(
    "users",
    "role = 'admin_rw' || role = 'sysadmin'",
    "",
    500,
    0,
  );

  for (const record of records) {
    const role = record.getString("role");

    if (role === "admin_rw") {
      record.set("role", "admin");
    } else if (role === "sysadmin") {
      record.set("role", "superuser");
    }

    app.save(record);
  }
});
