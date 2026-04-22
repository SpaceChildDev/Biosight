import Foundation

/// iOS, uygulama güncellendiklerinde veya yeniden yüklendiğinde sandbox
/// container UUID'sini değiştirir. Bu nedenle tam yollar (absoluteString)
/// zaman içinde geçersiz kalır.
///
/// Bu utility:
/// 1. Tam yollardan dosya adını çıkararak güncel Documents dizini ile yeniden oluşturur.
/// 2. Yeni kayıtlarda sadece göreli yol saklanmasını sağlar.
/// 3. Mevcut kayıtları göreli yola migrate eder.
struct PDFPathResolver {

    // MARK: - Dizin

    private static var pdfDirectory: URL {
        FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            .appendingPathComponent("PDFs", isDirectory: true)
    }

    // MARK: - Çözümleme (resolve)

    /// Saklanan yoldan geçerli bir dosya URL'si döndürür.
    /// Hem eski tam yolları hem de yeni göreli yolları destekler.
    /// Dosya diskte yoksa nil döndürür.
    static func resolve(_ storedPath: String?) -> URL? {
        guard let stored = storedPath, !stored.isEmpty else { return nil }

        // 1. Saklanan yolu olduğu gibi dene (yeni format veya mevcut geçerli yol)
        if let url = URL(string: stored), FileManager.default.fileExists(atPath: url.path) {
            return url
        }
        // Yol formatı file:// değil düz path ise
        if FileManager.default.fileExists(atPath: stored) {
            return URL(fileURLWithPath: stored)
        }

        // 2. Dosya adını çıkar ve güncel Documents/PDFs ile yeniden birleştir
        let fileName = (stored as NSString).lastPathComponent
        guard !fileName.isEmpty, fileName.hasSuffix(".pdf") || fileName.hasSuffix(".PDF") else {
            return nil
        }

        let rebuilt = pdfDirectory.appendingPathComponent(fileName)
        if FileManager.default.fileExists(atPath: rebuilt.path) {
            return rebuilt
        }

        return nil
    }

    // MARK: - Otomatik İsimlendirme

    /// `YYYY-MM-DD_HastaneAdi.pdf` formatında benzersiz dosya adı üretir.
    /// Çakışma varsa `_2`, `_3` eklenir. PDF diske kaydedilir ve yolu döndürülür.
    @discardableResult
    static func save(data: Data, date: Date, hospital: String?) -> String? {
        let fm = FileManager.default
        try? fm.createDirectory(at: pdfDirectory, withIntermediateDirectories: true)

        let baseName = generateFileName(date: date, hospital: hospital)
        let fileURL = uniqueURL(base: baseName, directory: pdfDirectory)

        do {
            try data.write(to: fileURL)
            return fileURL.absoluteString
        } catch {
            return nil
        }
    }

    /// Tarihe + kuruma göre dosya adı üretir: `2024-03-12_Ege-Hastanesi.pdf`
    static func generateFileName(date: Date, hospital: String?) -> String {
        let datePart = isoDateString(date)
        let hospitalPart: String
        if let h = hospital, !h.trimmingCharacters(in: .whitespaces).isEmpty {
            hospitalPart = "_" + sanitize(h)
        } else {
            hospitalPart = "_tahlil"
        }
        return "\(datePart)\(hospitalPart).pdf"
    }

    /// Dizinde zaten aynı isimde dosya varsa `_2`, `_3` ekleyerek benzersiz URL döndürür.
    private static func uniqueURL(base: String, directory: URL) -> URL {
        let fm = FileManager.default
        var url = directory.appendingPathComponent(base)
        if !fm.fileExists(atPath: url.path) { return url }

        // Uzantıyı ayır
        let ext = (base as NSString).pathExtension
        let stem = (base as NSString).deletingPathExtension

        var counter = 2
        repeat {
            url = directory.appendingPathComponent("\(stem)_\(counter).\(ext)")
            counter += 1
        } while fm.fileExists(atPath: url.path) && counter < 100

        return url
    }

    /// Tarih → "YYYY-MM-DD"
    private static func isoDateString(_ date: Date) -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        f.locale = Locale(identifier: "en_US_POSIX")
        return f.string(from: date)
    }

    /// Kurum adını dosya sistemi için güvenli hale getirir.
    /// Türkçe karakterleri korur, özel karakterleri kaldırır, boşlukları tire yapar.
    private static func sanitize(_ name: String) -> String {
        let trimmed = name.trimmingCharacters(in: .whitespaces)
        // Boşlukları tire
        let dashed = trimmed.replacingOccurrences(of: " ", with: "-")
        // Sadece harf, rakam, tire, nokta ve alt çizgiye izin ver
        let allowed = CharacterSet.alphanumerics
            .union(CharacterSet(charactersIn: "-._"))
            .union(CharacterSet(charactersIn: "ğüşıöçĞÜŞİÖÇ"))
        let sanitized = dashed.unicodeScalars
            .filter { allowed.contains($0) }
            .reduce("") { $0 + String($1) }
        // Maksimum 40 karakter
        return String(sanitized.prefix(40))
    }

    /// Sadece dosya adını döndürür — saklama için önerilen format.
    static func fileName(from storedPath: String) -> String {
        (storedPath as NSString).lastPathComponent
    }

    // MARK: - Migration

    /// SwiftData kayıtlarındaki eski tam yolları sadece dosya adına günceller.
    /// BiosightApp.onAppear içinden bir kere çağrılabilir.
    static func migrateStoredPaths(in labResults: [LabResult]) {
        for result in labResults {
            guard let stored = result.originalPDFPath, !stored.isEmpty else { continue }

            // Zaten sadece dosya adı veya kısa göreli yol ise geç
            let isAlreadyRelative = !stored.hasPrefix("/") && !stored.hasPrefix("file://")
            if isAlreadyRelative { continue }

            // Tam yoldan dosya adını çıkar
            let name = (stored as NSString).lastPathComponent
            if name.isEmpty { continue }

            // Güncel path ile yeniden oluştur
            let newPath = pdfDirectory.appendingPathComponent(name).absoluteString
            if newPath != stored {
                result.originalPDFPath = newPath
            }
        }
    }
}
