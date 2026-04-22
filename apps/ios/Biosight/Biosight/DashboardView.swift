import SwiftUI
import SwiftData

struct DashboardView: View {
    @Query(sort: \LabResult.date, order: .reverse) private var allLabResults: [LabResult]
    @Query private var profiles: [Person]
    @AppStorage("activePersonID") private var activePersonID: String = ""
    @AppStorage("geminiAPIKey") private var apiKey = ""
    @AppStorage("lastAISummaryDate") private var lastAISummaryDate: Double = 0
    @AppStorage("cachedAISummary") private var cachedAISummary: String = ""
    @AppStorage("userTier") private var userTierRaw: String = "free"

    @State private var isLoadingSummary = false

    private var activePerson: Person? {
        profiles.first { $0.id.uuidString == activePersonID }
    }

    private var labResults: [LabResult] {
        guard let person = activePerson else { return allLabResults }
        return allLabResults.filter { $0.person == nil || $0.person?.id == person.id }
    }

    private var userTier: AnalysisTier {
        switch userTierRaw {
        case "basic": return .basic
        case "premium": return .premium
        default: return .free
        }
    }

    private var summaryLimitDays: Int {
        switch userTier {
        case .free: return 7
        case .basic: return 3
        case .premium: return 0  // Sınırsız
        }
    }

    private var followUpResults: [LabResult] {
        labResults.filter { $0.isAbnormal }
    }

    private var categoryCount: Int {
        Set(labResults.map { $0.category }).count
    }

    private var healthScore: Int {
        guard !labResults.isEmpty else { return 100 }
        let followUpRatio = Double(followUpResults.count) / Double(labResults.count)
        return max(0, Int((1.0 - followUpRatio) * 100))
    }

    private var healthScoreMessage: String {
        if healthScore >= 90 { return "Harika gidiyorsunuz!" }
        if healthScore >= 70 { return "Genel durumunuz iyi görünüyor." }
        if healthScore >= 50 { return "Bazı değerleri takip etmenizde fayda var." }
        return "Doktorunuzla görüşerek değerlerinizi değerlendirin."
    }

    private var canGenerateSummary: Bool {
        if summaryLimitDays == 0 { return true }  // Premium: sınırsız
        let lastDate = Date(timeIntervalSince1970: lastAISummaryDate)
        let daysSince = Calendar.current.dateComponents([.day], from: lastDate, to: .now).day ?? 999
        return daysSince >= summaryLimitDays
    }

    private var nextSummaryDate: String {
        if summaryLimitDays == 0 { return "" }
        let lastDate = Date(timeIntervalSince1970: lastAISummaryDate)
        guard let nextDate = Calendar.current.date(byAdding: .day, value: summaryLimitDays, to: lastDate) else { return "" }
        return nextDate.formatted(date: .abbreviated, time: .omitted)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Sağlık Skoru
                healthScoreCard

                // İstatistik Kartları
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 12) {
                    StatCard(title: "Toplam Sonuç", value: "\(labResults.count)", icon: "list.clipboard.fill", color: .blue)
                    StatCard(title: "İzleme", value: "\(followUpResults.count)", icon: "info.circle.fill", color: .orange)
                    StatCard(title: "Kategori", value: "\(categoryCount)", icon: "folder.fill", color: .green)
                }

                // AI Haftalık Özet
                if !labResults.isEmpty {
                    aiSummaryCard
                }

                // Takip Edilmesi Gereken Değerler
                if !followUpResults.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Referans Dışı Değerler", systemImage: "info.circle.fill")
                            .font(.title3.bold())
                            .foregroundColor(.orange)

                        Text("Bu değerler referans aralığı dışında. Egzersiz, stres veya geçici faktörler bunları etkileyebilir. Gerekirse doktorunuzla değerlendirin.")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        LazyVGrid(columns: [
                            GridItem(.flexible()),
                            GridItem(.flexible())
                        ], spacing: 12) {
                            ForEach(followUpResults.prefix(6)) { result in
                                FollowUpCard(result: result)
                            }
                        }
                    }
                }

                // Son Eklenen Tahliller
                if !labResults.isEmpty {
                    VStack(alignment: .leading, spacing: 12) {
                        Label("Son Eklenenler", systemImage: "clock.fill")
                            .font(.title3.bold())

                        ForEach(labResults.prefix(5)) { result in
                            RecentResultRow(result: result)
                        }
                    }
                }
            }
            .padding()
        }
        .navigationTitle("Özet Paneli")
    }

    private var healthScoreCard: some View {
        VStack(spacing: 8) {
            Text("Sağlık Durumu")
                .font(.headline)
                .foregroundColor(.secondary)
            Text("\(healthScore)")
                .font(.system(size: 56, weight: .bold, design: .rounded))
                .foregroundColor(healthScore >= 80 ? .green : healthScore >= 50 ? .orange : .blue)
            Text("/ 100")
                .font(.subheadline)
                .foregroundColor(.secondary)
            Text(healthScoreMessage)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 16)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(.ultraThinMaterial)
        .cornerRadius(16)
    }

    // MARK: - AI Summary Card

    private var aiSummaryCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Label("AI Sağlık Özeti", systemImage: "wand.and.stars")
                    .font(.title3.bold())
                Spacer()
                if !cachedAISummary.isEmpty {
                    Text("Haftalık")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 2)
                        .background(.ultraThinMaterial)
                        .cornerRadius(4)
                }
            }

            if !cachedAISummary.isEmpty {
                Text(cachedAISummary)
                    .font(.subheadline)
                    .foregroundColor(.secondary)

                Text("Bu yorum bilgilendirme amaçlıdır, tıbbi tavsiye değildir. Doktorunuza danışın.")
                    .font(.caption2)
                    .foregroundColor(.orange)
                    .italic()

                // Kaynak politikası
                HStack(spacing: 4) {
                    Image(systemName: "checkmark.shield.fill")
                        .foregroundColor(.green)
                    Text("Kaynaklar: PubMed, NCBI, WHO, UpToDate, Harrison's, Merck Manual, Mayo Clinic, MedlinePlus")
                        .foregroundColor(.secondary)
                }
                .font(.caption2)
            }

            if canGenerateSummary {
                Button {
                    generateWeeklySummary()
                } label: {
                    if isLoadingSummary {
                        HStack {
                            ProgressView()
                                .controlSize(.small)
                            Text(userTier == .premium ? "Detaylı analiz hazırlanıyor..." : "Özet hazırlanıyor...")
                                .font(.subheadline)
                        }
                        .frame(maxWidth: .infinity)
                    } else {
                        HStack {
                            Image(systemName: userTier == .premium ? "crown.fill" : "sparkles")
                            Text(userTier == .premium ? "Detaylı AI Analiz" : (cachedAISummary.isEmpty ? "Haftalık Özet Oluştur" : "Yeni Özet Oluştur"))
                        }
                        .font(.subheadline)
                        .frame(maxWidth: .infinity)
                    }
                }
                .buttonStyle(.borderedProminent)
                .tint(userTier == .premium ? .purple : .accentColor)
                .controlSize(.small)
                .disabled(isLoadingSummary || !AIServiceFactory.hasAvailableKey)
            } else {
                Text("Sonraki özet: \(nextSummaryDate)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            if userTier == .free {
                Text("Premium ile sınırsız detaylı AI analiz alın")
                    .font(.caption2)
                    .foregroundColor(.purple)
            }
        }
        .padding()
        .background(.ultraThinMaterial)
        .cornerRadius(12)
    }

    private func generateWeeklySummary() {
        isLoadingSummary = true
        // Premium: tüm veriler, diğerleri: son 30
        let limit = userTier == .premium ? labResults.count : 30
        let summary = labResults.prefix(limit).map { result in
            "\(result.valueName): \(result.value) \(result.unit) (Ref: \(result.referenceRange))\(result.isAbnormal ? " [İZLEME]" : "") [\(result.category)] \(result.date.formatted(date: .abbreviated, time: .omitted))"
        }.joined(separator: "\n")

        Task {
            do {
                let service = AIServiceFactory.create(tier: userTier)
                let analysis = try await service.analyzeHealthSummary(summary: summary)
                await MainActor.run {
                    cachedAISummary = analysis
                    lastAISummaryDate = Date.now.timeIntervalSince1970
                    isLoadingSummary = false
                }
            } catch {
                await MainActor.run {
                    isLoadingSummary = false
                }
            }
        }
    }
}

// MARK: - Alt Bileşenler

struct StatCard: View {
    let title: String
    let value: String
    let icon: String
    let color: Color

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(color)
            Text(value)
                .font(.title.bold())
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding()
        .background(color.opacity(0.1))
        .cornerRadius(12)
    }
}

struct FollowUpCard: View {
    let result: LabResult

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            HStack {
                CategoryIconView(category: result.category, size: 16)
                Spacer()
                Text(result.category)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            Text(result.valueName)
                .font(.subheadline.bold())
            HStack {
                Text("\(result.value) \(result.unit)")
                    .font(.caption)
                    .foregroundColor(.orange)
                Spacer()
                Text("Ref: \(result.referenceRange)")
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(10)
        .background(Color.orange.opacity(0.08))
        .cornerRadius(10)
    }
}

struct RecentResultRow: View {
    let result: LabResult

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text(result.valueName)
                    .font(.headline)
                Text("\(result.category) · \(result.type)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text("\(result.value) \(result.unit)")
                    .font(.subheadline)
                    .foregroundColor(result.isAbnormal ? .orange : .primary)
                Text(result.date.formatted(date: .abbreviated, time: .omitted))
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
        }
        .padding(.vertical, 6)
    }
}
