import Foundation

/// Akademik notları ve kaynaklarını cihazda önbelleğe alır.
/// Her değer adı (örn: "ALT", "TSH") için bir kez AI'dan çekilir, sonra lokal kullanılır.
/// Haftalık olarak güncellenir.
class AcademicNoteCache {
    static let shared = AcademicNoteCache()

    private let cacheKey = "academicNoteCache"
    private let sourceCacheKey = "academicSourceCache"
    private let lastUpdateKey = "academicNoteCacheLastUpdate"
    private let updateIntervalDays = 7

    private var cache: [String: String] {
        get {
            UserDefaults.standard.dictionary(forKey: cacheKey) as? [String: String] ?? [:]
        }
        set {
            UserDefaults.standard.set(newValue, forKey: cacheKey)
        }
    }

    /// Cache key'ini dil koduyla etiketler: "beta-2 mikroglobulin_tr"
    /// Eski dil etiketsiz key'ler okunmaz — dil değişiminde otomatik yeniden çekilir.
    private func langKey(_ valueName: String) -> String {
        let lang = Locale.current.language.languageCode?.identifier ?? "en"
        return "\(valueName.lowercased())_\(lang)"
    }

    private var sourceCache: [String: [[String: String]]] {
        get {
            UserDefaults.standard.dictionary(forKey: sourceCacheKey) as? [String: [[String: String]]] ?? [:]
        }
        set {
            UserDefaults.standard.set(newValue, forKey: sourceCacheKey)
        }
    }

    /// Returns the best available description for a value name.
    /// Priority: static library (always in device language) → language-tagged cached AI note.
    func note(for valueName: String) -> String? {
        if let libDesc = LabDescriptionLibrary.description(for: valueName) { return libDesc }
        return cache[langKey(valueName)]
    }

    /// Önbellekteki kaynakları döndürür
    func sources(for valueName: String) -> [(name: String, url: String?)] {
        guard let entries = sourceCache[valueName.lowercased()] else { return [] }
        return entries.map { (name: $0["name"] ?? "", url: $0["url"]) }
    }

    /// Tüm kaynaklı değer adlarını döndürür
    var allSourcedValues: [(valueName: String, sources: [(name: String, url: String?)])] {
        sourceCache.map { key, entries in
            (valueName: key, sources: entries.map { (name: $0["name"] ?? "", url: $0["url"]) })
        }.sorted { $0.valueName < $1.valueName }
    }

    /// Notu önbelleğe yaz (dil etiketiyle)
    func setNote(_ note: String, for valueName: String) {
        var current = cache
        current[langKey(valueName)] = note
        cache = current
    }

    /// Birden fazla notu tek seferde kaydet (dil etiketiyle)
    /// `language` parametresi verilmezse cihaz dilini kullanır.
    func setNotes(_ notes: [String: String], language: String? = nil) {
        let lang = language ?? Locale.current.language.languageCode?.identifier ?? "en"
        var current = cache
        for (key, value) in notes {
            current["\(key.lowercased())_\(lang)"] = value
        }
        cache = current
        UserDefaults.standard.set(Date(), forKey: lastUpdateKey)
    }

    /// Birden fazla kaynağı tek seferde kaydet
    func setSources(_ sources: [String: [[String: String]]]) {
        var current = sourceCache
        for (key, value) in sources {
            current[key.lowercased()] = value
        }
        sourceCache = current
    }

    /// Önbellekte olmayan (dil etiketli) değer adlarını döndürür
    func missingNotes(for valueNames: [String]) -> [String] {
        let existing = cache
        return valueNames.filter { existing[langKey($0)] == nil }
    }

    /// Haftalık güncelleme gerekiyor mu?
    var needsWeeklyUpdate: Bool {
        guard let lastUpdate = UserDefaults.standard.object(forKey: lastUpdateKey) as? Date else {
            return true
        }
        let daysSinceUpdate = Calendar.current.dateComponents([.day], from: lastUpdate, to: .now).day ?? 0
        return daysSinceUpdate >= updateIntervalDays
    }

    /// Önbelleği temizle (test/debug için)
    func clearCache() {
        UserDefaults.standard.removeObject(forKey: cacheKey)
        UserDefaults.standard.removeObject(forKey: sourceCacheKey)
        UserDefaults.standard.removeObject(forKey: lastUpdateKey)
    }
}
