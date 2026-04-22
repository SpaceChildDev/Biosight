import Foundation
import SwiftData

@Model
final class LabResult {
    var id: UUID
    var person: Person?
    var date: Date
    var type: String
    var category: String
    var valueName: String
    var value: String
    var unit: String
    var referenceRange: String
    var isAbnormal: Bool
    var hospital: String?
    var academicNote: String?
    var academicSource: String?
    var originalPDFPath: String?

    init(type: String, category: String, valueName: String, value: String, unit: String, referenceRange: String, academicNote: String? = nil, academicSource: String? = nil, isAbnormal: Bool, originalPDFPath: String? = nil, date: Date = .now, hospital: String? = nil) {
        self.id = UUID()
        self.type = type
        self.category = category
        self.valueName = valueName
        self.value = value
        self.unit = unit
        self.referenceRange = referenceRange
        self.academicNote = academicNote
        self.academicSource = academicSource
        self.isAbnormal = isAbnormal
        self.originalPDFPath = originalPDFPath
        self.date = date
        self.hospital = hospital
    }

    var numericValue: Double? {
        Double(value.replacingOccurrences(of: ",", with: "."))
    }

    var referenceLow: Double? {
        let parts = referenceRange.components(separatedBy: "-")
        guard parts.count == 2 else { return nil }
        return Double(parts[0].trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: "."))
    }

    var referenceHigh: Double? {
        let parts = referenceRange.components(separatedBy: "-")
        guard parts.count == 2 else { return nil }
        return Double(parts[1].trimmingCharacters(in: .whitespaces).replacingOccurrences(of: ",", with: "."))
    }

    /// Aynı gün, aynı kategori, aynı değer adı ve aynı sonuç varsa duplikasyondur.
    /// Aynı gün + kategori + değer adı ama farklı sonuç varsa güncelleme yapılır.
    struct SaveResult {
        var inserted: Int = 0
        var updated: Int = 0
        var skipped: Int = 0
    }

    static func saveWithDedup(
        values: [(type: String, category: String, valueName: String, value: String, unit: String, referenceRange: String, academicNote: String?, isAbnormal: Bool, originalPDFPath: String?, date: Date, hospital: String?)],
        existingResults: [LabResult],
        modelContext: ModelContext,
        person: Person? = nil
    ) -> SaveResult {
        var result = SaveResult()

        for v in values {
            // Aynı gün (takvim günü bazında), aynı kategori, aynı değer adı olanları bul
            let match = existingResults.first { existing in
                existing.valueName == v.valueName &&
                existing.category == v.category &&
                Calendar.current.isDate(existing.date, inSameDayAs: v.date)
            }

            if let match {
                // Aynı değer mi?
                if match.value == v.value {
                    // Tam duplikasyon — academicNote veya hospital boşsa güncelle
                    var updated = false
                    if match.academicNote == nil, let newNote = v.academicNote {
                        match.academicNote = newNote
                        updated = true
                    }
                    if match.hospital == nil, let newHospital = v.hospital {
                        match.hospital = newHospital
                        updated = true
                    }
                    
                    if updated {
                        result.updated += 1
                    } else {
                        result.skipped += 1
                    }
                } else {
                    // Aynı test, farklı değer — güncelle
                    match.value = v.value
                    match.unit = v.unit
                    match.referenceRange = v.referenceRange
                    match.isAbnormal = v.isAbnormal
                    if let newNote = v.academicNote {
                        match.academicNote = newNote
                    }
                    if let pdfPath = v.originalPDFPath {
                        match.originalPDFPath = pdfPath
                    }
                    if let newHospital = v.hospital {
                        match.hospital = newHospital
                    }
                    result.updated += 1
                }
            } else {
                // Yeni değer — ekle
                let labResult = LabResult(
                    type: v.type,
                    category: v.category,
                    valueName: v.valueName,
                    value: v.value,
                    unit: v.unit,
                    referenceRange: v.referenceRange,
                    academicNote: v.academicNote,
                    isAbnormal: v.isAbnormal,
                    originalPDFPath: v.originalPDFPath,
                    date: v.date,
                    hospital: v.hospital
                )
                labResult.person = person
                modelContext.insert(labResult)
                result.inserted += 1
            }
        }

        return result
    }
}
