/// <reference path="../pb_data/types.d.ts" />

migrate(
  (app) => {
    const authRule = "@request.auth.id != ''";

    setRules(app, "conversations", {
      listRule: authRule,
      viewRule: authRule,
      createRule: authRule,
      updateRule: authRule,
    });
    setRules(app, "conversation_members", {
      listRule: authRule,
      viewRule: authRule,
      createRule: authRule,
      updateRule: authRule,
    });
    setRules(app, "messages", {
      listRule: authRule,
      viewRule: authRule,
      createRule: authRule,
      updateRule: authRule,
      deleteRule: authRule,
    });
    setRules(app, "message_reads", {
      listRule: authRule,
      viewRule: authRule,
      createRule: authRule,
      updateRule: authRule,
    });
    setRules(app, "message_reactions", {
      listRule: authRule,
      viewRule: authRule,
      createRule: authRule,
      updateRule: authRule,
      deleteRule: authRule,
    });
    setRules(app, "chat_polls", {
      listRule: authRule,
      viewRule: authRule,
      createRule: authRule,
      updateRule: authRule,
      deleteRule: authRule,
    });
    setRules(app, "chat_poll_options", {
      listRule: authRule,
      viewRule: authRule,
      createRule: authRule,
      updateRule: authRule,
      deleteRule: authRule,
    });
    setRules(app, "chat_poll_votes", {
      listRule: authRule,
      viewRule: authRule,
      createRule: authRule,
      updateRule: authRule,
      deleteRule: authRule,
    });
  },
  (app) => {
    const rwProRule =
      "@request.auth.system_role = 'sysadmin' || (@request.auth.system_role = 'operator' && @request.auth.plan_code = 'rw_pro') || @request.auth.role = 'admin_rw_pro' || @request.auth.role = 'sysadmin'";

    setRules(app, "message_reactions", {
      listRule: null,
      viewRule: null,
      createRule: "@request.auth.id != ''",
      updateRule: null,
      deleteRule: "@request.auth.id != ''",
    });
    setRules(app, "chat_polls", {
      listRule: "@request.auth.id != ''",
      viewRule: "@request.auth.id != ''",
      createRule: rwProRule,
      updateRule: rwProRule,
      deleteRule: rwProRule,
    });
    setRules(app, "chat_poll_options", {
      listRule: "@request.auth.id != ''",
      viewRule: "@request.auth.id != ''",
      createRule: rwProRule,
      updateRule: rwProRule,
      deleteRule: rwProRule,
    });
    setRules(app, "chat_poll_votes", {
      listRule: "@request.auth.id != ''",
      viewRule: "@request.auth.id != ''",
      createRule: "@request.auth.id != ''",
      updateRule: rwProRule,
      deleteRule: rwProRule,
    });
  },
);

function setRules(app, collectionName, rules) {
  let collection = null;
  try {
    collection = app.findCollectionByNameOrId(collectionName);
  } catch (_) {
    return;
  }

  unmarshal(rules, collection);
  app.save(collection);
}
