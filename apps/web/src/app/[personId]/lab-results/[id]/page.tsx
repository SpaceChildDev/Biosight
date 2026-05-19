import Link from "next/link";
import { notFound } from "next/navigation";
import { db } from "@/lib/db";
import { persons, labReports, labValues } from "@/lib/db/schema";
import { eq, and, asc } from "drizzle-orm";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { ArrowLeft, ExternalLink } from "lucide-react";

export default async function LabReportDetailPage({
  params,
}: {
  params: Promise<{ personId: string; id: string }>;
}) {
  const { personId, id } = await params;

  const person = await db
    .select()
    .from(persons)
    .where(eq(persons.id, personId))
    .then((r) => r[0]);
  if (!person) notFound();

  const report = await db
    .select()
    .from(labReports)
    .where(and(eq(labReports.id, id), eq(labReports.personId, personId)))
    .then((r) => r[0]);
  if (!report) notFound();

  const values = await db
    .select()
    .from(labValues)
    .where(eq(labValues.reportId, id))
    .orderBy(asc(labValues.category), asc(labValues.testName));

  const statusColor = (status: string | null) => {
    if (!status) return "text-teal-dark/60";
    const s = status.toLowerCase();
    if (s.includes("yüksek") || s === "y") return "text-red-600 font-semibold";
    if (s.includes("düşük") || s === "d") return "text-blue-600 font-semibold";
    return "text-green-600";
  };

  return (
    <div className="space-y-8">
      <div className="flex items-center justify-between gap-4">
        <div className="flex items-center gap-4">
          <Link href={`/${personId}/lab-results`}>
            <Button variant="ghost" size="icon" className="text-teal-dark">
              <ArrowLeft />
            </Button>
          </Link>
          <div>
            <h1 className="text-2xl font-bold text-teal-dark">
              {report.reportType ?? "Tahlil"} — {report.date}
            </h1>
            <p className="text-sm text-teal-dark/60">
              {[report.hospital, report.doctor, report.department].filter(Boolean).join(" · ")}
            </p>
          </div>
        </div>

        {report.pdfUrl && (
          <a href={report.pdfUrl} target="_blank" rel="noopener noreferrer">
            <Button variant="outline" className="text-teal-dark border-teal-dark/20 gap-2">
              <ExternalLink size={16} />
              Orijinal PDF
            </Button>
          </a>
        )}
      </div>

      {values.length === 0 ? (
        <div className="bg-white/50 border border-dashed border-teal-medium/30 rounded-2xl p-12 text-center text-teal-dark/40 italic">
          Bu tahlilde henüz değer kaydedilmemiş.
        </div>
      ) : (
        <Card className="border-mint-light bg-white">
          <CardHeader>
            <CardTitle className="text-lg text-teal-dark">Sonuçlar</CardTitle>
          </CardHeader>
          <CardContent>
            <table className="w-full text-sm">
              <thead>
                <tr className="text-left text-teal-dark/60 border-b border-mint-light">
                  <th className="py-2 pr-4">Test</th>
                  <th className="py-2 pr-4">Değer</th>
                  <th className="py-2 pr-4">Birim</th>
                  <th className="py-2 pr-4">Referans</th>
                  <th className="py-2">Durum</th>
                </tr>
              </thead>
              <tbody>
                {values.map((v) => (
                  <tr key={v.id} className="border-b border-mint-light/50">
                    <td className="py-2 pr-4 font-medium text-teal-dark">{v.testName}</td>
                    <td className="py-2 pr-4">{v.valueNumeric ?? v.valueText ?? "—"}</td>
                    <td className="py-2 pr-4 text-teal-dark/60">{v.unit ?? ""}</td>
                    <td className="py-2 pr-4 text-teal-dark/60">
                      {v.refMin && v.refMax ? `${v.refMin} - ${v.refMax}` : "—"}
                    </td>
                    <td className={`py-2 ${statusColor(v.status)}`}>{v.status ?? "—"}</td>
                  </tr>
                ))}
              </tbody>
            </table>
          </CardContent>
        </Card>
      )}
    </div>
  );
}
