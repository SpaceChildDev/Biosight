import Foundation
import StoreKit
import OSLog

@MainActor
@Observable
class SubscriptionService {
    static let shared = SubscriptionService()

    // StoreKit 2 Product IDs
    static let basicMonthlyID = "dev.spacechild.biosight.basic.monthly"
    static let basicYearlyID = "dev.spacechild.biosight.basic.yearly"
    static let premiumMonthlyID = "dev.spacechild.biosight.premium.monthly"
    static let premiumYearlyID = "dev.spacechild.biosight.premium.yearly"

    var products: [Product] = []
    var purchasedProductIDs: Set<String> = []
    var isLoading = false

    private let logger = Logger(subsystem: "dev.spacechild.biosight", category: "Subscription")

    /// Debug veya TestFlight build'lerinde manuel tier override'a izin verir
    private var isOverrideEnabled: Bool {
        #if DEBUG
        return true
        #else
        return Bundle.main.appStoreReceiptURL?.lastPathComponent == "sandboxReceipt"
        #endif
    }

    var currentTier: AnalysisTier {
        if isOverrideEnabled {
            switch UserDefaults.standard.string(forKey: "debugTierOverride") ?? "" {
            case "premium": return .premium
            case "basic": return .basic
            default: break
            }
        }

        if purchasedProductIDs.contains(Self.premiumMonthlyID) || purchasedProductIDs.contains(Self.premiumYearlyID) {
            return .premium
        }
        if purchasedProductIDs.contains(Self.basicMonthlyID) || purchasedProductIDs.contains(Self.basicYearlyID) {
            return .basic
        }
        return .free
    }

    var currentTierRaw: String {
        switch currentTier {
        case .free: return "free"
        case .basic: return "basic"
        case .premium: return "premium"
        }
    }

    @ObservationIgnored
    private nonisolated(unsafe) var updateListenerTask: Task<Void, Error>?

    init() {
        updateListenerTask = listenForTransactions()
        Task { await loadProducts() }
        Task { await updatePurchasedProducts() }
    }

    deinit {
        updateListenerTask?.cancel()
    }

    func loadProducts() async {
        isLoading = true
        do {
            let productIDs: Set<String> = [
                Self.basicMonthlyID, Self.basicYearlyID,
                Self.premiumMonthlyID, Self.premiumYearlyID
            ]
            products = try await Product.products(for: productIDs)
                .sorted { $0.price < $1.price }
        } catch {
            logger.error("Ürünler yüklenemedi: \(error)")
        }
        isLoading = false
    }

    func purchase(_ product: Product) async throws -> StoreKit.Transaction? {
        let result = try await product.purchase()
        switch result {
        case .success(let verification):
            let transaction = try checkVerified(verification)
            await updatePurchasedProducts()
            await transaction.finish()
            return transaction
        case .userCancelled:
            return nil
        case .pending:
            return nil
        @unknown default:
            return nil
        }
    }

    func restorePurchases() async {
        try? await AppStore.sync()
        await updatePurchasedProducts()
    }

    // MARK: - AI Usage Limits

    func canUseAI() -> Bool {
        let today = Calendar.current.startOfDay(for: .now)
        let lastResetDate = UserDefaults.standard.object(forKey: "aiUsageResetDate") as? Date ?? .distantPast
        var count = UserDefaults.standard.integer(forKey: "aiUsageCount")

        if !Calendar.current.isDate(lastResetDate, inSameDayAs: today) {
            count = 0
            UserDefaults.standard.set(today, forKey: "aiUsageResetDate")
            UserDefaults.standard.set(0, forKey: "aiUsageCount")
        }

        let limit: Int
        switch currentTier {
        case .free: limit = 3
        case .basic: limit = 15
        case .premium: limit = 50
        }

        return count < limit
    }

    func recordAIUsage() {
        let count = UserDefaults.standard.integer(forKey: "aiUsageCount")
        UserDefaults.standard.set(count + 1, forKey: "aiUsageCount")
    }

    var remainingAIUsage: Int {
        let today = Calendar.current.startOfDay(for: .now)
        let lastResetDate = UserDefaults.standard.object(forKey: "aiUsageResetDate") as? Date ?? .distantPast
        var count = UserDefaults.standard.integer(forKey: "aiUsageCount")

        if !Calendar.current.isDate(lastResetDate, inSameDayAs: today) {
            count = 0
        }

        return max(0, currentTierLimit - count)
    }

    var currentTierLimit: Int {
        switch currentTier {
        case .free: return 3
        case .basic: return 15
        case .premium: return 50
        }
    }

    // MARK: - Private

    private func listenForTransactions() -> Task<Void, Error> {
        Task.detached {
            for await result in Transaction.updates {
                do {
                    let transaction = try Self.checkVerifiedStatic(result)
                    await self.updatePurchasedProducts()
                    await transaction.finish()
                } catch {
                    let msg = "Transaction doğrulanamadı: \(error)"
                    await MainActor.run { self.logger.error("\(msg)") }
                }
            }
        }
    }

    private func updatePurchasedProducts() async {
        var purchased: Set<String> = []
        for await result in Transaction.currentEntitlements {
            do {
                let transaction = try checkVerified(result)
                purchased.insert(transaction.productID)
            } catch {
                // Doğrulanamayan transaction'ı atla
            }
        }
        purchasedProductIDs = purchased
        UserDefaults.standard.set(currentTierRaw, forKey: "userTier")
    }

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreError.verificationFailed
        case .verified(let safe):
            return safe
        }
    }

    private nonisolated static func checkVerifiedStatic<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreError.verificationFailed
        case .verified(let safe):
            return safe
        }
    }

    enum StoreError: Error {
        case verificationFailed
    }
}
