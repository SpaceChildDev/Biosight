import Link from "next/link";
import { notFound } from "next/navigation";
import { db } from "@/lib/db";
import { persons, labReports, healthMetrics, labValues } from "@/lib/db/schema";
import { eq, desc, sql, asc } from "drizzle-orm";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Activity, FileText, TrendingUp, ArrowLeft, ChevronRight, Layers } from "lucide-react";
import { Button } from "@/components/ui/button";

export default async function PersonDashboard({
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

  // Tahlil istatistikleri
  const [labStats] = await db
    .select({
      count: sql<number>`count(*)::int`,
      latestDate: sql<string | null>`max(${labReports.date})`,
    })
    .from(labReports)
    .where(eq(labReports.personId, personId));

  // Kategorileri ve her kategorideki metrikleri getir
  const metricsData = await db
    .select({
      category: labValues.category,
      testName: labValues.testName,
    })
    .from(labValues)
    .innerJoin(labReports, eq(labValues.reportId, labReports.id))
    .where(eq(labReports.personId, personId))
    .groupBy(labValues.category, labValues.testName)
    .orderBy(asc(labValues.category), asc(labValues.testName));

  const categories: Record<string, string[]> = {};
  metricsData.forEach(m => {
    const cat = m.category || "Diğer";
    if (!categories[cat]) categories[cat] = [];
    if (!categories[cat].includes(m.testName)) {
      categories[cat].push(m.testName);
    }
  });

  // Health metrics istatistikleri
  const [metricStats] = await db
    .select({
      count: sql<number>`count(*)::int`,
      latestAt: sql<Date | null>`max(${healthMetrics.recordedAt})`,
    })
    .from(healthMetrics)
    .where(eq(healthMetrics.personId, personId));

  // Son eklenen tahliller
  const recentReports = await db
    .select()
    .from(labReports)
    .where(eq(labReports.personId, personId))
    .orderBy(desc(labReports.date))
    .limit(5);

  const formatDate = (d: string | Date | null) => {
    if (!d) return "—";
    const date = typeof d === "string" ? new Date(d) : d;
    return date.toLocaleDateString("tr-TR");
  };

  return (
    <div className="space-y-8">
      <div className="flex items-center justify-between">
        <div className="flex items-center gap-4">
          <Link href="/">
            <Button variant="ghost" size="icon" className="text-teal-dark">
              <ArrowLeft />
            </Button>
          </Link>
          <h1 className="text-3xl font-bold text-teal-dark">{person.name} - Özet</h1>
        </div>
        <div className="text-sm text-teal-dark/60 font-medium">
          Son Güncelleme: {new Date().toLocaleDateString("tr-TR")}
        </div>
      </div>

      <div className="grid grid-cols-1 md:grid-cols-3 gap-6">
        <Link href={`/${personId}/lab-results`}>
          <Card className="hover:shadow-md transition-shadow cursor-pointer border-mint-light bg-white h-full">
            <CardHeader className="flex flex-row items-center justify-between pb-2 space-y-0">
              <CardTitle className="text-sm font-semibold text-teal-dark/70">Tahlil</CardTitle>
              <FileText className="w-5 h-5 text-teal-medium" />
            </CardHeader>
            <CardContent>
              <div className="text-2xl font-bold text-teal-dark">
                {labStats?.count ?? 0} Kayıt
              </div>
              <p className="text-xs text-teal-dark/50 mt-1">
                {labStats?.latestDate ? `Son tahlil: ${formatDate(labStats.latestDate)}` : "Henüz tahlil yok"}
              </p>
            </CardContent>
          </Card>
        </Link>

        <Link href={`/${personId}/health-data`}>
          <Card className="hover:shadow-md transition-shadow cursor-pointer border-mint-light bg-white h-full">
            <CardHeader className="flex flex-row items-center justify-between pb-2 space-y-0">
              <CardTitle className="text-sm font-semibold text-teal-dark/70">Apple Health</CardTitle>
              <Activity className="w-5 h-5 text-teal-medium" />
            </CardHeader>
            <CardContent>
              <div className="text-2xl font-bold text-teal-dark">
                {metricStats?.count ?? 0} Ölçüm
              </div>
              <p className="text-xs text-teal-dark/50 mt-1">
                {metricStats?.latestAt ? `Son: ${formatDate(metricStats.latestAt)}` : "Henüz veri yok"}
              </p>
            </CardContent>
          </Card>
        </Link>

        <Link href={`/${personId}/trends`}>
          <Card className="hover:shadow-md transition-shadow cursor-pointer border-mint-light bg-white h-full">
            <CardHeader className="flex flex-row items-center justify-between pb-2 space-y-0">
              <CardTitle className="text-sm font-semibold text-teal-dark/70">Trendler & Analiz</CardTitle>
              <TrendingUp className="w-5 h-5 text-teal-medium" />
            </CardHeader>
            <CardContent>
              <div className="text-2xl font-bold text-teal-dark">Görselleştir</div>
              <p className="text-xs text-teal-dark/50 mt-1">Zaman serisi grafikleri</p>
            </CardContent>
          </Card>
        </Link>
      </div>

      <div className="grid grid-cols-1 lg:grid-cols-2 gap-8">
        {/* Sol Taraf: Son Tahliller */}
        <div className="space-y-6">
          <Card className="border-mint-light bg-white h-full">
            <CardHeader className="flex flex-row items-center justify-between">
              <CardTitle className="text-lg text-teal-dark">Son Tahliller</CardTitle>
              <Link href={`/${personId}/lab-results`}>
                <Button variant="link" className="text-teal-medium">Tümünü Gör</Button>
              </Link>
            </CardHeader>
            <CardContent>
              {recentReports.length > 0 ? (
                <ul className="divide-y divide-mint-light">
                  {recentReports.map((r) => (
                    <li key={r.id}>
                      <Link
                        href={`/${personId}/lab-results/${r.id}`}
                        className="flex justify-between py-3 text-sm hover:bg-blue-soft/40 rounded px-2 transition-colors"
                      >
                        <span className="font-medium text-teal-dark">
                          {r.reportType ?? "Tahlil"}
                        </span>
                        <span className="text-teal-dark/60">
                          {formatDate(r.date)}
                        </span>
                      </Link>
                    </li>
                  ))}
                </ul>
              ) : (
                <div className="bg-white/50 border border-dashed border-teal-medium/30 rounded-2xl p-8 text-center text-teal-dark/40 italic">
                  Henüz tahlil eklenmemiş. İlk tahlili yüklemek için{" "}
                  <Link href={`/${personId}/lab-results/upload`} className="underline hover:text-teal-dark">
                    buraya tıklayın
                  </Link>
                  .
                </div>
              )}
            </CardContent>
          </Card>
        </div>

        {/* Sağ Taraf: Kategoriler/Metrikler */}
        <div className="space-y-6">
          <Card className="border-mint-light bg-white h-full">
            <CardHeader className="flex flex-row items-center justify-between">
              <CardTitle className="text-lg text-teal-dark flex items-center gap-2">
                <Layers className="w-5 h-5 text-teal-medium" />
                Kategoriler
              </CardTitle>
            </CardHeader>
            <CardContent className="p-0">
              {Object.keys(categories).length > 0 ? (
                <div className="divide-y divide-mint-light max-h-[500px] overflow-y-auto">
                  {Object.entries(categories).map(([category, tests]) => (
                    <div key={category} className="p-4">
                      <h3 className="text-xs font-bold text-teal-dark/50 uppercase tracking-widest mb-3 px-2">{category}</h3>
                      <div className="grid grid-cols-1 gap-1">
                        {tests.map(test => (
                          <Link 
                            key={test} 
                            href={`/${personId}/trends?metric=${encodeURIComponent(test)}`}
                            className="flex items-center justify-between p-2 text-sm hover:bg-teal-medium/10 rounded-lg transition-colors group"
                          >
                            <span className="text-teal-dark font-medium">{test}</span>
                            <ChevronRight size={14} className="text-teal-medium opacity-0 group-hover:opacity-100 transition-all transform translate-x-[-4px] group-hover:translate-x-0" />
                          </Link>
                        ))}
                      </div>
                    </div>
                  ))}
                </div>
              ) : (
                <div className="p-12 text-center text-teal-dark/40 italic">
                  Henüz kategorize edilmiş metrik bulunamadı.
                </div>
              )}
            </CardContent>
          </Card>
        </div>
      </div>
    </div>
  );
}
