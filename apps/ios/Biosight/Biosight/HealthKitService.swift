import Foundation
import HealthKit

struct HealthMetric: Identifiable {
    let id = UUID()
    let name: String
    let value: Double
    let unit: String
    let date: Date
    let category: String
    let referenceRange: String
    let isAbnormal: Bool
}

class HealthKitService {
    private let healthStore = HKHealthStore()

    static var isAvailable: Bool {
        HKHealthStore.isHealthDataAvailable()
    }

    // Referans aralıklar genel yetişkin dinlenme değerleridir.
    // Egzersiz, stres, kafein gibi faktörler geçici değişimlere neden olabilir.
    // "isOutOfRange" = referans dışı, panik değil sadece bilgilendirme.
    private let quantityTypes: [(HKQuantityTypeIdentifier, String, String, HKUnit, String, @Sendable (Double) -> Bool)] = [
        (.heartRate, "Kalp Atış Hızı", "Kardiyovasküler", HKUnit.count().unitDivided(by: .minute()), "50-120", { $0 < 50 || $0 > 120 }),
        (.restingHeartRate, "Dinlenme Kalp Hızı", "Kardiyovasküler", HKUnit.count().unitDivided(by: .minute()), "50-100", { $0 < 50 || $0 > 100 }),
        (.heartRateVariabilitySDNN, "Kalp Hızı Değişkenliği", "Kardiyovasküler", HKUnit.secondUnit(with: .milli), "20-200", { $0 < 20 || $0 > 200 }),
        (.oxygenSaturation, "Oksijen Satürasyonu", "Kardiyovasküler", HKUnit.percent(), "94-100", { $0 < 94 }),
        (.vo2Max, "VO2 Max", "Kardiyovasküler", HKUnit(from: "ml/kg*min"), "25-60", { $0 < 25 }),
        (.bloodPressureSystolic, "Sistolik Tansiyon", "Tansiyon", HKUnit.millimeterOfMercury(), "90-140", { $0 < 90 || $0 > 140 }),
        (.bloodPressureDiastolic, "Diastolik Tansiyon", "Tansiyon", HKUnit.millimeterOfMercury(), "60-90", { $0 < 60 || $0 > 90 }),
        (.bloodGlucose, "Kan Şekeri", "Kan Değerleri", HKUnit(from: "mg/dL"), "70-140", { $0 < 70 || $0 > 140 }),
        (.bodyTemperature, "Vücut Sıcaklığı", "Vücut Ölçüleri", HKUnit.degreeCelsius(), "35.5-37.5", { $0 < 35.5 || $0 > 37.5 }),
        (.bodyMass, "Kilo", "Vücut Ölçüleri", HKUnit.gramUnit(with: .kilo), "-", { _ in false }),
        (.bodyMassIndex, "BMI", "Vücut Ölçüleri", HKUnit.count(), "18.5-30", { $0 < 18.5 || $0 > 30 }),
        (.bodyFatPercentage, "Vücut Yağ Oranı", "Vücut Ölçüleri", HKUnit.percent(), "8-30", { $0 < 8 || $0 > 30 }),
        (.height, "Boy", "Vücut Ölçüleri", HKUnit.meterUnit(with: .centi), "-", { _ in false }),
        (.waistCircumference, "Bel Çevresi", "Vücut Ölçüleri", HKUnit.meterUnit(with: .centi), "-", { _ in false }),
        (.respiratoryRate, "Solunum Hızı", "Solunum", HKUnit.count().unitDivided(by: .minute()), "12-20", { $0 < 12 || $0 > 20 }),
        (.forcedVitalCapacity, "Zorlu Vital Kapasite", "Solunum", HKUnit.liter(), "3-6", { $0 < 3 }),
        (.stepCount, "Adım Sayısı", "Aktivite", HKUnit.count(), "-", { _ in false }),
        (.distanceWalkingRunning, "Yürüme/Koşma Mesafesi", "Aktivite", HKUnit.meterUnit(with: .kilo), "-", { _ in false }),
        (.activeEnergyBurned, "Aktif Kalori", "Aktivite", HKUnit.kilocalorie(), "-", { _ in false }),
        (.appleExerciseTime, "Egzersiz Süresi", "Aktivite", HKUnit.minute(), "-", { _ in false }),
        (.dietaryEnergyConsumed, "Alınan Kalori", "Beslenme", HKUnit.kilocalorie(), "-", { _ in false }),
        (.dietaryProtein, "Protein", "Beslenme", HKUnit.gram(), "-", { _ in false }),
        (.dietaryCarbohydrates, "Karbonhidrat", "Beslenme", HKUnit.gram(), "-", { _ in false }),
        (.dietaryFatTotal, "Toplam Yağ", "Beslenme", HKUnit.gram(), "-", { _ in false }),
        (.dietaryWater, "Su Tüketimi", "Beslenme", HKUnit.liter(), "-", { _ in false }),
    ]

    private var readTypes: Set<HKSampleType> {
        var types = Set<HKSampleType>()
        for (identifier, _, _, _, _, _) in quantityTypes {
            if let type = HKQuantityType.quantityType(forIdentifier: identifier) {
                types.insert(type)
            }
        }
        if let sleepType = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis) {
            types.insert(sleepType)
        }
        return types
    }

    func requestAuthorization() async throws {
        try await healthStore.requestAuthorization(toShare: [], read: readTypes)
    }

    /// Son değerleri çeker (eski davranış)
    func fetchAllMetrics() async throws -> [HealthMetric] {
        try await fetchAllMetrics(from: Calendar.current.date(byAdding: .month, value: -3, to: .now)!, to: .now, historyLimit: 1)
    }

    /// Belirli tarih aralığında tüm verileri çeker (geçmişe dönük)
    func fetchAllMetrics(from startDate: Date, to endDate: Date, historyLimit: Int = 100) async throws -> [HealthMetric] {
        var metrics: [HealthMetric] = []

        for (identifier, name, category, unit, refRange, isAbnormalCheck) in quantityTypes {
            let fetched = try await fetchQuantityHistory(identifier: identifier, name: name, category: category, unit: unit, referenceRange: refRange, isAbnormalCheck: isAbnormalCheck, startDate: startDate, endDate: endDate, limit: historyLimit)
            metrics.append(contentsOf: fetched)
        }

        let sleepMetrics = try await fetchSleepHistory(startDate: startDate, endDate: endDate)
        metrics.append(contentsOf: sleepMetrics)

        return metrics.sorted { $0.date > $1.date }
    }

    private func fetchQuantityHistory(identifier: HKQuantityTypeIdentifier, name: String, category: String, unit: HKUnit, referenceRange: String, isAbnormalCheck: @escaping @Sendable (Double) -> Bool, startDate: Date, endDate: Date, limit: Int) async throws -> [HealthMetric] {
        guard let quantityType = HKQuantityType.quantityType(forIdentifier: identifier) else { return [] }

        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(sampleType: quantityType, predicate: predicate, limit: limit, sortDescriptors: [sortDescriptor]) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let quantitySamples = samples as? [HKQuantitySample] else {
                    continuation.resume(returning: [])
                    return
                }
                let isPercentUnit = unit == HKUnit.percent()
                let metrics = quantitySamples.map { sample in
                    // HKUnit.percent() returns a fraction (0.0–1.0); convert to percentage (0–100) for display.
                    let raw = sample.quantity.doubleValue(for: unit)
                    let value = isPercentUnit ? (raw * 100).rounded() : raw
                    return HealthMetric(
                        name: name,
                        value: value,
                        unit: isPercentUnit ? "%" : unit.unitString,
                        date: sample.startDate,
                        category: category,
                        referenceRange: referenceRange,
                        isAbnormal: isAbnormalCheck(value)
                    )
                }
                continuation.resume(returning: metrics)
            }
            healthStore.execute(query)
        }
    }

    private func fetchSleepHistory(startDate: Date, endDate: Date) async throws -> [HealthMetric] {
        guard let sleepType = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis) else { return [] }

        let predicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate, options: .strictStartDate)
        let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)

        return try await withCheckedThrowingContinuation { continuation in
            let query = HKSampleQuery(sampleType: sleepType, predicate: predicate, limit: 100, sortDescriptors: [sortDescriptor]) { _, samples, error in
                if let error {
                    continuation.resume(throwing: error)
                    return
                }
                guard let categorySamples = samples as? [HKCategorySample], !categorySamples.isEmpty else {
                    continuation.resume(returning: [])
                    return
                }

                // Günlere göre grupla
                let calendar = Calendar.current
                let grouped = Dictionary(grouping: categorySamples) { sample in
                    calendar.startOfDay(for: sample.startDate)
                }

                // Only count actual sleep stages, not "inBed" or "awake" periods.
                let asleepValues: Set<Int> = [
                    HKCategoryValueSleepAnalysis.asleepUnspecified.rawValue,
                    HKCategoryValueSleepAnalysis.asleepCore.rawValue,
                    HKCategoryValueSleepAnalysis.asleepDeep.rawValue,
                    HKCategoryValueSleepAnalysis.asleepREM.rawValue,
                ]
                let metrics = grouped.compactMap { (day, daySamples) -> HealthMetric? in
                    let totalSleep = daySamples
                        .filter { asleepValues.contains($0.value) }
                        .reduce(0.0) { $0 + $1.endDate.timeIntervalSince($1.startDate) }
                    let hours = totalSleep / 3600.0
                    guard hours > 0 else { return nil }
                    return HealthMetric(
                        name: "Uyku Süresi",
                        value: (hours * 10).rounded() / 10,
                        unit: "saat",
                        date: day,
                        category: "Uyku",
                        referenceRange: "7-9",
                        isAbnormal: hours < 7 || hours > 9
                    )
                }
                continuation.resume(returning: metrics.sorted { $0.date > $1.date })
            }
            healthStore.execute(query)
        }
    }
}
