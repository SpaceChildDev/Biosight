import SwiftUI
import SwiftData

struct EditResultView: View {
    @Environment(\.dismiss) private var dismiss
    let result: LabResult

    @State private var type: String
    @State private var category: String
    @State private var valueName: String
    @State private var value: String
    @State private var unit: String
    @State private var referenceRange: String
    @State private var hospital: String
    @State private var isAbnormal: Bool
    @State private var date: Date

    private let types = ["Kan", "İdrar", "MR", "BT", "Ultrason", "Apple Health"]
    private let predefinedCategories = [
        "Böbrek", "Karaciğer", "Hemogram", "Tiroid", "Lipid", "Hormon", "Vitamin",
        "Kardiyovasküler", "Tansiyon", "Kan Değerleri", "Vücut Ölçüleri",
        "Solunum", "Aktivite", "Beslenme", "Uyku", "Diğer"
    ]

    private var allCategories: [String] {
        if predefinedCategories.contains(result.category) {
            return predefinedCategories
        }
        return predefinedCategories + [result.category]
    }

    init(result: LabResult) {
        self.result = result
        _type = State(initialValue: result.type)
        _category = State(initialValue: result.category)
        _valueName = State(initialValue: result.valueName)
        _value = State(initialValue: result.value)
        _unit = State(initialValue: result.unit)
        _referenceRange = State(initialValue: result.referenceRange)
        _hospital = State(initialValue: result.hospital ?? "")
        _isAbnormal = State(initialValue: result.isAbnormal)
        _date = State(initialValue: result.date)
    }

    private var isFormValid: Bool {
        !valueName.trimmingCharacters(in: .whitespaces).isEmpty &&
        !value.trimmingCharacters(in: .whitespaces).isEmpty &&
        !unit.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Temel Bilgiler") {
                    Picker("Tür", selection: $type) {
                        ForEach(types, id: \.self) { Text($0) }
                    }
                    Picker("Kategori", selection: $category) {
                        ForEach(allCategories, id: \.self) { Text($0) }
                    }
                    DatePicker("Tarih", selection: $date, displayedComponents: [.date])
                    TextField("Hastane / Kurum", text: $hospital)
                }

                Section("Değerler") {
                    TextField("Değer Adı", text: $valueName)
                    HStack {
                        TextField("Sonuç", text: $value)
                            #if os(iOS)
                            .keyboardType(.decimalPad)
                            #endif
                        Text(unit.isEmpty ? "birim" : unit)
                            .foregroundColor(.secondary)
                    }
                    TextField("Birim (örn: U/L, mg/dL)", text: $unit)
                    TextField("Referans Aralığı (örn: 0-40)", text: $referenceRange)
                    Toggle("Referans Aralığı Dışında", isOn: $isAbnormal)
                }

                Section {
                    Label("Referans aralığını doğru girmek için tahlil belgenize bakın. Referans değerler hastane ve yönteme göre farklılık gösterebilir.", systemImage: "info.circle.fill")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .navigationTitle("Düzenle")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("İptal") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Kaydet") {
                        saveChanges()
                    }
                    .disabled(!isFormValid)
                }
            }
        }
    }

    private func saveChanges() {
        result.type = type
        result.category = category
        result.valueName = valueName.trimmingCharacters(in: .whitespaces)
        result.value = value.trimmingCharacters(in: .whitespaces)
        result.unit = unit.trimmingCharacters(in: .whitespaces)
        result.referenceRange = referenceRange.trimmingCharacters(in: .whitespaces)
        result.hospital = hospital.trimmingCharacters(in: .whitespaces).isEmpty
            ? nil
            : hospital.trimmingCharacters(in: .whitespaces)
        result.isAbnormal = isAbnormal
        result.date = date
        dismiss()
    }
}
