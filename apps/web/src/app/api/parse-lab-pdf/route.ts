import { NextResponse } from "next/server";
import { GoogleGenAI, Type } from "@google/genai";

const apiKey = process.env.GEMINI_API_KEY;

export const maxDuration = 300;

const parseSchema = {
  type: Type.OBJECT,
  properties: {
    date: { type: Type.STRING, description: "Tahlil tarihi YYYY-MM-DD formatında" },
    hospital: { type: Type.STRING, description: "Hastane adı" },
    doctor: { type: Type.STRING, description: "Doktor adı" },
    department: { type: Type.STRING, description: "Bölüm adı" },
    reportType: {
      type: Type.STRING,
      description: "Tahlil türü (Biyokimya, Hemogram, İdrar, vb.)",
    },
    values: {
      type: Type.ARRAY,
      items: {
        type: Type.OBJECT,
        properties: {
          testName: { type: Type.STRING, description: "Testin adı" },
          testNameStd: {
            type: Type.STRING,
            description:
              "Standart test adı (örn: SGOT→AST, Üre→BUN). Bilinmiyorsa boş bırak.",
          },
          valueNumeric: {
            type: Type.STRING,
            description: "Sayısal sonuç değeri (nokta ile ondalık, örn: '12.5')",
          },
          valueText: {
            type: Type.STRING,
            description: "Sonuç sayısal değilse metin (örn: 'Negatif', 'Pozitif')",
          },
          unit: { type: Type.STRING, description: "Birim (mg/dL, g/L, vb.)" },
          refMin: { type: Type.STRING, description: "Referans alt sınır" },
          refMax: { type: Type.STRING, description: "Referans üst sınır" },
          status: {
            type: Type.STRING,
            description: "Durum: Normal, Yüksek, Düşük",
          },
          category: {
            type: Type.STRING,
            description: "Kategori (Karaciğer, Böbrek, Hemogram, vb.)",
          },
        },
        required: ["testName"],
      },
    },
  },
  required: ["date", "values"],
};

const SYSTEM_PROMPT = `Sen Türkçe sağlık tahlil raporlarını yapısal veri çıkarımı yapan bir asistansın.
Verilen PDF'den tüm test sonuçlarını çıkar.

Kurallar:
- Tarihleri YYYY-MM-DD formatında döndür
- Sayısal değerleri nokta ile ondalık ayırıcı olarak döndür (örn: "12.5", "110")
- Durum alanında: normal aralıktaysa "Normal", üstündeyse "Yüksek", altındaysa "Düşük" yaz
- Kategorileri belirle: Karaciğer, Böbrek, Hemogram, Lipid, Tiroid, Vitamin, Mineral, İdrar, Diyabet, vb.
- Standart test adlarını kullan: SGOT→AST, SGPT→ALT, Üre→BUN, HGB→Hemoglobin, vb.
- Eksik bilgi varsa alanı boş bırak (null değil, boş string)
- Bir raporda birden fazla tahlil türü varsa ana türü reportType'a yaz
- Birden fazla tahlil tarihi varsa en son (veya rapor tarihini) al`;

export async function POST(request: Request) {
  if (!apiKey) {
    return NextResponse.json(
      { error: "GEMINI_API_KEY is not configured" },
      { status: 500 }
    );
  }

  try {
    const formData = await request.formData();
    const file = formData.get("file");

    if (!file || !(file instanceof File)) {
      return NextResponse.json({ error: "PDF file is required" }, { status: 400 });
    }

    if (file.type !== "application/pdf") {
      return NextResponse.json({ error: "Only PDF files are supported" }, { status: 400 });
    }

    const arrayBuffer = await file.arrayBuffer();
    const base64 = Buffer.from(arrayBuffer).toString("base64");

    const ai = new GoogleGenAI({ apiKey });

    const response = await ai.models.generateContent({
      model: "gemini-2.5-pro",
      contents: [
        {
          role: "user",
          parts: [
            {
              inlineData: {
                mimeType: "application/pdf",
                data: base64,
              },
            },
            {
              text: "Bu tahlil raporundaki tüm değerleri çıkar ve yapısal formatta döndür.",
            },
          ],
        },
      ],
      config: {
        systemInstruction: SYSTEM_PROMPT,
        responseMimeType: "application/json",
        responseSchema: parseSchema,
        temperature: 0.1,
      },
    });

    const text = response.text;
    if (!text) {
      return NextResponse.json(
        { error: "Gemini returned empty response" },
        { status: 500 }
      );
    }

    const parsed = JSON.parse(text);
    return NextResponse.json(parsed);
  } catch (error) {
    const message = error instanceof Error ? error.message : "Unknown error";
    console.error("parse-lab-pdf failed:", error);
    return NextResponse.json(
      { error: "Failed to parse PDF", details: message },
      { status: 500 }
    );
  }
}
