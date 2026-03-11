/// <reference path="../pb_data/types.d.ts" />

const USERS_COLLECTION = "users";
const SUBSCRIPTION_PLANS_COLLECTION = "subscription_plans";
const SUBSCRIPTION_TRANSACTIONS_COLLECTION = "subscription_transactions";

const DEFAULT_SUBSCRIPTION_PLANS = {
  admin_rt_monthly: {
    code: "admin_rt_monthly",
    name: "Admin RT Bulanan",
    description: "Langganan dashboard dan operasional Admin RT selama 30 hari.",
    amount: 30000,
    durationDays: 30,
    currency: "IDR",
    targetRole: "admin_rt",
    isActive: true,
    sortOrder: 10,
  },
  admin_rw_monthly: {
    code: "admin_rw_monthly",
    name: "Admin RW Bulanan",
    description: "Langganan dashboard RW dan akses lintas wilayah selama 30 hari.",
    amount: 100000,
    durationDays: 30,
    currency: "IDR",
    targetRole: "admin_rw",
    isActive: true,
    sortOrder: 20,
  },
  admin_rw_pro_monthly: {
    code: "admin_rw_pro_monthly",
    name: "Admin RW Pro Bulanan",
    description: "Langganan Admin RW Pro dengan OCR dan integrasi pembayaran selama 30 hari.",
    amount: 250000,
    durationDays: 30,
    currency: "IDR",
    targetRole: "admin_rw_pro",
    isActive: true,
    sortOrder: 30,
  },
};

function inferPlanCode(planCodeOrSku, targetRole) {
  const normalizedPlan = asString(planCodeOrSku).trim().toLowerCase();
  if (normalizedPlan === "rt" || normalizedPlan === "admin_rt_monthly") {
    return "rt";
  }
  if (normalizedPlan === "rw" || normalizedPlan === "admin_rw_monthly") {
    return "rw";
  }
  if (normalizedPlan === "rw_pro" || normalizedPlan === "admin_rw_pro_monthly") {
    return "rw_pro";
  }

  const normalizedRole = normalizeUserRole(targetRole);
  if (normalizedRole === "admin_rt") {
    return "rt";
  }
  if (normalizedRole === "admin_rw") {
    return "rw";
  }
  if (normalizedRole === "admin_rw_pro") {
    return "rw_pro";
  }
  return "free";
}

function inferTargetSystemRole(targetRole) {
  const normalizedRole = normalizeUserRole(targetRole);
  if (normalizedRole === "sysadmin") {
    return "sysadmin";
  }
  if (
    normalizedRole === "admin_rt" ||
    normalizedRole === "admin_rw" ||
    normalizedRole === "admin_rw_pro"
  ) {
    return "operator";
  }
  return "warga";
}

function inferScopeLevel(planCodeOrSku, targetRole) {
  const planCode = inferPlanCode(planCodeOrSku, targetRole);
  if (planCode === "rt") {
    return "rt";
  }
  if (planCode === "rw" || planCode === "rw_pro") {
    return "rw";
  }
  return "self";
}

function featureFlagsForPlan(planCodeOrSku, targetRole) {
  const planCode = inferPlanCode(planCodeOrSku, targetRole);
  if (planCode === "rt") {
    return ["chat_basic", "broadcast_rt", "agenda_basic", "finance_basic"];
  }
  if (planCode === "rw") {
    return [
      "chat_basic",
      "broadcast_rw",
      "custom_group_basic",
      "agenda_basic",
      "finance_basic",
      "finance_publish",
    ];
  }
  if (planCode === "rw_pro") {
    return [
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
    ];
  }
  return ["chat_basic"];
}

function applyUserAccessSubscription(
  userRecord,
  targetRole,
  subscriptionPlanCode,
  startedAt,
  expiredAt,
) {
  const normalizedRole = normalizeUserRole(targetRole);
  userRecord.set("role", normalizedRole || "warga");
  userRecord.set("system_role", inferTargetSystemRole(normalizedRole));
  userRecord.set("plan_code", inferPlanCode(subscriptionPlanCode, normalizedRole));
  userRecord.set("subscription_plan", asString(subscriptionPlanCode));
  userRecord.set("subscription_status", "active");
  userRecord.set("subscription_started", startedAt);
  userRecord.set("subscription_expired", expiredAt);
}

function requireUserAuth(e) {
  const info = e.requestInfo();

  if (!info.auth) {
    throw e.unauthorizedError("Autentikasi dibutuhkan.", null);
  }

  return info.auth;
}

function getMidtransConfig() {
  const isProduction = isTruthy($os.getenv("RW_MIDTRANS_IS_PRODUCTION"));

  return {
    isProduction: isProduction,
    serverKey: asString($os.getenv("RW_MIDTRANS_SERVER_KEY")),
    clientKey: asString($os.getenv("RW_MIDTRANS_CLIENT_KEY")),
    merchantId: asString($os.getenv("RW_MIDTRANS_MERCHANT_ID")),
    notificationUrl: asString($os.getenv("RW_MIDTRANS_NOTIFICATION_URL")),
    finishUrl: asString($os.getenv("RW_MIDTRANS_FINISH_URL")),
  };
}

function getPlanList(role) {
  return getPlanListForRole(role || "");
}

function getPlanListForRole(role) {
  const planCollection = safeFindCollectionByNameOrId(
    SUBSCRIPTION_PLANS_COLLECTION,
  );
  const normalizedRole = normalizeUserRole(role);

  if (!canSelfSubscribe(normalizedRole)) {
    return [];
  }

  if (!planCollection) {
    return getDefaultPlanList(normalizedRole);
  }

  const records = $app.findRecordsByFilter(
    SUBSCRIPTION_PLANS_COLLECTION,
    "is_active = true",
    "sort_order,created",
    100,
    0,
  );

  const plans = [];
  for (const record of records) {
    if (!record) {
      continue;
    }

    const plan = serializePlanRecord(record);
    if (canPurchasePlan(normalizedRole, plan.targetRole)) {
      plans.push(plan);
    }
  }

  if (plans.length > 0) {
    return plans;
  }

  return getDefaultPlanList(normalizedRole);
}

function findSubscriptionPlan(planCode) {
  const normalizedCode = asString(planCode);
  if (!normalizedCode) {
    return null;
  }

  const planCollection = safeFindCollectionByNameOrId(
    SUBSCRIPTION_PLANS_COLLECTION,
  );

  if (!planCollection) {
    return DEFAULT_SUBSCRIPTION_PLANS[normalizedCode] || null;
  }

  try {
    const record = $app.findFirstRecordByFilter(
      SUBSCRIPTION_PLANS_COLLECTION,
      "code = {:code} && is_active = true",
      { code: normalizedCode },
    );

    if (!record) {
      return null;
    }

    return serializePlanRecord(record);
  } catch (_) {
    return null;
  }
}

function getDefaultPlanList(role) {
  if (!canSelfSubscribe(role)) {
    return [];
  }

  const plans = Object.keys(DEFAULT_SUBSCRIPTION_PLANS)
    .map(function (key) {
      return DEFAULT_SUBSCRIPTION_PLANS[key];
    })
    .filter(function (plan) {
      return canPurchasePlan(role, plan.targetRole);
    });

  plans.sort(function (left, right) {
    return (left.sortOrder || 0) - (right.sortOrder || 0);
  });

  return plans;
}

function serializePlanRecord(record) {
  const targetRole = normalizeUserRole(record.getString("target_role"));
  const planCode =
    asString(record.getString("plan_code")) ||
    inferPlanCode(record.getString("code"), targetRole);
  return {
    code: record.getString("code"),
    name: record.getString("name"),
    description: record.getString("description"),
    planCode: planCode,
    amount: record.getInt("amount"),
    durationDays: record.getInt("duration_days"),
    currency: asString(record.getString("currency")) || "IDR",
    targetRole: targetRole,
    targetSystemRole:
      asString(record.getString("target_system_role")) ||
      inferTargetSystemRole(targetRole),
    scopeLevel:
      asString(record.getString("scope_level")) ||
      inferScopeLevel(planCode, targetRole),
    featureFlags: featureFlagsForPlan(planCode, targetRole),
    isActive: record.getBool("is_active"),
    sortOrder: record.getInt("sort_order"),
  };
}

function ensurePlanAllowedForRole(plan, role, e) {
  if (!canSelfSubscribe(role)) {
    throw e.forbiddenError(
      "Role akun ini tidak dapat melakukan checkout subscription.",
      null,
    );
  }

  if (!canPurchasePlan(role, plan.targetRole)) {
    throw e.badRequestError("Plan subscription tidak sesuai dengan role user.", {
      role: role,
      planCode: plan.code,
      targetRole: plan.targetRole,
    });
  }
}

function normalizeUserRole(role) {
  const normalized = asString(role).trim().toLowerCase();

  if (normalized === "admin") {
    return "admin_rw";
  }

  if (normalized === "superuser") {
    return "sysadmin";
  }

  if (normalized === "user" || normalized === "warga") {
    return "warga";
  }

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

function requiresSubscriptionRole(role) {
  return role === "admin_rt" || role === "admin_rw" || role === "admin_rw_pro";
}

function canSelfSubscribe(role) {
  return role === "warga" || requiresSubscriptionRole(role);
}

function roleRank(role) {
  switch (role) {
    case "admin_rt":
      return 1;
    case "admin_rw":
      return 2;
    case "admin_rw_pro":
      return 3;
    case "sysadmin":
      return 99;
    case "warga":
    default:
      return 0;
  }
}

function canPurchasePlan(currentRole, targetRole) {
  if (!requiresSubscriptionRole(targetRole)) {
    return false;
  }

  if (currentRole === "sysadmin") {
    return false;
  }

  if (currentRole === "warga") {
    return true;
  }

  return roleRank(targetRole) >= roleRank(currentRole);
}

function safeFindCollectionByNameOrId(collectionName) {
  try {
    return $app.findCollectionByNameOrId(collectionName);
  } catch (_) {
    return null;
  }
}

function getSnapTransactionUrl(config) {
  if (config.isProduction) {
    return "https://app.midtrans.com/snap/v1/transactions";
  }

  return "https://app.sandbox.midtrans.com/snap/v1/transactions";
}

function getStatusTransactionUrl(config, orderId) {
  if (config.isProduction) {
    return "https://api.midtrans.com/v2/" + orderId + "/status";
  }

  return "https://api.sandbox.midtrans.com/v2/" + orderId + "/status";
}

function buildSnapPayload(authRecord, plan, orderId, requestBody, config) {
  const payload = {
    transaction_details: {
      order_id: orderId,
      gross_amount: plan.amount,
    },
    item_details: [
      {
        id: plan.code,
        name: plan.name,
        price: plan.amount,
        quantity: 1,
      },
    ],
    customer_details: {
      first_name: getUserDisplayName(authRecord),
      email: authRecord.getString("email"),
      phone: getUserPhone(authRecord),
    },
    custom_field1: plan.code,
    custom_field2: authRecord.id,
    custom_field3: "rukunwarga-subscription",
  };

  const enabledPayments = requestBody.enabledPayments;

  if (Array.isArray(enabledPayments) && enabledPayments.length > 0) {
    payload.enabled_payments = enabledPayments;
  }

  if (config.finishUrl) {
    payload.callbacks = {
      finish: config.finishUrl,
    };
  }

  return payload;
}

function midtransApiRequest(method, url, payload, config, allowNotificationOverride) {
  const headers = {
    Accept: "application/json",
    "Content-Type": "application/json",
    Authorization: "Basic " + base64Encode(config.serverKey + ":"),
  };

  if (allowNotificationOverride && config.notificationUrl) {
    headers["X-Override-Notification"] = config.notificationUrl;
  }

  return $http.send({
    method: method,
    url: url,
    headers: headers,
    body: payload ? serializeJson(payload) : "",
    timeout: 120,
  });
}

function syncTransactionWithMidtrans(transactionRecord) {
  const config = getMidtransConfig();

  if (!config.serverKey) {
    throw new Error("Server Key Midtrans belum dikonfigurasi.");
  }

  const orderId = transactionRecord.getString("order_id");
  const response = midtransApiRequest(
    "GET",
    getStatusTransactionUrl(config, orderId),
    null,
    config,
    false,
  );

  if (response.statusCode < 200 || response.statusCode >= 300) {
    throw new Error(
      "Gagal sinkron status transaksi Midtrans untuk order " + orderId + ".",
    );
  }

  const midtransData = response.json || {};

  updateTransactionFromMidtrans(transactionRecord, midtransData);
  applySubscriptionIfNeeded(transactionRecord);

  return transactionRecord;
}

function updateTransactionFromMidtrans(transactionRecord, midtransData) {
  const localState = mapMidtransStatusToLocalState(midtransData);

  transactionRecord.set("payment_state", localState);
  transactionRecord.set(
    "transaction_status",
    asString(midtransData.transaction_status),
  );
  transactionRecord.set(
    "transaction_id",
    asString(midtransData.transaction_id),
  );
  transactionRecord.set("payment_type", asString(midtransData.payment_type));
  transactionRecord.set("status_code", asString(midtransData.status_code));
  transactionRecord.set(
    "status_message",
    asString(midtransData.status_message),
  );
  transactionRecord.set("raw_midtrans_response", serializeJson(midtransData));

  $app.save(transactionRecord);
}

function applySubscriptionIfNeeded(transactionRecord) {
  const isPaid =
    transactionRecord.getString("payment_state") === "paid" &&
    !transactionRecord.getBool("subscription_applied");

  if (!isPaid) {
    return;
  }

  const subscriberId = transactionRecord.getString("subscriber");
  const periodDays = transactionRecord.getInt("period_days") || 30;
  const subscriberRecord = $app.findRecordById(USERS_COLLECTION, subscriberId);
  let targetRole = asString(transactionRecord.getString("target_role"));
  if (!targetRole) {
    const matchedPlan = findSubscriptionPlan(
      transactionRecord.getString("plan_code"),
    );
    targetRole = matchedPlan ? matchedPlan.targetRole : "";
  }
  const currentExpiry = asString(
    subscriberRecord.getString("subscription_expired"),
  );
  const now = new Date();
  let baseDate = now;

  if (currentExpiry) {
    const parsedExpiry = new Date(currentExpiry);

    if (
      !isNaN(parsedExpiry.getTime()) &&
      parsedExpiry.getTime() > now.getTime()
    ) {
      baseDate = parsedExpiry;
    }
  }

  const nextExpiry = new Date(
    baseDate.getTime() + periodDays * 24 * 60 * 60 * 1000,
  );
  const startedAt = now.toISOString();
  const expiredAt = nextExpiry.toISOString();

  if (targetRole) {
    subscriberRecord.set("role", targetRole);
  }
  subscriberRecord.set(
    "subscription_plan",
    transactionRecord.getString("plan_code"),
  );
  subscriberRecord.set("subscription_status", "active");
  subscriberRecord.set("subscription_started", startedAt);
  subscriberRecord.set("subscription_expired", expiredAt);
  $app.save(subscriberRecord);

  transactionRecord.set("subscription_applied", true);
  transactionRecord.set("subscription_started", startedAt);
  transactionRecord.set("subscription_expired", expiredAt);
  $app.save(transactionRecord);
}

function mapMidtransStatusToLocalState(midtransData) {
  const transactionStatus = asString(midtransData.transaction_status);
  const fraudStatus = asString(midtransData.fraud_status);

  if (transactionStatus === "settlement") {
    return "paid";
  }

  if (transactionStatus === "capture") {
    return fraudStatus && fraudStatus !== "accept" ? "review" : "paid";
  }

  if (
    transactionStatus === "deny" ||
    transactionStatus === "cancel" ||
    transactionStatus === "expire" ||
    transactionStatus === "failure"
  ) {
    return "failed";
  }

  if (
    transactionStatus === "refund" ||
    transactionStatus === "partial_refund" ||
    transactionStatus === "chargeback" ||
    transactionStatus === "partial_chargeback"
  ) {
    return "refunded";
  }

  if (transactionStatus === "authorize") {
    return "authorized";
  }

  return "pending";
}

function findTransactionByOrderId(orderId) {
  try {
    return $app.findFirstRecordByFilter(
      SUBSCRIPTION_TRANSACTIONS_COLLECTION,
      "order_id = {:orderId}",
      { orderId: orderId },
    );
  } catch (_) {
    return null;
  }
}

function serializeTransaction(transactionRecord) {
  return {
    id: transactionRecord.id,
    orderId: transactionRecord.getString("order_id"),
    planCode: transactionRecord.getString("plan_code"),
    targetRole: transactionRecord.getString("target_role"),
    planName: transactionRecord.getString("plan_name"),
    grossAmount: transactionRecord.getInt("gross_amount"),
    currency: transactionRecord.getString("currency"),
    snapToken: transactionRecord.getString("snap_token"),
    redirectUrl: transactionRecord.getString("redirect_url"),
    paymentState: transactionRecord.getString("payment_state"),
    transactionStatus: transactionRecord.getString("transaction_status"),
    transactionId: transactionRecord.getString("transaction_id"),
    paymentType: transactionRecord.getString("payment_type"),
    subscriptionApplied: transactionRecord.getBool("subscription_applied"),
    subscriptionStarted: transactionRecord.getString("subscription_started"),
    subscriptionExpired: transactionRecord.getString("subscription_expired"),
    statusCode: transactionRecord.getString("status_code"),
    statusMessage: transactionRecord.getString("status_message"),
    created: transactionRecord.getString("created"),
    updated: transactionRecord.getString("updated"),
  };
}

function buildOrderId(userId, planCode) {
  return (
    "SUB-" +
    planCode.toUpperCase() +
    "-" +
    userId.toUpperCase() +
    "-" +
    Date.now() +
    "-" +
    $security.randomString(6).toUpperCase()
  );
}

function getUserDisplayName(authRecord) {
  const nama = asString(authRecord.getString("nama"));

  if (nama) {
    return nama;
  }

  const name = asString(authRecord.getString("name"));

  if (name) {
    return name;
  }

  const email = asString(authRecord.getString("email"));

  if (!email) {
    return "RukunWarga User";
  }

  return email.split("@")[0];
}

function getUserPhone(authRecord) {
  const noHp = asString(authRecord.getString("no_hp"));

  if (noHp) {
    return noHp;
  }

  return asString(authRecord.getString("phone"));
}

function isTruthy(value) {
  const normalized = asString(value).toLowerCase();

  return normalized === "1" || normalized === "true" || normalized === "yes";
}

function asString(value) {
  if (value === null || value === undefined) {
    return "";
  }

  return String(value);
}

function serializeJson(value) {
  return JSON.stringify(value || {});
}

function base64Encode(input) {
  const chars =
    "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
  let output = "";
  let i = 0;

  while (i < input.length) {
    const chr1 = input.charCodeAt(i++);
    const chr2 = input.charCodeAt(i++);
    const chr3 = input.charCodeAt(i++);
    const enc1 = chr1 >> 2;
    const enc2 = ((chr1 & 3) << 4) | (chr2 >> 4);
    let enc3 = ((chr2 & 15) << 2) | (chr3 >> 6);
    let enc4 = chr3 & 63;

    if (isNaN(chr2)) {
      enc3 = 64;
      enc4 = 64;
    } else if (isNaN(chr3)) {
      enc4 = 64;
    }

    output =
      output +
      chars.charAt(enc1) +
      chars.charAt(enc2) +
      (enc3 === 64 ? "=" : chars.charAt(enc3)) +
      (enc4 === 64 ? "=" : chars.charAt(enc4));
  }

  return output;
}

globalThis.__rwSubscription = {
  handlePlans: function (e) {
    const info = e.requestInfo();
    if (!info.auth) {
      throw e.unauthorizedError("Autentikasi dibutuhkan.", null);
    }

    const authRecord = info.auth;
    const rawRole = String(authRecord.getString("role") || "")
      .trim()
      .toLowerCase();
    const userRole =
      rawRole === "admin" ? "admin_rw"
      : rawRole === "superuser" ? "sysadmin"
      : rawRole === "user" || rawRole === "warga" ? "warga"
      : rawRole === "admin_rt" ||
          rawRole === "admin_rw" ||
          rawRole === "admin_rw_pro" ||
          rawRole === "sysadmin"
      ? rawRole
      : "warga";

    if (!(userRole === "warga" || userRole === "admin_rt" || userRole === "admin_rw" || userRole === "admin_rw_pro")) {
      return e.json(200, {
        environment: "sandbox",
        plans: [],
      });
    }

    const isProduction =
      String($os.getenv("RW_MIDTRANS_IS_PRODUCTION") || "").toLowerCase() ===
        "true" ||
      String($os.getenv("RW_MIDTRANS_IS_PRODUCTION") || "").toLowerCase() ===
        "1" ||
      String($os.getenv("RW_MIDTRANS_IS_PRODUCTION") || "").toLowerCase() ===
        "yes";

    const roleRank = function (role) {
      switch (role) {
        case "admin_rt":
          return 1;
        case "admin_rw":
          return 2;
        case "admin_rw_pro":
          return 3;
        case "sysadmin":
          return 99;
        case "warga":
        default:
          return 0;
      }
    };

    const canPurchasePlan = function (currentRole, targetRole) {
      if (
        targetRole !== "admin_rt" &&
        targetRole !== "admin_rw" &&
        targetRole !== "admin_rw_pro"
      ) {
        return false;
      }

      if (currentRole === "sysadmin") {
        return false;
      }

      if (currentRole === "warga") {
        return true;
      }

      return roleRank(targetRole) >= roleRank(currentRole);
    };

    let plans = [];
    try {
      const records = $app.findRecordsByFilter(
        SUBSCRIPTION_PLANS_COLLECTION,
        "is_active = true",
        "sort_order,created",
        100,
        0,
      );

      for (const record of records) {
        if (!record) {
          continue;
        }

        const targetRole = String(record.getString("target_role") || "")
          .trim()
          .toLowerCase();
        if (!canPurchasePlan(userRole, targetRole)) {
          continue;
        }

        plans.push({
          code: record.getString("code"),
          name: record.getString("name"),
          description: record.getString("description"),
          planCode:
            asString(record.getString("plan_code")) ||
            inferPlanCode(record.getString("code"), targetRole),
          amount: record.getInt("amount"),
          durationDays: record.getInt("duration_days"),
          currency: String(record.getString("currency") || "IDR"),
          targetRole: targetRole,
          targetSystemRole:
            asString(record.getString("target_system_role")) ||
            inferTargetSystemRole(targetRole),
          scopeLevel:
            asString(record.getString("scope_level")) ||
            inferScopeLevel(record.getString("code"), targetRole),
          featureFlags: featureFlagsForPlan(record.getString("code"), targetRole),
          isActive: record.getBool("is_active"),
          sortOrder: record.getInt("sort_order"),
        });
      }
    } catch (_) {
      plans = [];
    }

    if (plans.length === 0) {
      const defaults = [
        DEFAULT_SUBSCRIPTION_PLANS.admin_rt_monthly,
        DEFAULT_SUBSCRIPTION_PLANS.admin_rw_monthly,
        DEFAULT_SUBSCRIPTION_PLANS.admin_rw_pro_monthly,
      ];
      plans = defaults.filter(function (plan) {
        return canPurchasePlan(userRole, plan.targetRole);
      });
    }

    return e.json(200, {
      environment: isProduction ? "production" : "sandbox",
      plans: plans,
    });
  },

  handleSnap: function (e) {
    const authRecord = requireUserAuth(e);
    const requestBody = {};
    e.bindBody(requestBody);

    const planCode = asString(requestBody.planCode);
    const userRole = normalizeUserRole(authRecord.getString("role"));
    const plan = findSubscriptionPlan(planCode);

    if (!plan) {
      throw e.badRequestError("Plan subscription tidak valid.", {
        planCode: planCode,
      });
    }

    ensurePlanAllowedForRole(plan, userRole, e);

    const config = getMidtransConfig();

    if (!config.serverKey) {
      throw e.internalServerError(
        "Server Key Midtrans belum dikonfigurasi pada environment PocketBase.",
        null,
      );
    }

    const transactionCollection = $app.findCollectionByNameOrId(
      SUBSCRIPTION_TRANSACTIONS_COLLECTION,
    );
    const orderId = buildOrderId(authRecord.id, plan.code);
    const transactionRecord = new Record(transactionCollection, {
      subscriber: authRecord.id,
      subscriber_name: getUserDisplayName(authRecord),
      subscriber_email: authRecord.getString("email"),
      plan_code: plan.code,
      target_role: plan.targetRole,
      plan_name: plan.name,
      period_days: plan.durationDays,
      gross_amount: plan.amount,
      currency: plan.currency || "IDR",
      order_id: orderId,
      payment_state: "initiated",
      transaction_status: "pending",
      subscription_applied: false,
    });

    $app.save(transactionRecord);

    const payload = buildSnapPayload(
      authRecord,
      plan,
      orderId,
      requestBody,
      config,
    );
    const response = midtransApiRequest(
      "POST",
      getSnapTransactionUrl(config),
      payload,
      config,
      true,
    );

    if (response.statusCode < 200 || response.statusCode >= 300) {
      transactionRecord.set("payment_state", "midtrans_error");
      transactionRecord.set(
        "raw_midtrans_response",
        serializeJson(response.json || { body: toString(response.body) }),
      );
      $app.save(transactionRecord);

      throw e.badRequestError("Midtrans gagal membuat transaksi Snap.", {
        statusCode: response.statusCode,
        response: response.json || toString(response.body),
      });
    }

    transactionRecord.set("snap_token", asString(response.json.token));
    transactionRecord.set("redirect_url", asString(response.json.redirect_url));
    transactionRecord.set("payment_state", "token_ready");
    transactionRecord.set(
      "raw_midtrans_response",
      serializeJson(response.json || {}),
    );
    $app.save(transactionRecord);

    return e.json(200, serializeTransaction(transactionRecord));
  },

  handleStatus: function (e) {
    const authRecord = requireUserAuth(e);
    const orderId = asString(e.request.pathValue("orderId"));

    if (!orderId) {
      throw e.badRequestError("orderId wajib diisi.", null);
    }

    const transactionRecord = findTransactionByOrderId(orderId);

    if (!transactionRecord) {
      throw e.notFoundError("Transaksi subscription tidak ditemukan.", {
        orderId: orderId,
      });
    }

    if (transactionRecord.getString("subscriber") !== authRecord.id) {
      throw e.forbiddenError("Anda tidak punya akses ke transaksi ini.", null);
    }

    const syncedRecord = syncTransactionWithMidtrans(transactionRecord);

    return e.json(200, serializeTransaction(syncedRecord));
  },

  handleNotification: function (e) {
    const requestBody = {};
    e.bindBody(requestBody);

    const orderId = asString(requestBody.order_id);
    const config = getMidtransConfig();

    if (!orderId) {
      throw e.badRequestError(
        "order_id wajib ada pada payload notifikasi.",
        null,
      );
    }

    if (!config.serverKey) {
      throw e.internalServerError(
        "Server Key Midtrans belum dikonfigurasi pada environment PocketBase.",
        null,
      );
    }

    const expectedSignature = $security.sha512(
      orderId +
        asString(requestBody.status_code) +
        asString(requestBody.gross_amount) +
        config.serverKey,
    );

    if (expectedSignature !== asString(requestBody.signature_key)) {
      throw e.unauthorizedError("Signature Midtrans tidak valid.", {
        orderId: orderId,
      });
    }

    const transactionRecord = findTransactionByOrderId(orderId);

    if (!transactionRecord) {
      throw e.notFoundError("Transaksi subscription tidak ditemukan.", {
        orderId: orderId,
      });
    }

    transactionRecord.set("raw_notification", serializeJson(requestBody));
    $app.save(transactionRecord);

    const syncedRecord = syncTransactionWithMidtrans(transactionRecord);

    return e.json(200, {
      ok: true,
      orderId: orderId,
      paymentState: syncedRecord.getString("payment_state"),
      transactionStatus: syncedRecord.getString("transaction_status"),
    });
  },
};

routerAdd(
  "GET",
  "/api/rukunwarga/payments/subscription/plans",
  (e) => {
    const normalizeRole = function (role) {
      const normalized = String(role || "").trim().toLowerCase();
      if (normalized === "admin") {
        return "admin_rw";
      }
      if (normalized === "superuser") {
        return "sysadmin";
      }
      if (normalized === "user" || normalized === "warga") {
        return "warga";
      }
      if (
        normalized === "admin_rt" ||
        normalized === "admin_rw" ||
        normalized === "admin_rw_pro" ||
        normalized === "sysadmin"
      ) {
        return normalized;
      }
      return "warga";
    };

    const canSelfSubscribe = function (role) {
      return (
        role === "warga" ||
        role === "admin_rt" ||
        role === "admin_rw" ||
        role === "admin_rw_pro"
      );
    };

    const roleRank = function (role) {
      switch (role) {
        case "admin_rt":
          return 1;
        case "admin_rw":
          return 2;
        case "admin_rw_pro":
          return 3;
        case "sysadmin":
          return 99;
        case "warga":
        default:
          return 0;
      }
    };

    const canPurchasePlan = function (currentRole, targetRole) {
      if (
        targetRole !== "admin_rt" &&
        targetRole !== "admin_rw" &&
        targetRole !== "admin_rw_pro"
      ) {
        return false;
      }
      if (currentRole === "sysadmin") {
        return false;
      }
      if (currentRole === "warga") {
        return true;
      }
      return roleRank(targetRole) >= roleRank(currentRole);
    };

    const inferPlanCodeLocal = function (planCodeOrSku, targetRole) {
      const normalizedPlan = String(planCodeOrSku || "").trim().toLowerCase();
      if (normalizedPlan === "rt" || normalizedPlan === "admin_rt_monthly") {
        return "rt";
      }
      if (normalizedPlan === "rw" || normalizedPlan === "admin_rw_monthly") {
        return "rw";
      }
      if (
        normalizedPlan === "rw_pro" ||
        normalizedPlan === "admin_rw_pro_monthly"
      ) {
        return "rw_pro";
      }
      const normalizedRole = normalizeRole(targetRole);
      if (normalizedRole === "admin_rt") {
        return "rt";
      }
      if (normalizedRole === "admin_rw") {
        return "rw";
      }
      if (normalizedRole === "admin_rw_pro") {
        return "rw_pro";
      }
      return "free";
    };

    const inferTargetSystemRoleLocal = function (targetRole) {
      const normalizedRole = normalizeRole(targetRole);
      if (normalizedRole === "sysadmin") {
        return "sysadmin";
      }
      if (
        normalizedRole === "admin_rt" ||
        normalizedRole === "admin_rw" ||
        normalizedRole === "admin_rw_pro"
      ) {
        return "operator";
      }
      return "warga";
    };

    const inferScopeLevelLocal = function (planCodeOrSku, targetRole) {
      const planCode = inferPlanCodeLocal(planCodeOrSku, targetRole);
      if (planCode === "rt") {
        return "rt";
      }
      if (planCode === "rw" || planCode === "rw_pro") {
        return "rw";
      }
      return "self";
    };

    const featureFlagsForPlanLocal = function (planCodeOrSku, targetRole) {
      const planCode = inferPlanCodeLocal(planCodeOrSku, targetRole);
      if (planCode === "rt") {
        return ["chat_basic", "broadcast_rt", "agenda_basic", "finance_basic"];
      }
      if (planCode === "rw") {
        return [
          "chat_basic",
          "broadcast_rw",
          "custom_group_basic",
          "agenda_basic",
          "finance_basic",
          "finance_publish",
        ];
      }
      if (planCode === "rw_pro") {
        return [
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
        ];
      }
      return ["chat_basic"];
    };

    const info = e.requestInfo();
    if (!info.auth) {
      throw e.unauthorizedError("Autentikasi dibutuhkan.", null);
    }

    const authRecord = info.auth;
    const userRole = normalizeRole(authRecord.getString("role"));

    if (!canSelfSubscribe(userRole)) {
      return e.json(200, { environment: "sandbox", plans: [] });
    }

    const envValue = String($os.getenv("RW_MIDTRANS_IS_PRODUCTION") || "")
      .trim()
      .toLowerCase();
    const isProduction =
      envValue === "1" || envValue === "true" || envValue === "yes";
    const serverKey = String($os.getenv("RW_MIDTRANS_SERVER_KEY") || "").trim();
    const checkoutReady = serverKey.length > 0;
    const checkoutMessage = checkoutReady
      ? ""
      : "Server Key Midtrans belum dikonfigurasi pada environment PocketBase.";

    let plans = [];
    try {
      const records = $app.findRecordsByFilter(
        "subscription_plans",
        "is_active = true",
        "sort_order,created",
        100,
        0,
      );

      for (const record of records) {
        if (!record) {
          continue;
        }

        const targetRole = normalizeRole(record.getString("target_role"));
        if (!canPurchasePlan(userRole, targetRole)) {
          continue;
        }

        plans.push({
          code: record.getString("code"),
          name: record.getString("name"),
          description: record.getString("description"),
          planCode:
            String(record.getString("plan_code") || "").trim().toLowerCase() ||
            inferPlanCodeLocal(record.getString("code"), targetRole),
          amount: record.getInt("amount"),
          durationDays: record.getInt("duration_days"),
          currency: String(record.getString("currency") || "IDR"),
          targetRole: targetRole,
          targetSystemRole:
            String(record.getString("target_system_role") || "").trim().toLowerCase() ||
            inferTargetSystemRoleLocal(targetRole),
          scopeLevel:
            String(record.getString("scope_level") || "").trim().toLowerCase() ||
            inferScopeLevelLocal(record.getString("code"), targetRole),
          featureFlags: featureFlagsForPlanLocal(record.getString("code"), targetRole),
          isActive: record.getBool("is_active"),
          sortOrder: record.getInt("sort_order"),
        });
      }
    } catch (_) {
      plans = [];
    }

    return e.json(200, {
      environment: isProduction ? "production" : "sandbox",
      checkoutReady: checkoutReady,
      checkoutMessage: checkoutMessage,
      plans: plans,
    });
  },
  $apis.requireAuth(USERS_COLLECTION),
);

routerAdd(
  "POST",
  "/api/rukunwarga/payments/subscription/snap",
  (e) => {
    const asString = function (value) {
      if (value === null || value === undefined) {
        return "";
      }

      return String(value);
    };

    const normalizeRole = function (role) {
      const normalized = asString(role).trim().toLowerCase();
      if (normalized === "admin") {
        return "admin_rw";
      }
      if (normalized === "superuser") {
        return "sysadmin";
      }
      if (normalized === "user" || normalized === "warga") {
        return "warga";
      }
      if (
        normalized === "admin_rt" ||
        normalized === "admin_rw" ||
        normalized === "admin_rw_pro" ||
        normalized === "sysadmin"
      ) {
        return normalized;
      }
      return "warga";
    };

    const roleRank = function (role) {
      switch (role) {
        case "admin_rt":
          return 1;
        case "admin_rw":
          return 2;
        case "admin_rw_pro":
          return 3;
        case "sysadmin":
          return 99;
        case "warga":
        default:
          return 0;
      }
    };

    const canPurchasePlan = function (currentRole, targetRole) {
      if (
        targetRole !== "admin_rt" &&
        targetRole !== "admin_rw" &&
        targetRole !== "admin_rw_pro"
      ) {
        return false;
      }
      if (currentRole === "sysadmin") {
        return false;
      }
      if (currentRole === "warga") {
        return true;
      }
      return roleRank(targetRole) >= roleRank(currentRole);
    };

    const serializeJson = function (value) {
      return JSON.stringify(value || {});
    };

    const base64Encode = function (input) {
      const chars =
        "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
      let output = "";
      let i = 0;

      while (i < input.length) {
        const chr1 = input.charCodeAt(i++);
        const chr2 = input.charCodeAt(i++);
        const chr3 = input.charCodeAt(i++);
        const enc1 = chr1 >> 2;
        const enc2 = ((chr1 & 3) << 4) | (chr2 >> 4);
        let enc3 = ((chr2 & 15) << 2) | (chr3 >> 6);
        let enc4 = chr3 & 63;

        if (isNaN(chr2)) {
          enc3 = 64;
          enc4 = 64;
        } else if (isNaN(chr3)) {
          enc4 = 64;
        }

        output =
          output +
          chars.charAt(enc1) +
          chars.charAt(enc2) +
          (enc3 === 64 ? "=" : chars.charAt(enc3)) +
          (enc4 === 64 ? "=" : chars.charAt(enc4));
      }

      return output;
    };

    const getConfig = function () {
      const envValue = asString($os.getenv("RW_MIDTRANS_IS_PRODUCTION"))
        .trim()
        .toLowerCase();
      const isProduction =
        envValue === "1" || envValue === "true" || envValue === "yes";

      return {
        isProduction: isProduction,
        serverKey: asString($os.getenv("RW_MIDTRANS_SERVER_KEY")),
        notificationUrl: asString($os.getenv("RW_MIDTRANS_NOTIFICATION_URL")),
        finishUrl: asString($os.getenv("RW_MIDTRANS_FINISH_URL")),
      };
    };

    const findPlan = function (planCode) {
      const normalizedCode = asString(planCode).trim().toLowerCase();
      const defaults = {
        admin_rt_monthly: {
          code: "admin_rt_monthly",
          name: "Admin RT Bulanan",
          description:
            "Langganan dashboard dan operasional Admin RT selama 30 hari.",
          amount: 30000,
          durationDays: 30,
          currency: "IDR",
          targetRole: "admin_rt",
        },
        admin_rw_monthly: {
          code: "admin_rw_monthly",
          name: "Admin RW Bulanan",
          description:
            "Langganan dashboard RW dan akses lintas wilayah selama 30 hari.",
          amount: 100000,
          durationDays: 30,
          currency: "IDR",
          targetRole: "admin_rw",
        },
        admin_rw_pro_monthly: {
          code: "admin_rw_pro_monthly",
          name: "Admin RW Pro Bulanan",
          description:
            "Langganan Admin RW Pro dengan OCR dan integrasi pembayaran selama 30 hari.",
          amount: 250000,
          durationDays: 30,
          currency: "IDR",
          targetRole: "admin_rw_pro",
        },
      };

      try {
        const record = $app.findFirstRecordByFilter(
          "subscription_plans",
          "code = {:code} && is_active = true",
          { code: normalizedCode },
        );

        if (!record) {
          return defaults[normalizedCode] || null;
        }

        return {
          code: record.getString("code"),
          name: record.getString("name"),
          description: record.getString("description"),
          amount: record.getInt("amount"),
          durationDays: record.getInt("duration_days"),
          currency: asString(record.getString("currency")) || "IDR",
          targetRole: normalizeRole(record.getString("target_role")),
        };
      } catch (_) {
        return defaults[normalizedCode] || null;
      }
    };

    const getDisplayName = function (authRecord) {
      const nama = asString(authRecord.getString("nama"));
      if (nama) {
        return nama;
      }
      const name = asString(authRecord.getString("name"));
      if (name) {
        return name;
      }
      const email = asString(authRecord.getString("email"));
      return email ? email.split("@")[0] : "RukunWarga User";
    };

    const getPhone = function (authRecord) {
      return (
        asString(authRecord.getString("no_hp")) ||
        asString(authRecord.getString("phone"))
      );
    };

    const info = e.requestInfo();
    if (!info.auth) {
      throw e.unauthorizedError("Autentikasi dibutuhkan.", null);
    }

    const authRecord = info.auth;
    const requestBody = info.body || {};

    const userRole = normalizeRole(authRecord.getString("role"));
    const plan = findPlan(requestBody.planCode);

    if (!plan) {
      throw e.badRequestError("Plan subscription tidak valid.", {
        planCode: requestBody.planCode,
      });
    }

    if (!canPurchasePlan(userRole, plan.targetRole)) {
      throw e.badRequestError("Plan subscription tidak sesuai dengan role user.", {
        role: userRole,
        planCode: plan.code,
        targetRole: plan.targetRole,
      });
    }

    const config = getConfig();
    if (!config.serverKey) {
      throw e.internalServerError(
        "Server Key Midtrans belum dikonfigurasi pada environment PocketBase.",
        null,
      );
    }

    const transactionCollection = $app.findCollectionByNameOrId(
      "subscription_transactions",
    );
    const planAlias =
      plan.targetRole === "admin_rt" ? "ART"
      : plan.targetRole === "admin_rw" ? "ARW"
      : plan.targetRole === "admin_rw_pro" ? "ARP"
      : "SUB";
    const orderId =
      "SUB-" +
      planAlias +
      "-" +
      authRecord.id.substring(0, 6).toUpperCase() +
      "-" +
      Date.now() +
      "-" +
      $security.randomString(4).toUpperCase();

    const transactionRecord = new Record(transactionCollection, {
      subscriber: authRecord.id,
      subscriber_name: getDisplayName(authRecord),
      subscriber_email: authRecord.getString("email"),
      plan_code: plan.code,
      target_role: plan.targetRole,
      target_system_role: inferTargetSystemRole(plan.targetRole),
      workspace: asString(authRecord.getString("active_workspace")),
      workspace_member: asString(authRecord.getString("active_workspace_member")),
      seat_target: authRecord.id,
      plan_name: plan.name,
      period_days: plan.durationDays,
      gross_amount: plan.amount,
      currency: plan.currency || "IDR",
      order_id: orderId,
      payment_state: "initiated",
      transaction_status: "pending",
      subscription_applied: false,
    });
    $app.save(transactionRecord);

    const payload = {
      transaction_details: {
        order_id: orderId,
        gross_amount: plan.amount,
      },
      item_details: [
        {
          id: plan.code,
          name: plan.name,
          price: plan.amount,
          quantity: 1,
        },
      ],
      customer_details: {
        first_name: getDisplayName(authRecord),
        email: authRecord.getString("email"),
        phone: getPhone(authRecord),
      },
      custom_field1: plan.code,
      custom_field2: authRecord.id,
      custom_field3: "rukunwarga-subscription",
    };

    if (
      Array.isArray(requestBody.enabledPayments) &&
      requestBody.enabledPayments.length > 0
    ) {
      payload.enabled_payments = requestBody.enabledPayments;
    }

    if (config.finishUrl) {
      payload.callbacks = { finish: config.finishUrl };
    }

    const headers = {
      Accept: "application/json",
      "Content-Type": "application/json",
      Authorization: "Basic " + base64Encode(config.serverKey + ":"),
    };

    if (config.notificationUrl) {
      headers["X-Override-Notification"] = config.notificationUrl;
    }

    const response = $http.send({
      method: "POST",
      url: config.isProduction
        ? "https://app.midtrans.com/snap/v1/transactions"
        : "https://app.sandbox.midtrans.com/snap/v1/transactions",
      headers: headers,
      body: serializeJson(payload),
      timeout: 120,
    });

    if (response.statusCode < 200 || response.statusCode >= 300) {
      transactionRecord.set("payment_state", "midtrans_error");
      transactionRecord.set(
        "raw_midtrans_response",
        serializeJson(response.json || { body: asString(response.body) }),
      );
      $app.save(transactionRecord);

      throw e.badRequestError("Midtrans gagal membuat transaksi Snap.", {
        statusCode: response.statusCode,
        response: response.json || asString(response.body),
      });
    }

    transactionRecord.set("snap_token", asString(response.json.token));
    transactionRecord.set("redirect_url", asString(response.json.redirect_url));
    transactionRecord.set("payment_state", "token_ready");
    transactionRecord.set(
      "raw_midtrans_response",
      serializeJson(response.json || {}),
    );
    $app.save(transactionRecord);

    return e.json(200, {
      id: transactionRecord.id,
      orderId: transactionRecord.getString("order_id"),
      planCode: inferPlanCode(
        transactionRecord.getString("plan_code"),
        transactionRecord.getString("target_role"),
      ),
      targetRole: transactionRecord.getString("target_role"),
      targetSystemRole:
        asString(transactionRecord.getString("target_system_role")) ||
        inferTargetSystemRole(transactionRecord.getString("target_role")),
      planName: transactionRecord.getString("plan_name"),
      grossAmount: transactionRecord.getInt("gross_amount"),
      currency: transactionRecord.getString("currency"),
      snapToken: transactionRecord.getString("snap_token"),
      redirectUrl: transactionRecord.getString("redirect_url"),
      paymentState: transactionRecord.getString("payment_state"),
      transactionStatus: transactionRecord.getString("transaction_status"),
      transactionId: transactionRecord.getString("transaction_id"),
      paymentType: transactionRecord.getString("payment_type"),
      subscriptionApplied: transactionRecord.getBool("subscription_applied"),
      seatTarget: transactionRecord.getString("seat_target"),
      scopeLevel: inferScopeLevel(
        transactionRecord.getString("plan_code"),
        transactionRecord.getString("target_role"),
      ),
      featureFlags: featureFlagsForPlan(
        transactionRecord.getString("plan_code"),
        transactionRecord.getString("target_role"),
      ),
      subscriptionStarted: transactionRecord.getString("subscription_started"),
      subscriptionExpired: transactionRecord.getString("subscription_expired"),
      statusCode: transactionRecord.getString("status_code"),
      statusMessage: transactionRecord.getString("status_message"),
      created: transactionRecord.getString("created"),
      updated: transactionRecord.getString("updated"),
    });
  },
  $apis.requireAuth(USERS_COLLECTION),
);

routerAdd(
  "GET",
  "/api/rukunwarga/payments/subscription/status/{orderId}",
  (e) => {
    const asString = function (value) {
      if (value === null || value === undefined) {
        return "";
      }

      return String(value);
    };

    const serializeJson = function (value) {
      return JSON.stringify(value || {});
    };

    const base64Encode = function (input) {
      const chars =
        "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
      let output = "";
      let i = 0;

      while (i < input.length) {
        const chr1 = input.charCodeAt(i++);
        const chr2 = input.charCodeAt(i++);
        const chr3 = input.charCodeAt(i++);
        const enc1 = chr1 >> 2;
        const enc2 = ((chr1 & 3) << 4) | (chr2 >> 4);
        let enc3 = ((chr2 & 15) << 2) | (chr3 >> 6);
        let enc4 = chr3 & 63;

        if (isNaN(chr2)) {
          enc3 = 64;
          enc4 = 64;
        } else if (isNaN(chr3)) {
          enc4 = 64;
        }

        output =
          output +
          chars.charAt(enc1) +
          chars.charAt(enc2) +
          (enc3 === 64 ? "=" : chars.charAt(enc3)) +
          (enc4 === 64 ? "=" : chars.charAt(enc4));
      }

      return output;
    };

    const inferTargetRole = function (planCode) {
      const normalized = asString(planCode).trim().toLowerCase();
      if (normalized === "admin_rt_monthly") {
        return "admin_rt";
      }
      if (normalized === "admin_rw_monthly") {
        return "admin_rw";
      }
      if (normalized === "admin_rw_pro_monthly") {
        return "admin_rw_pro";
      }
      return "";
    };

    const mapStatus = function (midtransData) {
      const transactionStatus = asString(midtransData.transaction_status);
      const fraudStatus = asString(midtransData.fraud_status);

      if (transactionStatus === "settlement") {
        return "paid";
      }
      if (transactionStatus === "capture") {
        return fraudStatus && fraudStatus !== "accept" ? "review" : "paid";
      }
      if (
        transactionStatus === "deny" ||
        transactionStatus === "cancel" ||
        transactionStatus === "expire" ||
        transactionStatus === "failure"
      ) {
        return "failed";
      }
      if (
        transactionStatus === "refund" ||
        transactionStatus === "partial_refund" ||
        transactionStatus === "chargeback" ||
        transactionStatus === "partial_chargeback"
      ) {
        return "refunded";
      }
      if (transactionStatus === "authorize") {
        return "authorized";
      }

      return "pending";
    };

    const info = e.requestInfo();
    if (!info.auth) {
      throw e.unauthorizedError("Autentikasi dibutuhkan.", null);
    }

    const authRecord = info.auth;
    const orderId = asString(e.request.pathValue("orderId"));
    if (!orderId) {
      throw e.badRequestError("orderId wajib diisi.", null);
    }

    let transactionRecord = null;
    try {
      transactionRecord = $app.findFirstRecordByFilter(
        "subscription_transactions",
        "order_id = {:orderId}",
        { orderId: orderId },
      );
    } catch (_) {
      transactionRecord = null;
    }

    if (!transactionRecord) {
      throw e.notFoundError("Transaksi subscription tidak ditemukan.", {
        orderId: orderId,
      });
    }

    if (transactionRecord.getString("subscriber") !== authRecord.id) {
      throw e.forbiddenError("Anda tidak punya akses ke transaksi ini.", null);
    }

    const envValue = asString($os.getenv("RW_MIDTRANS_IS_PRODUCTION"))
      .trim()
      .toLowerCase();
    const isProduction =
      envValue === "1" || envValue === "true" || envValue === "yes";
    const serverKey = asString($os.getenv("RW_MIDTRANS_SERVER_KEY"));

    if (!serverKey) {
      throw e.internalServerError(
        "Server Key Midtrans belum dikonfigurasi pada environment PocketBase.",
        null,
      );
    }

    const response = $http.send({
      method: "GET",
      url: isProduction
        ? "https://api.midtrans.com/v2/" + orderId + "/status"
        : "https://api.sandbox.midtrans.com/v2/" + orderId + "/status",
      headers: {
        Accept: "application/json",
        "Content-Type": "application/json",
        Authorization: "Basic " + base64Encode(serverKey + ":"),
      },
      body: "",
      timeout: 120,
    });

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw e.badRequestError(
        "Gagal sinkron status transaksi Midtrans.",
        { orderId: orderId, statusCode: response.statusCode },
      );
    }

    const midtransData = response.json || {};
    const localState = mapStatus(midtransData);

    transactionRecord.set("payment_state", localState);
    transactionRecord.set(
      "transaction_status",
      asString(midtransData.transaction_status),
    );
    transactionRecord.set(
      "transaction_id",
      asString(midtransData.transaction_id),
    );
    transactionRecord.set("payment_type", asString(midtransData.payment_type));
    transactionRecord.set("status_code", asString(midtransData.status_code));
    transactionRecord.set(
      "status_message",
      asString(midtransData.status_message),
    );
    transactionRecord.set("raw_midtrans_response", serializeJson(midtransData));
    $app.save(transactionRecord);

    if (
      transactionRecord.getString("payment_state") === "paid" &&
      !transactionRecord.getBool("subscription_applied")
    ) {
      const subscriberId = transactionRecord.getString("subscriber");
      const periodDays = transactionRecord.getInt("period_days") || 30;
      const subscriberRecord = $app.findRecordById("users", subscriberId);
      let targetRole = asString(transactionRecord.getString("target_role"));
      if (!targetRole) {
        targetRole = inferTargetRole(transactionRecord.getString("plan_code"));
      }

      const currentExpiry = asString(
        subscriberRecord.getString("subscription_expired"),
      );
      const now = new Date();
      let baseDate = now;

      if (currentExpiry) {
        const parsedExpiry = new Date(currentExpiry);
        if (
          !isNaN(parsedExpiry.getTime()) &&
          parsedExpiry.getTime() > now.getTime()
        ) {
          baseDate = parsedExpiry;
        }
      }

      const nextExpiry = new Date(
        baseDate.getTime() + periodDays * 24 * 60 * 60 * 1000,
      );
      const startedAt = now.toISOString();
      const expiredAt = nextExpiry.toISOString();

      applyUserAccessSubscription(
        subscriberRecord,
        targetRole,
        transactionRecord.getString("plan_code"),
        startedAt,
        expiredAt,
      );
      $app.save(subscriberRecord);

      transactionRecord.set("subscription_applied", true);
      transactionRecord.set("subscription_started", startedAt);
      transactionRecord.set("subscription_expired", expiredAt);
      $app.save(transactionRecord);
    }

    return e.json(200, {
      id: transactionRecord.id,
      orderId: transactionRecord.getString("order_id"),
      planCode: inferPlanCode(
        transactionRecord.getString("plan_code"),
        transactionRecord.getString("target_role"),
      ),
      targetRole: transactionRecord.getString("target_role"),
      targetSystemRole:
        asString(transactionRecord.getString("target_system_role")) ||
        inferTargetSystemRole(transactionRecord.getString("target_role")),
      planName: transactionRecord.getString("plan_name"),
      grossAmount: transactionRecord.getInt("gross_amount"),
      currency: transactionRecord.getString("currency"),
      snapToken: transactionRecord.getString("snap_token"),
      redirectUrl: transactionRecord.getString("redirect_url"),
      paymentState: transactionRecord.getString("payment_state"),
      transactionStatus: transactionRecord.getString("transaction_status"),
      transactionId: transactionRecord.getString("transaction_id"),
      paymentType: transactionRecord.getString("payment_type"),
      subscriptionApplied: transactionRecord.getBool("subscription_applied"),
      seatTarget: transactionRecord.getString("seat_target"),
      scopeLevel: inferScopeLevel(
        transactionRecord.getString("plan_code"),
        transactionRecord.getString("target_role"),
      ),
      featureFlags: featureFlagsForPlan(
        transactionRecord.getString("plan_code"),
        transactionRecord.getString("target_role"),
      ),
      subscriptionStarted: transactionRecord.getString("subscription_started"),
      subscriptionExpired: transactionRecord.getString("subscription_expired"),
      statusCode: transactionRecord.getString("status_code"),
      statusMessage: transactionRecord.getString("status_message"),
      created: transactionRecord.getString("created"),
      updated: transactionRecord.getString("updated"),
    });
  },
  $apis.requireAuth(USERS_COLLECTION),
);

routerAdd(
  "POST",
  "/api/rukunwarga/payments/subscription/midtrans-notification",
  (e) => globalThis.__rwSubscription.handleNotification(e),
);

routerAdd(
  "POST",
  "/api/rukunwarga/account/unsubscribe",
  (e) => {
    const info = e.requestInfo();
    if (!info.auth) {
      throw e.unauthorizedError("Autentikasi dibutuhkan.", null);
    }

    const authRecord = info.auth;
    const rawRole = String(authRecord.getString("role") || "")
      .trim()
      .toLowerCase();
    const currentRole =
      rawRole === "admin" ? "admin_rw"
      : rawRole === "superuser" ? "sysadmin"
      : rawRole === "user" || rawRole === "warga" ? "warga"
      : rawRole === "admin_rt" ||
          rawRole === "admin_rw" ||
          rawRole === "admin_rw_pro" ||
          rawRole === "sysadmin"
      ? rawRole
      : "warga";

    if (
      currentRole !== "admin_rt" &&
      currentRole !== "admin_rw" &&
      currentRole !== "admin_rw_pro"
    ) {
      throw e.badRequestError(
        "Role akun saat ini tidak dapat melakukan unsubscribe admin.",
        { role: currentRole },
      );
    }

    const userRecord = $app.findRecordById("_pb_users_auth_", authRecord.id);
    userRecord.set("role", "warga");
    userRecord.set("system_role", "warga");
    userRecord.set("plan_code", "free");
    userRecord.set("subscription_plan", "");
    userRecord.set("subscription_status", "inactive");
    userRecord.set("subscription_started", "");
    userRecord.set("subscription_expired", "");
    $app.save(userRecord);

    return e.json(200, {
      success: true,
      role: "warga",
      systemRole: "warga",
      planCode: "free",
      subscriptionStatus: "inactive",
    });
  },
);

routerAdd(
  "POST",
  "/api/rukunwarga/chat/profiles",
  (e) => {
    requireUserAuth(e);

    const requestBody = {};
    e.bindBody(requestBody);

    const ids = Array.isArray(requestBody.ids) ? requestBody.ids : [];
    const items = [];
    const seen = {};

    for (const rawId of ids) {
      const userId = asString(rawId).trim();
      if (!userId || seen[userId]) {
        continue;
      }
      seen[userId] = true;

      const profile = buildChatProfilePayload(userId);
      if (profile) {
        items.push(profile);
      }
    }

    return e.json(200, { items: items });
  },
  $apis.requireAuth(USERS_COLLECTION),
);

function requireUserAuth(e) {
  const info = e.requestInfo();

  if (!info.auth) {
    throw e.unauthorizedError("Autentikasi dibutuhkan.", null);
  }

  return info.auth;
}

function buildChatProfilePayload(userId) {
  let userRecord = null;
  try {
    userRecord = $app.findRecordById(USERS_COLLECTION, userId);
  } catch (_) {
    return null;
  }

  let wargaRecord = null;
  try {
    wargaRecord = $app.findFirstRecordByFilter(
      "warga",
      "user_id = {:userId}",
      { userId: userId },
    );
  } catch (_) {}

  const wargaName = wargaRecord ? asString(wargaRecord.getString("nama_lengkap")) : "";
  const avatarFile = asString(userRecord.getString("avatar"));
  const fotoWarga = wargaRecord ? asString(wargaRecord.getString("foto_warga")) : "";
  const displayName =
    wargaName ||
    getUserDisplayName(userRecord) ||
    asString(userRecord.getString("email")).split("@")[0] ||
    "Pengguna";

  return {
    userId: userId,
    displayName: displayName,
    avatarUrl:
      avatarFile
        ? buildRecordFileUrl(userRecord, avatarFile, userRecord.newFileToken())
        : fotoWarga
          ? buildRecordFileUrl(wargaRecord, fotoWarga, "")
          : "",
    role: normalizeUserRole(userRecord.getString("role")),
    systemRole: inferTargetSystemRole(userRecord.getString("role")),
    planCode: inferPlanCode(
      userRecord.getString("plan_code") || userRecord.getString("subscription_plan"),
      userRecord.getString("role"),
    ),
  };
}

function buildRecordFileUrl(record, filename, token) {
  if (!record || !filename) {
    return "";
  }

  const basePath = asString(record.baseFilesPath());
  if (!basePath) {
    return "";
  }

  let url = basePath + "/" + encodeURIComponent(filename);
  if (token) {
    url += (url.indexOf("?") >= 0 ? "&" : "?") + "token=" + encodeURIComponent(token);
  }

  return url;
}

function getMidtransConfig() {
  const isProduction = isTruthy($os.getenv("RW_MIDTRANS_IS_PRODUCTION"));

  return {
    isProduction: isProduction,
    serverKey: asString($os.getenv("RW_MIDTRANS_SERVER_KEY")),
    clientKey: asString($os.getenv("RW_MIDTRANS_CLIENT_KEY")),
    merchantId: asString($os.getenv("RW_MIDTRANS_MERCHANT_ID")),
    notificationUrl: asString($os.getenv("RW_MIDTRANS_NOTIFICATION_URL")),
    finishUrl: asString($os.getenv("RW_MIDTRANS_FINISH_URL")),
  };
}

function getPlanList(role) {
  return getPlanListForRole(role || "");
}

function getPlanListForRole(role) {
  const planCollection = safeFindCollectionByNameOrId(SUBSCRIPTION_PLANS_COLLECTION);
  const normalizedRole = normalizeUserRole(role);

  if (!canSelfSubscribe(normalizedRole)) {
    return [];
  }

  if (!planCollection) {
    return getDefaultPlanList(normalizedRole);
  }

  const records = $app.findRecordsByFilter(
    SUBSCRIPTION_PLANS_COLLECTION,
    "is_active = true",
    "sort_order,created",
    100,
    0,
  );

  const plans = [];
  for (const record of records) {
    if (!record) {
      continue;
    }

    const plan = serializePlanRecord(record);
    if (canPurchasePlan(normalizedRole, plan.targetRole)) {
      plans.push(plan);
    }
  }

  if (plans.length > 0) {
    return plans;
  }

  return getDefaultPlanList(normalizedRole);
}

function findSubscriptionPlan(planCode) {
  const normalizedCode = asString(planCode);
  if (!normalizedCode) {
    return null;
  }

  const planCollection = safeFindCollectionByNameOrId(SUBSCRIPTION_PLANS_COLLECTION);

  if (!planCollection) {
    return DEFAULT_SUBSCRIPTION_PLANS[normalizedCode] || null;
  }

  try {
    const record = $app.findFirstRecordByFilter(
      SUBSCRIPTION_PLANS_COLLECTION,
      "code = {:code} && is_active = true",
      { code: normalizedCode },
    );

    if (!record) {
      return null;
    }

    return serializePlanRecord(record);
  } catch (_) {
    return null;
  }
}

function getDefaultPlanList(role) {
  if (!canSelfSubscribe(role)) {
    return [];
  }

  const plans = Object.keys(DEFAULT_SUBSCRIPTION_PLANS)
    .map(function (key) {
      return DEFAULT_SUBSCRIPTION_PLANS[key];
    })
    .filter(function (plan) {
      return canPurchasePlan(role, plan.targetRole);
    });

  plans.sort(function (left, right) {
    return (left.sortOrder || 0) - (right.sortOrder || 0);
  });

  return plans;
}

function serializePlanRecord(record) {
  return {
    code: record.getString("code"),
    name: record.getString("name"),
    description: record.getString("description"),
    amount: record.getInt("amount"),
    durationDays: record.getInt("duration_days"),
    currency: asString(record.getString("currency")) || "IDR",
    targetRole: normalizeUserRole(record.getString("target_role")),
    isActive: record.getBool("is_active"),
    sortOrder: record.getInt("sort_order"),
  };
}

function ensurePlanAllowedForRole(plan, role, e) {
  if (!canSelfSubscribe(role)) {
    throw e.forbiddenError(
      "Role akun ini tidak dapat melakukan checkout subscription.",
      null,
    );
  }

  if (!canPurchasePlan(role, plan.targetRole)) {
    throw e.badRequestError(
      "Plan subscription tidak sesuai dengan role user.",
      {
        role: role,
        planCode: plan.code,
        targetRole: plan.targetRole,
      },
    );
  }
}

function normalizeUserRole(role) {
  const normalized = asString(role).trim().toLowerCase();

  if (normalized === "admin") {
    return "admin_rw";
  }

  if (normalized === "superuser") {
    return "sysadmin";
  }

  if (normalized === "user" || normalized === "warga") {
    return "warga";
  }

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

function requiresSubscriptionRole(role) {
  return role === "admin_rt" || role === "admin_rw" || role === "admin_rw_pro";
}

function canSelfSubscribe(role) {
  return role === "warga" || requiresSubscriptionRole(role);
}

function roleRank(role) {
  switch (role) {
    case "admin_rt":
      return 1;
    case "admin_rw":
      return 2;
    case "admin_rw_pro":
      return 3;
    case "sysadmin":
      return 99;
    case "warga":
    default:
      return 0;
  }
}

function canPurchasePlan(currentRole, targetRole) {
  if (!requiresSubscriptionRole(targetRole)) {
    return false;
  }

  if (currentRole === "sysadmin") {
    return false;
  }

  if (currentRole === "warga") {
    return true;
  }

  return roleRank(targetRole) >= roleRank(currentRole);
}

function safeFindCollectionByNameOrId(collectionName) {
  try {
    return $app.findCollectionByNameOrId(collectionName);
  } catch (_) {
    return null;
  }
}

function getSnapTransactionUrl(config) {
  if (config.isProduction) {
    return "https://app.midtrans.com/snap/v1/transactions";
  }

  return "https://app.sandbox.midtrans.com/snap/v1/transactions";
}

function getStatusTransactionUrl(config, orderId) {
  if (config.isProduction) {
    return "https://api.midtrans.com/v2/" + orderId + "/status";
  }

  return "https://api.sandbox.midtrans.com/v2/" + orderId + "/status";
}

function buildSnapPayload(authRecord, plan, orderId, requestBody, config) {
  const payload = {
    transaction_details: {
      order_id: orderId,
      gross_amount: plan.amount,
    },
    item_details: [
      {
        id: plan.code,
        name: plan.name,
        price: plan.amount,
        quantity: 1,
      },
    ],
    customer_details: {
      first_name: getUserDisplayName(authRecord),
      email: authRecord.getString("email"),
      phone: getUserPhone(authRecord),
    },
    custom_field1: plan.code,
    custom_field2: authRecord.id,
    custom_field3: "rukunwarga-subscription",
  };

  const enabledPayments = requestBody.enabledPayments;

  if (Array.isArray(enabledPayments) && enabledPayments.length > 0) {
    payload.enabled_payments = enabledPayments;
  }

  if (config.finishUrl) {
    payload.callbacks = {
      finish: config.finishUrl,
    };
  }

  return payload;
}

function midtransApiRequest(method, url, payload, config, allowNotificationOverride) {
  const headers = {
    Accept: "application/json",
    "Content-Type": "application/json",
    Authorization: "Basic " + base64Encode(config.serverKey + ":"),
  };

  if (allowNotificationOverride && config.notificationUrl) {
    headers["X-Override-Notification"] = config.notificationUrl;
  }

  return $http.send({
    method: method,
    url: url,
    headers: headers,
    body: payload ? serializeJson(payload) : "",
    timeout: 120,
  });
}

function syncTransactionWithMidtrans(transactionRecord) {
  const config = getMidtransConfig();

  if (!config.serverKey) {
    throw new Error("Server Key Midtrans belum dikonfigurasi.");
  }

  const orderId = transactionRecord.getString("order_id");
  const response = midtransApiRequest(
    "GET",
    getStatusTransactionUrl(config, orderId),
    null,
    config,
    false,
  );

  if (response.statusCode < 200 || response.statusCode >= 300) {
    throw new Error("Gagal sinkron status transaksi Midtrans untuk order " + orderId + ".");
  }

  const midtransData = response.json || {};

  updateTransactionFromMidtrans(transactionRecord, midtransData);
  applySubscriptionIfNeeded(transactionRecord);

  return transactionRecord;
}

function updateTransactionFromMidtrans(transactionRecord, midtransData) {
  const localState = mapMidtransStatusToLocalState(midtransData);

  transactionRecord.set("payment_state", localState);
  transactionRecord.set("transaction_status", asString(midtransData.transaction_status));
  transactionRecord.set("transaction_id", asString(midtransData.transaction_id));
  transactionRecord.set("payment_type", asString(midtransData.payment_type));
  transactionRecord.set("status_code", asString(midtransData.status_code));
  transactionRecord.set("status_message", asString(midtransData.status_message));
  transactionRecord.set("raw_midtrans_response", serializeJson(midtransData));

  $app.save(transactionRecord);
}

function applySubscriptionIfNeeded(transactionRecord) {
  const isPaid =
    transactionRecord.getString("payment_state") === "paid" &&
    !transactionRecord.getBool("subscription_applied");

  if (!isPaid) {
    return;
  }

  const subscriberId = transactionRecord.getString("subscriber");
  const periodDays = transactionRecord.getInt("period_days") || 30;
  const subscriberRecord = $app.findRecordById(USERS_COLLECTION, subscriberId);
  let targetRole = asString(transactionRecord.getString("target_role"));
  if (!targetRole) {
    const matchedPlan = findSubscriptionPlan(transactionRecord.getString("plan_code"));
    targetRole = matchedPlan ? matchedPlan.targetRole : "";
  }
  const currentExpiry = asString(subscriberRecord.getString("subscription_expired"));
  const now = new Date();
  let baseDate = now;

  if (currentExpiry) {
    const parsedExpiry = new Date(currentExpiry);

    if (!isNaN(parsedExpiry.getTime()) && parsedExpiry.getTime() > now.getTime()) {
      baseDate = parsedExpiry;
    }
  }

  const nextExpiry = new Date(
    baseDate.getTime() + periodDays * 24 * 60 * 60 * 1000,
  );
  const startedAt = now.toISOString();
  const expiredAt = nextExpiry.toISOString();

  applyUserAccessSubscription(
    subscriberRecord,
    targetRole,
    transactionRecord.getString("plan_code"),
    startedAt,
    expiredAt,
  );
  $app.save(subscriberRecord);

  transactionRecord.set("subscription_applied", true);
  transactionRecord.set("subscription_started", startedAt);
  transactionRecord.set("subscription_expired", expiredAt);
  $app.save(transactionRecord);
}

function mapMidtransStatusToLocalState(midtransData) {
  const transactionStatus = asString(midtransData.transaction_status);
  const fraudStatus = asString(midtransData.fraud_status);

  if (transactionStatus === "settlement") {
    return "paid";
  }

  if (transactionStatus === "capture") {
    return fraudStatus && fraudStatus !== "accept" ? "review" : "paid";
  }

  if (
    transactionStatus === "deny" ||
    transactionStatus === "cancel" ||
    transactionStatus === "expire" ||
    transactionStatus === "failure"
  ) {
    return "failed";
  }

  if (
    transactionStatus === "refund" ||
    transactionStatus === "partial_refund" ||
    transactionStatus === "chargeback" ||
    transactionStatus === "partial_chargeback"
  ) {
    return "refunded";
  }

  if (transactionStatus === "authorize") {
    return "authorized";
  }

  return "pending";
}

function findTransactionByOrderId(orderId) {
  try {
    return $app.findFirstRecordByFilter(
      SUBSCRIPTION_TRANSACTIONS_COLLECTION,
      "order_id = {:orderId}",
      { orderId: orderId },
    );
  } catch (_) {
    return null;
  }
}

function serializeTransaction(transactionRecord) {
  const targetRole = transactionRecord.getString("target_role");
  const planCode = inferPlanCode(
    transactionRecord.getString("plan_code"),
    targetRole,
  );
  return {
    id: transactionRecord.id,
    orderId: transactionRecord.getString("order_id"),
    planCode: planCode,
    targetRole: targetRole,
    targetSystemRole:
      asString(transactionRecord.getString("target_system_role")) ||
      inferTargetSystemRole(targetRole),
    planName: transactionRecord.getString("plan_name"),
    grossAmount: transactionRecord.getInt("gross_amount"),
    currency: transactionRecord.getString("currency"),
    snapToken: transactionRecord.getString("snap_token"),
    redirectUrl: transactionRecord.getString("redirect_url"),
    paymentState: transactionRecord.getString("payment_state"),
    transactionStatus: transactionRecord.getString("transaction_status"),
    transactionId: transactionRecord.getString("transaction_id"),
    paymentType: transactionRecord.getString("payment_type"),
    subscriptionApplied: transactionRecord.getBool("subscription_applied"),
    seatTarget: transactionRecord.getString("seat_target"),
    scopeLevel: inferScopeLevel(planCode, targetRole),
    featureFlags: featureFlagsForPlan(planCode, targetRole),
    subscriptionStarted: transactionRecord.getString("subscription_started"),
    subscriptionExpired: transactionRecord.getString("subscription_expired"),
    statusCode: transactionRecord.getString("status_code"),
    statusMessage: transactionRecord.getString("status_message"),
    created: transactionRecord.getString("created"),
    updated: transactionRecord.getString("updated"),
  };
}

function buildOrderId(userId, planCode) {
  return (
    "SUB-" +
    planCode.toUpperCase() +
    "-" +
    userId.toUpperCase() +
    "-" +
    Date.now() +
    "-" +
    $security.randomString(6).toUpperCase()
  );
}

function getUserDisplayName(authRecord) {
  const nama = asString(authRecord.getString("nama"));

  if (nama) {
    return nama;
  }

  const name = asString(authRecord.getString("name"));

  if (name) {
    return name;
  }

  const email = asString(authRecord.getString("email"));

  if (!email) {
    return "RukunWarga User";
  }

  return email.split("@")[0];
}

function getUserPhone(authRecord) {
  const noHp = asString(authRecord.getString("no_hp"));

  if (noHp) {
    return noHp;
  }

  return asString(authRecord.getString("phone"));
}

function isTruthy(value) {
  const normalized = asString(value).toLowerCase();

  return normalized === "1" || normalized === "true" || normalized === "yes";
}

function asString(value) {
  if (value === null || value === undefined) {
    return "";
  }

  return String(value);
}

function serializeJson(value) {
  return JSON.stringify(value || {});
}

function base64Encode(input) {
  const chars =
    "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/";
  let output = "";
  let i = 0;

  while (i < input.length) {
    const chr1 = input.charCodeAt(i++);
    const chr2 = input.charCodeAt(i++);
    const chr3 = input.charCodeAt(i++);
    const enc1 = chr1 >> 2;
    const enc2 = ((chr1 & 3) << 4) | (chr2 >> 4);
    let enc3 = ((chr2 & 15) << 2) | (chr3 >> 6);
    let enc4 = chr3 & 63;

    if (isNaN(chr2)) {
      enc3 = 64;
      enc4 = 64;
    } else if (isNaN(chr3)) {
      enc4 = 64;
    }

    output =
      output +
      chars.charAt(enc1) +
      chars.charAt(enc2) +
      (enc3 === 64 ? "=" : chars.charAt(enc3)) +
      (enc4 === 64 ? "=" : chars.charAt(enc4));
  }

  return output;
}
