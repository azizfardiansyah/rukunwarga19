/// <reference path="../pb_data/types.d.ts" />

migrate(
  (app) => {
    const rwProRule =
      "@request.auth.system_role = 'sysadmin' || (@request.auth.system_role = 'operator' && @request.auth.plan_code = 'rw_pro') || @request.auth.role = 'admin_rw_pro' || @request.auth.role = 'sysadmin'";

    const chatPolls = app.findCollectionByNameOrId("chat_polls");
    unmarshal(
      {
        createRule: rwProRule,
        updateRule: rwProRule,
        deleteRule: rwProRule,
      },
      chatPolls,
    );
    app.save(chatPolls);

    const chatPollOptions = app.findCollectionByNameOrId("chat_poll_options");
    unmarshal(
      {
        createRule: rwProRule,
        updateRule: rwProRule,
        deleteRule: rwProRule,
      },
      chatPollOptions,
    );
    app.save(chatPollOptions);

    const chatPollVotes = app.findCollectionByNameOrId("chat_poll_votes");
    unmarshal(
      {
        updateRule: rwProRule,
        deleteRule: rwProRule,
      },
      chatPollVotes,
    );

    return app.save(chatPollVotes);
  },
  (app) => {
    const legacyRule =
      "@request.auth.system_role = 'sysadmin' || ((@request.auth.system_role = 'operator' && (@request.auth.plan_code = 'rw_pro')) || @request.auth.role = 'admin_rt' || @request.auth.role = 'admin_rw' || @request.auth.role = 'admin_rw_pro' || @request.auth.role = 'sysadmin')";

    const chatPolls = app.findCollectionByNameOrId("chat_polls");
    unmarshal(
      {
        createRule: legacyRule,
        updateRule: legacyRule,
        deleteRule: legacyRule,
      },
      chatPolls,
    );
    app.save(chatPolls);

    const chatPollOptions = app.findCollectionByNameOrId("chat_poll_options");
    unmarshal(
      {
        createRule: legacyRule,
        updateRule: legacyRule,
        deleteRule: legacyRule,
      },
      chatPollOptions,
    );
    app.save(chatPollOptions);

    const chatPollVotes = app.findCollectionByNameOrId("chat_poll_votes");
    unmarshal(
      {
        updateRule: legacyRule,
        deleteRule: legacyRule,
      },
      chatPollVotes,
    );

    return app.save(chatPollVotes);
  },
);
