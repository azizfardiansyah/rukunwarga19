/// <reference path="../pb_data/types.d.ts" />

migrate((app) => {
  const orgUnits = findCollection(app, "org_units");
  const jabatanMaster = findCollection(app, "jabatan_master");

  if (orgUnits) {
    ensureSelectFieldValues(orgUnits, "type", ["karang_taruna"]);
    app.save(orgUnits);
  }

  if (jabatanMaster) {
    ensureSelectFieldValues(jabatanMaster, "unit_type", ["karang_taruna"]);
    app.save(jabatanMaster);

    const seeds = [
      seedJabatan("ketua_karang_taruna", "Ketua Karang Taruna", 181, {
        canManageUnit: true,
        canManageMembership: true,
        canApproveFinance: true,
        canPublishFinance: true,
        canManageSchedule: true,
        canBroadcastUnit: true,
      }),
      seedJabatan(
        "wakil_ketua_karang_taruna",
        "Wakil Ketua Karang Taruna",
        182,
        {
          canManageUnit: true,
          canManageMembership: true,
          canApproveFinance: true,
          canPublishFinance: true,
          canManageSchedule: true,
          canBroadcastUnit: true,
        },
      ),
      seedJabatan("sekretaris_karang_taruna", "Sekretaris Karang Taruna", 183, {
        canManageSchedule: true,
        canBroadcastUnit: true,
      }),
      seedJabatan("bendahara_karang_taruna", "Bendahara Karang Taruna", 184, {
        canSubmitFinance: true,
      }),
      seedJabatan("pengurus_karang_taruna", "Pengurus Karang Taruna", 185, {
        canManageSchedule: true,
        canBroadcastUnit: true,
      }),
    ];

    for (const seed of seeds) {
      upsertByCode(app, jabatanMaster, seed);
    }
  }
}, (app) => {
  // Intentionally non-destructive.
});

function seedJabatan(
  code,
  label,
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
    unit_type: "karang_taruna",
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

function ensureSelectFieldValues(collection, fieldName, values) {
  const field = collection.fields.getByName(fieldName);
  if (!field) {
    return;
  }
  field.values = Array.from(new Set([...(field.values || []), ...values]));
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
