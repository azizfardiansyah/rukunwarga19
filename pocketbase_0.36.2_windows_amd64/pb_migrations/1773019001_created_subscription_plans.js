/// <reference path="../pb_data/types.d.ts" />

migrate((app) => {
  const collection = new Collection({
    type: "base",
    name: "subscription_plans",
    listRule: null,
    viewRule: null,
    createRule: null,
    updateRule: null,
    deleteRule: null,
    fields: [
      new TextField({
        name: "code",
        required: true,
      }),
      new TextField({
        name: "name",
        required: true,
      }),
      new TextField({
        name: "description",
      }),
      new SelectField({
        name: "target_role",
        maxSelect: 1,
        values: ["admin_rt", "admin_rw", "admin_rw_pro"],
        required: true,
      }),
      new NumberField({
        name: "amount",
        onlyInt: true,
        required: true,
        min: 0,
      }),
      new NumberField({
        name: "duration_days",
        onlyInt: true,
        required: true,
        min: 1,
      }),
      new SelectField({
        name: "currency",
        maxSelect: 1,
        values: ["IDR"],
        required: true,
      }),
      new BoolField({
        name: "is_active",
      }),
      new NumberField({
        name: "sort_order",
        onlyInt: true,
      }),
      new AutodateField({
        name: "created",
        onCreate: true,
        onUpdate: false,
      }),
      new AutodateField({
        name: "updated",
        onCreate: true,
        onUpdate: true,
      }),
    ],
  });

  app.save(collection);

  const plans = [
    {
      code: "admin_rt_monthly",
      name: "Admin RT Bulanan",
      description: "Langganan dashboard dan operasional Admin RT selama 30 hari.",
      target_role: "admin_rt",
      amount: 30000,
      duration_days: 30,
      currency: "IDR",
      is_active: true,
      sort_order: 10,
    },
    {
      code: "admin_rw_monthly",
      name: "Admin RW Bulanan",
      description: "Langganan dashboard RW dan akses lintas wilayah selama 30 hari.",
      target_role: "admin_rw",
      amount: 100000,
      duration_days: 30,
      currency: "IDR",
      is_active: true,
      sort_order: 20,
    },
    {
      code: "admin_rw_pro_monthly",
      name: "Admin RW Pro Bulanan",
      description: "Langganan Admin RW Pro dengan OCR dan integrasi pembayaran selama 30 hari.",
      target_role: "admin_rw_pro",
      amount: 250000,
      duration_days: 30,
      currency: "IDR",
      is_active: true,
      sort_order: 30,
    },
  ];

  for (const plan of plans) {
    app.save(new Record(collection, plan));
  }

  return app.save(collection);
}, (app) => {
  const collection = app.findCollectionByNameOrId("subscription_plans");

  return app.delete(collection);
});
