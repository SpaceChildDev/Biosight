import Foundation
import Vision
import PDFKit

/// PDF'den cihaz üzerinde (on-device) metin çıkarır ve kurum adını tespit eder.
/// Hiçbir veri dışarıya gönderilmez.
struct LocalPDFExtractor {

    /// PDF'den kurum adını çıkarır (Vision OCR + pattern matching, AI fallback)
    static func extractHospitalName(from pdfData: Data) async -> String? {
        guard let text = extractText(from: pdfData) else { return nil }
        // Önce regex dene
        if let found = findHospitalName(in: text) { return found }
        // Bulunamazsa AI fallback
        let service = AIServiceFactory.create()
        return await service.extractHospitalName(fromText: text)
    }

    /// PDF'den tarih çıkarır
    static func extractDate(from pdfData: Data) async -> Date? {
        guard let text = extractText(from: pdfData) else { return nil }
        return findDate(in: text)
    }

    /// PDF'den tüm metni çıkarır (Vision OCR)
    static func extractText(from pdfData: Data) -> String? {
        guard let pdfDocument = PDFDocument(data: pdfData) else { return nil }

        var fullText = ""

        for pageIndex in 0..<pdfDocument.pageCount {
            guard let page = pdfDocument.page(at: pageIndex) else { continue }

            // Önce PDFKit'in kendi text extraction'ını dene
            if let pageText = page.string, !pageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                fullText += pageText + "\n"
                continue
            }

            // PDFKit çalışmazsa Vision OCR kullan
            let pageRect = page.bounds(for: .mediaBox)
            let renderer = UIGraphicsImageRenderer(size: pageRect.size)
            let image = renderer.image { ctx in
                UIColor.white.set()
                ctx.fill(pageRect)
                ctx.cgContext.translateBy(x: 0, y: pageRect.height)
                ctx.cgContext.scaleBy(x: 1, y: -1)
                page.draw(with: .mediaBox, to: ctx.cgContext)
            }

            guard let cgImage = image.cgImage else { continue }

            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            request.recognitionLanguages = ["tr", "en"]
            request.usesLanguageCorrection = true

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            try? handler.perform([request])

            if let observations = request.results {
                for observation in observations {
                    if let text = observation.topCandidates(1).first?.string {
                        fullText += text + "\n"
                    }
                }
            }
        }

        return fullText.isEmpty ? nil : fullText
    }

    // MARK: - Pattern Matching

    /// Kurum adını metin içinden bulur (public alias for PDFUploadView)
    static func findHospitalNameLocal(in text: String) -> String? {
        findHospitalName(in: text)
    }

    /// Tarih bilgisini metin içinden bulur (public alias for PDFUploadView)
    static func findDateLocal(in text: String) -> Date? {
        findDate(in: text)
    }

    /// Kurum adını metin içinden bulur
    private static func findHospitalName(in text: String) -> String? {
        let lines = text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }

        // Kurum anahtar kelimeleri
        let keywords = [
            "hastanesi", "hastanası", "hospital",
            "tıp merkezi", "tıp fakültesi",
            "laboratuvar", "laboratuarı", "lab.",
            "sağlık merkezi", "sağlık kuruluşu",
            "poliklinik", "polikliniği",
            "klinik", "kliniği",
            "üniversitesi", "üniversite",
            "devlet hastanesi", "şehir hastanesi",
            "eğitim ve araştırma",
            "tıbbi biyokimya", "biyokimya lab",
            "medical center", "clinic",
            "research hospital"
        ]

        // Her satırda anahtar kelime ara
        for line in lines {
            let lower = line.lowercased(with: Locale(identifier: "tr"))
            for keyword in keywords {
                if lower.contains(keyword) {
                    // Satırı temizle ve döndür
                    return cleanHospitalName(line)
                }
            }
        }

        // Header'daki ilk birkaç satıra bak (genellikle kurum adı en üstte olur)
        // Büyük harfle yazılmış ve kısa olan satırlar kurum adı olabilir
        for line in lines.prefix(5) {
            let uppercaseRatio = Double(line.filter { $0.isUppercase }.count) / Double(max(line.count, 1))
            if uppercaseRatio > 0.6 && line.count > 5 && line.count < 80 {
                return cleanHospitalName(line)
            }
        }

        return nil
    }

    /// Kurum adını temizler
    private static func cleanHospitalName(_ raw: String) -> String {
        var name = raw
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .trimmingCharacters(in: .punctuationCharacters)

        // Çok uzunsa kısalt
        if name.count > 60 {
            if let range = name.range(of: " - ") {
                name = String(name[..<range.lowerBound])
            } else if let range = name.range(of: ",") {
                name = String(name[..<range.lowerBound])
            }
        }

        return name.trimmingCharacters(in: .whitespaces)
    }

    /// Tarih bilgisini metin içinden bulur.
    /// Önce "rapor tarihi", "tarih" gibi anahtar kelimelerin bulunduğu satırlara bakar;
    /// "doğum", "birth" gibi satırları görmezden gelir.
    private static func findDate(in text: String) -> Date? {
        let lines = text.components(separatedBy: .newlines)

        // Tarih arama anahtar kelimeleri (öncelikli)
        let priorityKeywords = ["rapor tarihi", "test tarihi", "numune tarihi", "istek tarihi",
                                "analiz tarihi", "kabul tarihi", "işlem tarihi", "sonuç tarihi",
                                "tarih:", "tarih :", "date:"]
        // Doğum tarihi satırlarını atla
        let skipKeywords = ["doğum", "birth", "d.t.", "doğ.", "d.tarihi", "doğ.tarihi",
                            "hasta doğum", "patient dob", "dob:"]

        let dateFormats = ["dd.MM.yyyy", "dd/MM/yyyy", "yyyy-MM-dd", "d MMMM yyyy", "dd-MM-yyyy"]
        let dateFormatter = DateFormatter()
        dateFormatter.locale = Locale(identifier: "tr_TR")

        let datePatterns = [
            "\\b(\\d{2})[./\\-](\\d{2})[./\\-](\\d{4})\\b",
            "\\b(\\d{4})[\\-](\\d{2})[\\-](\\d{2})\\b",
            "\\b(\\d{1,2})\\s+(Ocak|Şubat|Mart|Nisan|Mayıs|Haziran|Temmuz|Ağustos|Eylül|Ekim|Kasım|Aralık|January|February|March|April|May|June|July|August|September|October|November|December)\\s+(\\d{4})\\b"
        ]

        func extractDate(from line: String) -> Date? {
            for pattern in datePatterns {
                guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else { continue }
                let nsLine = line as NSString
                let range = NSRange(location: 0, length: nsLine.length)
                if let match = regex.firstMatch(in: line, range: range) {
                    let matchString = nsLine.substring(with: match.range)
                    for format in dateFormats {
                        dateFormatter.dateFormat = format
                        if let date = dateFormatter.date(from: matchString) {
                            return date
                        }
                    }
                }
            }
            return nil
        }

        // Geçen 1: Öncelikli anahtar kelimeli satırlar
        for line in lines {
            let lower = line.lowercased(with: Locale(identifier: "tr"))
            let shouldSkip = skipKeywords.contains { lower.contains($0) }
            guard !shouldSkip else { continue }
            let isPriority = priorityKeywords.contains { lower.contains($0) }
            if isPriority, let date = extractDate(from: line) {
                return date
            }
        }

        // Geçen 2: Doğum tarihi olmayan herhangi bir satır
        for line in lines {
            let lower = line.lowercased(with: Locale(identifier: "tr"))
            let shouldSkip = skipKeywords.contains { lower.contains($0) }
            guard !shouldSkip else { continue }
            if let date = extractDate(from: line) {
                return date
            }
        }

        return nil
    }
}
