import Foundation
import SwiftData

@Model
final class Person {
    var id: UUID
    var name: String
    var birthDate: Date?
    var gender: String?
    var avatarEmoji: String
    var height: Double?
    var weight: Double?
    var createdAt: Date
    @Relationship(deleteRule: .cascade, inverse: \LabResult.person)
    var labResults: [LabResult]

    init(name: String, birthDate: Date? = nil, gender: String? = nil, avatarEmoji: String = "hi-man", height: Double? = nil, weight: Double? = nil) {
        self.id = UUID()
        self.name = name
        self.birthDate = birthDate
        self.gender = gender
        self.avatarEmoji = avatarEmoji
        self.height = height
        self.weight = weight
        self.createdAt = .now
        self.labResults = []
    }
}
