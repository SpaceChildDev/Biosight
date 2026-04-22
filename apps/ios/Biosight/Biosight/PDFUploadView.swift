import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct PDFUploadView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @AppStorage("geminiAPIKey") private var apiKey = ""
    @Query private var profiles: [Person]
    @AppStorage("activePersonID") private var activePersonID: String = ""

    @State private var showFilePicker = false
    @State private var isExtracting = false
    @State private var previewData: PreviewData?
    @State private var pendingFiles: [(data: Data, name: String)] = []
    @State private var errorMessage: String?
    @State private var showAPIKeyField = false
    @State private var apiKeyStatus: APIKeyStatus = .unknown

    enum APIKeyStatus { case unknown, checking, valid, invalid }

    private struct PreviewData: Identifiable {
        let id = UUID()
        let data: Data
        let name: String
        let items: [EditableLabValue]
        let hospital: String?
        let date: Date?
    }

    private var activePerson: Person? {
        profiles.first { $0.id.uuidString == activePersonID }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 28) {
                Spacer()

                Image(systemName: "doc.badge.plus")
                    .font(.system(size: 64))
                    .foregroundColor(.accentColor)

                VStack(spacing: 8) {
                    Text("Tahlil Belgesi Yükle")
                        .font(.title2.bold())
                    Text("PDF seçilince değerler otomatik okunur. Kaydetmeden önce kontrol edebilirsiniz.")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }

                if isExtracting {
                    VStack(spacing: 10) {
                        ProgressView()
                        Text("Belge okunuyor…")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } else {
                    Button {
                        showFilePicker = true
                    } label: {
                        Label("Dosya Seç", systemImage: "folder.badge.plus")
                            .frame(maxWidth: 280)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }

                if let errorMessage {
                    Text(errorMessage)
                        .font(.caption)
                        .foregroundColor(.red)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                }

                Spacer()
            }
            .padding()
            .navigationTitle("Tahlil Yükle")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Kapat") { dismiss() }
                }
                ToolbarItem(placement: .primaryAction) {
                    Button { showAPIKeyField.toggle() } label: {
                        HStack(spacing: 4) {
                            Circle()
                                .fill(apiKeyStatusColor)
                                .frame(width: 9, height: 9)
                            Image(systemName: "key.fill")
                        }
                    }
                }
            }
            .alert("API Anahtarı", isPresented: $showAPIKeyField) {
                TextField("Gemini API Key", text: $apiKey)
                Button("Tamam") { validateAPIKey() }
            } message: {
                Text("Google AI Studio'dan alınan Gemini API anahtarı. AI Destekli mod için gerekli.")
            }
            .fileImporter(
                isPresented: $showFilePicker,
                allowedContentTypes: [UTType.pdf],
                allowsMultipleSelection: true
            ) { result in
                handleFileImport(result)
            }
            .sheet(item: $previewData) { preview in
                PDFImportPreviewView(
                    pdfData:      preview.data,
                    fileName:     preview.name,
                    initialItems: preview.items,
                    hospital:     preview.hospital,
                    date:         preview.date
                )
                .onDisappear { processNextPending() }
            }
            .onAppear { validateAPIKey() }
            .onChange(of: apiKey) { _, _ in validateAPIKey() }
        }
    }

    // MARK: - File Import

    private func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            var files: [(data: Data, name: String)] = []
            for url in urls {
                guard url.startAccessingSecurityScopedResource() else { continue }
                defer { url.stopAccessingSecurityScopedResource() }
                if let data = try? Data(contentsOf: url) {
                    files.append((data: data, name: url.lastPathComponent))
                }
            }
            guard !files.isEmpty else {
                errorMessage = "Dosyalar okunamadı."
                return
            }
            errorMessage = nil
            pendingFiles = Array(files.dropFirst())
            extractAndPreview(file: files[0])

        case .failure(let error):
            errorMessage = "Dosya seçilemedi: \(error.localizedDescription)"
        }
    }

    private func extractAndPreview(file: (data: Data, name: String)) {
        isExtracting = true
        Task {
            // Extract text on background thread
            let text = await Task.detached(priority: .userInitiated) {
                LocalPDFExtractor.extractText(from: file.data)
            }.value

            let items: [EditableLabValue]
            let hospital: String?
            let date: Date?

            if let text {
                items = LabValueParser.parse(from: text).map { EditableLabValue(from: $0) }
                hospital = LocalPDFExtractor.findHospitalNameLocal(in: text)
                date = LocalPDFExtractor.findDateLocal(in: text)
            } else {
                items = []
                hospital = nil
                date = nil
            }

            await MainActor.run {
                isExtracting = false
                previewData = PreviewData(
                    data:    file.data,
                    name:    file.name,
                    items:   items,
                    hospital: hospital,
                    date:    date
                )
            }
        }
    }

    private func processNextPending() {
        guard let next = pendingFiles.first else { return }
        pendingFiles.removeFirst()
        extractAndPreview(file: next)
    }

    // MARK: - API Key

    private var apiKeyStatusColor: Color {
        switch apiKeyStatus {
        case .unknown:  return .gray
        case .checking: return .yellow
        case .valid:    return .green
        case .invalid:  return .red
        }
    }

    private func validateAPIKey() {
        guard AIServiceFactory.hasAvailableKey else { apiKeyStatus = .invalid; return }
        apiKeyStatus = .checking
        Task {
            let isValid = await AIServiceFactory.create().validateAPIKey()
            await MainActor.run { apiKeyStatus = isValid ? .valid : .invalid }
        }
    }
}
