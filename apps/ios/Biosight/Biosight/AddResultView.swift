import SwiftUI
import SwiftData

struct AddResultView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var profiles: [Person]
    @AppStorage("activePersonID") private var activePersonID: String = ""

    private var activePerson: Person? {
        profiles.first { $0.id.uuidString == activePersonID }
    }

    @State private var type = "Kan"
    @State private var category = ""
    @State private var valueName = ""
    @State private var value = ""
    @State private var unit = ""
    @State private var referenceRange = ""
    @State private var hospital = ""
    @State private var academicNote = ""
    @State private var academicSource = ""
    @State private var isAbnormal = false
    @State private var date = Date.now

    private let types = ["Kan", "İdrar", "MR", "BT", "Ultrason"]
    private let categories = ["Böbrek", "Karaciğer", "Hemogram", "Tiroid", "Lipid", "Hormon", "Vitamin", "Diğer"]

    private var isFormValid: Bool {
        !category.isEmpty && !valueName.isEmpty && !value.isEmpty && !unit.isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Temel Bilgiler") {
                    Picker("Tür", selection: $type) {
                        ForEach(types, id: \.self) { Text($0) }
                    }
                    Picker("Kategori", selection: $category) {
                        Text("Seçiniz").tag("")
                        ForEach(categories, id: \.self) { Text($0) }
                    }
                    DatePicker("Tarih", selection: $date, displayedComponents: [.date])
                }

                Section("Değerler") {
                    TextField("Değer Adı (örn: ALT)", text: $valueName)
                    TextField("Değer (örn: 65)", text: $value)
                        #if os(iOS)
                        .keyboardType(.decimalPad)
                        #endif
                    TextField("Birim (örn: U/L)", text: $unit)
                    TextField("Referans Aralığı (örn: 0-40)", text: $referenceRange)
                    TextField("Hastane / Kurum", text: $hospital)
                    Toggle("Referans Aralığı Dışında", isOn: $isAbnormal)
                }

                Section("Değer Hakkında (Opsiyonel)") {
                    TextField("Not", text: $academicNote, axis: .vertical)
                        .lineLimit(3...6)
                    TextField("Kaynak (PubMed ID vb.)", text: $academicSource)
                }
            }
            .navigationTitle("Yeni Sonuç Ekle")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("İptal") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Kaydet") {
                        saveResult()
                    }
                    .disabled(!isFormValid)
                }
            }
        }
    }

    private func saveResult() {
        let result = LabResult(
            type: type,
            category: category,
            valueName: valueName,
            value: value,
            unit: unit,
            referenceRange: referenceRange,
            academicNote: academicNote.isEmpty ? nil : academicNote,
            isAbnormal: isAbnormal,
            date: date,
            hospital: hospital.isEmpty ? nil : hospital
        )
        if !academicSource.isEmpty {
            result.academicSource = academicSource
        }
        result.person = activePerson
        modelContext.insert(result)
        dismiss()
    }
}
