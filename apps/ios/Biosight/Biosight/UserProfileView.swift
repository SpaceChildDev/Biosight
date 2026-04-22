import SwiftUI
import SwiftData

struct UserProfileView: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("geminiAPIKey") private var geminiApiKey = ""
    @AppStorage("userTier") private var userTierRaw: String = "free"
    @AppStorage("iCloudBackupEnabled") private var iCloudBackupEnabled = true
    @AppStorage("notificationsEnabled") private var notificationsEnabled = true
    @AppStorage("easyMode") private var easyMode = false
    @AppStorage("healthKitAutoSyncEnabled") private var healthKitAutoSyncEnabled = false
    @AppStorage("activePersonID") private var activePersonID: String = ""

    private var syncService = HealthKitSyncService.shared

    @State private var showSubscription = false
    @State private var showPrivacy = false
    @State private var showFeedback = false
    @State private var showAPIKeyAlert = false
    @State private var showDeleteConfirm = false
    @State private var debugTier: String = UserDefaults.standard.string(forKey: "debugTierOverride") ?? "free"
    @State private var isTestingAPI = false
    @State private var apiTestResult: String?

    @Environment(\.modelContext) private var modelContext
    @Query private var labResults: [LabResult]

    private var tierName: String {
        switch userTierRaw {
        case "basic": return "Temel"
        case "premium": return "Premium"
        default: return "Ücretsiz"
        }
    }

    private var tierColor: Color {
        switch userTierRaw {
        case "basic": return .blue
        case "premium": return .purple
        default: return .gray
        }
    }

    private var isTestFlightOrDebug: Bool {
        #if DEBUG
        return true
        #else
        return Bundle.main.appStoreReceiptURL?.lastPathComponent == "sandboxReceipt"
        #endif
    }

    var body: some View {
        NavigationStack {
            List {
                // Profil Özeti
                Section {
                    HStack(spacing: 16) {
                        Image(systemName: "person.crop.circle.fill")
                            .font(.system(size: 48))
                            .foregroundStyle(.linearGradient(colors: [tierColor, tierColor.opacity(0.6)], startPoint: .top, endPoint: .bottom))
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Biosight Kullanıcısı")
                                .font(.headline)
                            HStack(spacing: 4) {
                                Text(tierName)
                                    .font(.caption.bold())
                                    .foregroundColor(.white)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 2)
                                    .background(tierColor)
                                    .cornerRadius(4)
                                Text("\(labResults.count) kayıt")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                        }
                    }
                    .padding(.vertical, 4)
                }

                // Abonelik
                Section("Abonelik") {
                    Button {
                        showSubscription = true
                    } label: {
                        HStack {
                            Label("Planını Yönet", systemImage: "crown.fill")
                                .foregroundColor(.primary)
                            Spacer()
                            Text(tierName)
                                .font(.caption.bold())
                                .foregroundColor(tierColor)
                        }
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        HStack {
                            Label("Günlük AI Kullanımı", systemImage: "sparkles")
                                .font(.subheadline)
                            Spacer()
                            Text("\(SubscriptionService.shared.remainingAIUsage) kaldı")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        
                        let total = SubscriptionService.shared.currentTierLimit
                        let remaining = SubscriptionService.shared.remainingAIUsage
                        let used = total - remaining
                        
                        ProgressView(value: Double(used), total: Double(total))
                            .tint(tierColor)
                            .scaleEffect(x: 1, y: 1.5, anchor: .center)
                        
                        HStack {
                            Text("0")
                            Spacer()
                            Text("\(total)")
                        }
                        .font(.system(size: 8))
                        .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }

                // API Ayarları
                Section("AI Ayarları") {
                    Button {
                        showAPIKeyAlert = true
                    } label: {
                        HStack {
                            Label("Gemini API Anahtarı", systemImage: "key.fill")
                                .foregroundColor(.primary)
                            Spacer()
                            Circle()
                                .fill(AIServiceFactory.hasAvailableKey ? .green : .red)
                                .frame(width: 8, height: 8)
                        }
                    }
                }

                // Yedekleme
                Section("Veri Yönetimi") {
                    NavigationLink {
                        ImportedFilesView()
                    } label: {
                        Label("İçe Aktarılan Dosyalar", systemImage: "doc.on.doc.fill")
                    }

                    Toggle(isOn: $iCloudBackupEnabled) {
                        Label("iCloud Yedekleme", systemImage: "icloud.fill")
                    }

                    HStack {
                        Label("Toplam Kayıt", systemImage: "list.clipboard.fill")
                        Spacer()
                        Text("\(labResults.count)")
                            .foregroundColor(.secondary)
                    }

                    Button(role: .destructive) {
                        showDeleteConfirm = true
                    } label: {
                        Label("Tüm Verileri Sil", systemImage: "trash.fill")
                            .foregroundColor(.red)
                    }
                }

                // Apple Health Senkronizasyon
                if HealthKitService.isAvailable {
                    Section("Apple Health") {
                        Toggle(isOn: $healthKitAutoSyncEnabled) {
                            Label("Otomatik Senkronizasyon", systemImage: "heart.circle.fill")
                        }

                        if healthKitAutoSyncEnabled {
                            if syncService.isSyncing {
                                HStack(spacing: 10) {
                                    ProgressView().controlSize(.small)
                                    Text("Senkronize ediliyor...")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            } else {
                                HStack {
                                    Label("Son Senkronizasyon", systemImage: "clock.fill")
                                        .font(.subheadline)
                                    Spacer()
                                    if let last = syncService.lastSyncDate {
                                        Text(last, style: .relative)
                                            .font(.caption)
                                            .foregroundColor(.secondary)
                                    } else {
                                        Text("Henüz yapılmadı")
                                            .font(.caption)
                                            .foregroundColor(.orange)
                                    }
                                }

                                if syncService.lastSyncChangedCount > 0 {
                                    Text("Son senkronizasyonda \(syncService.lastSyncChangedCount) kayıt güncellendi.")
                                        .font(.caption2)
                                        .foregroundColor(.secondary)
                                }

                                Button {
                                    Task { @MainActor in
                                        await syncService.sync(
                                            modelContainer: modelContext.container,
                                            personID: activePersonID.isEmpty ? nil : activePersonID
                                        )
                                    }
                                } label: {
                                    Label("Şimdi Senkronize Et", systemImage: "arrow.clockwise")
                                }
                                .disabled(syncService.isSyncing)
                            }
                        }
                    }
                }

                // Görünüm
                Section("Görünüm") {
                    Toggle(isOn: $easyMode) {
                        Label("Kolay Mod", systemImage: "hand.thumbsup.fill")
                    }
                    if easyMode {
                        Text("Büyük butonlar ve sade ekran aktif.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }

                // Bildirimler
                Section("Bildirimler") {
                    Toggle(isOn: $notificationsEnabled) {
                        Label("Hatırlatıcılar", systemImage: "bell.fill")
                    }
                }

                // Gizlilik & Yasal
                Section("Gizlilik & Yasal") {
                    NavigationLink {
                        SourcesView()
                    } label: {
                        Label("Kaynaklar", systemImage: "book.closed.fill")
                    }

                    Button {
                        showPrivacy = true
                    } label: {
                        Label("Gizlilik Politikası", systemImage: "hand.raised.fill")
                            .foregroundColor(.primary)
                    }

                    NavigationLink {
                        DisclaimerView()
                    } label: {
                        Label("Kullanım Koşulları", systemImage: "doc.text.fill")
                    }

                    HStack {
                        Label("Versiyon", systemImage: "info.circle.fill")
                        Spacer()
                        Text("1.0.0")
                            .foregroundColor(.secondary)
                    }

                    Button {
                        showFeedback = true
                    } label: {
                        Label("Geri Bildirim", systemImage: "quote.bubble.fill")
                            .foregroundColor(.primary)
                    }
                }

                // Geliştirici Test Modu
                if isTestFlightOrDebug {
                Section("Geliştirici") {
                    Picker("Test Tier", selection: $debugTier) {
                        Text("Ücretsiz").tag("free")
                        Text("Temel").tag("basic")
                        Text("Premium").tag("premium")
                    }
                    .onChange(of: debugTier) { _, newValue in
                        UserDefaults.standard.set(newValue, forKey: "debugTierOverride")
                        userTierRaw = newValue
                    }

                    Button("API Anahtarını Test Et") {
                        Task {
                            isTestingAPI = true
                            apiTestResult = nil
                            let service = AIServiceFactory.create()
                            let valid = await service.validateAPIKey()
                            apiTestResult = valid ? "API anahtarı geçerli" : "API anahtarı geçersiz veya kotası dolmuş"
                            isTestingAPI = false
                        }
                    }
                    .disabled(isTestingAPI)

                    if isTestingAPI {
                        HStack {
                            ProgressView()
                            Text("Test ediliyor...")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                    }

                    if let apiTestResult {
                        Text(apiTestResult)
                            .font(.caption)
                            .foregroundColor(apiTestResult.contains("geçerli") && !apiTestResult.contains("geçersiz") ? .green : .red)
                    }
                }
                } // isTestFlightOrDebug

                // Gizlilik Notu
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Verileriniz Güvende", systemImage: "lock.shield.fill")
                            .font(.subheadline.bold())
                            .foregroundColor(.green)
                        Text("Sağlık verileriniz cihazınızda ve iCloud hesabınızda saklanır. AI analizi kullandığınızda tahlil değerleriniz analiz için Google Gemini sunucularına gönderilir. AI kullanımı tamamen isteğe bağlıdır.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding(.vertical, 4)
                }
            }
            .navigationTitle("Profil")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Kapat") { dismiss() }
                }
            }
            .sheet(isPresented: $showSubscription) {
                SubscriptionView()
            }
            .sheet(isPresented: $showPrivacy) {
                PrivacyPolicyView()
            }
            .sheet(isPresented: $showFeedback) {
                FeedbackView()
            }
            .alert("Gemini API Anahtarı", isPresented: $showAPIKeyAlert) {
                TextField("Gemini API Key", text: $geminiApiKey)
                Button("Tamam") {}
            } message: {
                Text("Google AI Studio'dan alınan Gemini API anahtarınızı girin.")
            }
            .alert("Tüm Verileri Sil", isPresented: $showDeleteConfirm) {
                Button("Sil", role: .destructive) { deleteAllData() }
                Button("Vazgeç", role: .cancel) {}
            } message: {
                Text("Tüm tahlil sonuçlarınız kalıcı olarak silinecek. Bu işlem geri alınamaz.")
            }
        }
    }

    private func deleteAllData() {
        for result in labResults {
            modelContext.delete(result)
        }
    }
}

// MARK: - Disclaimer View

struct DisclaimerView: View {
    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                Group {
                    Text("Kullanım Koşulları")
                        .font(.title2.bold())

                    Text("Son Güncelleme: Nisan 2026")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    disclaimerSection(
                        title: "Uygulama Amacı",
                        content: "Biosight, sağlık verilerinizi takip etmenize yardımcı olan bir yazılımdır. Tıbbi teşhis, tedavi veya tavsiye amaçlı kullanılamaz. Herhangi bir sağlık kararı almadan önce doktorunuza danışın."
                    )

                    disclaimerSection(
                        title: "AI Analizleri Hakkında",
                        content: "AI analizi isteğe bağlıdır. Kullandığınızda tahlil değerleriniz analiz için Google Gemini servisine gönderilir. AI yorumları yalnızca bilgilendirme amaçlıdır ve profesyonel sağlık değerlendirmesinin yerini almaz."
                    )

                    disclaimerSection(
                        title: "Referans Değerler",
                        content: "Gösterilen referans aralıkları genel yetişkin değerlerini temsil eder. Yaş, cinsiyet, hamilelik durumu ve laboratuvar yöntemine göre farklılık gösterebilir. Doktorunuzun belirlediği referans değerler önceliklidir."
                    )

                    disclaimerSection(
                        title: "Veri Gizliliği",
                        content: "Verileriniz cihazınızda ve iCloud hesabınızda saklanır. Biosight'in kendine ait sunucusu yoktur. AI analizi kullanıldığında yalnızca tahlil değerleri ilgili AI servisine gönderilir; kişisel bilgileriniz (ad, doğum tarihi vb.) gönderilmez."
                    )

                    disclaimerSection(
                        title: "Sorumluluk",
                        content: "Biosight, uygulama içindeki bilgilere dayanarak alınan kararlardan sorumlu tutulamaz. Kullanıcı, uygulamayı kullanarak bu koşulları kabul etmiş sayılır."
                    )
                }
            }
            .padding()
        }
        .navigationTitle("Kullanım Koşulları")
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
    }

    private func disclaimerSection(title: String, content: String) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.headline)
            Text(content)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }
}
