"use client";

import { useState } from "react";
import { useRouter } from "next/navigation";
import { Card, CardContent, CardHeader, CardTitle } from "@/components/ui/card";
import { Input } from "@/components/ui/input";
import { Label } from "@/components/ui/label";
import { Button } from "@/components/ui/button";
import { Plus, Trash2, Upload, Sparkles, AlertTriangle, CheckCircle2, Loader2 } from "lucide-react";

type ValueRow = {
  testName: string;
  testNameStd: string;
  valueNumeric: string;
  valueText: string;
  unit: string;
  refMin: string;
  refMax: string;
  status: string;
  category: string;
};

type ExistingMatch = {
  id: string;
  date: string;
  reportType: string | null;
  hospital: string | null;
  valueCount: number;
  testNames: string[];
};

const emptyRow = (): ValueRow => ({
  testName: "",
  testNameStd: "",
  valueNumeric: "",
  valueText: "",
  unit: "",
  refMin: "",
  refMax: "",
  status: "",
  category: "",
});

const normalizeName = (s: string) => s.toLowerCase().replace(/\s+/g, " ").trim();

export default function PdfUploadWizard({ personId }: { personId: string }) {
  const router = useRouter();

  const [pendingFiles, setPendingFiles] = useState<File[]>([]);
  const [currentIndex, setCurrentIndex] = useState(0);
  const [parsing, setParsing] = useState(false);
  const [saving, setSaving] = useState(false);
  const [parseError, setParseError] = useState<string | null>(null);

  const [date, setDate] = useState(new Date().toISOString().slice(0, 10));
  const [hospital, setHospital] = useState("");
  const [doctor, setDoctor] = useState("");
  const [department, setDepartment] = useState("");
  const [reportType, setReportType] = useState("");
  const [rows, setRows] = useState<ValueRow[]>([emptyRow()]);

  const [duplicates, setDuplicates] = useState<ExistingMatch[] | null>(null);
  const [mergeTargetId, setMergeTargetId] = useState<string | null>(null);

  const resetForm = () => {
    setDate(new Date().toISOString().slice(0, 10));
    setHospital("");
    setDoctor("");
    setDepartment("");
    setReportType("");
    setRows([emptyRow()]);
    setDuplicates(null);
    setMergeTargetId(null);
    setParseError(null);
  };

  const processFile = async (file: File) => {
    setParsing(true);
    setParseError(null);
    setDuplicates(null);
    setMergeTargetId(null);
    try {
      const fd = new FormData();
      fd.append("file", file);
      const res = await fetch("/api/parse-lab-pdf", { method: "POST", body: fd });
      if (!res.ok) {
        const err = await res.json();
        throw new Error(err.details || err.error || "Parse başarısız");
      }
      const data = await res.json();

      if (data.date) setDate(data.date);
      if (data.hospital) setHospital(data.hospital);
      if (data.doctor) setDoctor(data.doctor);
      if (data.department) setDepartment(data.department);
      if (data.reportType) setReportType(data.reportType);

      if (Array.isArray(data.values) && data.values.length > 0) {
        setRows(
          data.values.map((v: Partial<ValueRow>) => ({
            testName: v.testName ?? "",
            testNameStd: v.testNameStd ?? "",
            valueNumeric: v.valueNumeric ?? "",
            valueText: v.valueText ?? "",
            unit: v.unit ?? "",
            refMin: v.refMin ?? "",
            refMax: v.refMax ?? "",
            status: v.status ?? "",
            category: v.category ?? "",
          }))
        );
      }

      // Otomatik duplicate check
      await checkDuplicate(data.date, data.reportType);
    } catch (err) {
      const msg = err instanceof Error ? err.message : "Hata";
      setParseError(msg);
    } finally {
      setParsing(false);
    }
  };

  const handleFileSelect = async (e: React.ChangeEvent<HTMLInputElement>) => {
    const files = Array.from(e.target.files || []);
    if (files.length === 0) return;
    
    setPendingFiles(files);
    setCurrentIndex(0);
    resetForm();
    await processFile(files[0]);
  };

  const checkDuplicate = async (d: string, rt: string | null) => {
    const params = new URLSearchParams({ personId, date: d });
    if (rt) params.set("reportType", rt);
    const res = await fetch(`/api/lab-reports?${params}`);
    if (!res.ok) return;
    const data = await res.json();
    if (data.duplicate) {
      setDuplicates(data.matches);
      // Auto-merge preference: if exactly one match, pre-select it
      if (data.matches.length === 1) {
        setMergeTargetId(data.matches[0].id);
      }
    }
  };

  const updateRow = (i: number, patch: Partial<ValueRow>) => {
    setRows((rs) => rs.map((r, idx) => (idx === i ? { ...r, ...patch } : r)));
  };

  const moveToNext = async () => {
    if (currentIndex < pendingFiles.length - 1) {
      const nextIndex = currentIndex + 1;
      setCurrentIndex(nextIndex);
      resetForm();
      await processFile(pendingFiles[nextIndex]);
    } else {
      router.push(`/${personId}/lab-results`);
      router.refresh();
    }
  };

  const handleSubmit = async (mode: "create" | "merge") => {
    setSaving(true);
    try {
      const res = await fetch("/api/lab-reports", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          personId,
          date,
          hospital,
          doctor,
          department,
          reportType,
          values: rows.filter((r) => r.testName.trim()),
          mode,
          mergeTargetId: mode === "merge" ? mergeTargetId ?? undefined : undefined,
        }),
      });
      if (!res.ok) {
        const data = await res.json();
        alert(data.error ?? "Kaydetme başarısız");
        return;
      }
      
      await moveToNext();
    } catch (err) {
      console.error(err);
      alert("Bir hata oluştu");
    } finally {
      setSaving(false);
    }
  };

  const handleSkip = async () => {
    if (confirm("Bu raporu kaydetmeden geçmek istediğinize emin misiniz?")) {
      await moveToNext();
    }
  };

  // Mevcut raporla karşılaştırma: hangi değerler yeni, hangileri zaten var
  const newValueCount = (() => {
    if (!mergeTargetId) return rows.filter((r) => r.testName.trim()).length;
    const target = duplicates?.find((d) => d.id === mergeTargetId);
    if (!target) return 0;
    const existing = new Set(target.testNames.map(normalizeName));
    return rows.filter((r) => r.testName.trim() && !existing.has(normalizeName(r.testName))).length;
  })();

  const isLastFile = currentIndex === pendingFiles.length - 1;

  return (
    <div className="space-y-6">
      {/* Progress Header */}
      {pendingFiles.length > 0 && (
        <div className="flex items-center justify-between bg-white p-4 rounded-xl border border-mint-light shadow-sm">
          <div className="flex items-center gap-3">
            <div className="bg-teal-dark text-white w-8 h-8 rounded-full flex items-center justify-center font-bold text-sm">
              {currentIndex + 1}
            </div>
            <div>
              <p className="text-sm font-semibold text-teal-dark">
                Rapor {currentIndex + 1} / {pendingFiles.length}
              </p>
              <p className="text-xs text-teal-dark/60 truncate max-w-[200px] md:max-w-md">
                {pendingFiles[currentIndex].name}
              </p>
            </div>
          </div>
          <Button variant="ghost" size="sm" onClick={handleSkip} className="text-teal-dark/60 hover:text-red-500">
            Atla
          </Button>
        </div>
      )}

      {/* PDF Upload */}
      {pendingFiles.length === 0 && (
        <Card className="border-mint-light bg-white">
          <CardHeader>
            <CardTitle className="text-lg text-teal-dark flex items-center gap-2">
              <Sparkles className="w-5 h-5 text-teal-medium" />
              PDF'den Otomatik Çıkarım (Gemini AI)
            </CardTitle>
          </CardHeader>
          <CardContent className="space-y-4">
            <label
              htmlFor="pdf-input"
              className={`flex flex-col items-center justify-center border-2 border-dashed rounded-xl p-10 cursor-pointer transition ${
                parsing
                  ? "border-teal-medium bg-blue-soft/50"
                  : "border-teal-medium/40 hover:border-teal-medium hover:bg-blue-soft/30"
              }`}
            >
              {parsing ? (
                <>
                  <Loader2 className="w-8 h-8 text-teal-medium animate-spin mb-2" />
                  <p className="text-sm text-teal-dark/70">Gemini analiz ediyor...</p>
                </>
              ) : (
                <>
                  <Upload className="w-8 h-8 text-teal-medium mb-2" />
                  <p className="text-sm font-medium text-teal-dark">PDF dosyası seç</p>
                  <p className="text-xs text-teal-dark/50 mt-1">
                    Birden fazla dosya seçebilirsiniz. Otomatik olarak değerler çıkarılacak.
                  </p>
                </>
              )}
            </label>
            <input
              id="pdf-input"
              type="file"
              accept="application/pdf"
              className="hidden"
              onChange={handleFileSelect}
              disabled={parsing}
              multiple
            />
            {parseError && (
              <div className="flex items-start gap-2 p-3 bg-red-50 border border-red-200 rounded-lg text-sm text-red-700">
                <AlertTriangle size={16} className="mt-0.5 flex-shrink-0" />
                <span>{parseError}</span>
              </div>
            )}
          </CardContent>
        </Card>
      )}

      {(pendingFiles.length > 0 || parsing) && (
        <>
          {/* Duplicate uyarısı */}
          {duplicates && duplicates.length > 0 && (
            <Card className="border-amber-300 bg-amber-50">
              <CardHeader>
                <CardTitle className="text-lg text-amber-800 flex items-center gap-2">
                  <AlertTriangle className="w-5 h-5" />
                  Bu tarihte zaten bir rapor var
                </CardTitle>
              </CardHeader>
              <CardContent className="space-y-3">
                <p className="text-sm text-amber-800">
                  Aynı kişi için aynı tarihte {duplicates.length} rapor bulundu. Ne yapmak
                  istersin?
                </p>
                <div className="space-y-2">
                  {duplicates.map((d) => (
                    <label
                      key={d.id}
                      className={`block border rounded-lg p-3 cursor-pointer transition ${
                        mergeTargetId === d.id
                          ? "border-amber-500 bg-amber-100"
                          : "border-amber-200 bg-white hover:border-amber-400"
                      }`}
                    >
                      <input
                        type="radio"
                        name="mergeTarget"
                        checked={mergeTargetId === d.id}
                        onChange={() => setMergeTargetId(d.id)}
                        className="mr-2"
                      />
                      <span className="font-medium text-amber-900">
                        {d.reportType ?? "Tahlil"} — {d.date}
                      </span>
                      <span className="text-sm text-amber-700 ml-2">
                        ({d.valueCount} değer{d.hospital ? `, ${d.hospital}` : ""})
                      </span>
                    </label>
                  ))}
                </div>
                {mergeTargetId && (
                  <div className="flex items-center gap-2 p-2 bg-white rounded text-sm text-amber-900">
                    <CheckCircle2 size={14} />
                    Birleştirme modunda: {newValueCount} yeni değer eklenecek, diğerleri zaten
                    mevcut olduğu için pas geçilecek.
                  </div>
                )}
              </CardContent>
            </Card>
          )}

          {/* Metadata form */}
          <Card className="border-mint-light bg-white">
            <CardHeader>
              <CardTitle className="text-lg text-teal-dark">Tahlil Bilgileri</CardTitle>
            </CardHeader>
            <CardContent className="grid grid-cols-1 md:grid-cols-2 gap-4">
              <div className="space-y-2">
                <Label htmlFor="date">Tarih</Label>
                <Input id="date" type="date" value={date} onChange={(e) => setDate(e.target.value)} required />
              </div>
              <div className="space-y-2">
                <Label htmlFor="reportType">Tahlil Türü</Label>
                <Input id="reportType" placeholder="Biyokimya, Hemogram..." value={reportType} onChange={(e) => setReportType(e.target.value)} />
              </div>
              <div className="space-y-2">
                <Label htmlFor="hospital">Hastane</Label>
                <Input id="hospital" value={hospital} onChange={(e) => setHospital(e.target.value)} />
              </div>
              <div className="space-y-2">
                <Label htmlFor="doctor">Doktor</Label>
                <Input id="doctor" value={doctor} onChange={(e) => setDoctor(e.target.value)} />
              </div>
              <div className="space-y-2 md:col-span-2">
                <Label htmlFor="department">Bölüm</Label>
                <Input id="department" value={department} onChange={(e) => setDepartment(e.target.value)} />
              </div>
            </CardContent>
          </Card>

          {/* Değerler */}
          <Card className="border-mint-light bg-white">
            <CardHeader className="flex flex-row items-center justify-between">
              <CardTitle className="text-lg text-teal-dark">
                Sonuçlar ({rows.filter((r) => r.testName.trim()).length})
              </CardTitle>
              <Button
                type="button"
                variant="outline"
                size="sm"
                onClick={() => setRows((rs) => [...rs, emptyRow()])}
                className="gap-1"
              >
                <Plus size={14} /> Satır ekle
              </Button>
            </CardHeader>
            <CardContent className="space-y-3 overflow-x-auto">
              <div className="min-w-[900px] space-y-3">
                {rows.map((row, i) => (
                  <div key={i} className="grid grid-cols-12 gap-2 items-end">
                    <div className="col-span-3">
                      <Label className="text-xs">Test</Label>
                      <Input value={row.testName} onChange={(e) => updateRow(i, { testName: e.target.value })} />
                    </div>
                    <div className="col-span-2">
                      <Label className="text-xs">Değer</Label>
                      <Input value={row.valueNumeric} onChange={(e) => updateRow(i, { valueNumeric: e.target.value })} />
                    </div>
                    <div className="col-span-1">
                      <Label className="text-xs">Birim</Label>
                      <Input value={row.unit} onChange={(e) => updateRow(i, { unit: e.target.value })} />
                    </div>
                    <div className="col-span-1">
                      <Label className="text-xs">Min</Label>
                      <Input value={row.refMin} onChange={(e) => updateRow(i, { refMin: e.target.value })} />
                    </div>
                    <div className="col-span-1">
                      <Label className="text-xs">Max</Label>
                      <Input value={row.refMax} onChange={(e) => updateRow(i, { refMax: e.target.value })} />
                    </div>
                    <div className="col-span-2">
                      <Label className="text-xs">Durum</Label>
                      <Input value={row.status} onChange={(e) => updateRow(i, { status: e.target.value })} />
                    </div>
                    <div className="col-span-1">
                      <Label className="text-xs">Kategori</Label>
                      <Input value={row.category} onChange={(e) => updateRow(i, { category: e.target.value })} />
                    </div>
                    <div className="col-span-1 flex justify-end">
                      <Button
                        type="button"
                        variant="ghost"
                        size="icon"
                        onClick={() => setRows((rs) => rs.filter((_, idx) => idx !== i))}
                        disabled={rows.length === 1}
                      >
                        <Trash2 size={16} className="text-red-500" />
                      </Button>
                    </div>
                  </div>
                ))}
              </div>
            </CardContent>
          </Card>

          {/* Aksiyon butonları */}
          <div className="flex flex-wrap justify-end gap-2">
            {mergeTargetId && (
              <Button
                type="button"
                onClick={() => handleSubmit("merge")}
                className="bg-amber-600 hover:bg-amber-700"
                disabled={saving || parsing}
              >
                {saving ? "Kaydediliyor..." : isLastFile ? "Birleştir ve Bitir" : "Birleştir ve Sonrakine Geç"}
              </Button>
            )}
            <Button
              type="button"
              onClick={() => handleSubmit("create")}
              className="bg-teal-dark hover:bg-teal-medium"
              disabled={saving || parsing}
            >
              {saving ? "Kaydediliyor..." : isLastFile ? "Kaydet ve Bitir" : "Kaydet ve Sonrakine Geç"}
            </Button>
          </div>
        </>
      )}
    </div>
  );
}
