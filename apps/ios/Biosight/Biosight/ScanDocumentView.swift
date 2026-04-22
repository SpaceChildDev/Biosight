import SwiftUI
import SwiftData
import VisionKit

struct ScanDocumentView: View {
    @Environment(\.modelContext) private var modelContext
    @Environment(\.dismiss) private var dismiss
    @AppStorage("geminiAPIKey") private var apiKey = ""
    @Query private var existingResults: [LabResult]
    @Query private var profiles: [Person]
    @AppStorage("activePersonID") private var activePersonID: String = ""

    private var activePerson: Person? {
        profiles.first { $0.id.uuidString == activePersonID }
    }

    @State private var showScanner = false
    @State private var scannedImages: [UIImage] = []
    @State private var isAnalyzing = false
    @State private var parsedValues: [GeminiService.ParsedLabValue] = []
    @State private var errorMessage: String?
    @State private var phase: ScanPhase = .scan

    enum ScanPhase {
        case scan
        case analyzing
        case results
    }

    var body: some View {
        NavigationStack {
            Group {
                switch phase {
                case .scan:
                    if scannedImages.isEmpty {
                        VStack(spacing: 20) {
                            Spacer()
                            Image(systemName: "camera.viewfinder")
                                .font(.system(size: 64))
                                .foregroundColor(.accentColor)
                            Text("Tahlil Tara")
                                .font(.title2.bold())
                            Text("Kamera ile tahlil belgenizi tarayın. Metin otomatik olarak algılanacak ve analiz edilecek.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 32)

                            if VNDocumentCameraViewController.isSupported {
                                Button {
                                    showScanner = true
                                } label: {
                                    Label("Taramayı Başlat", systemImage: "camera.fill")
                                        .frame(maxWidth: 280)
                                }
                                .buttonStyle(.borderedProminent)
                                .controlSize(.large)
                            } else {
                                Label("Bu cihazda belge tarama desteklenmiyor.", systemImage: "exclamationmark.triangle.fill")
                                    .font(.subheadline)
                                    .foregroundColor(.orange)
                            }

                            if let errorMessage {
                                Text(errorMessage)
                                    .font(.caption)
                                    .foregroundColor(.red)
                                    .padding(.horizontal)
                            }
                            Spacer()
                        }
                        .padding()
                    } else {
                        VStack(spacing: 20) {
                            Spacer()
                            Image(systemName: "checkmark.circle.fill")
                                .font(.system(size: 48))
                                .foregroundColor(.green)
                            Text("\(scannedImages.count) sayfa tarandı")
                                .font(.headline)
                            Button {
                                analyzeScannedImages()
                            } label: {
                                Label("Analiz Et", systemImage: "wand.and.stars")
                                    .frame(maxWidth: 280)
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.large)

                            Button {
                                scannedImages = []
                                showScanner = true
                            } label: {
                                Label("Tekrar Tara", systemImage: "arrow.counterclockwise")
                                    .frame(maxWidth: 280)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.large)
                            Spacer()
                        }
                    }
                case .analyzing:
                    VStack(spacing: 20) {
                        Spacer()
                        ProgressView()
                            .scaleEffect(1.5)
                        Text("Analiz ediliyor...")
                            .font(.headline)
                        Text("\(scannedImages.count) sayfa işleniyor.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text("Bu işlem birkaç saniye sürebilir.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Spacer()
                    }
                case .results:
                    ParsedResultsView(
                        values: $parsedValues,
                        pdfData: nil,
                        onSave: saveResults,
                        onCancel: { phase = .scan; scannedImages = [] }
                    )
                }
            }
            .navigationTitle("Tahlil Tara")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Kapat") { dismiss() }
                }
            }
            .sheet(isPresented: $showScanner) {
                DocumentScannerView { images in
                    scannedImages = images
                    showScanner = false
                } onCancel: {
                    showScanner = false
                    if scannedImages.isEmpty {
                        dismiss()
                    }
                }
            }
        }
    }

    private func analyzeScannedImages() {
        phase = .analyzing
        Task {
            do {
                let service = AIServiceFactory.create()
                var allValues: [GeminiService.ParsedLabValue] = []
                for image in scannedImages {
                    let values = try await service.analyzeImage(image: image)
                    allValues.append(contentsOf: values)
                }
                await MainActor.run {
                    parsedValues = allValues
                    phase = .results
                }
            } catch let error as GeminiService.GeminiError {
                await MainActor.run {
                    errorMessage = "Analiz hatası: \(error.message)"
                    phase = .scan
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Analiz hatası: \(error.localizedDescription)"
                    phase = .scan
                }
            }
        }
    }

    private func saveResults() {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        let values = parsedValues.map { parsed in
            let parsedDate: Date
            if let dateStr = parsed.date, let d = dateFormatter.date(from: dateStr) {
                parsedDate = d
            } else {
                parsedDate = .now
            }
            return (type: parsed.type, category: parsed.category, valueName: parsed.valueName, value: parsed.value, unit: parsed.unit, referenceRange: parsed.referenceRange, academicNote: parsed.academicNote, isAbnormal: parsed.isAbnormal, originalPDFPath: nil as String?, date: parsedDate, hospital: nil as String?)
        }

        _ = LabResult.saveWithDedup(values: values, existingResults: existingResults, modelContext: modelContext, person: activePerson)
        dismiss()
    }
}

// MARK: - Document Scanner UIKit Wrapper

struct DocumentScannerView: UIViewControllerRepresentable {
    var onScan: ([UIImage]) -> Void
    var onCancel: () -> Void

    func makeUIViewController(context: Context) -> VNDocumentCameraViewController {
        let scanner = VNDocumentCameraViewController()
        scanner.delegate = context.coordinator
        return scanner
    }

    func updateUIViewController(_ uiViewController: VNDocumentCameraViewController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(onScan: onScan, onCancel: onCancel)
    }

    class Coordinator: NSObject, VNDocumentCameraViewControllerDelegate {
        var onScan: ([UIImage]) -> Void
        var onCancel: () -> Void

        init(onScan: @escaping ([UIImage]) -> Void, onCancel: @escaping () -> Void) {
            self.onScan = onScan
            self.onCancel = onCancel
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFinishWith scan: VNDocumentCameraScan) {
            var images: [UIImage] = []
            for i in 0..<scan.pageCount {
                images.append(scan.imageOfPage(at: i))
            }
            controller.dismiss(animated: true) {
                self.onScan(images)
            }
        }

        func documentCameraViewControllerDidCancel(_ controller: VNDocumentCameraViewController) {
            controller.dismiss(animated: true) {
                self.onCancel()
            }
        }

        func documentCameraViewController(_ controller: VNDocumentCameraViewController, didFailWithError error: Error) {
            controller.dismiss(animated: true) {
                self.onCancel()
            }
        }
    }
}
