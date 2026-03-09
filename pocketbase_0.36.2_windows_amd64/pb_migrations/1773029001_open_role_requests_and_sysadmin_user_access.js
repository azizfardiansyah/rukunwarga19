/// <reference path="../pb_data/types.d.ts" />

migrate((app) => {
  const roleRequests = app.findCollectionByNameOrId("role_requests");
  roleRequests.listRule =
    "@request.auth.id != '' && (requester = @request.auth.id || reviewer = @request.auth.id || @request.auth.role = 'sysadmin')";
  roleRequests.viewRule =
    "@request.auth.id != '' && (requester = @request.auth.id || reviewer = @request.auth.id || @request.auth.role = 'sysadmin')";
  roleRequests.createRule =
    "@request.auth.id != '' && requester = @request.auth.id && status = 'pending'";
  roleRequests.updateRule =
    "@request.auth.id != '' && @request.auth.role = 'sysadmin'";
  roleRequests.deleteRule =
    "@request.auth.id != '' && @request.auth.role = 'sysadmin'";
  app.save(roleRequests);

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
}, (app) => {
  const roleRequests = app.findCollectionByNameOrId("role_requests");
  roleRequests.listRule = null;
  roleRequests.viewRule = null;
  roleRequests.createRule = null;
  roleRequests.updateRule = null;
  roleRequests.deleteRule = null;
  app.save(roleRequests);

  const users = app.findCollectionByNameOrId("_pb_users_auth_");
  users.listRule = null;
  users.viewRule = null;
  users.updateRule = null;
  users.manageRule = null;

  return app.save(users);
});
