import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct SharedFileImportView: View {
    let url: URL
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @AppStorage("geminiAPIKey") private var apiKey = ""
    @Query private var existingResults: [LabResult]
    @Query private var profiles: [Person]
    @AppStorage("activePersonID") private var activePersonID: String = ""

    private var activePerson: Person? {
        profiles.first { $0.id.uuidString == activePersonID }
    }

    @State private var phase: ImportPhase = .reading
    @State private var parsedValues: [GeminiService.ParsedLabValue] = []
    @State private var errorMessage: String?
    @State private var fileData: Data?
    @State private var fileName: String = ""
    @State private var hospitalName: String?

    enum ImportPhase {
        case reading
        case analyzing
        case results
        case error
    }

    var body: some View {
        NavigationStack {
            Group {
                switch phase {
                case .reading, .analyzing:
                    loadingView
                case .results:
                    ParsedResultsView(
                        values: $parsedValues,
                        pdfData: fileData,
                        onSave: saveResults,
                        onCancel: { dismiss() }
                    )
                case .error:
                    errorView
                }
            }
            .navigationTitle("Dosya İçe Aktar")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Kapat") { dismiss() }
                }
            }
            .onAppear {
                startImport()
            }
        }
    }

    private var loadingView: some View {
        VStack(spacing: 20) {
            Spacer()
            ProgressView()
                .scaleEffect(1.5)
            Text(phase == .reading ? "Dosya okunuyor..." : "Analiz ediliyor...")
                .font(.headline)
            Text(fileName)
                .font(.caption)
                .foregroundColor(.secondary)
            Text("Bu işlem birkaç saniye sürebilir.")
                .font(.caption)
                .foregroundColor(.secondary)
            Spacer()
        }
    }

    private var errorView: some View {
        VStack(spacing: 20) {
            Spacer()
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 64))
                .foregroundColor(.orange)
            Text("Hata Oluştu")
                .font(.title2.bold())
            if let errorMessage {
                Text(errorMessage)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
            }
            Button("Kapat") { dismiss() }
                .buttonStyle(.bordered)
            Spacer()
        }
    }

    private func startImport() {
        fileName = url.lastPathComponent
        
        guard url.startAccessingSecurityScopedResource() else {
            errorMessage = "Dosyaya erişim izni alınamadı."
            phase = .error
            return
        }
        defer { url.stopAccessingSecurityScopedResource() }

        do {
            let data = try Data(contentsOf: url)
            fileData = data
            phase = .analyzing

            // Kurum adını cihaz üzerinde çıkar (async)
            Task {
                hospitalName = await LocalPDFExtractor.extractHospitalName(from: data)
            }

            analyzeData(data)
        } catch {
            errorMessage = "Dosya okunamadı: \(error.localizedDescription)"
            phase = .error
        }
    }

    private func analyzeData(_ data: Data) {
        Task {
            let service = AIServiceFactory.create()
            do {
                // Dosya tipine göre analiz et
                let values: [GeminiService.ParsedLabValue]
                let ext = url.pathExtension.lowercased()
                
                if ext == "pdf" {
                    values = try await service.analyzePDF(data: data)
                } else {
                    let mimeType: String
                    if ext == "png" {
                        mimeType = "image/png"
                    } else if ext == "jpg" || ext == "jpeg" {
                        mimeType = "image/jpeg"
                    } else {
                        mimeType = "image/jpeg" // Fallback
                    }
                    values = try await service.analyzeImage(data: data, mimeType: mimeType)
                }

                await MainActor.run {
                    if values.isEmpty {
                        errorMessage = "Dosyadan herhangi bir sonuç çıkarılamadı."
                        phase = .error
                    } else {
                        parsedValues = values
                        phase = .results
                    }
                }
            } catch let error as GeminiService.GeminiError {
                await MainActor.run {
                    errorMessage = error.message
                    phase = .error
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Hata: \(error.localizedDescription)"
                    phase = .error
                }
            }
        }
    }

    private func saveResults() {
        guard let fileData else { return }

        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        // Dosyayı diske kaydet
        let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let pdfDir = documentsURL.appendingPathComponent("PDFs", conformingTo: .folder)
        try? FileManager.default.createDirectory(at: pdfDir, withIntermediateDirectories: true)

        let fileURL = pdfDir.appendingPathComponent(fileName)
        try? fileData.write(to: fileURL)
        let savedPath = fileURL.absoluteString

        let cache = AcademicNoteCache.shared

        let values = parsedValues.map { parsed in
            let parsedDate: Date
            if let dateStr = parsed.date, let d = dateFormatter.date(from: dateStr) {
                parsedDate = d
            } else {
                parsedDate = .now
            }
            let cachedNote = parsed.academicNote ?? cache.note(for: parsed.valueName)
            return (type: parsed.type, category: parsed.category, valueName: parsed.valueName, value: parsed.value, unit: parsed.unit, referenceRange: parsed.referenceRange, academicNote: cachedNote, isAbnormal: parsed.isAbnormal, originalPDFPath: savedPath, date: parsedDate, hospital: self.hospitalName)
        }

        _ = LabResult.saveWithDedup(values: values, existingResults: existingResults, modelContext: modelContext, person: activePerson)

        // Arka planda eksik akademik notları çek
        let valueNames = parsedValues.map(\.valueName)
        Task {
            let service = AIServiceFactory.create()
            await service.fetchAcademicNotes(for: valueNames)
        }

        dismiss()
    }
}
