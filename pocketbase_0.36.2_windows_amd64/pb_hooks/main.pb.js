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

routerAdd(
  "GET",
  "/api/rukunwarga/payments/subscription/plans",
  (e) => {
    const authRecord = requireUserAuth(e);
    const userRole = normalizeUserRole(authRecord.getString("role"));

    return e.json(200, {
      environment: getMidtransConfig().isProduction ? "production" : "sandbox",
      plans: getPlanList(userRole),
    });
  },
  $apis.requireAuth(USERS_COLLECTION),
);

routerAdd(
  "POST",
  "/api/rukunwarga/payments/subscription/snap",
  (e) => {
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

    const payload = buildSnapPayload(authRecord, plan, orderId, requestBody, config);
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
  $apis.requireAuth(USERS_COLLECTION),
);

routerAdd(
  "GET",
  "/api/rukunwarga/payments/subscription/status/{orderId}",
  (e) => {
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
  $apis.requireAuth(USERS_COLLECTION),
);

routerAdd(
  "POST",
  "/api/rukunwarga/payments/subscription/midtrans-notification",
  (e) => {
    const requestBody = {};
    e.bindBody(requestBody);

    const orderId = asString(requestBody.order_id);
    const config = getMidtransConfig();

    if (!orderId) {
      throw e.badRequestError("order_id wajib ada pada payload notifikasi.", null);
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
);

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
  const planCollection = safeFindCollectionByNameOrId(SUBSCRIPTION_PLANS_COLLECTION);
  const normalizedRole = normalizeUserRole(role);

  if (!planCollection) {
    return getDefaultPlanList(normalizedRole);
  }

  let filter = "is_active = true";
  const params = {};

  if (requiresSubscriptionRole(normalizedRole)) {
    filter += " && target_role = {:role}";
    params.role = normalizedRole;
  }

  const records = $app.findRecordsByFilter(
    SUBSCRIPTION_PLANS_COLLECTION,
    filter,
    "sort_order,created",
    100,
    0,
    params,
  );

  const plans = [];
  for (const record of records) {
    if (!record) {
      continue;
    }

    plans.push(serializePlanRecord(record));
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
  const plans = Object.keys(DEFAULT_SUBSCRIPTION_PLANS)
    .map(function (key) {
      return DEFAULT_SUBSCRIPTION_PLANS[key];
    })
    .filter(function (plan) {
      if (!requiresSubscriptionRole(role)) {
        return true;
      }

      return plan.targetRole === role;
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
  if (!requiresSubscriptionRole(role)) {
    throw e.forbiddenError(
      "Role akun ini tidak membutuhkan subscription checkout.",
      null,
    );
  }

  if (plan.targetRole && plan.targetRole !== role) {
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

  if (
    normalized === "admin_rt" ||
    normalized === "admin_rw" ||
    normalized === "admin_rw_pro" ||
    normalized === "sysadmin"
  ) {
    return normalized;
  }

  return "user";
}

function requiresSubscriptionRole(role) {
  return role === "admin_rt" || role === "admin_rw" || role === "admin_rw_pro";
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

  subscriberRecord.set("subscription_plan", transactionRecord.getString("plan_code"));
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
