import { NextResponse } from "next/server";
import { db } from "@/lib/db";
import { healthMetrics } from "@/lib/db/schema";
import { eq, desc } from "drizzle-orm";
import { z } from "zod";

const metricSchema = z.object({
  personId: z.string().uuid(),
  metricType: z.string().min(1),
  value: z.string().min(1),
  unit: z.string().optional().nullable(),
  recordedAt: z.string().min(1),
  source: z.string().optional().nullable(),
});

const bodySchema = z.union([metricSchema, z.array(metricSchema)]);

export async function GET(request: Request) {
  const { searchParams } = new URL(request.url);
  const personId = searchParams.get("personId");
  if (!personId) {
    return NextResponse.json({ error: "personId required" }, { status: 400 });
  }
  try {
    const rows = await db
      .select()
      .from(healthMetrics)
      .where(eq(healthMetrics.personId, personId))
      .orderBy(desc(healthMetrics.recordedAt))
      .limit(500);
    return NextResponse.json(rows);
  } catch (error) {
    console.error("GET /api/health-metrics failed:", error);
    return NextResponse.json({ error: "Failed to fetch metrics" }, { status: 500 });
  }
}

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
    const items = Array.isArray(parsed.data) ? parsed.data : [parsed.data];
    const inserted = await db
      .insert(healthMetrics)
      .values(
        items.map((m) => ({
          personId: m.personId,
          metricType: m.metricType,
          value: m.value,
          unit: m.unit ?? null,
          recordedAt: new Date(m.recordedAt),
          source: m.source ?? null,
        }))
      )
      .returning({ id: healthMetrics.id });
    return NextResponse.json({ inserted: inserted.length });
  } catch (error) {
    console.error("POST /api/health-metrics failed:", error);
    return NextResponse.json({ error: "Failed to create metrics" }, { status: 500 });
  }
}
