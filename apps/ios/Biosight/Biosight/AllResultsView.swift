import SwiftUI
import SwiftData

struct AllResultsView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \LabResult.date, order: .reverse) private var allLabResults: [LabResult]
    @Query private var profiles: [Person]
    @AppStorage("activePersonID") private var activePersonID: String = ""
    @State private var searchText = ""
    @State private var reportToEdit: LabReport?

    private var activePerson: Person? {
        profiles.first { $0.id.uuidString == activePersonID }
    }

    private var labResults: [LabResult] {
        guard let person = activePerson else { return allLabResults }
        return allLabResults.filter { $0.person == nil || $0.person?.id == person.id }
    }

    private var filteredResults: [LabResult] {
        let nonHealth = labResults.filter { $0.type != "Apple Health" }
        if searchText.isEmpty {
            return nonHealth
        }
        return nonHealth.filter {
            $0.valueName.localizedCaseInsensitiveContains(searchText) ||
            $0.category.localizedCaseInsensitiveContains(searchText) ||
            ($0.hospital ?? "").localizedCaseInsensitiveContains(searchText)
        }
    }

    /// Aynı gün + aynı hastane = 1 rapor
    private var reports: [LabReport] {
        let grouped = Dictionary(grouping: filteredResults) { result in
            let day = Calendar.current.startOfDay(for: result.date)
            let hospital = result.hospital ?? ""
            return "\(day.timeIntervalSince1970)_\(hospital)"
        }
        return grouped.map { _, results in
            let sorted = results.sorted { $0.valueName < $1.valueName }
            return LabReport(
                date: sorted.first?.date ?? .now,
                hospital: sorted.first?.hospital,
                type: sorted.first?.type ?? "Kan",
                results: sorted,
                hasPDF: sorted.contains { $0.originalPDFPath != nil }
            )
        }.sorted { $0.date > $1.date }
    }

    var body: some View {
        List {
            if filteredResults.isEmpty && searchText.isEmpty {
                ContentUnavailableView(
                    "Henüz Tahlil Yok",
                    systemImage: "tray",
                    description: Text("PDF yükleyerek, kamera ile taratarak veya manuel girerek tahlil ekleyebilirsiniz.")
                )
            } else if reports.isEmpty {
                ContentUnavailableView(
                    "Sonuç Bulunamadı",
                    systemImage: "magnifyingglass",
                    description: Text("Aramanızla eşleşen tahlil bulunamadı.")
                )
            } else {
                ForEach(reports) { report in
                    NavigationLink {
                        ReportDetailView(report: report)
                    } label: {
                        ReportRow(report: report)
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        Button(role: .destructive) {
                            for result in report.results {
                                modelContext.delete(result)
                            }
                        } label: {
                            Label("Sil", systemImage: "trash")
                        }
                    }
                    .swipeActions(edge: .leading, allowsFullSwipe: false) {
                        Button {
                            reportToEdit = report
                        } label: {
                            Label("Düzenle", systemImage: "pencil")
                        }
                        .tint(.blue)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .searchable(text: $searchText, prompt: "Tahlil, kategori veya kurum ara...")
        .navigationTitle("Tahlil")
        .sheet(item: $reportToEdit) { report in
            EditReportView(report: report)
        }
    }
}

// MARK: - Rapor Modeli

struct LabReport: Identifiable {
    let id = UUID()
    let date: Date
    let hospital: String?
    let type: String
    let results: [LabResult]
    let hasPDF: Bool

    var abnormalResults: [LabResult] {
        results.filter { $0.isAbnormal }
    }

    var categories: [String] {
        Array(Set(results.map { $0.category })).sorted()
    }
}

// MARK: - Rapor Satırı (Inbox Tarzı)

struct ReportRow: View {
    let report: LabReport

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            // Üst: Tarih + Tür + PDF ikonu
            HStack {
                Text(report.date.formatted(date: .long, time: .omitted))
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                if report.hasPDF {
                    Image(systemName: "doc.fill")
                        .font(.caption2)
                        .foregroundColor(.blue)
                }

                Text(report.type)
                    .font(.caption2.bold())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 2)
                    .background(Color.accentColor.opacity(0.1))
                    .foregroundColor(.accentColor)
                    .cornerRadius(4)
            }

            // Orta: Hastane + Değer sayısı
            HStack {
                Label(report.hospital ?? "Kurum belirtilmemiş", systemImage: "building.columns.fill")
                    .font(.headline)
                    .lineLimit(1)

                Spacer()

                Text("\(report.results.count) değer")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            // Alt: Anormal değerler
            if !report.abnormalResults.isEmpty {
                HStack(spacing: 6) {
                    Image(systemName: "info.circle.fill")
                        .font(.caption2)
                        .foregroundColor(.orange)

                    Text(report.abnormalResults.map { $0.valueName }.joined(separator: ", "))
                        .font(.caption)
                        .foregroundColor(.orange)
                        .lineLimit(2)

                    Spacer()

                    Text("\(report.abnormalResults.count) referans dışı")
                        .font(.caption2.bold())
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(Color.orange)
                        .cornerRadius(4)
                }
            } else {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.caption2)
                        .foregroundColor(.green)
                    Text("Tüm değerler normal")
                        .font(.caption)
                        .foregroundColor(.green)
                }
            }

            // Kategoriler (max 3 göster)
            if report.categories.count > 1 {
                let visible = Array(report.categories.prefix(3))
                let overflow = report.categories.count - visible.count
                HStack(spacing: 4) {
                    ForEach(visible, id: \.self) { category in
                        HStack(spacing: 3) {
                            CategoryIconView(category: category, size: 10)
                            Text(category)
                        }
                        .font(.system(size: 10))
                        .padding(.horizontal, 6)
                        .padding(.vertical, 2)
                        .background(Color.secondary.opacity(0.1))
                        .cornerRadius(3)
                    }
                    if overflow > 0 {
                        Text("+\(overflow)")
                            .font(.system(size: 10))
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.secondary.opacity(0.1))
                            .foregroundColor(.secondary)
                            .cornerRadius(3)
                    }
                }
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Rapor Detay Sayfası

struct ReportDetailView: View {
    let report: LabReport
    @Environment(\.modelContext) private var modelContext
    @State private var resultToEdit: LabResult?

    private var groupedByCategory: [(category: String, results: [LabResult])] {
        let grouped = Dictionary(grouping: report.results) { $0.category }
        return grouped.map { (category: $0.key, results: $0.value) }
            .sorted { $0.category < $1.category }
    }

    var body: some View {
        List {
            // Rapor özeti
            Section {
                VStack(alignment: .leading, spacing: 10) {
                    HStack {
                        Label(report.hospital ?? "Kurum belirtilmemiş", systemImage: "building.columns.fill")
                            .font(.headline)
                        Spacer()
                    }

                    HStack(spacing: 16) {
                        Label(report.date.formatted(date: .long, time: .omitted), systemImage: "calendar")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }

                    HStack(spacing: 16) {
                        StatBadge(
                            value: "\(report.results.count)",
                            label: "Değer",
                            color: .blue
                        )
                        StatBadge(
                            value: "\(report.abnormalResults.count)",
                            label: "Referans Dışı",
                            color: report.abnormalResults.isEmpty ? .green : .orange
                        )
                        StatBadge(
                            value: "\(report.results.count - report.abnormalResults.count)",
                            label: "Normal",
                            color: .green
                        )
                    }
                }
                .padding(.vertical, 4)
            }

            // Kategorilere göre değerler
            ForEach(groupedByCategory, id: \.category) { category, results in
                Section {
                    ForEach(results) { result in
                        NavigationLink {
                            DetailView(result: result)
                        } label: {
                            ReportValueRow(result: result)
                        }
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                modelContext.delete(result)
                            } label: {
                                Label("Sil", systemImage: "trash")
                            }
                        }
                        .swipeActions(edge: .leading) {
                            Button {
                                resultToEdit = result
                            } label: {
                                Label("Düzenle", systemImage: "pencil")
                            }
                            .tint(.blue)
                        }
                    }
                } header: {
                    HStack(spacing: 6) {
                        CategoryIconView(category: category, size: 14)
                        Text(category)
                    }
                }
            }
        }
        .listStyle(.insetGrouped)
        .navigationTitle("Tahlil Detayı")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .sheet(item: $resultToEdit) { result in
            EditResultView(result: result)
        }
    }
}

// MARK: - Değer Satırı (Detay İçi)

struct ReportValueRow: View {
    let result: LabResult

    var body: some View {
        HStack {
            // Sol: Durum ikonu + değer adı
            HStack(spacing: 8) {
                Circle()
                    .fill(result.isAbnormal ? Color.orange : Color.green)
                    .frame(width: 8, height: 8)

                VStack(alignment: .leading, spacing: 2) {
                    Text(result.valueName)
                        .font(.subheadline.bold())
                    if !result.referenceRange.isEmpty && result.referenceRange != "-" {
                        Text("Ref: \(result.referenceRange)")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }

            Spacer()

            // Sağ: Sonuç
            Text("\(result.value) \(result.unit)")
                .font(.subheadline.bold())
                .foregroundColor(result.isAbnormal ? .orange : .primary)
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Rapor Düzenleme

struct EditReportView: View {
    @Environment(\.dismiss) private var dismiss
    let report: LabReport

    @State private var date: Date
    @State private var hospital: String
    @State private var editingResult: LabResult?

    init(report: LabReport) {
        self.report = report
        _date     = State(initialValue: report.date)
        _hospital = State(initialValue: report.hospital ?? "")
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Rapor Bilgileri") {
                    DatePicker("Tarih", selection: $date, displayedComponents: .date)
                    TextField("Hastane / Kurum", text: $hospital)
                        .autocorrectionDisabled()
                }

                Section {
                    ForEach(report.results) { result in
                        Button {
                            editingResult = result
                        } label: {
                            HStack {
                                Circle()
                                    .fill(result.isAbnormal ? Color.orange : Color.green)
                                    .frame(width: 7, height: 7)

                                VStack(alignment: .leading, spacing: 2) {
                                    Text(result.valueName)
                                        .font(.subheadline.bold())
                                        .foregroundColor(.primary)
                                    Text(result.category)
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }

                                Spacer()

                                Text("\(result.value) \(result.unit)")
                                    .font(.subheadline)
                                    .foregroundColor(result.isAbnormal ? .orange : .secondary)

                                Image(systemName: "chevron.right")
                                    .font(.caption2)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                } header: {
                    Text("\(report.results.count) Değer")
                }
            }
            .navigationTitle("Raporu Düzenle")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("İptal") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Kaydet") { saveChanges() }
                        .fontWeight(.semibold)
                }
            }
            .sheet(item: $editingResult) { result in
                EditResultView(result: result)
            }
        }
    }

    private func saveChanges() {
        let h = hospital.trimmingCharacters(in: .whitespaces)
        for result in report.results {
            result.date     = date
            result.hospital = h.isEmpty ? nil : h
        }
        dismiss()
    }
}

// MARK: - İstatistik Badge

struct StatBadge: View {
    let value: String
    let label: String
    let color: Color

    var body: some View {
        VStack(spacing: 2) {
            Text(value)
                .font(.title2.bold())
                .foregroundColor(color)
            Text(label)
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(color.opacity(0.08))
        .cornerRadius(8)
    }
}
