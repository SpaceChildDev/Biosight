"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Button } from "@/components/ui/button";
import { Upload, Loader2, AlertTriangle, CheckCircle2 } from "lucide-react";

type ImportResult = {
  parsedCount: number;
  insertedCount: number;
  duplicateCount: number;
  skippedUnknownType: number;
  typeBreakdown: Record<string, number>;
  parseErrorSample?: string[];
};

export default function HealthImportCard({ personId }: { personId: string }) {
  const router = useRouter();
  const [uploading, setUploading] = useState(false);
  const [progress, setProgress] = useState<string | null>(null);
  const [result, setResult] = useState<ImportResult | null>(null);
  const [error, setError] = useState<string | null>(null);

  const handleFile = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const file = e.target.files?.[0];
    if (!file) return;
    // Reset
    setUploading(true);
    setError(null);
    setResult(null);
    setProgress(`${file.name} yükleniyor (${(file.size / 1024 / 1024).toFixed(1)} MB)...`);

    try {
      const res = await fetch(`/api/health-import?personId=${personId}`, {
        method: "POST",
        headers: { "Content-Type": "application/xml" },
        body: file,
        // @ts-expect-error — streaming body is a modern fetch feature
        duplex: "half",
      });

      if (!res.ok) {
        const err = await res.json().catch(() => ({ error: "Upload failed" }));
        throw new Error(err.details || err.error || "Upload failed");
      }

      const data: ImportResult = await res.json();
      setResult(data);
      setProgress(null);
      router.refresh();
    } catch (err) {
      const msg = err instanceof Error ? err.message : "Hata";
      setError(msg);
      setProgress(null);
    } finally {
      setUploading(false);
      // file input reset
      e.target.value = "";
    }
  };

  return (
    <Card className="border-mint-light bg-white">
      <CardHeader>
        <CardTitle className="text-lg text-teal-dark flex items-center gap-2">
          <Upload className="w-5 h-5 text-teal-medium" />
          Apple Health XML Import
        </CardTitle>
      </CardHeader>
      <CardContent className="space-y-4">
        <label
          htmlFor="health-xml-input"
          className={`flex flex-col items-center justify-center border-2 border-dashed rounded-xl p-10 transition cursor-pointer ${
            uploading
              ? "border-teal-medium bg-blue-soft/50"
              : "border-teal-medium/40 hover:border-teal-medium hover:bg-blue-soft/30"
          }`}
        >
          {uploading ? (
            <>
              <Loader2 className="w-8 h-8 text-teal-medium animate-spin mb-2" />
              <p className="text-sm text-teal-dark/70">{progress}</p>
              <p className="text-xs text-teal-dark/50 mt-1">
                Büyük dosyalar (500MB+) birkaç dakika sürebilir — sayfayı kapatma
              </p>
            </>
          ) : (
            <>
              <Upload className="w-8 h-8 text-teal-medium mb-2" />
              <p className="text-sm font-medium text-teal-dark">
                Apple Health export.xml dosyasını seç
              </p>
              <p className="text-xs text-teal-dark/50 mt-1 text-center max-w-md">
                Tekrar import ettiğinde mevcut ölçümler otomatik atlanır, sadece yeni
                veriler eklenir
              </p>
            </>
          )}
        </label>
        <input
          id="health-xml-input"
          type="file"
          accept=".xml,application/xml,text/xml"
          className="hidden"
          onChange={handleFile}
          disabled={uploading}
        />

        {error && (
          <div className="flex items-start gap-2 p-3 bg-red-50 border border-red-200 rounded-lg text-sm text-red-700">
            <AlertTriangle size={16} className="mt-0.5 flex-shrink-0" />
            <span>{error}</span>
          </div>
        )}

        {result && (
          <div className="p-4 bg-green-50 border border-green-200 rounded-lg space-y-2">
            <div className="flex items-center gap-2 text-green-800 font-semibold">
              <CheckCircle2 size={18} />
              Import tamamlandı
            </div>
            <div className="grid grid-cols-2 gap-2 text-sm text-green-900">
              <div>
                <span className="font-medium">Eklenen:</span> {result.insertedCount.toLocaleString("tr-TR")}
              </div>
              <div>
                <span className="font-medium">Tekrarlı (atlandı):</span>{" "}
                {result.duplicateCount.toLocaleString("tr-TR")}
              </div>
              <div>
                <span className="font-medium">İşlenen toplam:</span>{" "}
                {result.parsedCount.toLocaleString("tr-TR")}
              </div>
              <div>
                <span className="font-medium">Bilinmeyen tür:</span>{" "}
                {result.skippedUnknownType.toLocaleString("tr-TR")}
              </div>
            </div>
            {Object.keys(result.typeBreakdown).length > 0 && (
              <details className="text-xs text-green-900">
                <summary className="cursor-pointer font-medium">Tür dağılımı</summary>
                <ul className="mt-2 space-y-1 pl-4">
                  {Object.entries(result.typeBreakdown)
                    .sort((a, b) => b[1] - a[1])
                    .map(([type, count]) => (
                      <li key={type}>
                        {type}: {count.toLocaleString("tr-TR")}
                      </li>
                    ))}
                </ul>
              </details>
            )}
          </div>
        )}
      </CardContent>
    </Card>
  );
}
