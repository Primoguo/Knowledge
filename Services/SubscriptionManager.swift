// Knowledge/Services/SubscriptionManager.swift
import Foundation
import StoreKit

/// 订阅管理器 — 管理 Premium 订阅状态
/// 使用 StoreKit 2，支持订阅检查、购买和恢复
@MainActor
final class SubscriptionManager: ObservableObject {

    static let shared = SubscriptionManager()

    // MARK: - Published State

    /// 用户是否已订阅 Premium
    @Published var isPremium: Bool = false

    /// 是否正在加载/检查订阅状态
    @Published var isLoading: Bool = false

    /// 可用的订阅产品列表
    @Published var products: [Product] = []

    /// 当前活跃的订阅（如果有）
    @Published var currentSubscription: Product.SubscriptionInfo?

    // MARK: - Configuration

    // TODO: [待办] 在 App Store Connect 中配置 IAP 产品后，替换为实际的产品 ID
    // 配置步骤：App Store Connect → 你的 App → 订阅 → 创建订阅组 → 添加月订阅 + 年订阅
    private let productIDs = ["com.knowledge.premium.monthly", "com.knowledge.premium.yearly"]

    // MARK: - Init

    private init() {
        Task {
            await loadProducts()
            await checkSubscriptionStatus()
        }
    }

    // MARK: - Public API

    /// 加载可用订阅产品
    func loadProducts() async {
        isLoading = true
        defer { isLoading = false }

        do {
            products = try await Product.products(for: productIDs)
        } catch {
            print("加载订阅产品失败: \(error.localizedDescription)")
            products = []
        }
    }

    /// 检查当前订阅状态
    func checkSubscriptionStatus() async {
        // 检查所有订阅类型的 entitlements
        for await result in Transaction.currentEntitlements {
            if case .verified(let transaction) = result {
                // 检查交易是否仍在有效期内
                if transaction.revocationDate == nil {
                    isPremium = true
                    return
                }
            }
        }
        isPremium = false
    }

    /// 购买订阅
    func purchase(_ product: Product) async throws -> Bool {
        let result = try await product.purchase()

        switch result {
        case .success(let verification):
            // 验证交易
            let transaction = try checkVerified(verification)
            // 完成交易（告诉 App Store 已处理）
            await transaction.finish()
            // 刷新订阅状态
            await checkSubscriptionStatus()
            return true

        case .userCancelled:
            return false

        case .pending:
            // 等待家长审批等
            return false

        @unknown default:
            return false
        }
    }

    /// 恢复购买（用户换设备/重装 App 时使用）
    func restorePurchases() async {
        try? await AppStore.sync()
        await checkSubscriptionStatus()
    }

    // MARK: - Private

    private func checkVerified<T>(_ result: VerificationResult<T>) throws -> T {
        switch result {
        case .unverified:
            throw StoreError.failedVerification
        case .verified(let safe):
            return safe
        }
    }

    // MARK: - Errors

    enum StoreError: LocalizedError {
        case failedVerification

        var errorDescription: String? {
            switch self {
            case .failedVerification:
                return "购买验证失败，请重试"
            }
        }
    }
}
