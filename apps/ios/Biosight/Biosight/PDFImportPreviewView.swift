import SwiftUI
import SwiftData

// MARK: - Editable Model

struct EditableLabValue: Identifiable {
    var id = UUID()
    var valueName: String
    var value: String
    var unit: String
    var referenceRange: String
    var isAbnormal: Bool
    var category: String
    var type: String

    init(from p: LabValueParser.ParsedValue) {
        valueName = p.valueName; value = p.value; unit = p.unit
        referenceRange = p.referenceRange; isAbnormal = p.isAbnormal
        category = p.category; type = p.type
    }

    init(from g: GeminiService.ParsedLabValue) {
        valueName = g.valueName; value = g.value; unit = g.unit
        referenceRange = g.referenceRange; isAbnormal = g.isAbnormal
        category = g.category; type = g.type
    }
}

// MARK: - Preview View

struct PDFImportPreviewView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @Query private var profiles: [Person]
    @AppStorage("activePersonID") private var activePersonID: String = ""

    let pdfData: Data
    let fileName: String

    @State private var items: [EditableLabValue]
    @State private var hospital: String
    @State private var date: Date
    @State private var importMode: ImportMode = .manual
    @State private var isAnalyzing = false
    @State private var errorMessage: String?
    @State private var editingItem: EditableLabValue?
    @State private var showHospitalEdit = false
    /// Manuel (regex) sonuçları — mode geçişlerinde korunur
    @State private var manualItems: [EditableLabValue] = []
    /// AI sonuçları — bir kez analiz edilince cache'lenir
    @State private var cachedAIItems: [EditableLabValue]?

    enum ImportMode: String, CaseIterable {
        case manual = "Manuel"
        case ai = "AI Destekli"
    }

    private var activePerson: Person? {
        profiles.first { $0.id.uuidString == activePersonID }
    }

    init(pdfData: Data, fileName: String,
         initialItems: [EditableLabValue], hospital: String?, date: Date?) {
        self.pdfData = pdfData
        self.fileName = fileName
        _items       = State(initialValue: initialItems)
        _manualItems = State(initialValue: initialItems)
        _hospital    = State(initialValue: hospital ?? "")
        _date        = State(initialValue: date ?? .now)
    }

    var body: some View {
        NavigationStack {
            Group {
                if isAnalyzing {
                    analyzingView
                } else {
                    contentView
                }
            }
            .navigationTitle("Önizleme")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar { toolbarContent }
            .sheet(item: $editingItem) { item in
                EditLabValueSheet(item: item) { updated in
                    if let idx = items.firstIndex(where: { $0.id == updated.id }) {
                        items[idx] = updated
                    }
                }
            }
            .alert("Hastane Adı", isPresented: $showHospitalEdit) {
                TextField("Hastane adı", text: $hospital)
                Button("Tamam") {}
                Button("İptal", role: .cancel) {}
            }
        }
    }

    // MARK: - Subviews

    private var analyzingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .scaleEffect(1.4)
            Text("AI analiz yapıyor...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private var contentView: some View {
        List {
            // Mode + meta
            Section {
                Picker("Mod", selection: $importMode) {
                    ForEach(ImportMode.allCases, id: \.self) { Text($0.rawValue).tag($0) }
                }
                .pickerStyle(.segmented)
                .onChange(of: importMode) { _, new in
                    if new == .ai {
                        if let cached = cachedAIItems {
                            // Daha önce analiz yapıldı — cache'den yükle
                            items = cached
                        } else {
                            runAIAnalysis()
                        }
                    } else {
                        // AI → Manuel: mevcut AI düzenlemelerini sakla, manuel'e geç
                        cachedAIItems = items
                        items = manualItems
                    }
                }

                HStack {
                    Label(hospital.isEmpty ? "Kurum belirtilmemiş" : hospital,
                          systemImage: "building.columns.fill")
                    Spacer()
                    Button { showHospitalEdit = true } label: {
                        Image(systemName: "pencil")
                            .foregroundColor(.accentColor)
                    }
                    .buttonStyle(.plain)
                }

                DatePicker("Tarih", selection: $date, displayedComponents: .date)
            }

            // Error
            if let errorMessage {
                Section {
                    Label(errorMessage, systemImage: "exclamationmark.triangle.fill")
                        .foregroundColor(.red)
                        .font(.caption)
                }
            }

            // Values
            if items.isEmpty {
                Section {
                    ContentUnavailableView(
                        "Değer Bulunamadı",
                        systemImage: "doc.questionmark",
                        description: Text("Bu belgeden otomatik değer çıkarılamadı. AI Destekli modu deneyin veya manuel giriş yapın.")
                    )
                }
            } else {
                Section("\(items.count) değer bulundu") {
                    ForEach($items) { $item in
                        PreviewRowView(item: item)
                            .contentShape(Rectangle())
                            .onTapGesture { editingItem = item }
                            .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                                Button(role: .destructive) {
                                    items.removeAll { $0.id == item.id }
                                } label: {
                                    Label("Sil", systemImage: "trash")
                                }
                            }
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
    }

    @ToolbarContentBuilder
    private var toolbarContent: some ToolbarContent {
        ToolbarItem(placement: .cancellationAction) {
            Button("İptal") { dismiss() }
        }
        ToolbarItem(placement: .confirmationAction) {
            Button("Kaydet (\(items.count))") { saveAndDismiss() }
                .disabled(items.isEmpty)
                .fontWeight(.semibold)
        }
    }

    // MARK: - AI Analysis

    private func runAIAnalysis() {
        guard AIServiceFactory.hasAvailableKey else {
            errorMessage = "AI analizi için önce API anahtarı girin (Ayarlar > AI Ayarları)."
            importMode = .manual
            return
        }
        isAnalyzing = true
        errorMessage = nil
        Task {
            do {
                let service = AIServiceFactory.create()
                let parsed = try await service.analyzePDF(data: pdfData)
                await MainActor.run {
                    let aiItems = parsed.map { EditableLabValue(from: $0) }
                    cachedAIItems = aiItems   // cache — bir daha analiz yapılmaz
                    items = aiItems
                    isAnalyzing = false
                }
            } catch {
                await MainActor.run {
                    errorMessage = "AI analizi başarısız: \(error.localizedDescription)"
                    importMode = .manual
                    isAnalyzing = false
                }
            }
        }
    }

    // MARK: - Save

    private func saveAndDismiss() {
        let hospitalValue = hospital.trimmingCharacters(in: .whitespaces)
        let savedPath = PDFPathResolver.save(
            data: pdfData,
            date: date,
            hospital: hospitalValue.isEmpty ? nil : hospitalValue
        )

        let descriptor = FetchDescriptor<LabResult>()
        let existing = (try? modelContext.fetch(descriptor)) ?? []

        let mapped = items.map { item in (
            type: item.type,
            category: item.category,
            valueName: item.valueName,
            value: item.value,
            unit: item.unit,
            referenceRange: item.referenceRange,
            academicNote: nil as String?,
            isAbnormal: item.isAbnormal,
            originalPDFPath: savedPath,
            date: date,
            hospital: hospitalValue.isEmpty ? nil : hospitalValue
        )}

        _ = LabResult.saveWithDedup(
            values: mapped,
            existingResults: existing,
            modelContext: modelContext,
            person: activePerson
        )
        dismiss()
    }

    // savePDFToDisk replaced by PDFPathResolver.save()
}

// MARK: - Preview Row

private struct PreviewRowView: View {
    let item: EditableLabValue

    var body: some View {
        HStack(spacing: 12) {
            Circle()
                .fill(item.isAbnormal ? Color.orange : Color.green)
                .frame(width: 8, height: 8)

            VStack(alignment: .leading, spacing: 2) {
                Text(item.valueName)
                    .font(.subheadline.bold())
                if !item.referenceRange.isEmpty && item.referenceRange != "-" {
                    Text("Ref: \(item.referenceRange)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text("\(item.value) \(item.unit)")
                    .font(.subheadline.bold())
                    .foregroundColor(item.isAbnormal ? .orange : .primary)
                Text(item.category)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Edit Sheet

struct EditLabValueSheet: View {
    @Environment(\.dismiss) private var dismiss
    @State var item: EditableLabValue
    let onSave: (EditableLabValue) -> Void

    private let categories = ["Hemogram","Karaciğer","Böbrek","Tiroid","Lipid",
                               "Hormon","Vitamin","Kardiyovasküler","Kan Değerleri",
                               "İdrar","Diğer"]
    private let types = ["Kan","İdrar","MR","BT","Ultrason"]

    var body: some View {
        NavigationStack {
            Form {
                Section("Temel") {
                    TextField("Değer Adı", text: $item.valueName)
                    Picker("Tür", selection: $item.type) {
                        ForEach(types, id: \.self) { Text($0) }
                    }
                    Picker("Kategori", selection: $item.category) {
                        ForEach(categories, id: \.self) { Text($0) }
                    }
                }
                Section("Sonuç") {
                    HStack {
                        TextField("Değer", text: $item.value)
                            #if os(iOS)
                            .keyboardType(.decimalPad)
                            #endif
                        Text(item.unit.isEmpty ? "birim" : item.unit)
                            .foregroundColor(.secondary)
                    }
                    TextField("Birim", text: $item.unit)
                    TextField("Referans Aralığı", text: $item.referenceRange)
                    Toggle("Referans Dışı", isOn: $item.isAbnormal)
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
                    Button("Tamam") { onSave(item); dismiss() }
                }
            }
        }
    }
}
