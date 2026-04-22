import SwiftUI
import SwiftData

@main
struct BiosightApp: App {
    var sharedModelContainer: ModelContainer = {
        let schema = Schema([
            Person.self,
            LabResult.self,
        ])

        do {
            let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
            return try ModelContainer(for: schema, configurations: [modelConfiguration])
        } catch {
            // Eski şema uyumsuzsa veritabanını sıfırla
            let urls = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
            if let appSupportURL = urls.first {
                let storeURL = appSupportURL.appendingPathComponent("default.store")
                try? FileManager.default.removeItem(at: storeURL)
                // .store-shm ve .store-wal dosyalarını da temizle
                try? FileManager.default.removeItem(at: appSupportURL.appendingPathComponent("default.store-shm"))
                try? FileManager.default.removeItem(at: appSupportURL.appendingPathComponent("default.store-wal"))
            }
            do {
                let modelConfiguration = ModelConfiguration(schema: schema, isStoredInMemoryOnly: false)
                return try ModelContainer(for: schema, configurations: [modelConfiguration])
            } catch {
                // Kalıcı depolama da başarısız — geçici bellek içi depolama ile devam et
                let memConfig = ModelConfiguration(schema: schema, isStoredInMemoryOnly: true)
                return try! ModelContainer(for: schema, configurations: [memConfig])
            }
        }
    }()

    @State private var sharedURL: URL?
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("easyMode") private var easyMode = false
    @AppStorage("healthKitAutoSyncEnabled") private var healthKitAutoSyncEnabled = false
    @AppStorage("activePersonID") private var activePersonID: String = ""
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            if !hasCompletedOnboarding {
                OnboardingView()
            } else if easyMode {
                EasyModeHomeView()
                    .onOpenURL { url in
                        sharedURL = url
                    }
                    .sheet(item: $sharedURL) { url in
                        SharedFileImportView(url: url)
                    }
            } else {
                ContentView()
                    .onOpenURL { url in
                        sharedURL = url
                    }
                    .sheet(item: $sharedURL) { url in
                        SharedFileImportView(url: url)
                    }
            }
        }
        .modelContainer(sharedModelContainer)
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active && healthKitAutoSyncEnabled {
                Task { @MainActor in
                    await HealthKitSyncService.shared.sync(
                        modelContainer: sharedModelContainer,
                        personID: activePersonID.isEmpty ? nil : activePersonID
                    )
                }
            }
        }
    }
}

extension URL: @retroactive Identifiable {
    public var id: String { absoluteString }
}
