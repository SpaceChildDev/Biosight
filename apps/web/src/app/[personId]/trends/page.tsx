import Link from "next/link";
import { notFound } from "next/navigation";
import { db } from "@/lib/db";
import { persons, labValues, labReports } from "@/lib/db/schema";
import { eq, asc } from "drizzle-orm";
import { Button } from "@/components/ui/button";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { ArrowLeft, TrendingUp } from "lucide-react";
import TrendsChart from "@/components/trends/TrendsChart";

export default async function TrendsPage({
  params,
  searchParams,
}: {
  params: Promise<{ personId: string }>;
  searchParams: Promise<{ metric?: string }>;
}) {
  const { personId } = await params;
  const { metric } = await searchParams;

  const person = await db
    .select()
    .from(persons)
    .where(eq(persons.id, personId))
    .then((r) => r[0]);
  if (!person) notFound();

  // Kişinin tüm tahlil değerlerini tarihle birlikte çek
  const rows = await db
    .select({
      date: labReports.date,
      testName: labValues.testName,
      valueNumeric: labValues.valueNumeric,
      valueText: labValues.valueText,
      unit: labValues.unit,
      refMin: labValues.refMin,
      refMax: labValues.refMax,
      status: labValues.status,
    })
    .from(labValues)
    .innerJoin(labReports, eq(labValues.reportId, labReports.id))
    .where(eq(labReports.personId, personId))
    .orderBy(desc(labReports.date)); // En yeni en üstte

  // testName bazında grupla
  const grouped = new Map<
    string,
    { date: string; value: number | null; valueText: string | null; unit: string | null; refMin: number | null; refMax: number | null; status: string | null }[]
  >();

  for (const r of rows) {
    const list = grouped.get(r.testName) ?? [];
    list.push({
      date: r.date,
      value: r.valueNumeric ? Number(r.valueNumeric) : null,
      valueText: r.valueText,
      unit: r.unit,
      refMin: r.refMin ? Number(r.refMin) : null,
      refMax: r.refMax ? Number(r.refMax) : null,
      status: r.status,
    });
    grouped.set(r.testName, list);
  }

  // Filtreleme varsa uygula, yoksa 2+ ölçümü olanları göster
  let series = Array.from(grouped.entries())
    .map(([testName, points]) => ({ testName, points }));
  
  if (metric) {
    series = series.filter(s => s.testName === metric);
  } else {
    series = series.filter(s => s.points.filter(p => p.value !== null).length >= 2);
  }

  const statusColor = (status: string | null) => {
    if (!status) return "text-teal-dark/60";
    const s = status.toLowerCase();
    if (s.includes("yüksek") || s === "y") return "text-red-600 font-semibold";
    if (s.includes("düşük") || s === "d") return "text-blue-600 font-semibold";
    return "text-green-600";
  };

  return (
    <div className="space-y-8">
      <div className="flex items-center gap-4">
        <Link href={`/${personId}`}>
          <Button variant="ghost" size="icon" className="text-teal-dark">
            <ArrowLeft />
          </Button>
        </Link>
        <h1 className="text-3xl font-bold text-teal-dark">
          {metric ? `${metric} Geçmişi` : `${person.name} — Trendler`}
        </h1>
      </div>

      {series.length === 0 ? (
        <div className="bg-white/50 border border-dashed border-teal-medium/30 rounded-2xl p-16 text-center text-teal-dark/50 space-y-3">
          <TrendingUp className="w-12 h-12 mx-auto text-teal-medium/50" />
          <p className="italic">
            {metric ? "Bu metrik için henüz veri bulunamadı." : "Trend gösterimi için en az 2 farklı tarihte kaydedilmiş tahlil değeri gerekli."}
          </p>
        </div>
      ) : (
        <div className="space-y-12">
          {series.map((s) => (
            <div key={s.testName} className="space-y-6">
              {!metric && <h2 className="text-xl font-bold text-teal-dark border-b border-mint-light pb-2">{s.testName}</h2>}
              
              <div className="grid grid-cols-1 lg:grid-cols-3 gap-8">
                {/* Grafik (Eğer nümerik veriler varsa) */}
                <div className="lg:col-span-2">
                  <Card className="border-mint-light bg-white h-full">
                    <CardHeader>
                      <CardTitle className="text-base text-teal-dark flex items-center justify-between">
                        <span>Değişim Grafiği</span>
                        <span className="text-xs font-normal text-teal-dark/50">
                          {s.points[0].unit ? `Birim: ${s.points[0].unit}` : ""}
                        </span>
                      </CardTitle>
                    </CardHeader>
                    <CardContent>
                      {s.points.some(p => p.value !== null) ? (
                        <TrendsChart
                          data={s.points
                            .filter(p => p.value !== null)
                            .map((p) => ({ date: p.date, value: p.value! }))
                            .reverse() // Grafik için eskiden yeniye
                          }
                          refMin={s.points[0].refMin}
                          refMax={s.points[0].refMax}
                        />
                      ) : (
                        <div className="h-[300px] flex items-center justify-center text-sm text-teal-dark/40 italic">
                          Grafik için nümerik veri bulunamadı.
                        </div>
                      )}
                    </CardContent>
                  </Card>
                </div>

                {/* Geçmiş Listesi */}
                <div>
                  <Card className="border-mint-light bg-white h-full">
                    <CardHeader>
                      <CardTitle className="text-base text-teal-dark">Ölçüm Geçmişi</CardTitle>
                    </CardHeader>
                    <CardContent className="p-0">
                      <div className="divide-y divide-mint-light">
                        {s.points.map((p, idx) => (
                          <div key={idx} className="p-4 flex justify-between items-center text-sm hover:bg-blue-soft/20 transition-colors">
                            <div className="flex flex-col">
                              <span className="font-semibold text-teal-dark">
                                {p.value ?? p.valueText ?? "—"} 
                                <span className="text-xs font-normal text-teal-dark/50 ml-1">{p.unit}</span>
                              </span>
                              <span className="text-xs text-teal-dark/40">{p.date}</span>
                            </div>
                            <div className={`text-xs ${statusColor(p.status)}`}>
                              {p.status ?? "Normal"}
                            </div>
                          </div>
                        ))}
                      </div>
                    </CardContent>
                  </Card>
                </div>
              </div>
            </div>
          ))}
        </div>
      )}
    </div>
  );
}
