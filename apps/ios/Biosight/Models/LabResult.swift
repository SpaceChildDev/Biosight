import Foundation
import SwiftData

@Model
final class LabResult {
    var id: UUID
    var date: Date
    var type: String // Kan, İdrar, MR, BT, Ultrason vb.
    var category: String // Böbrek, Karaciğer, Hemogram vb.
    var valueName: String // Üre, ALT, AST
    var value: String
    var unit: String
    var referenceRange: String
    
    // Vizyon maddeleri için eklenen alanlar
    var academicNote: String? // AI tarafından eklenen akademik bilgi
    var academicSource: String? // Akademik makale linki veya adı
    var originalPDFPath: String? // Saklanan orijinal PDF yolu
    var isAbnormal: Bool // Değer referans aralığı dışındaysa true
    
    init(id: UUID = UUID(), 
         date: Date = .now, 
         type: String, 
         category: String, 
         valueName: String, 
         value: String, 
         unit: String, 
         referenceRange: String, 
         academicNote: String? = nil,
         academicSource: String? = nil,
         originalPDFPath: String? = nil,
         isAbnormal: Bool = false) {
        self.id = id
        self.date = date
        self.type = type
        self.category = category
        self.valueName = valueName
        self.value = value
        self.unit = unit
        self.referenceRange = referenceRange
        self.academicNote = academicNote
        self.academicSource = academicSource
        self.originalPDFPath = originalPDFPath
        self.isAbnormal = isAbnormal
    }
}
