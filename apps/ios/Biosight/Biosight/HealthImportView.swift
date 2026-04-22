import SwiftUI
import SwiftData

struct HealthImportView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @AppStorage("geminiAPIKey") private var apiKey = ""
    @Query private var existingResults: [LabResult]
    @Query private var profiles: [Person]
    @AppStorage("activePersonID") private var activePersonID: String = ""

    private var activePerson: Person? {
        profiles.first { $0.id.uuidString == activePersonID }
    }

    @State private var metrics: [HealthMetric] = []
    @State private var selectedMetrics: Set<UUID> = []
    @State private var phase: ImportPhase = .dateSelect
    @State private var errorMessage: String?
    @State private var aiAnalysis: String?
    @State private var isAnalyzingWithAI = false
    @State private var startDate = Calendar.current.date(byAdding: .month, value: -6, to: .now)!
    @State private var endDate = Date.now

    private let healthService = HealthKitService()

    enum ImportPhase {
        case dateSelect
        case loading
        case list
        case error
    }

    var body: some View {
        NavigationStack {
            Group {
                switch phase {
                case .dateSelect:
                    dateSelectView
                case .loading:
                    VStack(spacing: 20) {
                        Spacer()
                        ProgressView()
                            .scaleEffect(1.5)
                        Text("Apple Health verileri okunuyor...")
                            .font(.headline)
                        Text("Geçmişe dönük veriler taranıyor")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                case .error:
                    VStack(spacing: 20) {
                        Spacer()
                        Image(systemName: "heart.slash.fill")
                            .font(.system(size: 64))
                            .foregroundColor(.orange)
                        Text("Veri Okunamadı")
                            .font(.title2.bold())
                        if let errorMessage {
                            Text(errorMessage)
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 32)
                        }
                        Button("Tekrar Dene") {
                            phase = .dateSelect
                        }
                        .buttonStyle(.bordered)
                        Spacer()
                    }
                case .list:
                    metricsListView
                }
            }
            .navigationTitle("Apple Health")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Kapat") { dismiss() }
                }
                if phase == .list && !metrics.isEmpty {
                    ToolbarItem(placement: .primaryAction) {
                        Button("Kaydet") { saveSelectedMetrics() }
                            .disabled(selectedMetrics.isEmpty)
                    }
                }
            }
        }
    }

    // MARK: - Date Selection

    private var dateSelectView: some View {
        VStack(spacing: 24) {
            Spacer()

            Image(systemName: "heart.circle.fill")
                .font(.system(size: 64))
                .foregroundStyle(.linearGradient(colors: [.pink, .red], startPoint: .topLeading, endPoint: .bottomTrailing))

            Text("Apple Health Verileri")
                .font(.title2.bold())

            Text("Geçmişe dönük tüm sağlık verilerinizi içeri aktarın. Tarih aralığı seçip verileri görüntüleyebilirsiniz.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            // Tarih seçiciler
            VStack(spacing: 16) {
                DatePicker("Başlangıç", selection: $startDate, in: ...endDate, displayedComponents: .date)
                DatePicker("Bitiş", selection: $endDate, in: startDate...Date.now, displayedComponents: .date)
            }
            .padding(.horizontal, 32)

            // Hızlı seçim
            HStack(spacing: 12) {
                quickDateButton("1 Ay", months: 1)
                quickDateButton("3 Ay", months: 3)
                quickDateButton("6 Ay", months: 6)
                quickDateButton("1 Yıl", months: 12)
            }

            Button {
                Task { await loadHealthData() }
            } label: {
                Label("Verileri Getir", systemImage: "arrow.down.heart.fill")
                    .frame(maxWidth: 280)
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)

            Spacer()
        }
        .padding()
    }

    private func quickDateButton(_ title: String, months: Int) -> some View {
        Button(title) {
            startDate = Calendar.current.date(byAdding: .month, value: -months, to: .now)!
            endDate = .now
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
    }

    // MARK: - Metrics List

    private var metricsListView: some View {
        List {
            if metrics.isEmpty {
                Section {
                    VStack(spacing: 12) {
                        Image(systemName: "heart.text.square")
                            .font(.system(size: 40))
                            .foregroundColor(.secondary)
                        Text("Seçilen tarih aralığında veri bulunamadı")
                            .font(.headline)
                        Button("Tarih Aralığını Değiştir") {
                            phase = .dateSelect
                        }
                        .buttonStyle(.bordered)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                }
            } else {
                // Bilgilendirme
                Section {
                    Label("Bu veriler yalnızca bilgilendirme amaçlıdır ve sağlık takibi için kullanılabilir. Şüpheli durumlarda doktorunuza danışın.", systemImage: "info.circle.fill")
                        .font(.caption)
                        .foregroundColor(.blue)
                }

                // Özet
                Section {
                    HStack {
                        VStack(alignment: .leading) {
                            Text("\(metrics.count) ölçüm bulundu")
                                .font(.headline)
                            Text("\(startDate.formatted(date: .abbreviated, time: .omitted)) - \(endDate.formatted(date: .abbreviated, time: .omitted))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                        Button(selectedMetrics.count == metrics.count ? "Kaldır" : "Tümünü Seç") {
                            if selectedMetrics.count == metrics.count {
                                selectedMetrics.removeAll()
                            } else {
                                selectedMetrics = Set(metrics.map(\.id))
                            }
                        }
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                    }
                }

                // Kategorilere göre grupla
                let grouped = Dictionary(grouping: metrics, by: \.category)
                ForEach(grouped.keys.sorted(), id: \.self) { category in
                    Section(header: Text("\(category) (\((grouped[category] ?? []).count))")) {
                        ForEach(grouped[category] ?? []) { metric in
                            HealthMetricRow(metric: metric, isSelected: selectedMetrics.contains(metric.id)) {
                                if selectedMetrics.contains(metric.id) {
                                    selectedMetrics.remove(metric.id)
                                } else {
                                    selectedMetrics.insert(metric.id)
                                }
                            }
                        }
                    }
                }

                // AI Analiz
                if !selectedMetrics.isEmpty {
                    Section {
                        Button {
                            analyzeWithAI()
                        } label: {
                            if isAnalyzingWithAI {
                                HStack {
                                    ProgressView()
                                    Text("Analiz ediliyor...")
                                        .padding(.leading, 8)
                                }
                            } else {
                                Label("Seçili Değerleri AI ile Yorumla", systemImage: "wand.and.stars")
                            }
                        }
                        .disabled(isAnalyzingWithAI || !AIServiceFactory.hasAvailableKey)

                        if let aiAnalysis {
                            VStack(alignment: .leading, spacing: 8) {
                                Label("AI Yorumu", systemImage: "brain.head.profile")
                                    .font(.headline)
                                Text(aiAnalysis)
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                Text("Bu yorum yalnızca bilgilendirme amaçlıdır, tıbbi tavsiye değildir. Doktorunuza danışın.")
                                    .font(.caption2)
                                    .foregroundColor(.orange)
                                    .italic()
                            }
                            .padding(.vertical, 4)
                        }
                    }
                }

                // Tarih değiştir
                Section {
                    Button {
                        phase = .dateSelect
                    } label: {
                        Label("Tarih Aralığını Değiştir", systemImage: "calendar")
                    }
                }
            }
        }
    }

    // MARK: - Actions

    private func loadHealthData() async {
        guard HealthKitService.isAvailable else {
            errorMessage = "Bu cihazda Apple Health desteklenmiyor."
            phase = .error
            return
        }

        phase = .loading

        do {
            try await healthService.requestAuthorization()
            let fetched = try await healthService.fetchAllMetrics(from: startDate, to: endDate)
            await MainActor.run {
                metrics = fetched
                selectedMetrics = Set(fetched.map(\.id))
                phase = .list
            }
        } catch {
            await MainActor.run {
                errorMessage = "Veriler okunurken hata oluştu: \(error.localizedDescription)"
                phase = .error
            }
        }
    }

    private func analyzeWithAI() {
        let selected = metrics.filter { selectedMetrics.contains($0.id) }
        guard !selected.isEmpty else { return }

        guard SubscriptionService.shared.canUseAI() else {
            aiAnalysis = "Günlük AI kullanım limitinize ulaştınız. Premium'a geçiş yapın veya yarın tekrar deneyin."
            return
        }

        isAnalyzingWithAI = true
        aiAnalysis = nil

        let summary = selected.map { metric in
            "\(metric.name): \(formatValue(metric.value)) \(metric.unit) (Ref: \(metric.referenceRange))\(metric.isAbnormal ? " [İZLEME]" : "") [\(metric.date.formatted(date: .abbreviated, time: .omitted))]"
        }.joined(separator: "\n")

        Task {
            do {
                let service = AIServiceFactory.create()
                let analysis = try await service.analyzeHealthSummary(summary: summary)
                SubscriptionService.shared.recordAIUsage()
                await MainActor.run {
                    aiAnalysis = analysis
                    isAnalyzingWithAI = false
                }
            } catch {
                await MainActor.run {
                    aiAnalysis = "Analiz yapılamadı: \(error.localizedDescription)"
                    isAnalyzingWithAI = false
                }
            }
        }
    }

    private func saveSelectedMetrics() {
        let selected = metrics.filter { selectedMetrics.contains($0.id) }
        let values = selected.map { metric in
            (type: "Apple Health", category: metric.category, valueName: metric.name, value: formatValue(metric.value), unit: metric.unit, referenceRange: metric.referenceRange, academicNote: nil as String?, isAbnormal: metric.isAbnormal, originalPDFPath: nil as String?, date: metric.date, hospital: "Apple Health" as String?)
        }

        _ = LabResult.saveWithDedup(values: values, existingResults: existingResults, modelContext: modelContext, person: activePerson)
        dismiss()
    }

    private func formatValue(_ value: Double) -> String {
        if value == value.rounded() && value < 100000 {
            return String(format: "%.0f", value)
        }
        return String(format: "%.1f", value)
    }
}

// MARK: - Metric Row

struct HealthMetricRow: View {
    let metric: HealthMetric
    let isSelected: Bool
    let onToggle: () -> Void

    var body: some View {
        Button(action: onToggle) {
            HStack {
                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundColor(isSelected ? .accentColor : .secondary)

                VStack(alignment: .leading, spacing: 2) {
                    Text(metric.name)
                        .font(.subheadline.bold())
                        .foregroundColor(.primary)
                    Text(metric.date.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(formatValue(metric.value)) \(metric.unit)")
                        .font(.subheadline)
                        .foregroundColor(metric.isAbnormal ? .orange : .primary)
                    if metric.referenceRange != "-" {
                        Text("Ref: \(metric.referenceRange)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }

                if metric.isAbnormal {
                    Image(systemName: "info.circle.fill")
                        .foregroundColor(.orange)
                        .font(.caption)
                }
            }
        }
    }

    private func formatValue(_ value: Double) -> String {
        if value == value.rounded() && value < 100000 {
            return String(format: "%.0f", value)
        }
        return String(format: "%.1f", value)
    }
}
