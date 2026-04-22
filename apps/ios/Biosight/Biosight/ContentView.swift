import SwiftUI
import SwiftData

struct ContentView: View {
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \LabResult.date, order: .reverse) private var labResults: [LabResult]
    @Query(sort: \Person.createdAt) private var profiles: [Person]
    @AppStorage("activePersonID") private var activePersonID: String = ""

    @State private var selectedCategory: String?
    @State private var selectedResult: LabResult?
    @State private var showAddResult = false
    @State private var showPDFUpload = false
    @State private var showScanDocument = false
    @State private var showHealthImport = false
    @State private var showProfile = false
    @State private var showProfileManagement = false

    private var activePerson: Person? {
        profiles.first { $0.id.uuidString == activePersonID }
    }

    /// Aktif profile ait sonuçlar (profil atanmamışlar da dahil)
    private var activeResults: [LabResult] {
        guard let person = activePerson else { return labResults }
        return labResults.filter { $0.person == nil || $0.person?.id == person.id }
    }

    private var categories: [String] {
        Array(Set(activeResults.map { $0.category })).sorted()
    }

    var body: some View {
        NavigationSplitView {
            List(selection: $selectedCategory) {
                NavigationLink(value: "Dashboard") {
                    Label("Özet Paneli", systemImage: "heart.text.square.fill")
                }

                NavigationLink(value: "AllResults") {
                    Label("Tahlil", systemImage: "tray.full.fill")
                }

                Section("Kategoriler") {
                    if categories.isEmpty {
                        Text("Henüz veri yok")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    ForEach(categories, id: \.self) { category in
                        NavigationLink(value: category) {
                            HStack(spacing: 10) {
                                CategoryIconView(category: category, size: 20)
                                Text(category)
                            }
                        }
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                if BackgroundPDFProcessor.shared.hasActiveJobs {
                    ProcessingBanner()
                }
            }
            .navigationTitle("Biosight")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Menu {
                        // Profil seçimi
                        ForEach(profiles) { profile in
                            Button {
                                activePersonID = profile.id.uuidString
                            } label: {
                                HStack {
                                    Text(profile.name)
                                    if profile.id.uuidString == activePersonID {
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                        Divider()
                        Button {
                            showProfileManagement = true
                        } label: {
                            Label("Profil Yönetimi", systemImage: "person.2.fill")
                        }
                        Button {
                            showProfile = true
                        } label: {
                            Label("Ayarlar", systemImage: "gearshape.fill")
                        }
                    } label: {
                        HStack(spacing: 4) {
                            ProfileIconView(iconName: activePerson?.avatarEmoji ?? "hi-man", size: 24)
                                .foregroundColor(.accentColor)
                            Image(systemName: "chevron.down")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                    }
                }
                ToolbarItem {
                    Menu {
                        Button {
                            showHealthImport = true
                        } label: {
                            Label("Apple Health", systemImage: "heart.fill")
                        }
                        Button {
                            showScanDocument = true
                        } label: {
                            Label("Tahlil Tara (Kamera)", systemImage: "camera.viewfinder")
                        }
                        Button {
                            showPDFUpload = true
                        } label: {
                            Label("Tahlil Yükle", systemImage: "doc.badge.plus")
                        }
                        Button {
                            showAddResult = true
                        } label: {
                            Label("Manuel Giriş", systemImage: "square.and.pencil")
                        }
                    } label: {
                        Label("Ekle", systemImage: "plus")
                    }
                }
            }
        } content: {
            if let category = selectedCategory {
                if category == "Dashboard" {
                    DashboardView()
                } else if category == "AllResults" {
                    AllResultsView()
                } else {
                    CategoryResultListView(category: category, selectedResult: $selectedResult)
                }
            } else {
                ContentUnavailableView(
                    "Biosight",
                    systemImage: "heart.text.square",
                    description: Text("Soldan bir kategori seçin veya yeni sonuç ekleyin.")
                )
            }
        } detail: {
            if let result = selectedResult {
                DetailView(result: result)
            } else {
                ContentUnavailableView(
                    "Detay",
                    systemImage: "doc.text.magnifyingglass",
                    description: Text("Detayları görmek için bir sonuç seçin.")
                )
            }
        }
        .sheet(isPresented: $showAddResult) {
            AddResultView()
        }
        .sheet(isPresented: $showPDFUpload) {
            PDFUploadView()
        }
        .sheet(isPresented: $showScanDocument) {
            ScanDocumentView()
        }
        .sheet(isPresented: $showHealthImport) {
            HealthImportView()
        }
        .sheet(isPresented: $showProfile) {
            UserProfileView()
        }
        .sheet(isPresented: $showProfileManagement) {
            ProfileManagementView()
        }
        .onChange(of: showPDFUpload) { old, new in
            if old && !new { selectedCategory = "AllResults" }
        }
        .onChange(of: showScanDocument) { old, new in
            if old && !new { selectedCategory = "AllResults" }
        }
        .onChange(of: showAddResult) { old, new in
            if old && !new { selectedCategory = "AllResults" }
        }
        .onAppear {
            ensureDefaultProfile()
        }
    }

    private func ensureDefaultProfile() {
        if profiles.isEmpty {
            let person = Person(name: "Ben", avatarEmoji: "hi-man")
            modelContext.insert(person)
            activePersonID = person.id.uuidString
        } else if activePersonID.isEmpty {
            activePersonID = profiles.first?.id.uuidString ?? ""
        }
    }
}

// MARK: - Processing Banner

struct ProcessingBanner: View {
    private var processor: BackgroundPDFProcessor { .shared }

    var body: some View {
        HStack(spacing: 10) {
            ProgressView()
                .controlSize(.small)

            VStack(alignment: .leading, spacing: 2) {
                Text("\(processor.activeJobCount) PDF analiz ediliyor...")
                    .font(.caption.bold())
                if let current = processor.jobs.first(where: { $0.status == .processing }) {
                    Text(current.fileName)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .lineLimit(1)
                }
            }

            Spacer()

            let failed = processor.jobs.filter { $0.status == .failed }.count
            if failed > 0 {
                Text("\(failed) hata")
                    .font(.caption2.bold())
                    .foregroundColor(.red)
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .background(.ultraThinMaterial)
    }
}

#Preview {
    ContentView()
        .modelContainer(for: [Person.self, LabResult.self], inMemory: true)
}
