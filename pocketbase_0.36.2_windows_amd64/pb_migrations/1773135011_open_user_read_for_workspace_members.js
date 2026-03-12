/// <reference path="../pb_data/types.d.ts" />

migrate((app) => {
  const users = app.findCollectionByNameOrId("_pb_users_auth_");
  const sameWorkspaceRule =
    "workspace_members_via_user.workspace ?= @request.auth.active_workspace && workspace_members_via_user.is_active ?= true";

  users.listRule =
    "@request.auth.id != '' && (@request.auth.role = 'sysadmin' || id = @request.auth.id || (" +
    sameWorkspaceRule +
    "))";
  users.viewRule = users.listRule;
  users.updateRule =
    "@request.auth.id != '' && @request.auth.role = 'sysadmin'";
  users.manageRule =
    "@request.auth.id != '' && @request.auth.role = 'sysadmin'";

  return app.save(users);
}, (app) => {
  const users = app.findCollectionByNameOrId("_pb_users_auth_");

  users.listRule =
    "@request.auth.id != '' && @request.auth.role = 'sysadmin'";
  users.viewRule =
    "@request.auth.id != '' && (id = @request.auth.id || @request.auth.role = 'sysadmin')";
  users.updateRule =
    "@request.auth.id != '' && @request.auth.role = 'sysadmin'";
  users.manageRule =
    "@request.auth.id != '' && @request.auth.role = 'sysadmin'";

  return app.save(users);
});
