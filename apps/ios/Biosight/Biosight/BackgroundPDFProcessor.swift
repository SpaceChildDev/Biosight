import Foundation
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

/// Arka planda PDF analizi yapan servis.
/// PDF'ler hemen kuyruğa eklenir, kullanıcı beklemez.
@MainActor
@Observable
class BackgroundPDFProcessor {
    static let shared = BackgroundPDFProcessor()

    struct PDFJob: Identifiable {
        let id = UUID()
        let fileName: String
        let data: Data
        let personID: String?
        var tempPath: String? = nil   // geçici disk yolu (kilitlenme kurtarımı için)
        var status: JobStatus = .queued
        var errorMessage: String?

        enum JobStatus {
            case queued
            case processing
            case completed
            case failed
        }
    }

    var jobs: [PDFJob] = []

    var activeJobCount: Int {
        jobs.filter { $0.status == .queued || $0.status == .processing }.count
    }

    var hasActiveJobs: Bool {
        activeJobCount > 0
    }

    private var isProcessing = false

    /// PDF'leri kuyruğa ekle ve arka planda işlemeye başla.
    /// Dosya adı analiz tamamlandıktan sonra otomatik olarak belirlenir.
    func enqueue(files: [(data: Data, name: String)], personID: String?, modelContext: ModelContext) {
        let pdfDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            .appendingPathComponent("PDFs", isDirectory: true)
        try? FileManager.default.createDirectory(at: pdfDir, withIntermediateDirectories: true)

        for file in files {
            // Kilitlenme kurtarımı için geçici ad ile hemen diske yaz
            let tempURL = pdfDir.appendingPathComponent("temp_\(file.name)")
            try? file.data.write(to: tempURL)

            var job = PDFJob(fileName: file.name, data: file.data, personID: personID,
                             tempPath: tempURL.path)
            job.status = .queued
            jobs.append(job)
        }

        if !isProcessing {
            processQueue(modelContext: modelContext)
        }
    }

    private func processQueue(modelContext: ModelContext) {
        isProcessing = true

        Task {
            while let index = jobs.firstIndex(where: { $0.status == .queued }) {
                jobs[index].status = .processing

                do {
                    // Önce cihaz üzerinde kurum adını çıkar (veri dışarı gönderilmez)
                    let hospitalName = await LocalPDFExtractor.extractHospitalName(from: jobs[index].data)

                    let service = AIServiceFactory.create()
                    let values = try await service.analyzePDF(data: jobs[index].data)

                    if values.isEmpty {
                        jobs[index].status = .failed
                        jobs[index].errorMessage = "Değer bulunamadı"
                        continue
                    }

                    // Sonuçları kaydet
                    saveResults(
                        values: values,
                        pdfData: jobs[index].data,
                        fileName: jobs[index].fileName,
                        personID: jobs[index].personID,
                        hospitalName: hospitalName,
                        tempPath: jobs[index].tempPath,
                        modelContext: modelContext
                    )

                    // Akademik notları arka planda çek
                    let valueNames = values.map(\.valueName)
                    Task {
                        let svc = AIServiceFactory.create()
                        await svc.fetchAcademicNotes(for: valueNames)
                    }

                    jobs[index].status = .completed
                } catch let error as GeminiService.GeminiError {
                    jobs[index].status = .failed
                    jobs[index].errorMessage = error.message
                } catch {
                    jobs[index].status = .failed
                    jobs[index].errorMessage = "Hata: \(error.localizedDescription)"
                }
            }

            isProcessing = false

            // Tamamlananları 5 sn sonra temizle (başarısızlar kalır)
            let completedIDs = jobs.filter { $0.status == .completed }.map(\.id)
            if !completedIDs.isEmpty {
                try? await Task.sleep(for: .seconds(5))
                jobs.removeAll { completedIDs.contains($0.id) }
            }
            // Başarısız işler kullanıcı müdahalesine kadar listede kalır
        }
    }

    private func saveResults(values: [GeminiService.ParsedLabValue], pdfData: Data, fileName: String, personID: String?, hospitalName: String? = nil, tempPath: String? = nil, modelContext: ModelContext) {
        let dateFormatter = DateFormatter()
        dateFormatter.dateFormat = "yyyy-MM-dd"

        // Determine the report date (use first value's date or today)
        let reportDate: Date = {
            if let firstDateStr = values.first?.date,
               let d = dateFormatter.date(from: firstDateStr) { return d }
            return .now
        }()
        let savedPath = PDFPathResolver.save(data: pdfData, date: reportDate, hospital: hospitalName)
        let cache = AcademicNoteCache.shared

        // Person'u bul
        let person: Person?
        if let personID {
            let descriptor = FetchDescriptor<Person>()
            let allPersons = (try? modelContext.fetch(descriptor)) ?? []
            person = allPersons.first { $0.id.uuidString == personID }
        } else {
            person = nil
        }

        let existingDescriptor = FetchDescriptor<LabResult>()
        let existingResults = (try? modelContext.fetch(existingDescriptor)) ?? []

        let mapped = values.map { parsed in
            let parsedDate: Date
            if let dateStr = parsed.date, let d = dateFormatter.date(from: dateStr) {
                parsedDate = d
            } else {
                parsedDate = .now
            }
            let cachedNote = parsed.academicNote ?? cache.note(for: parsed.valueName)
            return (type: parsed.type, category: parsed.category, valueName: parsed.valueName, value: parsed.value, unit: parsed.unit, referenceRange: parsed.referenceRange, academicNote: cachedNote, isAbnormal: parsed.isAbnormal, originalPDFPath: savedPath, date: parsedDate, hospital: hospitalName as String?)
        }

        _ = LabResult.saveWithDedup(values: mapped, existingResults: existingResults, modelContext: modelContext, person: person)

        // Geçici dosyayı sil (artık gerekli değil)
        if let tempPath {
            try? FileManager.default.removeItem(atPath: tempPath)
        }
    }

    /// Başarısız işi tekrar dene
    func retry(job: PDFJob, modelContext: ModelContext) {
        guard let index = jobs.firstIndex(where: { $0.id == job.id }) else { return }
        jobs[index].status = .queued
        jobs[index].errorMessage = nil

        if !isProcessing {
            processQueue(modelContext: modelContext)
        }
    }

    /// Tamamlanan ve başarısız işleri temizle
    func clearFinished() {
        jobs.removeAll { $0.status == .completed || $0.status == .failed }
    }

    /// Belirli bir işi kaldır
    func removeJob(_ job: PDFJob) {
        jobs.removeAll { $0.id == job.id }
    }

    /// Tüm başarısız işleri temizle
    func clearFailed() {
        jobs.removeAll { $0.status == .failed }
    }

    /// Diske kaydedilmiş bir PDF'i tekrar AI ile analiz eder
    func reanalyzeFile(at url: URL, modelContext: ModelContext) {
        guard let data = try? Data(contentsOf: url) else { return }
        let name = url.lastPathComponent
        // Mevcut aynı isimli iş varsa kaldır
        jobs.removeAll { $0.fileName == name && ($0.status == .failed || $0.status == .completed) }
        var job = PDFJob(fileName: name, data: data, personID: nil)
        job.status = .queued
        jobs.append(job)
        if !isProcessing {
            processQueue(modelContext: modelContext)
        }
    }
}
