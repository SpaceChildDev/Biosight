import Link from "next/link";
import { db } from "@/lib/db";
import { persons, labReports } from "@/lib/db/schema";
import { eq, desc } from "drizzle-orm";
import { notFound } from "next/navigation";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { ArrowLeft, FileText, Plus } from "lucide-react";

export default async function LabResultsPage({ params }: { params: Promise<{ personId: string }> }) {
  const { personId } = await params;

  const person = await db.select().from(persons).where(eq(persons.id, personId)).then(r => r[0]);
  if (!person) notFound();

  const reports = await db
    .select()
    .from(labReports)
    .where(eq(labReports.personId, personId))
    .orderBy(desc(labReports.date));

  return (
    <div className="space-y-8">
      <div className="flex items-center justify-between">
        <div className="flex items-center gap-4">
          <Link href={`/${personId}`}>
            <Button variant="ghost" size="icon" className="text-teal-dark">
              <ArrowLeft />
            </Button>
          </Link>
          <h1 className="text-3xl font-bold text-teal-dark">{person.name} - Tahlil</h1>
        </div>
        <Link href={`/${personId}/lab-results/upload`}>
          <Button className="bg-teal-dark hover:bg-teal-medium gap-2">
            <Plus size={16} />
            Tahlil Ekle
          </Button>
        </Link>
      </div>

      {reports.length === 0 ? (
        <div className="bg-white/50 border border-dashed border-teal-medium/30 rounded-2xl p-16 text-center text-teal-dark/40 italic">
          Henüz tahlil sonucu eklenmemiş. Yeni bir tahlil eklemek için &quot;Tahlil Ekle&quot; butonuna tıklayın.
        </div>
      ) : (
        <div className="space-y-4">
          {reports.map((report) => (
            <Link key={report.id} href={`/${personId}/lab-results/${report.id}`}>
              <Card className="hover:shadow-md transition-shadow cursor-pointer border-mint-light bg-white">
                <CardHeader className="flex flex-row items-center justify-between pb-2 space-y-0">
                  <CardTitle className="text-base font-semibold text-teal-dark flex items-center gap-2">
                    <FileText size={16} className="text-teal-medium" />
                    {report.reportType ?? "Tahlil"}
                  </CardTitle>
                  <span className="text-sm text-teal-dark/50">{report.date}</span>
                </CardHeader>
                <CardContent>
                  <div className="text-sm text-teal-dark/60 space-x-4">
                    {report.hospital && <span>{report.hospital}</span>}
                    {report.doctor && <span>Dr. {report.doctor}</span>}
                    {report.department && <span>{report.department}</span>}
                  </div>
                </CardContent>
              </Card>
            </Link>
          ))}
        </div>
      )}
    </div>
  );
}
