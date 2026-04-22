import Foundation
import HealthKit
import SwiftData

/// Arka planda Apple Health senkronizasyonu yönetir.
/// Uygulama her ön plana geçtiğinde son senkronizasyon tarihinden itibaren
/// yeni verileri otomatik olarak çekip SwiftData'ya kaydeder.
@MainActor
@Observable
class HealthKitSyncService {
    static let shared = HealthKitSyncService()

    private let healthKitService = HealthKitService()
    private let lastSyncKey = "healthKitLastSyncDate"

    var isSyncing = false
    /// Son başarılı senkronizasyon tarihi. UserDefaults'ta kalıcı olarak saklanır.
    var lastSyncDate: Date? {
        didSet { UserDefaults.standard.set(lastSyncDate, forKey: lastSyncKey) }
    }
    /// Son senkronizasyonda eklenen/güncellenen kayıt sayısı.
    var lastSyncChangedCount: Int = 0

    init() {
        lastSyncDate = UserDefaults.standard.object(forKey: lastSyncKey) as? Date
    }

    /// Apple Health'ten yeni verileri çekip SwiftData'ya kaydeder.
    /// - İlk senkronizasyonda son 30 günü çeker.
    /// - Sonraki senkronizasyonlarda yalnızca son syncDate'den itibaren çeker.
    /// - Mevcut kayıtlar `saveWithDedup` ile duplikasyondan korunur.
    func sync(modelContainer: ModelContainer, personID: String?) async {
        guard !isSyncing, HealthKitService.isAvailable else { return }
        isSyncing = true

        do {
            try await healthKitService.requestAuthorization()

            let from = lastSyncDate ?? Calendar.current.date(byAdding: .day, value: -30, to: .now)!
            let fetched = try await healthKitService.fetchAllMetrics(from: from, to: .now, historyLimit: 500)

            guard !fetched.isEmpty else {
                lastSyncDate = .now
                isSyncing = false
                return
            }

            let context = ModelContext(modelContainer)
            let existing = (try? context.fetch(FetchDescriptor<LabResult>())) ?? []

            let person: Person? = {
                guard let pid = personID, !pid.isEmpty else { return nil }
                let persons = (try? context.fetch(FetchDescriptor<Person>())) ?? []
                return persons.first { $0.id.uuidString == pid }
            }()

            let values = fetched.map { metric in
                (type: "Apple Health",
                 category: metric.category,
                 valueName: metric.name,
                 value: formatValue(metric.value),
                 unit: metric.unit,
                 referenceRange: metric.referenceRange,
                 academicNote: nil as String?,
                 isAbnormal: metric.isAbnormal,
                 originalPDFPath: nil as String?,
                 date: metric.date,
                 hospital: "Apple Health" as String?)
            }

            let saveResult = LabResult.saveWithDedup(
                values: values,
                existingResults: existing,
                modelContext: context,
                person: person
            )
            try? context.save()

            lastSyncDate = .now
            lastSyncChangedCount = saveResult.inserted + saveResult.updated
        } catch {
            // Sessizce başarısız — kullanıcı manuel olarak tekrar deneyebilir
        }

        isSyncing = false
    }

    private func formatValue(_ value: Double) -> String {
        if value == value.rounded() && value < 100_000 {
            return String(format: "%.0f", value)
        }
        return String(format: "%.1f", value)
    }
}
