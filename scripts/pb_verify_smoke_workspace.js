const BASE_URL = process.env.PB_BASE_URL || "http://127.0.0.1:8090";
const SUPERUSER_EMAIL =
  process.env.PB_SUPERUSER_EMAIL || "dev.superuser@local.test";
const SUPERUSER_PASSWORD =
  process.env.PB_SUPERUSER_PASSWORD || "DevSuper123!";
const USER_PASSWORD = process.env.PB_SMOKE_USER_PASSWORD || "SmokePass123!";

const USERS = [
  {
    key: "warga",
    email: "smoke.warga@local.test",
    role: "warga",
    systemRole: "warga",
    planCode: "free",
    expectedPlans: ["rt", "rw", "rw_pro"],
  },
  {
    key: "rt_ketua",
    email: "smoke.rt.ketua@local.test",
    role: "admin_rt",
    systemRole: "operator",
    planCode: "rt",
    expectedPlans: ["rt", "rw", "rw_pro"],
  },
  {
    key: "rw_bendahara",
    email: "smoke.rw.bendahara@local.test",
    role: "admin_rw",
    systemRole: "operator",
    planCode: "rw",
    expectedPlans: ["rw", "rw_pro"],
  },
  {
    key: "rw_owner",
    email: "smoke.rw.owner@local.test",
    role: "admin_rw_pro",
    systemRole: "operator",
    planCode: "rw_pro",
    expectedPlans: ["rw_pro"],
  },
];

async function main() {
  const admin = await authSuperuser();
  const adminToken = admin.token;
  const workspace = await findFirstRecord(
    adminToken,
    "workspaces",
    'code = "smoke-rw19"',
  );
  assert(workspace, "Workspace smoke-rw19 tidak ditemukan.");

  const rwConversation = await findFirstRecord(
    adminToken,
    "conversations",
    'key = "smoke-scope-rw-19"',
  );
  assert(rwConversation, "Conversation smoke-scope-rw-19 tidak ditemukan.");

  const financeAccounts = await listRecords(
    adminToken,
    "finance_accounts",
    `workspace = "${workspace.id}"`,
    20,
    1,
    "label,created",
  );
  assert(
    (financeAccounts.items || []).length >= 1,
    "Finance account smoke belum tersedia.",
  );

  const results = [];

  for (const user of USERS) {
    const session = await authUser(user.email, USER_PASSWORD);
    const record = session.record || {};
    assertEqual(record.role, user.role, `${user.key} role mismatch`);
    assertEqual(
      record.system_role,
      user.systemRole,
      `${user.key} system_role mismatch`,
    );
    assertEqual(
      record.plan_code,
      user.planCode,
      `${user.key} plan_code mismatch`,
    );

    const plans = await request("/api/rukunwarga/payments/subscription/plans", {
      method: "GET",
      token: session.token,
    });
    const returnedPlanCodes = (plans.plans || []).map((item) => item.planCode);
    assertArrayEqual(
      returnedPlanCodes,
      user.expectedPlans,
      `${user.key} accessible plan list mismatch`,
    );

    for (const plan of plans.plans || []) {
      assert(plan.planCode, `${user.key} planCode kosong.`);
      assert(plan.targetSystemRole, `${user.key} targetSystemRole kosong.`);
      assert(plan.scopeLevel, `${user.key} scopeLevel kosong.`);
      assert(Array.isArray(plan.featureFlags), `${user.key} featureFlags invalid.`);
    }

    results.push({
      user: user.key,
      auth: "ok",
      plans: returnedPlanCodes,
    });
  }

  const wargaSession = await authUser(USERS[0].email, USER_PASSWORD);
  const wargaContext = await authRefresh(wargaSession.token);
  const wargaFinance = await request(
    "/api/collections/finance_transactions/records",
    {
      method: "POST",
      token: wargaSession.token,
      body: {
        workspace: wargaContext.record.active_workspace || workspace.id,
        org_unit: financeAccounts.items[0].org_unit,
        account: financeAccounts.items[0].id,
        source_module: "manual",
        direction: "in",
        category: "uji",
        title: "Warga tidak boleh create finance",
        amount: 10000,
        payment_method: "cash",
        maker_member: wargaContext.record.active_workspace_member || "",
        approval_status: "approved",
        publish_status: "pending",
      },
      allowedStatus: [400, 403],
    },
  );
  results.push({
    user: "warga",
    financeCreateForbidden: isForbiddenStatus(wargaFinance.status),
  });

  const rtSession = await authUser(USERS[1].email, USER_PASSWORD);
  const rtMessage = await createUserMessage(
    rtSession.token,
    rwConversation.id,
    "Temp poll message RT forbidden",
  );
  const rtPollAttempt = await request("/api/collections/chat_polls/records", {
    method: "POST",
    token: rtSession.token,
    body: {
      workspace: workspace.id,
      conversation: rwConversation.id,
      message: rtMessage.id,
      title: "RT should not create poll",
      allow_multiple_choice: false,
      allow_anonymous_vote: false,
      status: "open",
    },
    allowedStatus: [400, 403],
  });
  results.push({
    user: "rt_ketua",
    pollCreateForbidden: isForbiddenStatus(rtPollAttempt.status),
  });

  const rwSession = await authUser(USERS[2].email, USER_PASSWORD);
  const rwContext = await authRefresh(rwSession.token);
  const rwMessage = await createUserMessage(
    rwSession.token,
    rwConversation.id,
    "Temp poll message RW forbidden",
  );
  const rwPollAttempt = await request("/api/collections/chat_polls/records", {
    method: "POST",
    token: rwSession.token,
    body: {
      workspace: workspace.id,
      conversation: rwConversation.id,
      message: rwMessage.id,
      title: "RW should not create poll",
      allow_multiple_choice: false,
      allow_anonymous_vote: false,
      status: "open",
    },
    allowedStatus: [400, 403],
  });
  results.push({
    user: "rw_bendahara",
    pollCreateForbidden: isForbiddenStatus(rwPollAttempt.status),
  });

  const rwProSession = await authUser(USERS[3].email, USER_PASSWORD);
  const rwProMessage = await createUserMessage(
    rwProSession.token,
    rwConversation.id,
    "Temp poll message RW Pro allowed",
  );
  const rwProPoll = await request("/api/collections/chat_polls/records", {
    method: "POST",
    token: rwProSession.token,
    body: {
      workspace: workspace.id,
      conversation: rwConversation.id,
      message: rwProMessage.id,
      title: "RW Pro allowed poll",
      allow_multiple_choice: false,
      allow_anonymous_vote: false,
      status: "open",
    },
  });

  await request("/api/collections/chat_poll_options/records", {
    method: "POST",
    token: rwProSession.token,
    body: {
      poll: rwProPoll.id,
      label: "Ya",
      sort_order: 1,
    },
  });
  await request("/api/collections/chat_poll_options/records", {
    method: "POST",
    token: rwProSession.token,
    body: {
      poll: rwProPoll.id,
      label: "Tidak",
      sort_order: 2,
    },
  });

  results.push({
    user: "rw_owner",
    pollCreateAllowed: !!rwProPoll.id,
  });

  const financeByRw = await request("/api/collections/finance_transactions/records", {
    method: "POST",
    token: rwSession.token,
    body: {
      workspace: rwContext.record.active_workspace || workspace.id,
      org_unit: financeAccounts.items[0].org_unit,
      account: financeAccounts.items[0].id,
      source_module: "manual",
      direction: "out",
      category: "uji",
      title: "RW direct finance create smoke",
      description: "Verifikasi create rule operator",
      amount: 50000,
      payment_method: "transfer",
      maker_member: rwContext.record.active_workspace_member || "",
      approval_status: "submitted",
      publish_status: "pending",
    },
  });
  results.push({
    user: "rw_bendahara",
    financeCreateAllowed: !!financeByRw.id,
  });

  console.log(
    JSON.stringify(
      {
        ok: true,
        baseUrl: BASE_URL,
        checks: results,
      },
      null,
      2,
    ),
  );
}

async function createUserMessage(token, conversationId, text) {
  const auth = await authRefresh(token);
  return request("/api/collections/messages/records", {
    method: "POST",
    token,
    body: {
      conversation: conversationId,
      workspace: auth.record.active_workspace || "",
      sender: auth.record.id,
      sender_member: auth.record.active_workspace_member || "",
      text,
      message_type: "text",
      is_starred: false,
      is_pinned: false,
    },
  });
}

async function authRefresh(token) {
  return request("/api/collections/users/auth-refresh", {
    method: "POST",
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

async function authUser(email, password) {
  return request("/api/collections/users/auth-with-password", {
    method: "POST",
    body: {
      identity: email,
      password,
    },
  });
}

async function findFirstRecord(token, collection, filter) {
  const result = await listRecords(token, collection, filter, 1, 1);
  return result.items && result.items.length > 0 ? result.items[0] : null;
}

async function listRecords(token, collection, filter, perPage, page, sort) {
  const params = new URLSearchParams();
  if (filter) params.set("filter", filter);
  if (perPage) params.set("perPage", String(perPage));
  if (page) params.set("page", String(page));
  if (sort) params.set("sort", sort);
  return request(`/api/collections/${collection}/records?${params.toString()}`, {
    method: "GET",
    token,
  });
}

async function request(path, options) {
  const allowedStatus = options.allowedStatus || [200, 201];
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
  data.status = response.status;
  if (!allowedStatus.includes(response.status)) {
    throw new Error(
      `${options.method || "GET"} ${path} failed: ${response.status} ${JSON.stringify(data)}`,
    );
  }
  return data;
}

function assert(condition, message) {
  if (!condition) {
    throw new Error(message);
  }
}

function assertEqual(actual, expected, message) {
  if (actual !== expected) {
    throw new Error(`${message}: expected=${expected} actual=${actual}`);
  }
}

function assertArrayEqual(actual, expected, message) {
  const left = [...actual].sort().join(",");
  const right = [...expected].sort().join(",");
  if (left !== right) {
    throw new Error(`${message}: expected=${right} actual=${left}`);
  }
}

function isForbiddenStatus(status) {
  return status === 400 || status === 403;
}

main().catch((error) => {
  console.error(error.stack || String(error));
  process.exitCode = 1;
});
