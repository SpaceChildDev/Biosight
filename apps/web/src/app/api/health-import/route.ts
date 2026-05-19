import { NextResponse } from "next/server";
import { Readable } from "node:stream";
import sax from "sax";
import { db } from "@/lib/db";
import { healthMetrics } from "@/lib/db/schema";

export const maxDuration = 300;
export const dynamic = "force-dynamic";

// Apple Health HK type ID → insan okunabilir Türkçe isim
const TYPE_MAP: Record<string, string> = {
  HKQuantityTypeIdentifierHeartRate: "Kalp Hızı",
  HKQuantityTypeIdentifierRestingHeartRate: "Dinlenme Kalp Hızı",
  HKQuantityTypeIdentifierWalkingHeartRateAverage: "Yürüme Kalp Hızı",
  HKQuantityTypeIdentifierHeartRateVariabilitySDNN: "HRV",
  HKQuantityTypeIdentifierStepCount: "Adım",
  HKQuantityTypeIdentifierDistanceWalkingRunning: "Yürüme/Koşu Mesafesi",
  HKQuantityTypeIdentifierFlightsClimbed: "Çıkılan Kat",
  HKQuantityTypeIdentifierOxygenSaturation: "SpO2",
  HKQuantityTypeIdentifierRespiratoryRate: "Solunum Hızı",
  HKQuantityTypeIdentifierBloodPressureSystolic: "Tansiyon (Sistolik)",
  HKQuantityTypeIdentifierBloodPressureDiastolic: "Tansiyon (Diastolik)",
  HKQuantityTypeIdentifierBodyMass: "Kilo",
  HKQuantityTypeIdentifierBodyMassIndex: "BMI",
  HKQuantityTypeIdentifierBodyFatPercentage: "Vücut Yağ Oranı",
  HKQuantityTypeIdentifierLeanBodyMass: "Yağsız Vücut Kütlesi",
  HKQuantityTypeIdentifierBodyTemperature: "Vücut Sıcaklığı",
  HKQuantityTypeIdentifierVO2Max: "VO2 Max",
  HKQuantityTypeIdentifierActiveEnergyBurned: "Aktif Kalori",
  HKQuantityTypeIdentifierBasalEnergyBurned: "Bazal Kalori",
  HKQuantityTypeIdentifierBloodGlucose: "Kan Şekeri",
};

type MetricRow = {
  personId: string;
  metricType: string;
  value: string;
  unit: string | null;
  recordedAt: Date;
  source: string | null;
};

const BATCH_SIZE = 500;

async function flushBatch(batch: MetricRow[]): Promise<number> {
  if (batch.length === 0) return 0;
  const result = await db
    .insert(healthMetrics)
    .values(batch)
    .onConflictDoNothing({
      target: [
        healthMetrics.personId,
        healthMetrics.metricType,
        healthMetrics.recordedAt,
        healthMetrics.value,
      ],
    })
    .returning({ id: healthMetrics.id });
  return result.length;
}

export async function POST(request: Request) {
  const { searchParams } = new URL(request.url);
  const personId = searchParams.get("personId");
  if (!personId) {
    return NextResponse.json({ error: "personId query param is required" }, { status: 400 });
  }
  if (!request.body) {
    return NextResponse.json({ error: "Request body is empty" }, { status: 400 });
  }

  const parser = sax.createStream(true, { trim: true, normalize: true });

  let totalParsed = 0;
  let totalInserted = 0;
  let skippedType = 0;
  let batch: MetricRow[] = [];
  const typeCounts: Record<string, number> = {};

  // SAX işlerken batch flush için bir promise zinciri tutuyoruz
  let flushChain: Promise<void> = Promise.resolve();

  parser.on("opentag", (node) => {
    if (node.name !== "Record") return;
    const attrs = node.attributes as Record<string, string>;
    const hkType = attrs.type;
    if (!hkType) return;

    // Sadece numeric quantity type'ları al — category (uyku, vb.) sonradan
    if (!hkType.startsWith("HKQuantityTypeIdentifier")) {
      skippedType++;
      return;
    }

    const friendlyName = TYPE_MAP[hkType];
    if (!friendlyName) {
      skippedType++;
      return;
    }

    const rawValue = attrs.value;
    if (!rawValue) return;
    const numValue = Number(rawValue);
    if (!Number.isFinite(numValue)) return;

    // Apple Health tarih formatı: "2024-01-15 14:32:11 +0300"
    const dateStr = attrs.startDate ?? attrs.creationDate;
    if (!dateStr) return;
    const recordedAt = new Date(dateStr);
    if (Number.isNaN(recordedAt.getTime())) return;

    batch.push({
      personId,
      metricType: friendlyName,
      value: rawValue,
      unit: attrs.unit ?? null,
      recordedAt,
      source: attrs.sourceName ?? null,
    });
    totalParsed++;
    typeCounts[friendlyName] = (typeCounts[friendlyName] ?? 0) + 1;

    if (batch.length >= BATCH_SIZE) {
      const toFlush = batch;
      batch = [];
      // Serialize flushes to avoid too many concurrent DB calls
      flushChain = flushChain.then(async () => {
        try {
          const inserted = await flushBatch(toFlush);
          totalInserted += inserted;
        } catch (e) {
          console.error("Batch insert failed:", e);
        }
      });
    }
  });

  // Parse hatalarını yakala ama devam et (Apple Health XML bazen geçersiz entity içerir)
  const parseErrors: string[] = [];
  parser.on("error", (err) => {
    parseErrors.push(err.message);
    // SAX'ta hatadan sonra devam etmek için _parser.error = null
    // @ts-expect-error — internal reset
    parser._parser.error = null;
    parser.resume();
  });

  const done = new Promise<void>((resolve, reject) => {
    parser.on("end", () => resolve());
    parser.on("error", () => {
      /* errors handled above */
    });
    parser.on("close", () => resolve());
    // timeout safety
    setTimeout(() => reject(new Error("Parse timeout")), 290_000);
  });

  try {
    // Web ReadableStream → Node Readable → sax
    const nodeStream = Readable.fromWeb(request.body as unknown as Parameters<typeof Readable.fromWeb>[0]);
    nodeStream.pipe(parser);
    await done;

    // Son batch'i flush et
    if (batch.length > 0) {
      const toFlush = batch;
      batch = [];
      flushChain = flushChain.then(async () => {
        const inserted = await flushBatch(toFlush);
        totalInserted += inserted;
      });
    }
    await flushChain;

    return NextResponse.json({
      parsedCount: totalParsed,
      insertedCount: totalInserted,
      duplicateCount: totalParsed - totalInserted,
      skippedUnknownType: skippedType,
      typeBreakdown: typeCounts,
      parseErrorSample: parseErrors.slice(0, 5),
    });
  } catch (error) {
    const msg = error instanceof Error ? error.message : String(error);
    console.error("health-import failed:", error);
    return NextResponse.json(
      {
        error: "Failed to import health data",
        details: msg,
        parsedSoFar: totalParsed,
        insertedSoFar: totalInserted,
      },
      { status: 500 }
    );
  }
}
