import Link from "next/link";
import { notFound } from "next/navigation";
import { db } from "@/lib/db";
import { persons, healthMetrics } from "@/lib/db/schema";
import { eq, desc, sql } from "drizzle-orm";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { ArrowLeft, Activity, Heart, Moon, Footprints } from "lucide-react";
import HealthImportCard from "@/components/health-data/HealthImportCard";

export default async function HealthDataPage({
  params,
}: {
  params: Promise<{ personId: string }>;
}) {
  const { personId } = await params;

  const person = await db
    .select()
    .from(persons)
    .where(eq(persons.id, personId))
    .then((r) => r[0]);
  if (!person) notFound();

  // Son kayıtlar
  const recent = await db
    .select()
    .from(healthMetrics)
    .where(eq(healthMetrics.personId, personId))
    .orderBy(desc(healthMetrics.recordedAt))
    .limit(20);

  // Metrik türüne göre özet
  const summary = await db
    .select({
      metricType: healthMetrics.metricType,
      count: sql<number>`count(*)::int`,
      latest: sql<string>`max(${healthMetrics.recordedAt})`,
    })
    .from(healthMetrics)
    .where(eq(healthMetrics.personId, personId))
    .groupBy(healthMetrics.metricType);

  const iconFor = (type: string) => {
    const t = type.toLowerCase();
    if (t.includes("kalp") || t.includes("heart")) return <Heart className="w-5 h-5 text-teal-medium" />;
    if (t.includes("adım") || t.includes("step")) return <Footprints className="w-5 h-5 text-teal-medium" />;
    if (t.includes("uyku") || t.includes("sleep")) return <Moon className="w-5 h-5 text-teal-medium" />;
    return <Activity className="w-5 h-5 text-teal-medium" />;
  };

  return (
    <div className="space-y-8">
      <div className="flex items-center justify-between">
        <div className="flex items-center gap-4">
          <Link href={`/${personId}`}>
            <Button variant="ghost" size="icon" className="text-teal-dark">
              <ArrowLeft />
            </Button>
          </Link>
          <h1 className="text-3xl font-bold text-teal-dark">{person.name} — Apple Health</h1>
        </div>
      </div>

      <HealthImportCard personId={personId} />

      {summary.length === 0 ? (
        <div className="bg-white/50 border border-dashed border-teal-medium/30 rounded-2xl p-16 text-center text-teal-dark/50 space-y-3">
          <Activity className="w-12 h-12 mx-auto text-teal-medium/50" />
          <p className="italic">Henüz Apple Health verisi eklenmemiş.</p>
          <p className="text-sm">
            Yukarıdan Apple Health export.xml dosyanı yükle.
          </p>
        </div>
      ) : (
        <>
          <div className="grid grid-cols-1 md:grid-cols-2 lg:grid-cols-3 gap-6">
            {summary.map((s) => (
              <Card key={s.metricType} className="border-mint-light bg-white">
                <CardHeader className="flex flex-row items-center justify-between pb-2 space-y-0">
                  <CardTitle className="text-sm font-semibold text-teal-dark/70">{s.metricType}</CardTitle>
                  {iconFor(s.metricType)}
                </CardHeader>
                <CardContent>
                  <div className="text-2xl font-bold text-teal-dark">{s.count} kayıt</div>
                  <p className="text-xs text-teal-dark/50 mt-1">
                    Son: {s.latest ? new Date(s.latest).toLocaleDateString("tr-TR") : "—"}
                  </p>
                </CardContent>
              </Card>
            ))}
          </div>

          <Card className="border-mint-light bg-white">
            <CardHeader>
              <CardTitle className="text-lg text-teal-dark">Son Ölçümler</CardTitle>
            </CardHeader>
            <CardContent>
              <table className="w-full text-sm">
                <thead>
                  <tr className="text-left text-teal-dark/60 border-b border-mint-light">
                    <th className="py-2 pr-4">Tür</th>
                    <th className="py-2 pr-4">Değer</th>
                    <th className="py-2 pr-4">Birim</th>
                    <th className="py-2 pr-4">Zaman</th>
                    <th className="py-2">Kaynak</th>
                  </tr>
                </thead>
                <tbody>
                  {recent.map((m) => (
                    <tr key={m.id} className="border-b border-mint-light/50">
                      <td className="py-2 pr-4 font-medium text-teal-dark">{m.metricType}</td>
                      <td className="py-2 pr-4">{m.value}</td>
                      <td className="py-2 pr-4 text-teal-dark/60">{m.unit ?? ""}</td>
                      <td className="py-2 pr-4 text-teal-dark/60">
                        {new Date(m.recordedAt).toLocaleString("tr-TR")}
                      </td>
                      <td className="py-2 text-teal-dark/60">{m.source ?? "—"}</td>
                    </tr>
                  ))}
                </tbody>
              </table>
            </CardContent>
          </Card>
        </>
      )}
    </div>
  );
}
