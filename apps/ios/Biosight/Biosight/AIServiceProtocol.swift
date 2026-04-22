import Foundation
import UIKit

/// Ortak AI servisi arayüzü
protocol AIServiceProtocol {
    func analyzePDF(data: Data) async throws -> [GeminiService.ParsedLabValue]
    func analyzeImage(data: Data, mimeType: String) async throws -> [GeminiService.ParsedLabValue]
    func analyzeImage(image: UIImage) async throws -> [GeminiService.ParsedLabValue]
    func analyzeHealthSummary(summary: String) async throws -> String
    func fetchAcademicNotes(for valueNames: [String]) async
    func fetchSingleAcademicNote(for valueName: String) async throws -> String?
    func validateAPIKey() async -> Bool
    func extractHospitalName(fromText text: String) async -> String?
}

/// Gemini servisini döndürür
struct AIServiceFactory {
    /// Kullanıcının girdiği Gemini API anahtarı var mı?
    static var hasAvailableKey: Bool {
        !resolveKey(userDefaultsKey: "geminiAPIKey", plistKey: "GEMINI_API_KEY").isEmpty
    }

    /// Info.plist'ten (xcconfig) gömülü API anahtarını okur
    private static func bundledKey(for plistKey: String) -> String {
        let value = Bundle.main.object(forInfoDictionaryKey: plistKey) as? String ?? ""
        if value.hasPrefix("$(") { return "" }
        return value
    }

    /// Kullanıcının girdiği anahtar varsa onu, yoksa xcconfig anahtarını döndürür
    private static func resolveKey(userDefaultsKey: String, plistKey: String) -> String {
        let userKey = UserDefaults.standard.string(forKey: userDefaultsKey) ?? ""
        if !userKey.isEmpty { return userKey }
        return bundledKey(for: plistKey)
    }

    static func create(tier: AnalysisTier = .free) -> AIServiceProtocol {
        let apiKey = resolveKey(userDefaultsKey: "geminiAPIKey", plistKey: "GEMINI_API_KEY")
        return GeminiService(apiKey: apiKey, tier: tier)
    }
}
