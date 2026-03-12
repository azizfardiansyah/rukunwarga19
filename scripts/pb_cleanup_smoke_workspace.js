const BASE_URL = process.env.PB_BASE_URL || "http://127.0.0.1:8090";
const SUPERUSER_EMAIL =
  process.env.PB_SUPERUSER_EMAIL || "dev.superuser@local.test";
const SUPERUSER_PASSWORD =
  process.env.PB_SUPERUSER_PASSWORD || "DevSuper123!";

const SMOKE_WORKSPACE_CODE = process.env.PB_SMOKE_WORKSPACE_CODE || "smoke-rw19";
const SMOKE_EMAIL_PREFIX = process.env.PB_SMOKE_EMAIL_PREFIX || "smoke.";
const PAGE_SIZE = 200;

async function main() {
  const admin = await authSuperuser();
  const token = admin.token;

  const allUsers = await listAllRecords(token, "users");
  const smokeUsers = allUsers.filter((user) =>
    String(user.email || "").toLowerCase().startsWith(SMOKE_EMAIL_PREFIX),
  );
  const smokeUserIds = new Set(smokeUsers.map((user) => user.id));

  const workspace = await findFirstRecord(
    token,
    "workspaces",
    `code = "${escapeFilter(SMOKE_WORKSPACE_CODE)}"`,
  );
  const workspaceId = workspace?.id || "";

  if (!workspaceId && smokeUsers.length === 0) {
    console.log(
      JSON.stringify(
        {
          ok: true,
          deleted: {},
          message: "Tidak ada data smoke yang ditemukan.",
        },
        null,
        2,
      ),
    );
    return;
  }

  const workspaceMembers = workspaceId
    ? await listAllRecords(
        token,
        "workspace_members",
        `workspace = "${escapeFilter(workspaceId)}"`,
      )
    : [];
  const workspaceMemberIds = new Set(workspaceMembers.map((item) => item.id));

  if (workspaceId) {
    await updateRecord(token, "workspaces", workspaceId, { owner_member: null });
  }

  for (const user of allUsers) {
    const activeWorkspace = String(user.active_workspace || "");
    const activeWorkspaceMember = String(user.active_workspace_member || "");
    if (
      activeWorkspace === workspaceId ||
      workspaceMemberIds.has(activeWorkspaceMember)
    ) {
      await updateRecord(token, "users", user.id, {
        active_workspace: null,
        active_workspace_member: null,
      });
    }
  }

  const orgMemberships = await listByWorkspace(token, "org_memberships", workspaceId);
  const orgUnits = await listByWorkspace(token, "org_units", workspaceId);
  const financeAccounts = await listByWorkspace(token, "finance_accounts", workspaceId);
  const financeTransactions = await listByWorkspace(
    token,
    "finance_transactions",
    workspaceId,
  );
  const conversations = await listByWorkspace(token, "conversations", workspaceId);
  const announcements = await listByWorkspace(token, "announcements", workspaceId);
  const messages = await listByWorkspace(token, "messages", workspaceId);
  const polls = await listByWorkspace(token, "chat_polls", workspaceId);
  const subscriptionTransactions = await listWorkspaceMemberScopedRecords(
    token,
    "subscription_transactions",
    workspaceId,
    [...workspaceMemberIds],
    [...smokeUserIds],
    "workspace",
    "workspace_member",
    "subscriber",
  );
  const roleRequests = await listWorkspaceMemberScopedRecords(
    token,
    "role_requests",
    "",
    [],
    [...smokeUserIds],
    "",
    "",
    "requester",
    "reviewer",
    [...smokeUserIds],
  );

  const conversationIds = conversations.map((item) => item.id);
  const messageIds = messages.map((item) => item.id);
  const announcementIds = announcements.map((item) => item.id);
  const pollIds = polls.map((item) => item.id);
  const transactionIds = financeTransactions.map((item) => item.id);

  const conversationMembers = await listRelationScopedRecords(
    token,
    "conversation_members",
    "conversation",
    conversationIds,
    "user",
    [...smokeUserIds],
  );
  const messageReads = await listRelationScopedRecords(
    token,
    "message_reads",
    "message",
    messageIds,
    "user",
    [...smokeUserIds],
  );
  const messageReactions = await listRelationScopedRecords(
    token,
    "message_reactions",
    "message",
    messageIds,
    "user",
    [...smokeUserIds],
  );
  const announcementViews = await listRelationScopedRecords(
    token,
    "announcement_views",
    "announcement",
    announcementIds,
    "user",
    [...smokeUserIds],
  );
  const pollOptions = await listRelationScopedRecords(
    token,
    "chat_poll_options",
    "poll",
    pollIds,
  );
  const pollVotes = await listWorkspaceMemberScopedRecords(
    token,
    "chat_poll_votes",
    "",
    [...workspaceMemberIds],
    [...smokeUserIds],
    "",
    "workspace_member",
    "user",
    "poll",
    pollIds,
  );
  const financeApprovals = await listRelationScopedRecords(
    token,
    "finance_approvals",
    "transaction",
    transactionIds,
  );

  const deleted = {};

  deleted.announcementViews = await deleteRecords(
    token,
    "announcement_views",
    announcementViews,
  );
  deleted.messageReads = await deleteRecords(token, "message_reads", messageReads);
  deleted.messageReactions = await deleteRecords(
    token,
    "message_reactions",
    messageReactions,
  );
  deleted.conversationMembers = await deleteRecords(
    token,
    "conversation_members",
    conversationMembers,
  );
  deleted.pollVotes = await deleteRecords(token, "chat_poll_votes", pollVotes);
  deleted.pollOptions = await deleteRecords(token, "chat_poll_options", pollOptions);
  deleted.financeApprovals = await deleteRecords(
    token,
    "finance_approvals",
    financeApprovals,
  );
  deleted.roleRequests = await deleteRecords(token, "role_requests", roleRequests);
  deleted.subscriptionTransactions = await deleteRecords(
    token,
    "subscription_transactions",
    subscriptionTransactions,
  );
  deleted.polls = await deleteRecords(token, "chat_polls", polls);
  deleted.messages = await deleteRecords(token, "messages", messages);
  deleted.announcements = await deleteRecords(token, "announcements", announcements);
  deleted.conversations = await deleteRecords(token, "conversations", conversations);
  deleted.financeTransactions = await deleteRecords(
    token,
    "finance_transactions",
    financeTransactions,
  );
  deleted.financeAccounts = await deleteRecords(
    token,
    "finance_accounts",
    financeAccounts,
  );
  deleted.orgMemberships = await deleteRecords(
    token,
    "org_memberships",
    orgMemberships,
  );
  deleted.orgUnits = await deleteRecords(token, "org_units", orgUnits);
  deleted.workspaceMembers = await deleteRecords(
    token,
    "workspace_members",
    workspaceMembers,
  );
  deleted.smokeUsers = await deleteRecords(token, "users", smokeUsers);
  deleted.workspace = workspaceId
    ? await deleteRecord(token, "workspaces", workspaceId).then(() => 1)
    : 0;

  console.log(
    JSON.stringify(
      {
        ok: true,
        workspaceCode: SMOKE_WORKSPACE_CODE,
        workspaceId,
        smokeUsers: smokeUsers.map((user) => user.email),
        deleted,
      },
      null,
      2,
    ),
  );
}

async function listByWorkspace(token, collection, workspaceId) {
  if (!workspaceId) {
    return [];
  }
  return listAllRecords(
    token,
    collection,
    `workspace = "${escapeFilter(workspaceId)}"`,
  );
}

async function listRelationScopedRecords(
  token,
  collection,
  primaryField,
  primaryIds,
  secondaryField,
  secondaryIds,
) {
  const filters = [];
  const primaryFilter = orFilter(primaryField, primaryIds || []);
  if (primaryFilter) {
    filters.push(primaryFilter);
  }
  const secondaryFilter = orFilter(secondaryField, secondaryIds || []);
  if (secondaryFilter) {
    filters.push(secondaryFilter);
  }
  if (filters.length === 0) {
    return [];
  }
  return listAllRecords(token, collection, filters.join(" || "));
}

async function listWorkspaceMemberScopedRecords(
  token,
  collection,
  workspaceId,
  workspaceMemberIds,
  userIds,
  workspaceField,
  workspaceMemberField,
  userField,
  extraField,
  extraIds,
) {
  const filters = [];
  if (workspaceField && workspaceId) {
    filters.push(`${workspaceField} = "${escapeFilter(workspaceId)}"`);
  }
  const memberFilter = orFilter(workspaceMemberField, workspaceMemberIds || []);
  if (memberFilter) {
    filters.push(memberFilter);
  }
  const userFilter = orFilter(userField, userIds || []);
  if (userFilter) {
    filters.push(userFilter);
  }
  const extraFilter = orFilter(extraField, extraIds || []);
  if (extraFilter) {
    filters.push(extraFilter);
  }
  if (filters.length === 0) {
    return [];
  }
  return listAllRecords(token, collection, filters.join(" || "));
}

async function deleteRecords(token, collection, records) {
  let count = 0;
  for (const record of records || []) {
    await deleteRecord(token, collection, record.id);
    count += 1;
  }
  return count;
}

async function deleteRecord(token, collection, id) {
  return request(`/api/collections/${collection}/records/${id}`, {
    method: "DELETE",
    token,
  });
}

async function updateRecord(token, collection, id, body) {
  return request(`/api/collections/${collection}/records/${id}`, {
    method: "PATCH",
    token,
    body,
  });
}

async function findFirstRecord(token, collection, filter) {
  const records = await listAllRecords(token, collection, filter, 1);
  return records[0] || null;
}

async function listAllRecords(token, collection, filter, perPage = PAGE_SIZE) {
  const items = [];
  let page = 1;
  let totalPages = 1;

  while (page <= totalPages) {
    const result = await listRecords(token, collection, filter, perPage, page);
    items.push(...(result.items || []));
    totalPages = result.totalPages || 1;
    page += 1;
  }

  return items;
}

async function listRecords(token, collection, filter, perPage, page) {
  const params = new URLSearchParams();
  if (filter) {
    params.set("filter", filter);
  }
  params.set("perPage", String(perPage || PAGE_SIZE));
  params.set("page", String(page || 1));
  return request(`/api/collections/${collection}/records?${params.toString()}`, {
    method: "GET",
    token,
  });
}

async function authSuperuser() {
  return request("/api/collections/_superusers/auth-with-password", {
    method: "POST",
    body: {
      identity: SUPERUSER_EMAIL,
      password: SUPERUSER_PASSWORD,
    },
  });
}

async function request(path, options) {
  const response = await fetch(`${BASE_URL}${path}`, {
    method: options.method || "GET",
    headers: {
      "Content-Type": "application/json",
      ...(options.token
        ? {
            Authorization: options.token.startsWith("Bearer ")
              ? options.token
              : `Bearer ${options.token}`,
          }
        : {}),
    },
    body: options.body ? JSON.stringify(options.body) : undefined,
  });

  const text = await response.text();
  const data = text ? JSON.parse(text) : {};
  if (!response.ok) {
    throw new Error(
      `${options.method || "GET"} ${path} failed: ${response.status} ${JSON.stringify(data)}`,
    );
  }
  return data;
}

function orFilter(field, ids) {
  if (!field || !Array.isArray(ids) || ids.length === 0) {
    return "";
  }
  return ids
    .map((id) => String(id || "").trim())
    .filter(Boolean)
    .map((id) => `${field} = "${escapeFilter(id)}"`)
    .join(" || ");
}

function escapeFilter(value) {
  return String(value || "").replaceAll("\\", "\\\\").replaceAll('"', '\\"');
}

main().catch((error) => {
  console.error(error.stack || String(error));
  process.exitCode = 1;
});
