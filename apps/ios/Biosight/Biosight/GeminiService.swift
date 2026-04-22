import Foundation
import UIKit

    enum AnalysisTier {
        case free       // Haftalık 1 özet, flash
        case basic      // Haftalık 3 özet, flash
        case premium    // Sınırsız, pro model ile detaylı analiz
    }

struct GeminiService: AIServiceProtocol {
    private let apiKey: String
    /// PDF/tarama okuma için — fallback sırasıyla denenir
    private let parseModels = ["gemini-2.5-flash", "gemini-2.5-flash-lite", "gemini-2.0-flash"]
    /// Ücretsiz/temel özet analiz için
    private let analysisModel = "gemini-2.5-flash"
    /// Premium detaylı analiz için
    private let premiumModel = "gemini-2.5-pro"

    let tier: AnalysisTier

    init(apiKey: String, tier: AnalysisTier = .free) {
        self.apiKey = apiKey
        self.tier = tier
    }

    private static let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 120
        config.timeoutIntervalForResource = 300
        return URLSession(configuration: config)
    }()
    
    struct ParsedLabValue: Codable, Identifiable {
        var id = UUID()
        let type: String
        let category: String
        let valueName: String
        let value: String
        let unit: String
        let referenceRange: String
        let isAbnormal: Bool
        let academicNote: String?
        let date: String?
        
        enum CodingKeys: String, CodingKey {
            case type, category, valueName, value, unit, referenceRange, isAbnormal, academicNote, date
        }
        
        init(from decoder: Decoder) throws {
            let container = try decoder.container(keyedBy: CodingKeys.self)
            self.id = UUID()
            self.type = try container.decode(String.self, forKey: .type)
            self.category = try container.decode(String.self, forKey: .category)
            self.valueName = LabDescriptionLibrary.canonicalize(try container.decode(String.self, forKey: .valueName))
            self.value = try container.decode(String.self, forKey: .value)
            self.unit = try container.decode(String.self, forKey: .unit)
            self.referenceRange = try container.decodeIfPresent(String.self, forKey: .referenceRange) ?? ""
            self.isAbnormal = try container.decodeIfPresent(Bool.self, forKey: .isAbnormal) ?? false
            self.academicNote = try container.decodeIfPresent(String.self, forKey: .academicNote)
            self.date = try container.decodeIfPresent(String.self, forKey: .date)
        }
    }
    
    struct GeminiResponse: Codable {
        let candidates: [Candidate]?
        let error: GeminiError?
    }
    
    struct GeminiError: Codable, LocalizedError {
        let message: String
        var errorDescription: String? { message }
    }
    
    struct Candidate: Codable {
        let content: Content
    }
    
    struct Content: Codable {
        let parts: [Part]
    }
    
    struct Part: Codable {
        let text: String?
    }
    
    func validateAPIKey() async -> Bool {
        guard let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models?key=\(apiKey)") else {
            return false
        }
        do {
            let (_, response) = try await Self.session.data(from: url)
            return (response as? HTTPURLResponse)?.statusCode == 200
        } catch {
            return false
        }
    }

    /// Model listesini sırayla dener; kota hatası alırsa sonrakine geçer.
    private func callGenerateContent(model: String, requestBody: [String: Any]) async throws -> String {
        guard let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent?key=\(apiKey)") else {
            throw GeminiError(message: "Geçersiz API anahtarı formatı.")
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        let (responseData, httpResponse) = try await Self.session.data(for: request)

        guard let statusCode = (httpResponse as? HTTPURLResponse)?.statusCode else {
            throw GeminiError(message: "Sunucuya bağlanılamadı.")
        }

        guard statusCode == 200 else {
            if let errorResponse = try? JSONDecoder().decode(GeminiResponse.self, from: responseData),
               let errorMsg = errorResponse.error?.message {
                if statusCode == 429 || errorMsg.lowercased().contains("quota") {
                    throw QuotaError(model: model)
                }
                throw GeminiError(message: errorMsg)
            }
            throw GeminiError(message: "Sunucu hatası (kod: \(statusCode)). Lütfen tekrar deneyin.")
        }

        let geminiResponse = try JSONDecoder().decode(GeminiResponse.self, from: responseData)
        guard let text = geminiResponse.candidates?.first?.content.parts.first?.text else {
            throw GeminiError(message: "Analiz sonucu alınamadı. Lütfen tekrar deneyin.")
        }
        return text
    }

    /// Kota hatası — fallback tetikler
    private struct QuotaError: Error {
        let model: String
    }

    /// Model fallback ile generateContent çağırır
    private func callWithFallback(models: [String], requestBody: [String: Any]) async throws -> String {
        for (index, model) in models.enumerated() {
            do {
                return try await callGenerateContent(model: model, requestBody: requestBody)
            } catch is QuotaError {
                if index == models.count - 1 {
                    throw GeminiError(message: "AI analiz kotası doldu. Lütfen birkaç dakika sonra tekrar deneyin.")
                }
                // Sonraki modeli dene
                continue
            }
        }
        throw GeminiError(message: "AI analiz kotası doldu. Lütfen birkaç dakika sonra tekrar deneyin.")
    }

    private func parseLabValues(from text: String) throws -> [ParsedLabValue] {
        let cleaned = text
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let jsonData = cleaned.data(using: .utf8) else {
            throw GeminiError(message: "Analiz sonucu işlenemedi.")
        }

        do {
            return try JSONDecoder().decode([ParsedLabValue].self, from: jsonData)
        } catch {
            throw GeminiError(message: "Tahlil değerleri ayrıştırılamadı. Belge formatı desteklenmiyor olabilir.")
        }
    }

    func analyzePDF(data: Data) async throws -> [ParsedLabValue] {
        let base64PDF = data.base64EncodedString()

        let requestBody: [String: Any] = [
            "contents": [
                [
                    "parts": [
                        ["text": labAnalysisPrompt],
                        [
                            "inline_data": [
                                "mime_type": "application/pdf",
                                "data": base64PDF
                            ]
                        ]
                    ]
                ]
            ],
            "generationConfig": [
                "temperature": 0.1,
                "maxOutputTokens": 8192
            ]
        ]

        let text = try await callWithFallback(models: parseModels, requestBody: requestBody)
        return try parseLabValues(from: text)
    }

    private let labAnalysisPrompt = """
        Bu bir tahlil/laboratuvar sonucu belgesidir. Belgedeki TÜM tahlil değerlerini çıkar ve JSON formatında döndür.

        Her değer için:
        - type: "Kan", "İdrar", "MR", "BT" veya "Ultrason"
        - category: "Böbrek", "Karaciğer", "Hemogram", "Tiroid", "Lipid", "Hormon", "Vitamin" veya "Diğer"
        - valueName: Değerin adı (örn: "ALT", "Üre", "TSH")
        - value: Sayısal değer (string olarak)
        - unit: Birimi
        - referenceRange: Referans aralığı (örn: "0-40")
        - isAbnormal: Referans dışında mı (true/false)
        - date: Tahlil tarihi (YYYY-MM-DD, bulunamazsa null)

        SADECE JSON array döndür, başka metin ekleme. academicNote EKLEME.
        [{"type":"Kan","category":"Karaciğer","valueName":"ALT","value":"65","unit":"U/L","referenceRange":"0-40","isAbnormal":true,"date":"2024-03-15"}]
        """

    func analyzeImage(data: Data, mimeType: String) async throws -> [ParsedLabValue] {
        let base64Image = data.base64EncodedString()

        let requestBody: [String: Any] = [
            "contents": [
                [
                    "parts": [
                        ["text": labAnalysisPrompt],
                        [
                            "inline_data": [
                                "mime_type": mimeType,
                                "data": base64Image
                            ]
                        ]
                    ]
                ]
            ],
            "generationConfig": [
                "temperature": 0.1,
                "maxOutputTokens": 8192
            ]
        ]

        let text = try await callWithFallback(models: parseModels, requestBody: requestBody)
        return try parseLabValues(from: text)
    }

    func analyzeImage(image: UIImage) async throws -> [ParsedLabValue] {
        guard let jpegData = image.jpegData(compressionQuality: 0.8) else {
            throw GeminiError(message: "Görüntü işlenemedi.")
        }
        return try await analyzeImage(data: jpegData, mimeType: "image/jpeg")
    }

    func analyzeHealthSummary(summary: String) async throws -> String {
        let model = tier == .premium ? premiumModel : analysisModel
        guard let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(model):generateContent?key=\(apiKey)") else {
            throw GeminiError(message: "Geçersiz API anahtarı formatı.")
        }

        let basePrompt = """
        Aşağıda bir kişinin sağlık verileri bulunmaktadır. Bu verileri Türkçe olarak yorumla.

        FORMAT:
        1. GENEL DURUM: Verilere bakarak genel sağlık durumunu 1-2 cümleyle özetle. Herkesin anlayacağı sade bir dil kullan.

        2. DEĞER ANALİZİ: Her metrik için şu yapıda yaz:
           - Değer adı ve sonucu
           - Ne anlama geldiği (günlük dilde, herkesin anlayacağı şekilde)
           - Referans aralığına göre durumu (normal/yüksek/düşük)
           - Varsa pratik öneri (örn: "günde 2 litre su içmeye özen gösterin")

        3. DİKKAT EDİLMESİ GEREKENLER: Referans dışı değerleri bilgilendirici bir şekilde açıkla. Egzersiz, stres, kafein gibi geçici faktörlerin değerleri etkileyebileceğini belirt. Panik yaratmadan, pozitif ve yapıcı bir dil kullan.

        4. ÖNERİLER: Genel yaşam tarzı önerileri (beslenme, egzersiz, uyku vb.)

        5. KAYNAKLAR: Bu analizde kullandığın her bilgi için kaynağını açıkça belirt. Her kaynak şu formatta olmalı:
           - Kaynak adı (PubMed ID, WHO rehber adı vb.)
           - Varsa URL (örn: https://pubmed.ncbi.nlm.nih.gov/XXXXX/)

        KURALLAR:
        - Tıbbi terim kullandığında parantez içinde ne demek olduğunu yaz
        - Samimi ama bilgilendirici bir dil kullan
        - SADECE şu kaynaklardan bilgi kullan: PubMed/NCBI, PMC, Cochrane Library, WHO, NIH, CDC, CLSI, Mayo Clinic Laboratories, Johns Hopkins Medicine, KDIGO, ADA, ACC/AHA, ESC, Clinical Chemistry, JACC, Circulation, Diabetes Care, Kidney International, Blood (ASH), Thyroid (ATA), Journal of Hepatology
        - Blog yazıları, özel hastane siteleri veya reklam içerikli kaynakları KULLANMA
        - Her açıklama için güvenilir tıbbi kaynaklara dayalı bilgiler ver.
        - Bu bir tıbbi teşhis değildir, sadece bilgilendirme amaçlıdır. Endişe verici değerler varsa mutlaka doktora başvurulması gerektiğini belirt.
        """

        let premiumExtra = """

        EK OLARAK (DETAYLI ANALİZ):
        5. DEĞERLER ARASI İLİŞKİLER: Farklı değerlerin birbiriyle ilişkisini analiz et. Örneğin yüksek LDL + düşük HDL birlikte ne anlama gelir, böbrek ve karaciğer değerleri arasındaki bağlantılar vb.

        6. TREND ANALİZİ: Eğer aynı testin farklı tarihlerde sonuçları varsa, trendin yönünü (iyileşme/kötüleşme) belirt ve ne anlama geldiğini açıkla.

        7. KİŞİSELLEŞTİRİLMİŞ BESLENME ÖNERİLERİ: Referans dışı değerlere özel besin ve diyet önerileri sun. Hangi besinlerin faydalı, hangilerinden kaçınılması gerektiğini belirt.

        8. YAŞAM TARZI DEĞERLENDİRMESİ: Aktivite, uyku, stres gibi verileri birlikte değerlendir ve bütünsel bir yaşam tarzı değerlendirmesi yap.

        9. TAKİP ÖNERİSİ: Hangi değerlerin ne zaman tekrar kontrol edilmesi gerektiğini öner.

        Çok detaylı ve kapsamlı yaz. Sınır yok.
        """

        let prompt: String
        if tier == .premium {
            prompt = basePrompt + premiumExtra + "\n\nVeriler:\n\(summary)\n\nDüz metin yaz, markdown formatı KULLANMA."
        } else {
            prompt = basePrompt + "\n\nVeriler:\n\(summary)\n\nKısa ve öz yaz. Düz metin yaz, markdown formatı KULLANMA."
        }

        let maxTokens = tier == .premium ? 8192 : 4096

        let requestBody: [String: Any] = [
            "contents": [["parts": [["text": prompt]]]],
            "generationConfig": ["temperature": 0.3, "maxOutputTokens": maxTokens]
        ]

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: requestBody)

        let (responseData, httpResponse) = try await Self.session.data(for: request)

        guard let statusCode = (httpResponse as? HTTPURLResponse)?.statusCode, statusCode == 200 else {
            throw GeminiError(message: "Analiz yapılamadı. Lütfen tekrar deneyin.")
        }

        let geminiResponse = try JSONDecoder().decode(GeminiResponse.self, from: responseData)
        guard let text = geminiResponse.candidates?.first?.content.parts.first?.text else {
            throw GeminiError(message: "Yanıt alınamadı.")
        }
        return text
    }

    /// Akademik not için yapılandırılmış yanıt
    struct AcademicNoteResponse: Codable {
        let note: String
        let sources: [AcademicSource]
    }

    struct AcademicSource: Codable {
        let name: String
        let url: String?
    }

    /// Birden fazla değer adı için akademik not çeker (tek istek, önbellek ile).
    /// Önbellekte olmayanlar için AI'dan çeker, önbelleğe yazar.
    func fetchAcademicNotes(for valueNames: [String]) async {
        let cache = AcademicNoteCache.shared
        let missing = cache.missingNotes(for: valueNames)
        guard !missing.isEmpty else { return }

        let nameList = missing.joined(separator: ", ")
        let langCode = Locale.current.language.languageCode?.identifier ?? "en"
        let langInstruction: String
        switch langCode {
        case "tr": langInstruction = "Türkçe"
        case "de": langInstruction = "German"
        case "fr": langInstruction = "French"
        case "es": langInstruction = "Spanish"
        case "ar": langInstruction = "Arabic"
        case "ru": langInstruction = "Russian"
        default:   langInstruction = "English"
        }
        let prompt = """
        For each of the following medical/laboratory values, write a short patient-friendly description in \(langInstruction).
        Use plain language everyone can understand. If you use a technical term, briefly explain it in parentheses.

        For each value return:
        1. "note": What the value measures and why it matters (2-3 sentences).
        2. "sources": List of academic sources. For each source:
           - "name": Source name (e.g. "PubMed: PMID 12345678", "WHO Guidelines 2024")
           - "url": Direct access URL if available (PubMed, NCBI, WHO, etc.)

        ONLY use these academic/official sources:
        Primary databases: PubMed/NCBI, PMC, NCBI Bookshelf, Cochrane Library, MEDLINE
        International organizations: WHO, NIH, CDC, CLSI
        University/lab: Mayo Clinic Laboratories, Johns Hopkins Medicine, Harvard Medical School
        Clinical guidelines: KDIGO (kidney), ADA (diabetes), ACC/AHA (cardiovascular), ESC (cardiovascular)
        Journals: Clinical Chemistry, JACC, European Heart Journal, Circulation, Diabetes Care, Kidney International, Blood, Thyroid, Journal of Hepatology

        Do NOT use blog posts, private hospital websites, or ad-supported content.
        For source URLs ONLY use these domains: pubmed.ncbi.nlm.nih.gov, pmc.ncbi.nlm.nih.gov, ncbi.nlm.nih.gov, who.int, cdc.gov, nih.gov, clsi.org, cochranelibrary.com, kdigo.org, mayocliniclabs.com, hopkinsmedicine.org, acc.org, escardio.org, diabetesjournals.org, ashpublications.org, kidney-international.org, jasn.asnjournals.org

        Values: \(nameList)

        Return ONLY a JSON object, no extra text:
        {
          "ALT": {
            "note": "...",
            "sources": [
              {"name": "PubMed: PMID 29083587", "url": "https://pubmed.ncbi.nlm.nih.gov/29083587/"}
            ]
          }
        }
        """

        let requestBody: [String: Any] = [
            "contents": [["parts": [["text": prompt]]]],
            "generationConfig": ["temperature": 0.2, "maxOutputTokens": 4096]
        ]

        guard let text = try? await callWithFallback(models: parseModels, requestBody: requestBody) else { return }

        let cleaned = text
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let jsonData = cleaned.data(using: .utf8),
              let parsed = try? JSONDecoder().decode([String: AcademicNoteResponse].self, from: jsonData) else {
            // Eski format fallback: düz string döndüyse
            if let jsonData = cleaned.data(using: .utf8),
               let notes = try? JSONDecoder().decode([String: String].self, from: jsonData) {
                cache.setNotes(notes, language: langCode)
            }
            return
        }

        // Yapılandırılmış notları ve kaynakları kaydet (dil etiketiyle)
        var notes: [String: String] = [:]
        var sources: [String: [[String: String]]] = [:]
        for (key, response) in parsed {
            notes[key] = response.note
            sources[key] = response.sources.map { source in
                var dict: [String: String] = ["name": source.name]
                if let url = source.url { dict["url"] = url }
                return dict
            }
        }
        cache.setNotes(notes, language: langCode)
        cache.setSources(sources)
    }

    /// Fetches a description for a single lab value in the device's current language.
    func fetchSingleAcademicNote(for valueName: String) async throws -> String? {
        let cache = AcademicNoteCache.shared
        if let existing = cache.note(for: valueName) { return existing }

        let langCode = Locale.current.language.languageCode?.identifier ?? "en"
        let langInstruction: String
        switch langCode {
        case "tr": langInstruction = "Türkçe"
        case "de": langInstruction = "German (Deutsch)"
        case "fr": langInstruction = "French (Français)"
        case "es": langInstruction = "Spanish (Español)"
        case "ar": langInstruction = "Arabic (العربية)"
        case "ru": langInstruction = "Russian (Русский)"
        default:   langInstruction = "English"
        }

        let prompt = """
        What is "\(valueName)" as a medical/laboratory value? Write a 2–3 sentence patient-friendly explanation in \(langInstruction).
        If you use a technical term, briefly explain it in parentheses. Return only the explanation, nothing else.
        """

        let requestBody: [String: Any] = [
            "contents": [["parts": [["text": prompt]]]],
            "generationConfig": ["temperature": 0.3, "maxOutputTokens": 200]
        ]

        let text = try await callWithFallback(
            models: ["gemini-2.5-flash-lite", "gemini-2.0-flash"],
            requestBody: requestBody
        )
        let note = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if !note.isEmpty { cache.setNote(note, for: valueName) }
        return note.isEmpty ? nil : note
    }

    /// PDF metinden kurum adını AI ile çıkarır (regex başarısız olursa fallback)
    func extractHospitalName(fromText text: String) async -> String? {
        let prompt = """
        Aşağıdaki metin bir tıbbi laboratuvar veya hastane tahlil raporundan alınmıştır.
        Metnin ilk birkaç satırına bakarak hastane, klinik veya laboratuvar adını bul.

        SADECE kurum adını döndür. Başka hiçbir şey yazma. Bulamazsan boş string döndür.

        Metin:
        \(String(text.prefix(500)))
        """

        let requestBody: [String: Any] = [
            "contents": [["parts": [["text": prompt]]]],
            "generationConfig": ["maxOutputTokens": 50, "temperature": 0.0]
        ]

        guard let result = try? await callGenerateContent(model: "gemini-2.5-flash-lite", requestBody: requestBody),
              !result.isEmpty else { return nil }

        let cleaned = result.trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? nil : cleaned
    }
}
