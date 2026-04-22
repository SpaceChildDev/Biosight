import SwiftUI
import StoreKit

struct SubscriptionView: View {
    @Environment(\.dismiss) private var dismiss
    private var subscriptionService = SubscriptionService.shared
    @State private var selectedPlan: String?
    @State private var isYearly = false
    @State private var errorMessage: String?
    @State private var isPurchasing = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // Header
                    VStack(spacing: 8) {
                        Image(systemName: "heart.circle.fill")
                            .font(.system(size: 56))
                            .foregroundStyle(.linearGradient(colors: [.blue, .purple], startPoint: .topLeading, endPoint: .bottomTrailing))
                        Text("Biosight Pro")
                            .font(.title.bold())
                        Text("Sağlığınızı daha iyi takip edin")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    .padding(.top, 12)

                    // Aylık/Yıllık toggle
                    Picker("Periyot", selection: $isYearly) {
                        Text("Aylık").tag(false)
                        HStack {
                            Text("Yıllık")
                            Text("-15%")
                                .font(.caption2.bold())
                                .foregroundColor(.green)
                        }.tag(true)
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal)

                    // Plan kartları
                    VStack(spacing: 16) {
                        planCard(
                            name: "Ücretsiz",
                            price: "0 TL",
                            period: "",
                            features: [
                                "Günde 3 AI analiz",
                                "Haftada 1 özet rapor",
                                "PDF ve kamera tarama",
                                "Apple Health entegrasyonu",
                                "Değer hakkında bilgiler"
                            ],
                            tier: "free",
                            isCurrent: subscriptionService.currentTier == .free,
                            color: .gray
                        )

                        planCard(
                            name: "Temel",
                            price: isYearly ? "295 TL/yıl" : "29 TL/ay",
                            period: isYearly ? "(~24.5 TL/ay)" : "",
                            features: [
                                "Günde 15 AI analiz",
                                "3 günde 1 özet rapor",
                                "Sınırsız PDF/tarama",
                                "Detaylı değer bilgileri",
                                "Trend analizi"
                            ],
                            tier: "basic",
                            isCurrent: subscriptionService.currentTier == .basic,
                            color: .blue
                        )

                        planCard(
                            name: "Premium",
                            price: isYearly ? "1.009 TL/yıl" : "99 TL/ay",
                            period: isYearly ? "(~84 TL/ay)" : "",
                            features: [
                                "Günde 50 AI analiz",
                                "Sınırsız özet rapor",
                                "Gemini 2.5 Pro ile detaylı analiz",
                                "Değerler arası ilişki analizi",
                                "Kişiselleştirilmiş beslenme önerileri",
                                "Trend ve takip önerileri",
                                "Öncelikli destek"
                            ],
                            tier: "premium",
                            isCurrent: subscriptionService.currentTier == .premium,
                            color: .purple,
                            isPopular: true
                        )
                    }
                    .padding(.horizontal)

                    if subscriptionService.isLoading {
                        ProgressView("Ürünler yükleniyor...")
                            .font(.caption)
                    }

                    if let errorMessage {
                        Text(errorMessage)
                            .font(.caption)
                            .foregroundColor(.red)
                    }

                    // Satın al butonu
                    if let selectedPlan, selectedPlan != "free" {
                        Button {
                            Task { await purchaseSelected() }
                        } label: {
                            if isPurchasing {
                                ProgressView()
                                    .frame(maxWidth: .infinity)
                            } else {
                                Text("Abone Ol")
                                    .font(.headline)
                                    .frame(maxWidth: .infinity)
                            }
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(selectedPlan == "premium" ? .purple : .blue)
                        .controlSize(.large)
                        .padding(.horizontal)
                        .disabled(isPurchasing)
                    }

                    // Restore + Legal
                    VStack(spacing: 8) {
                        Button("Satın Alımları Geri Yükle") {
                            Task { await subscriptionService.restorePurchases() }
                        }
                        .font(.caption)

                        Text("Abonelik otomatik yenilenir. Ayarlar > Apple ID > Abonelikler'den istediğiniz zaman iptal edebilirsiniz.")
                            .font(.caption2)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }
                    .padding(.bottom, 20)
                }
            }
            .navigationTitle("Abonelik")
            #if os(iOS)
            .navigationBarTitleDisplayMode(.inline)
            #endif
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Kapat") { dismiss() }
                }
            }
            .task {
                if subscriptionService.products.isEmpty {
                    await subscriptionService.loadProducts()
                }
            }
        }
    }

    private func planCard(name: String, price: String, period: String, features: [String], tier: String, isCurrent: Bool, color: Color, isPopular: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text(name)
                    .font(.title3.bold())
                Spacer()
                if isPopular {
                    Text("Popüler")
                        .font(.caption2.bold())
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(color)
                        .cornerRadius(4)
                }
                if isCurrent {
                    Text("Mevcut")
                        .font(.caption2.bold())
                        .foregroundColor(.white)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 3)
                        .background(.green)
                        .cornerRadius(4)
                }
            }

            HStack(alignment: .firstTextBaseline, spacing: 4) {
                Text(price)
                    .font(.title2.bold())
                    .foregroundColor(color)
                if !period.isEmpty {
                    Text(period)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            ForEach(features, id: \.self) { feature in
                HStack(spacing: 8) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(color)
                        .font(.caption)
                    Text(feature)
                        .font(.subheadline)
                }
            }
        }
        .padding()
        .background(selectedPlan == tier ? color.opacity(0.1) : Color(.systemBackground))
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(selectedPlan == tier ? color : Color.secondary.opacity(0.2), lineWidth: selectedPlan == tier ? 2 : 1)
        )
        .cornerRadius(12)
        .onTapGesture {
            if !isCurrent {
                selectedPlan = tier
            }
        }
    }

    private func purchaseSelected() async {
        guard let selectedPlan else { return }
        isPurchasing = true
        errorMessage = nil

        let productID: String
        switch (selectedPlan, isYearly) {
        case ("basic", false): productID = SubscriptionService.basicMonthlyID
        case ("basic", true): productID = SubscriptionService.basicYearlyID
        case ("premium", false): productID = SubscriptionService.premiumMonthlyID
        case ("premium", true): productID = SubscriptionService.premiumYearlyID
        default:
            isPurchasing = false
            return
        }

        // Ürünler henüz yüklenmediyse tekrar yükle
        if subscriptionService.products.isEmpty {
            await subscriptionService.loadProducts()
        }

        guard let product = subscriptionService.products.first(where: { $0.id == productID }) else {
            errorMessage = "Ürün bulunamadı. Gerçek cihazda test ediyorsanız App Store Connect'te ürünlerin tanımlı olduğundan emin olun. Simülatörde StoreKit Configuration dosyasının scheme'e bağlı olduğunu kontrol edin."
            isPurchasing = false
            return
        }

        do {
            _ = try await subscriptionService.purchase(product)
        } catch {
            errorMessage = "Satın alma başarısız: \(error.localizedDescription)"
        }
        isPurchasing = false
    }
}
