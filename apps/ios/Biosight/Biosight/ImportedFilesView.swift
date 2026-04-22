import SwiftUI
import SwiftData

struct ImportedFilesView: View {
    @Query(sort: \LabResult.date, order: .reverse) private var labResults: [LabResult]
    @Environment(\.modelContext) private var modelContext
    @State private var selectedPDFURL: URL?
    @State private var editingFilePath: String?
    @State private var editedHospital = ""
    @State private var rescanningPath: String?
    @State private var processor = BackgroundPDFProcessor.shared

    // Dosya → (değer sayısı, kurum adı, hata)
    private var importedFiles: [(name: String, url: URL, date: Date, valueCount: Int, hospital: String?)] {
        var fileMap: [String: (name: String, url: URL, date: Date, count: Int, hospital: String?)] = [:]
        for result in labResults {
            guard let path = result.originalPDFPath else { continue }
            // Resolver ile güncel URL'yi bul (sandbox UUID değişikliklerine karşı)
            guard let url = PDFPathResolver.resolve(path) else { continue }
            let stableKey = url.lastPathComponent  // dosya adı ile grupla (path-agnostic)
            let name = url.lastPathComponent
            if var existing = fileMap[stableKey] {
                existing.count += 1
                if result.date < existing.date { existing.date = result.date }
                if existing.hospital == nil, let h = result.hospital { existing.hospital = h }
                fileMap[stableKey] = existing
            } else {
                fileMap[stableKey] = (name: name, url: url, date: result.date, count: 1, hospital: result.hospital)
            }
        }
        return fileMap.values
            .map { (name: $0.name, url: $0.url, date: $0.date, valueCount: $0.count, hospital: $0.hospital) }
            .sorted { $0.date > $1.date }
    }

    /// Diskte kayıtlı olup hiç LabResult'u olmayan PDF'ler (başarısız yüklemeler)
    private var unprocessedFiles: [URL] {
        let pdfDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
            .appendingPathComponent("PDFs")
        guard let allFiles = try? FileManager.default.contentsOfDirectory(
            at: pdfDir, includingPropertiesForKeys: [.creationDateKey], options: [.skipsHiddenFiles]
        ) else { return [] }
        let knownPaths = Set(labResults.compactMap { $0.originalPDFPath })
        return allFiles.filter { url in
            !knownPaths.contains(url.absoluteString) &&
            url.pathExtension.lowercased() == "pdf"
        }
    }

    var body: some View {
        List {
            // Aktif işlemler
            if processor.hasActiveJobs {
                Section("İşleniyor") {
                    ForEach(processor.jobs.filter { $0.status == .queued || $0.status == .processing }) { job in
                        HStack(spacing: 12) {
                            ProgressView()
                                .controlSize(.small)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(job.fileName)
                                    .font(.subheadline.bold())
                                    .lineLimit(1)
                                Text(job.status == .processing ? "Analiz ediliyor..." : "Sırada bekliyor")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }

            // Başarısız işlemler (bellektekiler)
            let failedJobs = processor.jobs.filter { $0.status == .failed }
            if !failedJobs.isEmpty {
                Section {
                    ForEach(failedJobs) { job in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack(spacing: 10) {
                                Image(systemName: "exclamationmark.triangle.fill")
                                    .foregroundColor(.orange)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(job.fileName)
                                        .font(.subheadline.bold())
                                        .lineLimit(1)
                                    if let err = job.errorMessage {
                                        Text(err)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    }
                                }
                                Spacer()
                                Button {
                                    processor.retry(job: job, modelContext: modelContext)
                                } label: {
                                    Label("Tekrar Dene", systemImage: "arrow.clockwise")
                                        .font(.caption)
                                }
                                .buttonStyle(.bordered)
                                .controlSize(.small)
                            }
                        }
                        .padding(.vertical, 4)
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                processor.removeJob(job)
                            } label: {
                                Label("Temizle", systemImage: "trash")
                            }
                        }
                    }
                } header: {
                    HStack {
                        Label("Başarısız", systemImage: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                        Spacer()
                        Button("Tümünü Temizle") {
                            processor.clearFailed()
                        }
                        .font(.caption)
                        .foregroundColor(.red)
                    }
                }
            }

            // İşlenmemiş dosyalar (diskte var, sonuç yok)
            if !unprocessedFiles.isEmpty {
                Section {
                    ForEach(unprocessedFiles, id: \.absoluteString) { url in
                        HStack(spacing: 12) {
                            Image(systemName: "doc.badge.exclamationmark")
                                .font(.title2)
                                .foregroundColor(.orange)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(url.lastPathComponent)
                                    .font(.subheadline.bold())
                                    .lineLimit(1)
                                Text("Sonuç yüklenmemiş")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            Spacer()

                            if rescanningPath == url.absoluteString {
                                ProgressView().controlSize(.small)
                            } else {
                                Button {
                                    reanalyzeFile(url: url)
                                } label: {
                                    Label("Analiz Et", systemImage: "sparkles")
                                        .font(.caption)
                                }
                                .buttonStyle(.borderedProminent)
                                .controlSize(.small)
                            }
                        }
                        .padding(.vertical, 4)
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                deleteUnprocessedFile(url: url)
                            } label: {
                                Label("Sil", systemImage: "trash")
                            }
                        }
                    }
                } header: {
                    Label("İşlenmemiş Dosyalar", systemImage: "doc.badge.exclamationmark")
                        .foregroundColor(.orange)
                }
            }

            // Başarılı dosyalar
            if importedFiles.isEmpty && failedJobs.isEmpty && unprocessedFiles.isEmpty && !processor.hasActiveJobs {
                ContentUnavailableView(
                    "Dosya Yok",
                    systemImage: "doc.text.magnifyingglass",
                    description: Text("Henüz içe aktarılmış dosya bulunmuyor.")
                )
            } else if !importedFiles.isEmpty {
                Section("İçe Aktarılan Dosyalar") {
                    ForEach(importedFiles, id: \.url.absoluteString) { file in
                        Button {
                            selectedPDFURL = file.url
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "doc.fill")
                                    .font(.title2)
                                    .foregroundColor(.accentColor)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(file.name)
                                        .font(.subheadline.bold())
                                        .foregroundColor(.primary)
                                        .lineLimit(1)
                                    HStack(spacing: 8) {
                                        Text(file.date, style: .date)
                                        Text("\(file.valueCount) değer")
                                    }
                                    .font(.caption)
                                    .foregroundColor(.secondary)

                                    if let hospital = file.hospital, !hospital.isEmpty {
                                        Label(hospital, systemImage: "building.columns.fill")
                                            .font(.caption2)
                                            .foregroundColor(.secondary)
                                            .lineLimit(1)
                                    } else {
                                        Label("Kurum bilinmiyor", systemImage: "building.columns")
                                            .font(.caption2)
                                            .foregroundColor(.orange.opacity(0.8))
                                    }
                                }

                                Spacer()

                                if rescanningPath == file.url.absoluteString {
                                    ProgressView().controlSize(.small)
                                } else {
                                    Image(systemName: "chevron.right")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding(.vertical, 4)
                        }
                        .contextMenu {
                            Button {
                                editedHospital = file.hospital ?? ""
                                editingFilePath = file.url.absoluteString
                            } label: {
                                Label("Kurum Adını Düzenle", systemImage: "pencil")
                            }

                            Button {
                                rescanFile(url: file.url)
                            } label: {
                                Label("Kurum Adını Yeniden Tara", systemImage: "building.columns.badge.plus")
                            }

                            Button {
                                reanalyzeFile(url: file.url)
                            } label: {
                                Label("AI ile Yeniden Analiz Et", systemImage: "sparkles")
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("İçe Aktarılan Dosyalar")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .sheet(item: $selectedPDFURL) { url in
            NavigationStack {
                PDFViewer(path: url.absoluteString)
                    .navigationTitle(url.lastPathComponent)
                    #if os(iOS)
                    .navigationBarTitleDisplayMode(.inline)
                    #endif
            }
        }
        .alert("Kurum Adı", isPresented: Binding(
            get: { editingFilePath != nil },
            set: { if !$0 { editingFilePath = nil } }
        )) {
            TextField("Kurum adı girin", text: $editedHospital)
            Button("Kaydet") {
                if let path = editingFilePath {
                    updateHospitalName(for: path, newName: editedHospital.trimmingCharacters(in: .whitespaces))
                    editingFilePath = nil
                }
            }
            Button("İptal", role: .cancel) { editingFilePath = nil }
        } message: {
            Text("Bu dosyaya ait tüm sonuçların kurum adı güncellenecek.")
        }
    }

    /// Dosya adına göre (path-agnostic) tüm ilgili sonuçların kurum adını güncelle
    private func updateHospitalName(for path: String, newName: String) {
        let targetName = (path as NSString).lastPathComponent
        for result in labResults {
            guard let stored = result.originalPDFPath else { continue }
            let storedName = (stored as NSString).lastPathComponent
            if storedName == targetName || stored == path {
                result.hospital = newName.isEmpty ? nil : newName
            }
        }
    }

    /// Regex ile kurum adını yeniden tarat, bulunamazsa AI'a sor
    private func rescanFile(url: URL) {
        guard let data = try? Data(contentsOf: url) else { return }
        rescanningPath = url.absoluteString
        Task {
            let hospitalName = await LocalPDFExtractor.extractHospitalName(from: data)
            await MainActor.run {
                if let hospitalName {
                    updateHospitalName(for: url.absoluteString, newName: hospitalName)
                }
                rescanningPath = nil
            }
        }
    }

    /// PDF'i tekrar AI ile analiz et
    private func reanalyzeFile(url: URL) {
        rescanningPath = url.absoluteString
        Task {
            await MainActor.run {
                processor.reanalyzeFile(at: url, modelContext: modelContext)
                rescanningPath = nil
            }
        }
    }

    /// İşlenmemiş dosyayı diskten sil
    private func deleteUnprocessedFile(url: URL) {
        try? FileManager.default.removeItem(at: url)
    }
}

// URL already conforms to Identifiable via extension in BiosightApp.swift
