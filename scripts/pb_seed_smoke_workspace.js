const BASE_URL = process.env.PB_BASE_URL || "http://127.0.0.1:8090";
const SUPERUSER_EMAIL =
  process.env.PB_SUPERUSER_EMAIL || "dev.superuser@local.test";
const SUPERUSER_PASSWORD =
  process.env.PB_SUPERUSER_PASSWORD || "DevSuper123!";
const USER_PASSWORD = process.env.PB_SMOKE_USER_PASSWORD || "SmokePass123!";

const NOW = new Date();
const NEXT_MONTH = new Date(NOW.getTime() + 30 * 24 * 60 * 60 * 1000);

const USERS = [
  {
    key: "warga",
    email: "smoke.warga@local.test",
    name: "Smoke Warga",
    role: "warga",
    systemRole: "warga",
    planCode: "free",
    subscriptionPlan: "",
    subscriptionStatus: "inactive",
    scopeType: "rt",
    scopeRt: 1,
    scopeRw: 19,
  },
  {
    key: "rt_ketua",
    email: "smoke.rt.ketua@local.test",
    name: "Smoke Ketua RT",
    role: "admin_rt",
    systemRole: "operator",
    planCode: "rt",
    subscriptionPlan: "admin_rt_monthly",
    subscriptionStatus: "active",
    scopeType: "rt",
    scopeRt: 1,
    scopeRw: 19,
  },
  {
    key: "rw_bendahara",
    email: "smoke.rw.bendahara@local.test",
    name: "Smoke Bendahara RW",
    role: "admin_rw",
    systemRole: "operator",
    planCode: "rw",
    subscriptionPlan: "admin_rw_monthly",
    subscriptionStatus: "active",
    scopeType: "rw",
    scopeRt: 0,
    scopeRw: 19,
  },
  {
    key: "rw_owner",
    email: "smoke.rw.owner@local.test",
    name: "Smoke Ketua RW Pro",
    role: "admin_rw_pro",
    systemRole: "operator",
    planCode: "rw_pro",
    subscriptionPlan: "admin_rw_pro_monthly",
    subscriptionStatus: "active",
    scopeType: "rw",
    scopeRt: 0,
    scopeRw: 19,
    isOwner: true,
    ownerRank: 3,
  },
  {
    key: "dkm_ketua",
    email: "smoke.dkm.ketua@local.test",
    name: "Smoke Ketua DKM",
    role: "admin_rw",
    systemRole: "operator",
    planCode: "rw",
    subscriptionPlan: "admin_rw_monthly",
    subscriptionStatus: "active",
    scopeType: "unit",
    scopeRt: 0,
    scopeRw: 19,
  },
  {
    key: "dkm_bendahara",
    email: "smoke.dkm.bendahara@local.test",
    name: "Smoke Bendahara DKM",
    role: "admin_rw",
    systemRole: "operator",
    planCode: "rw",
    subscriptionPlan: "admin_rw_monthly",
    subscriptionStatus: "active",
    scopeType: "unit",
    scopeRt: 0,
    scopeRw: 19,
  },
  {
    key: "posyandu_ketua",
    email: "smoke.posyandu.ketua@local.test",
    name: "Smoke Ketua Posyandu",
    role: "admin_rw",
    systemRole: "operator",
    planCode: "rw",
    subscriptionPlan: "admin_rw_monthly",
    subscriptionStatus: "active",
    scopeType: "unit",
    scopeRt: 0,
    scopeRw: 19,
  },
];

const WORKSPACE = {
  code: "smoke-rw19",
  name: "Smoke Workspace RW 19",
  rw: 19,
  status: "active",
  desa_code: "3174010001",
  kecamatan_code: "3174010",
  kabupaten_code: "3174",
  provinsi_code: "31",
  desa_kelurahan: "Kelurahan Smoke",
  kecamatan: "Kecamatan Smoke",
  kabupaten_kota: "Kota Smoke",
  provinsi: "DKI Jakarta",
};

const UNITS = [
  {
    key: "rw",
    code: "rw-19",
    name: "RW 19",
    type: "rw",
    is_official: true,
    scope_rw: 19,
    scope_rt: 0,
    status: "active",
  },
  {
    key: "rt01",
    code: "rt-01-rw-19",
    name: "RT 01 / RW 19",
    type: "rt",
    is_official: true,
    parentKey: "rw",
    scope_rw: 19,
    scope_rt: 1,
    status: "active",
  },
  {
    key: "dkm",
    code: "dkm-al-ikhlas",
    name: "DKM Al Ikhlas",
    type: "dkm",
    is_official: true,
    parentKey: "rw",
    scope_rw: 19,
    scope_rt: 0,
    status: "active",
  },
  {
    key: "posyandu",
    code: "posyandu-melati",
    name: "Posyandu Melati",
    type: "posyandu",
    is_official: true,
    parentKey: "rw",
    scope_rw: 19,
    scope_rt: 0,
    status: "active",
  },
  {
    key: "panitia",
    code: "panitia-agustus-2026",
    name: "Panitia Agustus 2026",
    type: "custom",
    is_official: false,
    parentKey: "rw",
    scope_rw: 19,
    scope_rt: 0,
    status: "active",
  },
];

const MEMBERSHIPS = [
  { userKey: "rw_owner", unitKey: "rw", jabatanCode: "ketua_rw", isPrimary: true },
  {
    userKey: "rw_bendahara",
    unitKey: "rw",
    jabatanCode: "bendahara_rw",
    isPrimary: true,
  },
  { userKey: "rt_ketua", unitKey: "rt01", jabatanCode: "ketua_rt", isPrimary: true },
  { userKey: "dkm_ketua", unitKey: "dkm", jabatanCode: "ketua_dkm", isPrimary: true },
  {
    userKey: "dkm_bendahara",
    unitKey: "dkm",
    jabatanCode: "bendahara_dkm",
    isPrimary: true,
  },
  {
    userKey: "posyandu_ketua",
    unitKey: "posyandu",
    jabatanCode: "ketua_posyandu",
    isPrimary: true,
  },
  {
    userKey: "rw_owner",
    unitKey: "panitia",
    jabatanCode: "panitia_agustus",
    isPrimary: false,
  },
];

const ACCOUNTS = [
  { code: "kas-rw-19", label: "Kas RW 19", type: "cash", unitKey: "rw" },
  {
    code: "kas-dkm-al-ikhlas",
    label: "Kas DKM Al Ikhlas",
    type: "cash",
    unitKey: "dkm",
  },
];

async function main() {
  const admin = await authSuperuser();
  const adminToken = admin.token;

  const seededUsers = {};
  for (const user of USERS) {
    seededUsers[user.key] = await upsertUser(adminToken, user);
  }

  const workspace = await upsertRecord(
    adminToken,
    "workspaces",
    `code = "${escapeFilter(WORKSPACE.code)}"`,
    WORKSPACE,
  );

  const unitRecords = {};
  for (const unit of UNITS) {
    const parentUnitId = unit.parentKey ? unitRecords[unit.parentKey].id : "";
    unitRecords[unit.key] = await upsertRecord(
      adminToken,
      "org_units",
      `workspace = "${workspace.id}" && code = "${escapeFilter(unit.code)}"`,
      {
        workspace: workspace.id,
        type: unit.type,
        name: unit.name,
        code: unit.code,
        is_official: unit.is_official,
        scope_rt: unit.scope_rt,
        scope_rw: unit.scope_rw,
        status: unit.status,
        parent_unit: parentUnitId,
      },
    );
  }

  const workspaceMembers = {};
  for (const user of USERS) {
    workspaceMembers[user.key] = await upsertRecord(
      adminToken,
      "workspace_members",
      `workspace = "${workspace.id}" && user = "${seededUsers[user.key].id}"`,
      {
        workspace: workspace.id,
        user: seededUsers[user.key].id,
        system_role: user.systemRole,
        plan_code: user.planCode,
        subscription_status: user.subscriptionStatus,
        subscription_started:
          user.subscriptionStatus === "active" ? NOW.toISOString() : "",
        subscription_expired:
          user.subscriptionStatus === "active" ? NEXT_MONTH.toISOString() : "",
        is_owner: user.isOwner === true,
        owner_rank: user.ownerRank || ownerRankForPlan(user.planCode),
        scope_type: user.scopeType,
        scope_rt: user.scopeRt,
        scope_rw: user.scopeRw,
        is_active: true,
      },
    );
  }

  await updateRecord(adminToken, "workspaces", workspace.id, {
    owner_member: workspaceMembers.rw_owner.id,
  });

  for (const user of USERS) {
    await updateRecord(adminToken, "users", seededUsers[user.key].id, {
      role: user.role,
      system_role: user.systemRole,
      plan_code: user.planCode,
      subscription_plan: user.subscriptionPlan,
      subscription_status: user.subscriptionStatus,
      subscription_started:
        user.subscriptionStatus === "active" ? NOW.toISOString() : "",
      subscription_expired:
        user.subscriptionStatus === "active" ? NEXT_MONTH.toISOString() : "",
      active_workspace: workspace.id,
      active_workspace_member: workspaceMembers[user.key].id,
    });
  }

  const jabatanMap = await buildJabatanMap(adminToken);
  for (const membership of MEMBERSHIPS) {
    await upsertRecord(
      adminToken,
      "org_memberships",
      [
        `workspace = "${workspace.id}"`,
        `workspace_member = "${workspaceMembers[membership.userKey].id}"`,
        `org_unit = "${unitRecords[membership.unitKey].id}"`,
        `jabatan = "${jabatanMap[membership.jabatanCode].id}"`,
      ].join(" && "),
      {
        workspace: workspace.id,
        user: seededUsers[membership.userKey].id,
        workspace_member: workspaceMembers[membership.userKey].id,
        org_unit: unitRecords[membership.unitKey].id,
        jabatan: jabatanMap[membership.jabatanCode].id,
        is_primary: membership.isPrimary === true,
        status: "active",
        period_label: "Masa Bakti Smoke 2026",
        started_at: NOW.toISOString(),
        ended_at: "",
      },
    );
  }

  const financeAccounts = {};
  for (const account of ACCOUNTS) {
    financeAccounts[account.code] = await upsertRecord(
      adminToken,
      "finance_accounts",
      `workspace = "${workspace.id}" && code = "${escapeFilter(account.code)}"`,
      {
        workspace: workspace.id,
        org_unit: unitRecords[account.unitKey].id,
        code: account.code,
        label: account.label,
        type: account.type,
        is_active: true,
      },
    );
  }

  const rwConversation = await upsertRecord(
    adminToken,
    "conversations",
    `key = "smoke-scope-rw-19"`,
    {
      key: "smoke-scope-rw-19",
      type: "group_rw",
      name: "Forum RW 19 Smoke",
      workspace: workspace.id,
      scope_type: "rw",
      required_plan_code: "rt",
      created_by: seededUsers.rw_owner.id,
      rt: 0,
      rw: 19,
      desa_code: WORKSPACE.desa_code,
      kecamatan_code: WORKSPACE.kecamatan_code,
      kabupaten_code: WORKSPACE.kabupaten_code,
      provinsi_code: WORKSPACE.provinsi_code,
      desa_kelurahan: WORKSPACE.desa_kelurahan,
      kecamatan: WORKSPACE.kecamatan,
      kabupaten_kota: WORKSPACE.kabupaten_kota,
      provinsi: WORKSPACE.provinsi,
      is_readonly: false,
      last_message: "Seed smoke conversation",
      last_message_at: NOW.toISOString(),
    },
  );

  const dkmConversation = await upsertRecord(
    adminToken,
    "conversations",
    `key = "smoke-scope-dkm"`,
    {
      key: "smoke-scope-dkm",
      type: "group_rw",
      name: "DKM Smoke",
      workspace: workspace.id,
      scope_type: "dkm",
      org_unit: unitRecords.dkm.id,
      required_plan_code: "rw",
      created_by: seededUsers.dkm_ketua.id,
      rt: 0,
      rw: 19,
      desa_code: WORKSPACE.desa_code,
      kecamatan_code: WORKSPACE.kecamatan_code,
      kabupaten_code: WORKSPACE.kabupaten_code,
      provinsi_code: WORKSPACE.provinsi_code,
      desa_kelurahan: WORKSPACE.desa_kelurahan,
      kecamatan: WORKSPACE.kecamatan,
      kabupaten_kota: WORKSPACE.kabupaten_kota,
      provinsi: WORKSPACE.provinsi,
      is_readonly: false,
      last_message: "DKM smoke conversation",
      last_message_at: NOW.toISOString(),
    },
  );

  const pollMessage = await upsertRecord(
    adminToken,
    "messages",
    `conversation = "${dkmConversation.id}" && text = "Polling agenda DKM smoke"`,
    {
      conversation: dkmConversation.id,
      workspace: workspace.id,
      sender: seededUsers.rw_owner.id,
      sender_member: workspaceMembers.rw_owner.id,
      text: "Polling agenda DKM smoke",
      message_type: "poll",
      sender_badge_label: "Operator RW Pro",
      is_starred: false,
      is_pinned: false,
    },
  );

  const pollRecord = await upsertRecord(
    adminToken,
    "chat_polls",
    `message = "${pollMessage.id}"`,
    {
      workspace: workspace.id,
      conversation: dkmConversation.id,
      message: pollMessage.id,
      title: "Agenda DKM smoke minggu ini",
      allow_multiple_choice: false,
      allow_anonymous_vote: false,
      status: "open",
      closed_at: "",
    },
  );

  await updateRecord(adminToken, "messages", pollMessage.id, {
    poll: pollRecord.id,
  });

  const pollOptions = ["Kajian", "Kerja bakti", "Rapat pengurus"];
  for (let index = 0; index < pollOptions.length; index += 1) {
    await upsertRecord(
      adminToken,
      "chat_poll_options",
      `poll = "${pollRecord.id}" && label = "${escapeFilter(pollOptions[index])}"`,
      {
        poll: pollRecord.id,
        label: pollOptions[index],
        sort_order: index + 1,
      },
    );
  }

  const rwIncome = await upsertRecord(
    adminToken,
    "finance_transactions",
    `workspace = "${workspace.id}" && title = "Iuran cash smoke RW"`,
    {
      workspace: workspace.id,
      org_unit: unitRecords.rw.id,
      account: financeAccounts["kas-rw-19"].id,
      source_module: "manual",
      direction: "in",
      category: "iuran",
      title: "Iuran cash smoke RW",
      description: "Seed smoke pemasukan cash RW",
      amount: 250000,
      payment_method: "cash",
      maker_member: workspaceMembers.rw_bendahara.id,
      maker_jabatan_snapshot: "Bendahara RW",
      approval_status: "approved",
      publish_status: "published",
      submitted_at: NOW.toISOString(),
      approved_at: NOW.toISOString(),
      published_at: NOW.toISOString(),
    },
  );

  const rwExpense = await upsertRecord(
    adminToken,
    "finance_transactions",
    `workspace = "${workspace.id}" && title = "Pengeluaran transfer smoke RW"`,
    {
      workspace: workspace.id,
      org_unit: unitRecords.rw.id,
      account: financeAccounts["kas-rw-19"].id,
      source_module: "manual",
      direction: "out",
      category: "operasional",
      title: "Pengeluaran transfer smoke RW",
      description: "Seed smoke pengeluaran RW menunggu approval",
      amount: 100000,
      payment_method: "transfer",
      maker_member: workspaceMembers.rw_bendahara.id,
      maker_jabatan_snapshot: "Bendahara RW",
      approval_status: "submitted",
      publish_status: "pending",
      submitted_at: NOW.toISOString(),
    },
  );

  await upsertRecord(
    adminToken,
    "finance_approvals",
    `transaction = "${rwExpense.id}" && checker_member = "${workspaceMembers.rw_owner.id}"`,
    {
      transaction: rwExpense.id,
      checker_member: workspaceMembers.rw_owner.id,
      checker_jabatan_snapshot: "Ketua RW",
      decision: "approved",
      note: "Seed smoke approval",
    },
  );

  await updateRecord(adminToken, "finance_transactions", rwExpense.id, {
    approval_status: "approved",
    approved_at: NOW.toISOString(),
  });

  const financeAnnouncement = await upsertRecord(
    adminToken,
    "announcements",
    `workspace = "${workspace.id}" && title = "Pengumuman keuangan smoke RW"`,
    {
      workspace: workspace.id,
      org_unit: unitRecords.rw.id,
      author: seededUsers.rw_owner.id,
      title: "Pengumuman keuangan smoke RW",
      content: "Pemasukan dan pengeluaran smoke RW sudah terverifikasi.",
      target_type: "rw",
      rt: 0,
      rw: 19,
      source_module: "finance",
      publish_state: "published",
      published_by_member: workspaceMembers.rw_owner.id,
      is_published: true,
      desa_code: WORKSPACE.desa_code,
      kecamatan_code: WORKSPACE.kecamatan_code,
      kabupaten_code: WORKSPACE.kabupaten_code,
      provinsi_code: WORKSPACE.provinsi_code,
      desa_kelurahan: WORKSPACE.desa_kelurahan,
      kecamatan: WORKSPACE.kecamatan,
      kabupaten_kota: WORKSPACE.kabupaten_kota,
      provinsi: WORKSPACE.provinsi,
    },
  );

  console.log(
    JSON.stringify(
      {
        ok: true,
        baseUrl: BASE_URL,
        workspace: { id: workspace.id, code: workspace.code, name: workspace.name },
        users: USERS.map((user) => ({
          key: user.key,
          email: user.email,
          password: USER_PASSWORD,
          role: user.role,
          systemRole: user.systemRole,
          planCode: user.planCode,
        })),
        seeded: {
          rwConversationId: rwConversation.id,
          dkmConversationId: dkmConversation.id,
          pollMessageId: pollMessage.id,
          pollId: pollRecord.id,
          rwIncomeId: rwIncome.id,
          rwExpenseId: rwExpense.id,
          financeAnnouncementId: financeAnnouncement.id,
        },
      },
      null,
      2,
    ),
  );
}

async function buildJabatanMap(token) {
  const records = await listRecords(
    token,
    "jabatan_master",
    'is_active = true',
    200,
    1,
    "sort_order,created",
  );
  const map = {};
  for (const item of records.items || []) {
    map[item.code] = item;
  }
  return map;
}

async function upsertUser(token, user) {
  const filter = `email = "${escapeFilter(user.email)}"`;
  const existing = await findFirstRecord(token, "users", filter);
  const body = {
    email: user.email,
    emailVisibility: true,
    password: USER_PASSWORD,
    passwordConfirm: USER_PASSWORD,
    name: user.name,
    role: user.role,
    system_role: user.systemRole,
    plan_code: user.planCode,
    subscription_plan: user.subscriptionPlan,
    subscription_status: user.subscriptionStatus,
    subscription_started:
      user.subscriptionStatus === "active" ? NOW.toISOString() : "",
    subscription_expired:
      user.subscriptionStatus === "active" ? NEXT_MONTH.toISOString() : "",
  };

  if (existing) {
    return updateRecord(token, "users", existing.id, body);
  }
  return createRecord(token, "users", body);
}

async function upsertRecord(token, collection, filter, body) {
  const existing = await findFirstRecord(token, collection, filter);
  if (existing) {
    return updateRecord(token, collection, existing.id, body);
  }
  return createRecord(token, collection, body);
}

async function createRecord(token, collection, body) {
  return request(`/api/collections/${collection}/records`, {
    method: "POST",
    token,
    body,
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

function ownerRankForPlan(planCode) {
  switch (planCode) {
    case "rt":
      return 1;
    case "rw":
      return 2;
    case "rw_pro":
      return 3;
    default:
      return 0;
  }
}

function escapeFilter(value) {
  return String(value || "").replaceAll("\\", "\\\\").replaceAll('"', '\\"');
}

main().catch((error) => {
  console.error(error.stack || String(error));
  process.exitCode = 1;
});
