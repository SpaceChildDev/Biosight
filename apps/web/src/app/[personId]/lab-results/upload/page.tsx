import Link from "next/link";
import { notFound } from "next/navigation";
import { db } from "@/lib/db";
import { persons } from "@/lib/db/schema";
import { eq } from "drizzle-orm";
import { Button } from "@/components/ui/button";
import { ArrowLeft } from "lucide-react";
import PdfUploadWizard from "@/components/lab-results/PdfUploadWizard";

export default async function UploadLabPage({
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

  return (
    <div className="space-y-8">
      <div className="flex items-center gap-4">
        <Link href={`/${personId}/lab-results`}>
          <Button variant="ghost" size="icon" className="text-teal-dark">
            <ArrowLeft />
          </Button>
        </Link>
        <h1 className="text-3xl font-bold text-teal-dark">
          {person.name} — Tahlil Ekle
        </h1>
      </div>

      <PdfUploadWizard personId={personId} />
    </div>
  );
}
