import { NextResponse } from "next/server";
import { db } from "@/lib/db";
import { labReports, labValues } from "@/lib/db/schema";
import { and, eq } from "drizzle-orm";
import { z } from "zod";

const valueSchema = z.object({
  testName: z.string().min(1),
  testNameStd: z.string().optional().nullable(),
  valueNumeric: z.string().optional().nullable(),
  valueText: z.string().optional().nullable(),
  unit: z.string().optional().nullable(),
  refMin: z.string().optional().nullable(),
  refMax: z.string().optional().nullable(),
  status: z.string().optional().nullable(),
  category: z.string().optional().nullable(),
});

const bodySchema = z.object({
  personId: z.string().uuid(),
  date: z.string().min(1),
  hospital: z.string().optional().nullable(),
  doctor: z.string().optional().nullable(),
  department: z.string().optional().nullable(),
  reportType: z.string().optional().nullable(),
  pdfUrl: z.string().optional().nullable(),
  values: z.array(valueSchema).default([]),
  // "create" = her zaman yeni, "merge" = mevcut bulunursa eksikleri tamamla
  mode: z.enum(["create", "merge"]).default("create"),
  // merge modunda hangi raporla birleştirileceği (belirtilmezse otomatik arar)
  mergeTargetId: z.string().uuid().optional(),
});

const blankToNull = (v: unknown) =>
  typeof v === "string" && v.trim() === "" ? null : (v as string | null | undefined) ?? null;

const normalizeName = (s: string) => s.toLowerCase().replace(/\s+/g, " ").trim();

export async function POST(request: Request) {
  try {
    const json = await request.json();
    const parsed = bodySchema.safeParse(json);
    if (!parsed.success) {
      return NextResponse.json(
        { error: "Invalid payload", details: parsed.error.flatten() },
        { status: 400 }
      );
    }
    const {
      personId,
      date,
      hospital,
      doctor,
      department,
      reportType,
      pdfUrl,
      values,
      mode,
      mergeTargetId,
    } = parsed.data;

    // MERGE modu: mevcut raporu bul, eksik değerleri ekle
    if (mode === "merge") {
      let target = mergeTargetId
        ? await db
            .select()
            .from(labReports)
            .where(and(eq(labReports.id, mergeTargetId), eq(labReports.personId, personId)))
            .then((r) => r[0])
        : null;

      if (!target) {
        // Otomatik ara: aynı kişi + aynı tarih + aynı reportType (veya reportType null ise ignore)
        target = await db
          .select()
          .from(labReports)
          .where(and(eq(labReports.personId, personId), eq(labReports.date, date)))
          .then((r) =>
            reportType
              ? r.find((x) => (x.reportType ?? "").toLowerCase() === reportType.toLowerCase()) ??
                r[0]
              : r[0]
          );
      }

      if (!target) {
        // Birleştirilecek rapor yok → yeni oluştur
        return await createNewReport();
      }

      // Mevcut değerleri çek
      const existing = await db
        .select()
        .from(labValues)
        .where(eq(labValues.reportId, target.id));

      const existingNames = new Set(existing.map((v) => normalizeName(v.testName)));

      const toInsert = values.filter((v) => !existingNames.has(normalizeName(v.testName)));

      let addedCount = 0;
      if (toInsert.length > 0) {
        await db.insert(labValues).values(
          toInsert.map((v) => ({
            reportId: target!.id,
            testName: v.testName,
            testNameStd: blankToNull(v.testNameStd),
            valueNumeric: blankToNull(v.valueNumeric),
            valueText: blankToNull(v.valueText),
            unit: blankToNull(v.unit),
            refMin: blankToNull(v.refMin),
            refMax: blankToNull(v.refMax),
            status: blankToNull(v.status),
            category: blankToNull(v.category),
          }))
        );
        addedCount = toInsert.length;
      }

      // Eksik metadata alanlarını güncelle (mevcut null olanları yeni değerle doldur)
      const metadataUpdates: Record<string, string | null> = {};
      if (!target.hospital && hospital) metadataUpdates.hospital = hospital;
      if (!target.doctor && doctor) metadataUpdates.doctor = doctor;
      if (!target.department && department) metadataUpdates.department = department;
      if (!target.reportType && reportType) metadataUpdates.reportType = reportType;
      if (Object.keys(metadataUpdates).length > 0) {
        await db.update(labReports).set(metadataUpdates).where(eq(labReports.id, target.id));
      }

      return NextResponse.json({
        id: target.id,
        mode: "merged",
        addedCount,
        skippedCount: values.length - addedCount,
      });
    }

    return await createNewReport();

    async function createNewReport() {
      const [report] = await db
        .insert(labReports)
        .values({
          personId,
          date,
          hospital: blankToNull(hospital),
          doctor: blankToNull(doctor),
          department: blankToNull(department),
          reportType: blankToNull(reportType),
          pdfUrl: blankToNull(pdfUrl),
        })
        .returning();

      if (values.length > 0) {
        await db.insert(labValues).values(
          values.map((v) => ({
            reportId: report.id,
            testName: v.testName,
            testNameStd: blankToNull(v.testNameStd),
            valueNumeric: blankToNull(v.valueNumeric),
            valueText: blankToNull(v.valueText),
            unit: blankToNull(v.unit),
            refMin: blankToNull(v.refMin),
            refMax: blankToNull(v.refMax),
            status: blankToNull(v.status),
            category: blankToNull(v.category),
          }))
        );
      }

      return NextResponse.json({ id: report.id, mode: "created" });
    }
  } catch (error) {
    console.error("POST /api/lab-reports failed:", error);
    return NextResponse.json({ error: "Failed to create lab report" }, { status: 500 });
  }
}

// Duplicate kontrol endpoint
export async function GET(request: Request) {
  const { searchParams } = new URL(request.url);
  const personId = searchParams.get("personId");
  const date = searchParams.get("date");
  const reportType = searchParams.get("reportType");

  if (!personId || !date) {
    return NextResponse.json({ error: "personId and date are required" }, { status: 400 });
  }

  try {
    const rows = await db
      .select()
      .from(labReports)
      .where(and(eq(labReports.personId, personId), eq(labReports.date, date)));

    const matches = reportType
      ? rows.filter(
          (r) => (r.reportType ?? "").toLowerCase() === reportType.toLowerCase()
        )
      : rows;

    if (matches.length === 0) {
      return NextResponse.json({ duplicate: false });
    }

    // İlgili raporların değer sayısını da döndür
    const results = await Promise.all(
      matches.map(async (r) => {
        const vals = await db
          .select({ testName: labValues.testName })
          .from(labValues)
          .where(eq(labValues.reportId, r.id));
        return {
          id: r.id,
          date: r.date,
          reportType: r.reportType,
          hospital: r.hospital,
          valueCount: vals.length,
          testNames: vals.map((v) => v.testName),
        };
      })
    );

    return NextResponse.json({ duplicate: true, matches: results });
  } catch (error) {
    console.error("GET /api/lab-reports failed:", error);
    return NextResponse.json({ error: "Failed to check duplicate" }, { status: 500 });
  }
}
