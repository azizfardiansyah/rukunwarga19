/// <reference path="../pb_data/types.d.ts" />

migrate((app) => {
  ensureWorkspacesCollection(app);
  ensureWorkspaceMembersCollection(app);
  ensureOrgUnitsCollection(app);
  ensureJabatanMasterCollection(app);
  ensureOrgMembershipsCollection(app);
  ensureChatPollsCollection(app);
  ensureChatPollOptionsCollection(app);
  ensureChatPollVotesCollection(app);
  ensureFinanceAccountsCollection(app);
  ensureFinanceTransactionsCollection(app);
  ensureFinanceApprovalsCollection(app);

  ensureUsersAccessFields(app);
  ensureSubscriptionPlanMetadata(app);
  ensureSubscriptionTransactionMetadata(app);
  ensureConversationMetadata(app);
  ensureMessageMetadata(app);
  ensureAnnouncementMetadata(app);

  backfillUsersAccessFields(app);
  seedJabatanMaster(app);
  syncSubscriptionPlans(app);
}, (app) => {
  // Intentionally non-destructive. This migration creates additive foundation
  // for the new access model and should not remove existing data on rollback.
});

function ensureWorkspacesCollection(app) {
  let collection = findCollection(app, "workspaces");
  if (!collection) {
    collection = new Collection({
      type: "base",
      name: "workspaces",
      fields: [],
    });
  }

  applyAdminManagedRules(collection);

  addFieldIfMissing(collection, new TextField({ name: "code", required: true }));
  addFieldIfMissing(collection, new TextField({ name: "name", required: true }));
  addFieldIfMissing(
    collection,
    new NumberField({ name: "rw", onlyInt: true, min: 0 }),
  );
  addFieldIfMissing(collection, new TextField({ name: "desa_code" }));
  addFieldIfMissing(collection, new TextField({ name: "kecamatan_code" }));
  addFieldIfMissing(collection, new TextField({ name: "kabupaten_code" }));
  addFieldIfMissing(collection, new TextField({ name: "provinsi_code" }));
  addFieldIfMissing(collection, new TextField({ name: "desa_kelurahan" }));
  addFieldIfMissing(collection, new TextField({ name: "kecamatan" }));
  addFieldIfMissing(collection, new TextField({ name: "kabupaten_kota" }));
  addFieldIfMissing(collection, new TextField({ name: "provinsi" }));
  addFieldIfMissing(
    collection,
    new SelectField({
      name: "status",
      maxSelect: 1,
      values: ["active", "inactive"],
    }),
  );
  addFieldIfMissing(
    collection,
    new AutodateField({
      name: "created",
      onCreate: true,
      onUpdate: false,
    }),
  );
  addFieldIfMissing(
    collection,
    new AutodateField({
      name: "updated",
      onCreate: true,
      onUpdate: true,
    }),
  );

  app.save(collection);
}

function ensureWorkspaceMembersCollection(app) {
  const workspaces = findCollection(app, "workspaces");
  const users = findCollection(app, "users");
  if (!workspaces || !users) {
    return;
  }

  let collection = findCollection(app, "workspace_members");
  if (!collection) {
    collection = new Collection({
      type: "base",
      name: "workspace_members",
      fields: [],
    });
  }

  collection.listRule = "@request.auth.id != ''";
  collection.viewRule = "@request.auth.id != ''";
  collection.createRule = operatorOrSysadminRule();
  collection.updateRule = collection.createRule;
  collection.deleteRule = collection.createRule;

  addFieldIfMissing(
    collection,
    new RelationField({
      name: "workspace",
      collectionId: workspaces.id,
      maxSelect: 1,
      required: true,
    }),
  );
  addFieldIfMissing(
    collection,
    new RelationField({
      name: "user",
      collectionId: users.id,
      maxSelect: 1,
      required: true,
    }),
  );
  addFieldIfMissing(
    collection,
    new SelectField({
      name: "system_role",
      maxSelect: 1,
      values: ["warga", "operator", "sysadmin"],
      required: true,
    }),
  );
  addFieldIfMissing(
    collection,
    new SelectField({
      name: "plan_code",
      maxSelect: 1,
      values: ["free", "rt", "rw", "rw_pro"],
    }),
  );
  addFieldIfMissing(
    collection,
    new SelectField({
      name: "subscription_status",
      maxSelect: 1,
      values: ["inactive", "active", "expired"],
    }),
  );
  addFieldIfMissing(collection, new DateField({ name: "subscription_started" }));
  addFieldIfMissing(collection, new DateField({ name: "subscription_expired" }));
  addFieldIfMissing(collection, new BoolField({ name: "is_owner" }));
  addFieldIfMissing(
    collection,
    new NumberField({ name: "owner_rank", onlyInt: true, min: 0 }),
  );
  addFieldIfMissing(
    collection,
    new SelectField({
      name: "scope_type",
      maxSelect: 1,
      values: ["rw", "rt", "unit"],
    }),
  );
  addFieldIfMissing(
    collection,
    new NumberField({ name: "scope_rt", onlyInt: true, min: 0 }),
  );
  addFieldIfMissing(
    collection,
    new NumberField({ name: "scope_rw", onlyInt: true, min: 0 }),
  );
  addFieldIfMissing(collection, new BoolField({ name: "is_active" }));
  addFieldIfMissing(
    collection,
    new AutodateField({
      name: "created",
      onCreate: true,
      onUpdate: false,
    }),
  );
  addFieldIfMissing(
    collection,
    new AutodateField({
      name: "updated",
      onCreate: true,
      onUpdate: true,
    }),
  );

  app.save(collection);
}

function ensureOrgUnitsCollection(app) {
  const workspaces = findCollection(app, "workspaces");
  if (!workspaces) {
    return;
  }

  let collection = findCollection(app, "org_units");
  if (!collection) {
    collection = new Collection({
      type: "base",
      name: "org_units",
      fields: [],
    });
  }

  applyAdminManagedRules(collection);

  addFieldIfMissing(
    collection,
    new RelationField({
      name: "workspace",
      collectionId: workspaces.id,
      maxSelect: 1,
      required: true,
    }),
  );
  addFieldIfMissing(
    collection,
    new SelectField({
      name: "type",
      maxSelect: 1,
      values: ["rw", "rt", "dkm", "posyandu", "custom"],
      required: true,
    }),
  );
  addFieldIfMissing(collection, new TextField({ name: "name", required: true }));
  addFieldIfMissing(collection, new TextField({ name: "code", required: true }));
  addFieldIfMissing(collection, new BoolField({ name: "is_official" }));
  addFieldIfMissing(
    collection,
    new NumberField({ name: "scope_rt", onlyInt: true, min: 0 }),
  );
  addFieldIfMissing(
    collection,
    new NumberField({ name: "scope_rw", onlyInt: true, min: 0 }),
  );
  addFieldIfMissing(
    collection,
    new SelectField({
      name: "status",
      maxSelect: 1,
      values: ["active", "inactive"],
    }),
  );
  addFieldIfMissing(
    collection,
    new AutodateField({
      name: "created",
      onCreate: true,
      onUpdate: false,
    }),
  );
  addFieldIfMissing(
    collection,
    new AutodateField({
      name: "updated",
      onCreate: true,
      onUpdate: true,
    }),
  );

  app.save(collection);

  addSelfRelationIfMissing(collection, "parent_unit");
  app.save(collection);
}

function ensureJabatanMasterCollection(app) {
  let collection = findCollection(app, "jabatan_master");
  if (!collection) {
    collection = new Collection({
      type: "base",
      name: "jabatan_master",
      fields: [],
    });
  }

  applyAdminManagedRules(collection);

  addFieldIfMissing(collection, new TextField({ name: "code", required: true }));
  addFieldIfMissing(collection, new TextField({ name: "label", required: true }));
  addFieldIfMissing(
    collection,
    new SelectField({
      name: "unit_type",
      maxSelect: 1,
      values: ["rw", "rt", "dkm", "posyandu", "custom"],
      required: true,
    }),
  );
  addFieldIfMissing(
    collection,
    new NumberField({ name: "sort_order", onlyInt: true, min: 0 }),
  );
  addFieldIfMissing(collection, new BoolField({ name: "can_manage_workspace" }));
  addFieldIfMissing(collection, new BoolField({ name: "can_manage_unit" }));
  addFieldIfMissing(collection, new BoolField({ name: "can_manage_membership" }));
  addFieldIfMissing(collection, new BoolField({ name: "can_submit_finance" }));
  addFieldIfMissing(collection, new BoolField({ name: "can_approve_finance" }));
  addFieldIfMissing(collection, new BoolField({ name: "can_publish_finance" }));
  addFieldIfMissing(collection, new BoolField({ name: "can_manage_schedule" }));
  addFieldIfMissing(collection, new BoolField({ name: "can_broadcast_unit" }));
  addFieldIfMissing(collection, new BoolField({ name: "can_manage_iuran" }));
  addFieldIfMissing(collection, new BoolField({ name: "can_verify_iuran_payment" }));
  addFieldIfMissing(collection, new BoolField({ name: "is_active" }));
  addFieldIfMissing(
    collection,
    new AutodateField({
      name: "created",
      onCreate: true,
      onUpdate: false,
    }),
  );
  addFieldIfMissing(
    collection,
    new AutodateField({
      name: "updated",
      onCreate: true,
      onUpdate: true,
    }),
  );

  app.save(collection);
}

function ensureOrgMembershipsCollection(app) {
  const workspaces = findCollection(app, "workspaces");
  const users = findCollection(app, "users");
  const members = findCollection(app, "workspace_members");
  const units = findCollection(app, "org_units");
  const jabatan = findCollection(app, "jabatan_master");
  if (!workspaces || !users || !members || !units || !jabatan) {
    return;
  }

  let collection = findCollection(app, "org_memberships");
  if (!collection) {
    collection = new Collection({
      type: "base",
      name: "org_memberships",
      fields: [],
    });
  }

  applyAdminManagedRules(collection);

  addFieldIfMissing(
    collection,
    new RelationField({
      name: "workspace",
      collectionId: workspaces.id,
      maxSelect: 1,
      required: true,
    }),
  );
  addFieldIfMissing(
    collection,
    new RelationField({
      name: "user",
      collectionId: users.id,
      maxSelect: 1,
      required: true,
    }),
  );
  addFieldIfMissing(
    collection,
    new RelationField({
      name: "workspace_member",
      collectionId: members.id,
      maxSelect: 1,
      required: true,
    }),
  );
  addFieldIfMissing(
    collection,
    new RelationField({
      name: "org_unit",
      collectionId: units.id,
      maxSelect: 1,
      required: true,
    }),
  );
  addFieldIfMissing(
    collection,
    new RelationField({
      name: "jabatan",
      collectionId: jabatan.id,
      maxSelect: 1,
      required: true,
    }),
  );
  addFieldIfMissing(collection, new BoolField({ name: "is_primary" }));
  addFieldIfMissing(collection, new DateField({ name: "started_at" }));
  addFieldIfMissing(collection, new DateField({ name: "ended_at" }));
  addFieldIfMissing(
    collection,
    new SelectField({
      name: "status",
      maxSelect: 1,
      values: ["active", "inactive"],
    }),
  );
  addFieldIfMissing(collection, new TextField({ name: "period_label" }));
  addFieldIfMissing(
    collection,
    new AutodateField({
      name: "created",
      onCreate: true,
      onUpdate: false,
    }),
  );
  addFieldIfMissing(
    collection,
    new AutodateField({
      name: "updated",
      onCreate: true,
      onUpdate: true,
    }),
  );

  app.save(collection);
}

function ensureChatPollsCollection(app) {
  const workspaces = findCollection(app, "workspaces");
  const conversations = findCollection(app, "conversations");
  const messages = findCollection(app, "messages");
  if (!workspaces || !conversations || !messages) {
    return;
  }

  let collection = findCollection(app, "chat_polls");
  if (!collection) {
    collection = new Collection({
      type: "base",
      name: "chat_polls",
      fields: [],
    });
  }

  collection.listRule = "@request.auth.id != ''";
  collection.viewRule = "@request.auth.id != ''";
  collection.createRule = operatorWithPlanRule(["rw_pro"]);
  collection.updateRule = collection.createRule;
  collection.deleteRule = collection.createRule;

  addFieldIfMissing(
    collection,
    new RelationField({
      name: "workspace",
      collectionId: workspaces.id,
      maxSelect: 1,
      required: true,
    }),
  );
  addFieldIfMissing(
    collection,
    new RelationField({
      name: "conversation",
      collectionId: conversations.id,
      maxSelect: 1,
      required: true,
    }),
  );
  addFieldIfMissing(
    collection,
    new RelationField({
      name: "message",
      collectionId: messages.id,
      maxSelect: 1,
      required: true,
    }),
  );
  addFieldIfMissing(collection, new TextField({ name: "title", required: true }));
  addFieldIfMissing(collection, new BoolField({ name: "allow_multiple_choice" }));
  addFieldIfMissing(collection, new BoolField({ name: "allow_anonymous_vote" }));
  addFieldIfMissing(
    collection,
    new SelectField({
      name: "status",
      maxSelect: 1,
      values: ["open", "closed"],
      required: true,
    }),
  );
  addFieldIfMissing(collection, new DateField({ name: "closed_at" }));
  addFieldIfMissing(
    collection,
    new AutodateField({
      name: "created",
      onCreate: true,
      onUpdate: false,
    }),
  );
  addFieldIfMissing(
    collection,
    new AutodateField({
      name: "updated",
      onCreate: true,
      onUpdate: true,
    }),
  );

  app.save(collection);
}

function ensureChatPollOptionsCollection(app) {
  const polls = findCollection(app, "chat_polls");
  if (!polls) {
    return;
  }

  let collection = findCollection(app, "chat_poll_options");
  if (!collection) {
    collection = new Collection({
      type: "base",
      name: "chat_poll_options",
      fields: [],
    });
  }

  collection.listRule = "@request.auth.id != ''";
  collection.viewRule = "@request.auth.id != ''";
  collection.createRule = operatorWithPlanRule(["rw_pro"]);
  collection.updateRule = collection.createRule;
  collection.deleteRule = collection.createRule;

  addFieldIfMissing(
    collection,
    new RelationField({
      name: "poll",
      collectionId: polls.id,
      maxSelect: 1,
      required: true,
    }),
  );
  addFieldIfMissing(collection, new TextField({ name: "label", required: true }));
  addFieldIfMissing(
    collection,
    new NumberField({ name: "sort_order", onlyInt: true, min: 0 }),
  );
  addFieldIfMissing(
    collection,
    new AutodateField({
      name: "created",
      onCreate: true,
      onUpdate: false,
    }),
  );
  addFieldIfMissing(
    collection,
    new AutodateField({
      name: "updated",
      onCreate: true,
      onUpdate: true,
    }),
  );

  app.save(collection);
}

function ensureChatPollVotesCollection(app) {
  const polls = findCollection(app, "chat_polls");
  const options = findCollection(app, "chat_poll_options");
  const users = findCollection(app, "users");
  const members = findCollection(app, "workspace_members");
  if (!polls || !options || !users || !members) {
    return;
  }

  let collection = findCollection(app, "chat_poll_votes");
  if (!collection) {
    collection = new Collection({
      type: "base",
      name: "chat_poll_votes",
      fields: [],
    });
  }

  collection.listRule = "@request.auth.id != ''";
  collection.viewRule = "@request.auth.id != ''";
  collection.createRule = "@request.auth.id != ''";
  collection.updateRule = operatorOrSysadminRule(["rw_pro"]);
  collection.deleteRule = collection.updateRule;

  addFieldIfMissing(
    collection,
    new RelationField({
      name: "poll",
      collectionId: polls.id,
      maxSelect: 1,
      required: true,
    }),
  );
  addFieldIfMissing(
    collection,
    new RelationField({
      name: "option",
      collectionId: options.id,
      maxSelect: 1,
      required: true,
    }),
  );
  addFieldIfMissing(
    collection,
    new RelationField({
      name: "user",
      collectionId: users.id,
      maxSelect: 1,
      required: true,
    }),
  );
  addFieldIfMissing(
    collection,
    new RelationField({
      name: "workspace_member",
      collectionId: members.id,
      maxSelect: 1,
    }),
  );
  addFieldIfMissing(
    collection,
    new AutodateField({
      name: "created",
      onCreate: true,
      onUpdate: false,
    }),
  );
  addFieldIfMissing(
    collection,
    new AutodateField({
      name: "updated",
      onCreate: true,
      onUpdate: true,
    }),
  );

  app.save(collection);
}

function ensureFinanceAccountsCollection(app) {
  const workspaces = findCollection(app, "workspaces");
  const units = findCollection(app, "org_units");
  if (!workspaces || !units) {
    return;
  }

  let collection = findCollection(app, "finance_accounts");
  if (!collection) {
    collection = new Collection({
      type: "base",
      name: "finance_accounts",
      fields: [],
    });
  }

  applyAdminManagedRules(collection);

  addFieldIfMissing(
    collection,
    new RelationField({
      name: "workspace",
      collectionId: workspaces.id,
      maxSelect: 1,
      required: true,
    }),
  );
  addFieldIfMissing(
    collection,
    new RelationField({
      name: "org_unit",
      collectionId: units.id,
      maxSelect: 1,
    }),
  );
  addFieldIfMissing(collection, new TextField({ name: "code", required: true }));
  addFieldIfMissing(collection, new TextField({ name: "label", required: true }));
  addFieldIfMissing(
    collection,
    new SelectField({
      name: "type",
      maxSelect: 1,
      values: ["cash", "bank"],
      required: true,
    }),
  );
  addFieldIfMissing(collection, new BoolField({ name: "is_active" }));
  addFieldIfMissing(
    collection,
    new AutodateField({
      name: "created",
      onCreate: true,
      onUpdate: false,
    }),
  );
  addFieldIfMissing(
    collection,
    new AutodateField({
      name: "updated",
      onCreate: true,
      onUpdate: true,
    }),
  );

  app.save(collection);
}

function ensureFinanceTransactionsCollection(app) {
  const workspaces = findCollection(app, "workspaces");
  const units = findCollection(app, "org_units");
  const accounts = findCollection(app, "finance_accounts");
  const members = findCollection(app, "workspace_members");
  if (!workspaces || !units || !accounts || !members) {
    return;
  }

  let collection = findCollection(app, "finance_transactions");
  if (!collection) {
    collection = new Collection({
      type: "base",
      name: "finance_transactions",
      fields: [],
    });
  }

  collection.listRule = "@request.auth.id != ''";
  collection.viewRule = "@request.auth.id != ''";
  collection.createRule = operatorOrSysadminRule();
  collection.updateRule = collection.createRule;
  collection.deleteRule = collection.createRule;

  addFieldIfMissing(
    collection,
    new RelationField({
      name: "workspace",
      collectionId: workspaces.id,
      maxSelect: 1,
      required: true,
    }),
  );
  addFieldIfMissing(
    collection,
    new RelationField({
      name: "org_unit",
      collectionId: units.id,
      maxSelect: 1,
      required: true,
    }),
  );
  addFieldIfMissing(
    collection,
    new RelationField({
      name: "account",
      collectionId: accounts.id,
      maxSelect: 1,
      required: true,
    }),
  );
  addFieldIfMissing(
    collection,
    new SelectField({
      name: "source_module",
      maxSelect: 1,
      values: ["manual", "iuran", "surat", "event"],
      required: true,
    }),
  );
  addFieldIfMissing(
    collection,
    new SelectField({
      name: "direction",
      maxSelect: 1,
      values: ["in", "out"],
      required: true,
    }),
  );
  addFieldIfMissing(collection, new TextField({ name: "category", required: true }));
  addFieldIfMissing(collection, new TextField({ name: "title", required: true }));
  addFieldIfMissing(collection, new TextField({ name: "source_reference" }));
  addFieldIfMissing(collection, new TextField({ name: "description" }));
  addFieldIfMissing(
    collection,
    new NumberField({
      name: "amount",
      onlyInt: true,
      min: 0,
      required: true,
    }),
  );
  addFieldIfMissing(
    collection,
    new SelectField({
      name: "payment_method",
      maxSelect: 1,
      values: ["cash", "transfer"],
      required: true,
    }),
  );
  addFieldIfMissing(
    collection,
    new FileField({
      name: "proof_file",
      maxSelect: 1,
      maxSize: 10 * 1024 * 1024,
      mimeTypes: [],
      thumbs: [],
      protected: false,
    }),
  );
  addFieldIfMissing(
    collection,
    new RelationField({
      name: "maker_member",
      collectionId: members.id,
      maxSelect: 1,
      required: true,
    }),
  );
  addFieldIfMissing(collection, new TextField({ name: "maker_jabatan_snapshot" }));
  addFieldIfMissing(
    collection,
    new SelectField({
      name: "approval_status",
      maxSelect: 1,
      values: ["draft", "submitted", "approved", "rejected"],
      required: true,
    }),
  );
  addFieldIfMissing(
    collection,
    new SelectField({
      name: "publish_status",
      maxSelect: 1,
      values: ["pending", "published"],
      required: true,
    }),
  );
  addFieldIfMissing(collection, new DateField({ name: "submitted_at" }));
  addFieldIfMissing(collection, new DateField({ name: "approved_at" }));
  addFieldIfMissing(collection, new DateField({ name: "published_at" }));
  addFieldIfMissing(
    collection,
    new AutodateField({
      name: "created",
      onCreate: true,
      onUpdate: false,
    }),
  );
  addFieldIfMissing(
    collection,
    new AutodateField({
      name: "updated",
      onCreate: true,
      onUpdate: true,
    }),
  );

  app.save(collection);
}

function ensureFinanceApprovalsCollection(app) {
  const transactions = findCollection(app, "finance_transactions");
  const members = findCollection(app, "workspace_members");
  if (!transactions || !members) {
    return;
  }

  let collection = findCollection(app, "finance_approvals");
  if (!collection) {
    collection = new Collection({
      type: "base",
      name: "finance_approvals",
      fields: [],
    });
  }

  collection.listRule = "@request.auth.id != ''";
  collection.viewRule = "@request.auth.id != ''";
  collection.createRule = operatorOrSysadminRule();
  collection.updateRule = collection.createRule;
  collection.deleteRule = collection.createRule;

  addFieldIfMissing(
    collection,
    new RelationField({
      name: "transaction",
      collectionId: transactions.id,
      maxSelect: 1,
      required: true,
    }),
  );
  addFieldIfMissing(
    collection,
    new RelationField({
      name: "checker_member",
      collectionId: members.id,
      maxSelect: 1,
      required: true,
    }),
  );
  addFieldIfMissing(collection, new TextField({ name: "checker_jabatan_snapshot" }));
  addFieldIfMissing(
    collection,
    new SelectField({
      name: "decision",
      maxSelect: 1,
      values: ["approved", "rejected"],
      required: true,
    }),
  );
  addFieldIfMissing(collection, new TextField({ name: "note" }));
  addFieldIfMissing(
    collection,
    new AutodateField({
      name: "created",
      onCreate: true,
      onUpdate: false,
    }),
  );
  addFieldIfMissing(
    collection,
    new AutodateField({
      name: "updated",
      onCreate: true,
      onUpdate: true,
    }),
  );

  app.save(collection);
}

function ensureUsersAccessFields(app) {
  const users = findCollection(app, "users");
  const workspaces = findCollection(app, "workspaces");
  const members = findCollection(app, "workspace_members");
  if (!users || !workspaces || !members) {
    return;
  }

  addFieldIfMissing(
    users,
    new SelectField({
      name: "system_role",
      maxSelect: 1,
      values: ["warga", "operator", "sysadmin"],
    }),
  );
  addFieldIfMissing(
    users,
    new SelectField({
      name: "plan_code",
      maxSelect: 1,
      values: ["free", "rt", "rw", "rw_pro"],
    }),
  );
  addFieldIfMissing(
    users,
    new RelationField({
      name: "active_workspace",
      collectionId: workspaces.id,
      maxSelect: 1,
    }),
  );
  addFieldIfMissing(
    users,
    new RelationField({
      name: "active_workspace_member",
      collectionId: members.id,
      maxSelect: 1,
    }),
  );
  app.save(users);

  const workspacesCollection = findCollection(app, "workspaces");
  if (!workspacesCollection) {
    return;
  }
  addFieldIfMissing(
    workspacesCollection,
    new RelationField({
      name: "owner_member",
      collectionId: members.id,
      maxSelect: 1,
    }),
  );
  app.save(workspacesCollection);
}

function ensureSubscriptionPlanMetadata(app) {
  const collection = findCollection(app, "subscription_plans");
  if (!collection) {
    return;
  }

  addFieldIfMissing(
    collection,
    new SelectField({
      name: "plan_code",
      maxSelect: 1,
      values: ["free", "rt", "rw", "rw_pro"],
    }),
  );
  addFieldIfMissing(
    collection,
    new SelectField({
      name: "target_system_role",
      maxSelect: 1,
      values: ["warga", "operator", "sysadmin"],
    }),
  );
  addFieldIfMissing(
    collection,
    new SelectField({
      name: "scope_level",
      maxSelect: 1,
      values: ["self", "rt", "rw", "global"],
    }),
  );
  addFieldIfMissing(
    collection,
    new SelectField({
      name: "feature_flags",
      maxSelect: 12,
      values: [
        "chat_basic",
        "broadcast_rt",
        "broadcast_rw",
        "custom_group_basic",
        "custom_group_advanced",
        "agenda_basic",
        "agenda_advanced",
        "finance_basic",
        "finance_publish",
        "voice_note",
        "polling",
        "export_advanced",
      ],
    }),
  );

  app.save(collection);
}

function ensureSubscriptionTransactionMetadata(app) {
  const collection = findCollection(app, "subscription_transactions");
  const workspaces = findCollection(app, "workspaces");
  const members = findCollection(app, "workspace_members");
  if (!collection || !workspaces || !members) {
    return;
  }

  addFieldIfMissing(
    collection,
    new RelationField({
      name: "workspace",
      collectionId: workspaces.id,
      maxSelect: 1,
    }),
  );
  addFieldIfMissing(
    collection,
    new RelationField({
      name: "workspace_member",
      collectionId: members.id,
      maxSelect: 1,
    }),
  );
  addFieldIfMissing(collection, new TextField({ name: "seat_target" }));
  addFieldIfMissing(
    collection,
    new SelectField({
      name: "target_system_role",
      maxSelect: 1,
      values: ["warga", "operator", "sysadmin"],
    }),
  );

  app.save(collection);
}

function ensureConversationMetadata(app) {
  const collection = findCollection(app, "conversations");
  const workspaces = findCollection(app, "workspaces");
  const units = findCollection(app, "org_units");
  if (!collection || !workspaces || !units) {
    return;
  }

  addFieldIfMissing(
    collection,
    new RelationField({
      name: "workspace",
      collectionId: workspaces.id,
      maxSelect: 1,
    }),
  );
  addFieldIfMissing(
    collection,
    new SelectField({
      name: "scope_type",
      maxSelect: 1,
      values: [
        "private_support",
        "rt",
        "rw",
        "dkm",
        "posyandu",
        "custom",
        "developer_support",
      ],
    }),
  );
  addFieldIfMissing(
    collection,
    new RelationField({
      name: "org_unit",
      collectionId: units.id,
      maxSelect: 1,
    }),
  );
  addFieldIfMissing(
    collection,
    new SelectField({
      name: "required_plan_code",
      maxSelect: 1,
      values: ["free", "rt", "rw", "rw_pro"],
    }),
  );

  app.save(collection);
}

function ensureMessageMetadata(app) {
  const collection = findCollection(app, "messages");
  const workspaces = findCollection(app, "workspaces");
  const members = findCollection(app, "workspace_members");
  const polls = findCollection(app, "chat_polls");
  if (!collection || !workspaces || !members || !polls) {
    return;
  }

  addFieldIfMissing(
    collection,
    new RelationField({
      name: "workspace",
      collectionId: workspaces.id,
      maxSelect: 1,
    }),
  );
  addFieldIfMissing(
    collection,
    new RelationField({
      name: "sender_member",
      collectionId: members.id,
      maxSelect: 1,
    }),
  );
  addFieldIfMissing(
    collection,
    new NumberField({
      name: "voice_duration_seconds",
      onlyInt: true,
      min: 0,
    }),
  );
  addFieldIfMissing(
    collection,
    new RelationField({
      name: "poll",
      collectionId: polls.id,
      maxSelect: 1,
    }),
  );
  addFieldIfMissing(collection, new TextField({ name: "sender_badge_label" }));

  ensureSelectFieldValues(collection, "message_type", [
    "text",
    "file",
    "voice",
    "poll",
    "system",
  ]);
  app.save(collection);
}

function ensureAnnouncementMetadata(app) {
  const collection = findCollection(app, "announcements");
  const workspaces = findCollection(app, "workspaces");
  const members = findCollection(app, "workspace_members");
  const units = findCollection(app, "org_units");
  if (!collection || !workspaces || !members || !units) {
    return;
  }

  addFieldIfMissing(
    collection,
    new RelationField({
      name: "workspace",
      collectionId: workspaces.id,
      maxSelect: 1,
    }),
  );
  addFieldIfMissing(
    collection,
    new RelationField({
      name: "org_unit",
      collectionId: units.id,
      maxSelect: 1,
    }),
  );
  addFieldIfMissing(
    collection,
    new SelectField({
      name: "source_module",
      maxSelect: 1,
      values: ["manual", "finance", "chat", "system"],
    }),
  );
  addFieldIfMissing(
    collection,
    new SelectField({
      name: "publish_state",
      maxSelect: 1,
      values: ["draft", "published"],
    }),
  );
  addFieldIfMissing(
    collection,
    new RelationField({
      name: "published_by_member",
      collectionId: members.id,
      maxSelect: 1,
    }),
  );

  app.save(collection);
}

function backfillUsersAccessFields(app) {
  const users = findCollection(app, "users");
  if (!users) {
    return;
  }

  const records = app.findAllRecords(users);
  for (const record of records) {
    const role = normalizeLegacyRole(record.getString("role"));
    if (!record.getString("system_role")) {
      record.set("system_role", systemRoleFromLegacyRole(role));
    }
    if (!record.getString("plan_code")) {
      const planCode = planCodeFromLegacyRole(
        role,
        record.getString("subscription_plan"),
      );
      if (planCode) {
        record.set("plan_code", planCode);
      }
    }
    app.save(record);
  }
}

function seedJabatanMaster(app) {
  const collection = findCollection(app, "jabatan_master");
  if (!collection) {
    return;
  }

  const seeds = [
    seedJabatan("ketua_rw", "Ketua RW", "rw", 10, {
      canManageWorkspace: true,
      canManageUnit: true,
      canManageMembership: true,
      canApproveFinance: true,
      canPublishFinance: true,
      canManageSchedule: true,
      canBroadcastUnit: true,
      canManageIuran: true,
      canVerifyIuranPayment: true,
    }),
    seedJabatan("wakil_ketua_rw", "Wakil Ketua RW", "rw", 20, {
      canManageWorkspace: true,
      canManageUnit: true,
      canManageMembership: true,
      canApproveFinance: true,
      canPublishFinance: true,
      canManageSchedule: true,
      canBroadcastUnit: true,
      canManageIuran: true,
      canVerifyIuranPayment: true,
    }),
    seedJabatan("sekretaris_rw", "Sekretaris RW", "rw", 30, {
      canManageUnit: true,
      canManageMembership: true,
      canManageSchedule: true,
      canBroadcastUnit: true,
    }),
    seedJabatan("bendahara_rw", "Bendahara RW", "rw", 40, {
      canSubmitFinance: true,
      canManageIuran: true,
      canVerifyIuranPayment: true,
    }),
    seedJabatan("ketua_rt", "Ketua RT", "rt", 50, {
      canManageUnit: true,
      canManageMembership: true,
      canApproveFinance: true,
      canPublishFinance: true,
      canManageSchedule: true,
      canBroadcastUnit: true,
      canManageIuran: true,
      canVerifyIuranPayment: true,
    }),
    seedJabatan("wakil_ketua_rt", "Wakil Ketua RT", "rt", 60, {
      canManageUnit: true,
      canManageMembership: true,
      canApproveFinance: true,
      canPublishFinance: true,
      canManageSchedule: true,
      canBroadcastUnit: true,
      canManageIuran: true,
      canVerifyIuranPayment: true,
    }),
    seedJabatan("sekretaris_rt", "Sekretaris RT", "rt", 70, {
      canManageMembership: true,
      canManageSchedule: true,
      canBroadcastUnit: true,
    }),
    seedJabatan("bendahara_rt", "Bendahara RT", "rt", 80, {
      canSubmitFinance: true,
      canManageIuran: true,
      canVerifyIuranPayment: true,
    }),
    seedJabatan("ketua_dkm", "Ketua DKM", "dkm", 90, {
      canManageUnit: true,
      canManageMembership: true,
      canApproveFinance: true,
      canPublishFinance: true,
      canManageSchedule: true,
      canBroadcastUnit: true,
    }),
    seedJabatan("wakil_ketua_dkm", "Wakil Ketua DKM", "dkm", 100, {
      canManageUnit: true,
      canManageMembership: true,
      canApproveFinance: true,
      canPublishFinance: true,
      canManageSchedule: true,
      canBroadcastUnit: true,
    }),
    seedJabatan("sekretaris_dkm", "Sekretaris DKM", "dkm", 110, {
      canManageSchedule: true,
      canBroadcastUnit: true,
    }),
    seedJabatan("bendahara_dkm", "Bendahara DKM", "dkm", 120, {
      canSubmitFinance: true,
    }),
    seedJabatan("admin_dkm", "Admin DKM", "dkm", 130, {
      canManageSchedule: true,
      canBroadcastUnit: true,
    }),
    seedJabatan("ketua_posyandu", "Ketua Posyandu", "posyandu", 140, {
      canManageUnit: true,
      canManageMembership: true,
      canApproveFinance: true,
      canPublishFinance: true,
      canManageSchedule: true,
      canBroadcastUnit: true,
    }),
    seedJabatan("wakil_ketua_posyandu", "Wakil Ketua Posyandu", "posyandu", 150, {
      canManageUnit: true,
      canManageMembership: true,
      canApproveFinance: true,
      canPublishFinance: true,
      canManageSchedule: true,
      canBroadcastUnit: true,
    }),
    seedJabatan("sekretaris_posyandu", "Sekretaris Posyandu", "posyandu", 160, {
      canManageSchedule: true,
      canBroadcastUnit: true,
    }),
    seedJabatan("bendahara_posyandu", "Bendahara Posyandu", "posyandu", 170, {
      canSubmitFinance: true,
    }),
    seedJabatan("kader_posyandu", "Kader Posyandu", "posyandu", 180, {
      canManageSchedule: true,
    }),
    seedJabatan("panitia_agustus", "Panitia Agustus", "custom", 190, {
      canManageSchedule: true,
      canBroadcastUnit: true,
    }),
    seedJabatan("koordinator_ronda", "Koordinator Ronda", "custom", 200, {
      canManageSchedule: true,
      canBroadcastUnit: true,
    }),
  ];

  for (const seed of seeds) {
    upsertByCode(app, collection, seed);
  }
}

function syncSubscriptionPlans(app) {
  const collection = findCollection(app, "subscription_plans");
  if (!collection) {
    return;
  }

  const records = app.findAllRecords(collection);
  for (const record of records) {
    const metadata = planMetadataForRecord(record);
    if (!metadata) {
      continue;
    }

    record.set("plan_code", metadata.planCode);
    record.set("target_system_role", metadata.targetSystemRole);
    record.set("scope_level", metadata.scopeLevel);
    record.set("feature_flags", metadata.featureFlags);
    app.save(record);
  }
}

function seedJabatan(
  code,
  label,
  unitType,
  sortOrder,
  {
    canManageWorkspace = false,
    canManageUnit = false,
    canManageMembership = false,
    canSubmitFinance = false,
    canApproveFinance = false,
    canPublishFinance = false,
    canManageSchedule = false,
    canBroadcastUnit = false,
    canManageIuran = false,
    canVerifyIuranPayment = false,
  } = {},
) {
  return {
    code: code,
    label: label,
    unit_type: unitType,
    sort_order: sortOrder,
    can_manage_workspace: canManageWorkspace,
    can_manage_unit: canManageUnit,
    can_manage_membership: canManageMembership,
    can_submit_finance: canSubmitFinance,
    can_approve_finance: canApproveFinance,
    can_publish_finance: canPublishFinance,
    can_manage_schedule: canManageSchedule,
    can_broadcast_unit: canBroadcastUnit,
    can_manage_iuran: canManageIuran,
    can_verify_iuran_payment: canVerifyIuranPayment,
    is_active: true,
  };
}

function planMetadataForRecord(record) {
  const code = asString(record.getString("code")).trim().toLowerCase();
  if (code === "admin_rt_monthly") {
    return {
      planCode: "rt",
      targetSystemRole: "operator",
      scopeLevel: "rt",
      featureFlags: ["chat_basic", "broadcast_rt", "agenda_basic", "finance_basic"],
    };
  }
  if (code === "admin_rw_monthly") {
    return {
      planCode: "rw",
      targetSystemRole: "operator",
      scopeLevel: "rw",
      featureFlags: [
        "chat_basic",
        "broadcast_rw",
        "custom_group_basic",
        "agenda_basic",
        "finance_basic",
      ],
    };
  }
  if (code === "admin_rw_pro_monthly") {
    return {
      planCode: "rw_pro",
      targetSystemRole: "operator",
      scopeLevel: "rw",
      featureFlags: [
        "chat_basic",
        "broadcast_rw",
        "custom_group_basic",
        "custom_group_advanced",
        "agenda_basic",
        "agenda_advanced",
        "finance_basic",
        "finance_publish",
        "voice_note",
        "polling",
        "export_advanced",
      ],
    };
  }
  return null;
}

function systemRoleFromLegacyRole(role) {
  switch (normalizeLegacyRole(role)) {
    case "sysadmin":
      return "sysadmin";
    case "admin_rt":
    case "admin_rw":
    case "admin_rw_pro":
      return "operator";
    case "warga":
    default:
      return "warga";
  }
}

function planCodeFromLegacyRole(role, subscriptionPlan) {
  const normalizedRole = normalizeLegacyRole(role);
  if (normalizedRole === "admin_rt") return "rt";
  if (normalizedRole === "admin_rw") return "rw";
  if (normalizedRole === "admin_rw_pro") return "rw_pro";

  const normalizedPlan = asString(subscriptionPlan).trim().toLowerCase();
  if (normalizedPlan === "admin_rt_monthly") return "rt";
  if (normalizedPlan === "admin_rw_monthly") return "rw";
  if (normalizedPlan === "admin_rw_pro_monthly") return "rw_pro";
  if (normalizedRole === "warga") return "free";
  return "";
}

function normalizeLegacyRole(role) {
  const normalized = asString(role).trim().toLowerCase();
  if (normalized === "admin") return "admin_rw";
  if (normalized === "superuser") return "sysadmin";
  if (normalized === "user" || normalized === "warga") return "warga";
  if (
    normalized === "admin_rt" ||
    normalized === "admin_rw" ||
    normalized === "admin_rw_pro" ||
    normalized === "sysadmin"
  ) {
    return normalized;
  }
  return "warga";
}

function ensureSelectFieldValues(collection, fieldName, values) {
  const field = collection.fields.getByName(fieldName);
  if (!field) {
    return;
  }
  field.values = Array.from(new Set([...(field.values || []), ...values]));
}

function addSelfRelationIfMissing(collection, fieldName) {
  if (collection.fields.getByName(fieldName)) {
    return;
  }
  collection.fields.add(
    new RelationField({
      name: fieldName,
      collectionId: collection.id,
      maxSelect: 1,
    }),
  );
}

function upsertByCode(app, collection, data) {
  let existing = null;
  try {
    existing = app.findFirstRecordByFilter(
      collection,
      `code = "${escapeFilterValue(data.code)}"`,
    );
  } catch (_) {}

  if (existing) {
    for (const [key, value] of Object.entries(data)) {
      existing.set(key, value);
    }
    app.save(existing);
    return;
  }

  const record = new Record(collection);
  for (const [key, value] of Object.entries(data)) {
    record.set(key, value);
  }
  app.save(record);
}

function applyAdminManagedRules(collection) {
  const authRule = "@request.auth.id != ''";
  const adminRule = operatorOrSysadminRule();
  collection.listRule = authRule;
  collection.viewRule = authRule;
  collection.createRule = adminRule;
  collection.updateRule = adminRule;
  collection.deleteRule = adminRule;
}

function operatorOrSysadminRule(planCodes) {
  const modernBaseRule =
    "@request.auth.system_role = 'sysadmin' || @request.auth.system_role = 'operator'";
  if (!planCodes || planCodes.length === 0) {
    const legacyRoleRule =
      "@request.auth.role = 'admin_rt' || @request.auth.role = 'admin_rw' || @request.auth.role = 'admin_rw_pro' || @request.auth.role = 'sysadmin'";
    return `${modernBaseRule} || ${legacyRoleRule}`;
  }

  const expandedPlanCodes = expandPlanHierarchy(planCodes);
  const planRule = expandedPlanCodes
    .map((planCode) => `@request.auth.plan_code = '${planCode}'`)
    .join(" || ");
  const legacyRoleRule = legacyRoleRuleForPlans(expandedPlanCodes);
  return `@request.auth.system_role = 'sysadmin' || ((@request.auth.system_role = 'operator' && (${planRule}))${legacyRoleRule ? ` || (${legacyRoleRule})` : ""})`;
}

function operatorWithPlanRule(planCodes) {
  return operatorOrSysadminRule(planCodes);
}

function expandPlanHierarchy(planCodes) {
  const hierarchy = {
    free: ["free", "rt", "rw", "rw_pro"],
    rt: ["rt", "rw", "rw_pro"],
    rw: ["rw", "rw_pro"],
    rw_pro: ["rw_pro"],
  };

  const expanded = new Set();
  for (const planCode of planCodes || []) {
    const supported = hierarchy[planCode] || [planCode];
    supported.forEach((value) => expanded.add(value));
  }

  return Array.from(expanded);
}

function legacyRoleRuleForPlans(planCodes) {
  const roles = new Set(["sysadmin"]);
  if ((planCodes || []).includes("rt")) {
    roles.add("admin_rt");
  }
  if ((planCodes || []).includes("rw")) {
    roles.add("admin_rw");
  }
  if ((planCodes || []).includes("rw_pro")) {
    roles.add("admin_rw_pro");
  }

  return Array.from(roles)
    .map((role) => `@request.auth.role = '${role}'`)
    .join(" || ");
}

function addFieldIfMissing(collection, field) {
  if (collection.fields.getByName(field.name)) {
    return;
  }
  collection.fields.add(field);
}

function findCollection(app, name) {
  try {
    return app.findCollectionByNameOrId(name);
  } catch (_) {
    return null;
  }
}

function escapeFilterValue(value) {
  return `${value ?? ""}`.replaceAll("\\", "\\\\").replaceAll("\"", "\\\"");
}

function asString(value) {
  if (value === null || value === undefined) {
    return "";
  }
  return String(value);
}
