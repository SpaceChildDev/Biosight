import SwiftUI
import SwiftData
import PDFKit
import Charts

struct DetailView: View {
    let result: LabResult
    @Query(sort: \LabResult.date) private var allResults: [LabResult]
    @State private var showAcademicPanel = false
    @State private var showPDF = false
    @State private var showFullChart = false
    @State private var showEditHospital = false
    @State private var editedHospital = ""
    @State private var showEdit = false
    @State private var descriptionRequested = false

    /// Aynı değer adına sahip tüm ölçümler (kronolojik)
    private var historyResults: [LabResult] {
        allResults.filter {
            $0.valueName == result.valueName &&
            $0.type != "Apple Health" &&
            $0.numericValue != nil
        }
    }

    /// Mevcut değerin geçmişteki sırası
    private var currentIndex: Int? {
        historyResults.firstIndex(where: { $0.id == result.id })
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Başlık ve Durum
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(result.valueName)
                            .font(.largeTitle.bold())
                        Text("\(result.category) · \(result.type)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    Spacer()
                    StatusBadge(isAbnormal: result.isAbnormal)
                }

                Divider()

                // Değer Kartı
                HStack(spacing: 16) {
                    ValueCard(title: "Sonuç", value: "\(result.value) \(result.unit)", color: result.isAbnormal ? .orange : .green)
                    ValueCard(title: "Referans", value: result.referenceRange, color: .blue)
                }

                // Trend Grafiği (2+ ölçüm varsa)
                if historyResults.count >= 2 {
                    Divider()
                    ValueTrendSection(
                        results: historyResults,
                        currentResult: result,
                        showFullChart: $showFullChart
                    )
                }

                Divider()

                // Detay Bilgileri
                Group {
                    DetailInfoRow(label: "Tarih", value: result.date.formatted(date: .long, time: .shortened), icon: "calendar")
                    DetailInfoRow(label: "Tür", value: result.type, icon: "cross.vial.fill")
                    DetailInfoRow(label: "Kategori", value: result.category, icon: "folder.fill")
                    HStack {
                        if let hospital = result.hospital, !hospital.isEmpty {
                            DetailInfoRow(label: "Kurum", value: hospital, icon: "building.columns.fill")
                        } else {
                            DetailInfoRow(label: "Kurum", value: "Belirtilmemiş", icon: "building.columns.fill")
                        }
                        Button {
                            editedHospital = result.hospital ?? ""
                            showEditHospital = true
                        } label: {
                            Image(systemName: "pencil.circle.fill")
                                .foregroundColor(.accentColor)
                        }
                    }
                }

                // Tıbbi uyarı
                Divider()

                Label("Bu bilgiler yalnızca bilgilendirme amaçlıdır. Tıbbi tanı veya tedavi yerine geçmez. Doktorunuza danışın.", systemImage: "info.circle.fill")
                    .font(.caption2)
                    .foregroundColor(.orange)
                    .padding(.vertical, 4)

                let hasDescription = result.academicNote != nil
                    || AcademicNoteCache.shared.note(for: result.valueName) != nil

                HStack(spacing: 12) {
                    if hasDescription {
                        Button {
                            showAcademicPanel = true
                        } label: {
                            Label("Değer Hakkında", systemImage: "info.circle.fill")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.borderedProminent)
                    } else if descriptionRequested {
                        Label("Talep alındı", systemImage: "checkmark.circle")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .frame(maxWidth: .infinity)
                    } else {
                        Button {
                            requestDescription()
                        } label: {
                            Label("Açıklama İste", systemImage: "hand.raised")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                    }

                    if result.originalPDFPath != nil {
                        Button {
                            showPDF = true
                        } label: {
                            Label("Tahlil Belgesi", systemImage: "doc.richtext")
                                .frame(maxWidth: .infinity)
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
            .padding()
        }
        .navigationTitle(result.valueName)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                Button {
                    showEdit = true
                } label: {
                    Image(systemName: "pencil")
                }
            }
        }
        .sheet(isPresented: $showEdit) {
            EditResultView(result: result)
        }
        .sheet(isPresented: $showAcademicPanel) {
            AcademicInfoPanel(result: result)
        }
        .sheet(isPresented: $showPDF) {
            if let pdfPath = result.originalPDFPath,
               let resolvedURL = PDFPathResolver.resolve(pdfPath) {
                PDFViewer(path: resolvedURL.absoluteString)
            }
        }
        .fullScreenCover(isPresented: $showFullChart) {
            FullScreenChartView(results: historyResults, valueName: result.valueName)
        }
        .alert("Kurum Adı", isPresented: $showEditHospital) {
            TextField("Kurum adı girin", text: $editedHospital)
            Button("Kaydet") {
                result.hospital = editedHospital.trimmingCharacters(in: .whitespaces)
            }
            Button("İptal", role: .cancel) { }
        } message: {
            Text("Bu tahlil sonucunun kurum adını düzenleyin.")
        }
    }

    // MARK: - Açıklama İste

    /// Kullanıcının bu değer için açıklama talep ettiğini kaydeder.
    /// Açıklamalar AI tarafından değil, manuel olarak hazırlanıp push ile gönderilecek.
    private func requestDescription() {
        saveDescriptionRequest(for: result.valueName)
        descriptionRequested = true
    }

    private func saveDescriptionRequest(for valueName: String) {
        var requests = UserDefaults.standard.stringArray(forKey: "pendingDescriptionRequests") ?? []
        if !requests.contains(valueName) {
            requests.append(valueName)
            UserDefaults.standard.set(requests, forKey: "pendingDescriptionRequests")
        }
    }
}

// MARK: - Değer Trend Bölümü

struct ValueTrendSection: View {
    let results: [LabResult]
    let currentResult: LabResult
    @Binding var showFullChart: Bool

    private var chartData: [ChartDataPoint] {
        results.map {
            ChartDataPoint(date: $0.date, value: $0.numericValue ?? 0, isAbnormal: $0.isAbnormal)
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("Değer Geçmişi", systemImage: "chart.line.uptrend.xyaxis")
                    .font(.headline)
                Spacer()
                Button {
                    showFullChart = true
                } label: {
                    Label("Detay", systemImage: "arrow.up.left.and.arrow.down.right")
                        .font(.caption)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            // Mini grafik (bar chart)
            ChartContent(
                data: chartData,
                referenceLow: results.first?.referenceLow,
                referenceHigh: results.first?.referenceHigh,
                maxLabels: 4
            )
            .frame(height: 140)

            // Geçmiş ölçümler listesi
            VStack(spacing: 0) {
                ForEach(results.reversed()) { item in
                    HStack {
                        Circle()
                            .fill(item.id == currentResult.id ? Color.accentColor : (item.isAbnormal ? Color.orange : Color.green))
                            .frame(width: 8, height: 8)

                        Text(item.date.formatted(date: .abbreviated, time: .omitted))
                            .font(.caption)
                            .foregroundColor(.secondary)

                        if let hospital = item.hospital, !hospital.isEmpty {
                            Text("· \(hospital)")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                                .lineLimit(1)
                        }

                        Spacer()

                        Text("\(item.value) \(item.unit)")
                            .font(.subheadline.bold())
                            .foregroundColor(item.id == currentResult.id ? .accentColor : (item.isAbnormal ? .orange : .primary))
                    }
                    .padding(.vertical, 6)
                    .padding(.horizontal, 8)
                    .background(item.id == currentResult.id ? Color.accentColor.opacity(0.08) : Color.clear)
                    .cornerRadius(6)
                }
            }
            .padding(8)
            .background(Color(.secondarySystemBackground))
            .cornerRadius(10)
        }
    }
}

// MARK: - Alt Bileşenler

struct StatusBadge: View {
    let isAbnormal: Bool

    var body: some View {
        Label(isAbnormal ? "Takip" : "Normal",
              systemImage: isAbnormal ? "eye.fill" : "checkmark.circle.fill")
            .font(.subheadline.bold())
            .foregroundColor(isAbnormal ? .orange : .green)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background((isAbnormal ? Color.orange : Color.green).opacity(0.12))
            .cornerRadius(20)
    }
}

struct ValueCard: View {
    let title: String
    let value: String
    let color: Color

    var body: some View {
        VStack(spacing: 6) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.title2.bold())
                .foregroundColor(color)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(color.opacity(0.08))
        .cornerRadius(12)
    }
}

struct DetailInfoRow: View {
    let label: String
    let value: String
    let icon: String

    var body: some View {
        HStack {
            Label(label, systemImage: icon)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .fontWeight(.medium)
        }
        .padding(.vertical, 2)
    }
}

// MARK: - PDF Viewer

struct PDFViewer: View {
    let path: String
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Group {
                if let url = URL(string: path),
                   let document = PDFDocument(url: url) {
                    PDFKitView(document: document)
                } else {
                    ContentUnavailableView(
                        "PDF Bulunamadı",
                        systemImage: "doc.questionmark",
                        description: Text("Belge yüklenemedi.")
                    )
                }
            }
            .navigationTitle("Orijinal Belge")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Kapat") { dismiss() }
                }
            }
        }
    }
}

#if os(iOS)
struct PDFKitView: UIViewRepresentable {
    let document: PDFDocument

    func makeUIView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.document = document
        pdfView.autoScales = true
        return pdfView
    }

    func updateUIView(_ uiView: PDFView, context: Context) {
        uiView.document = document
    }
}
#else
struct PDFKitView: NSViewRepresentable {
    let document: PDFDocument

    func makeNSView(context: Context) -> PDFView {
        let pdfView = PDFView()
        pdfView.document = document
        pdfView.autoScales = true
        return pdfView
    }

    func updateNSView(_ nsView: PDFView, context: Context) {
        nsView.document = document
    }
}
#endif
