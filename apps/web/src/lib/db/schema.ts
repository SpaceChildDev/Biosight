import { pgTable, text, date, timestamp, decimal, uuid, pgEnum, uniqueIndex } from "drizzle-orm/pg-core";
import { relations } from "drizzle-orm";

export const genderEnum = pgEnum("gender", ["Erkek", "Kadın", "Diğer"]);

export const persons = pgTable("persons", {
  id: uuid("id").primaryKey().defaultRandom(),
  name: text("name").notNull(),
  birthDate: date("birth_date"),
  gender: genderEnum("gender"),
  createdAt: timestamp("created_at").defaultNow(),
});

export const labReports = pgTable("lab_reports", {
  id: uuid("id").primaryKey().defaultRandom(),
  personId: uuid("person_id").references(() => persons.id).notNull(),
  date: date("date").notNull(),
  hospital: text("hospital"),
  doctor: text("doctor"),
  department: text("department"),
  reportType: text("report_type"), // biyokimya, hemogram, idrar, vb.
  pdfUrl: text("pdf_url"),
  createdAt: timestamp("created_at").defaultNow(),
});

export const labValues = pgTable("lab_values", {
  id: uuid("id").primaryKey().defaultRandom(),
  reportId: uuid("report_id").references(() => labReports.id).notNull(),
  testName: text("test_name").notNull(),
  testNameStd: text("test_name_std"), // Standartlaştırılmış ad (örn: "AST")
  valueNumeric: decimal("value_numeric", { precision: 10, scale: 2 }),
  valueText: text("value_text"), // Eğer değer nümerik değilse (örn: "Negatif")
  unit: text("unit"),
  refMin: decimal("ref_min", { precision: 10, scale: 2 }),
  refMax: decimal("ref_max", { precision: 10, scale: 2 }),
  status: text("status"), // Normal, Yüksek, Düşük
  category: text("category"), // Metabolizma, Karaciğer, vb.
  createdAt: timestamp("created_at").defaultNow(),
});

export const healthMetrics = pgTable(
  "health_metrics",
  {
    id: uuid("id").primaryKey().defaultRandom(),
    personId: uuid("person_id").references(() => persons.id).notNull(),
    metricType: text("metric_type").notNull(), // Kalp Hızı, Adım, SpO2, vb.
    value: decimal("value", { precision: 10, scale: 2 }).notNull(),
    unit: text("unit"),
    recordedAt: timestamp("recorded_at").notNull(),
    source: text("source"), // Apple Watch, iPhone, vb.
    createdAt: timestamp("created_at").defaultNow(),
  },
  (t) => ({
    // Aynı kişi + tür + zaman + değer = aynı kayıt. Re-import'ta duplicate olmasın.
    uniqDedup: uniqueIndex("health_metrics_dedup_idx").on(
      t.personId,
      t.metricType,
      t.recordedAt,
      t.value
    ),
  })
);

// İlişkiler
export const personsRelations = relations(persons, ({ many }) => ({
  labReports: many(labReports),
  healthMetrics: many(healthMetrics),
}));

export const labReportsRelations = relations(labReports, ({ one, many }) => ({
  person: one(persons, { fields: [labReports.personId], references: [persons.id] }),
  values: many(labValues),
}));

export const labValuesRelations = relations(labValues, ({ one }) => ({
  report: one(labReports, { fields: [labValues.reportId], references: [labReports.id] }),
}));

export const healthMetricsRelations = relations(healthMetrics, ({ one }) => ({
  person: one(persons, { fields: [healthMetrics.personId], references: [persons.id] }),
}));
