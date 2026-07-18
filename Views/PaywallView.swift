// Knowledge/Views/PaywallView.swift
import SwiftUI
import StoreKit

/// 付费墙 — 未订阅用户尝试使用 AI 功能时弹出
struct PaywallView: View {
    @ObservedObject var subscriptionManager = SubscriptionManager.shared
    @Environment(\.dismiss) private var dismiss
    @State private var purchaseError: String?
    @State private var isPurchasing = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    // 顶部图标
                    Image(systemName: "sparkles.rectangle.stack.fill")
                        .font(.system(size: 56))
                        .foregroundStyle(
                            LinearGradient(
                                colors: [.accentColor, .purple],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                        .padding(.top, 20)

                    // 标题
                    VStack(spacing: 8) {
                        Text("解锁 Premium")
                            .font(.title2)
                            .fontWeight(.bold)

                        Text("一次订阅，解锁全部 AI 功能")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }

                    // 功能列表
                    VStack(alignment: .leading, spacing: 14) {
                        featureRow(icon: "sparkles", title: "AI 智能总结", desc: "一键生成文档摘要和关键要点")
                        featureRow(icon: "bubble.left.and.bubble.right", title: "AI 伴读", desc: "边听边问，AI 实时解答")
                        featureRow(icon: "mic.fill", title: "Vnote 精准转写", desc: "云端语音识别，字级时间戳高亮回放")
                        featureRow(icon: "tray.fill", title: "Vnote AI 分类", desc: "自动归类为会议纪要、创意速记、To-do")
                        featureRow(icon: "brain.head.profile", title: "知识库 + AI 对话", desc: "沉淀内容，随时向 AI 提问")
                    }
                    .padding(.horizontal, 24)

                    // 订阅选项
                    subscriptionOptions

                    // 恢复购买
                    Button("恢复购买") {
                        Task {
                            await subscriptionManager.restorePurchases()
                            if subscriptionManager.isPremium {
                                dismiss()
                            }
                        }
                    }
                    .font(.caption)
                    .foregroundColor(.secondary)

                    // 服务条款 & 隐私政策
                    HStack(spacing: 20) {
                        Link("使用条款", destination: URL(string: "https://naolizhi.cn/terms.html")!)
                        Link("隐私政策", destination: URL(string: "https://naolizhi.cn/privacy.html")!)
                    }
                    .font(.caption2)
                    .foregroundColor(.secondary)

                    // 错误提示
                    if let error = purchaseError {
                        Text(error)
                            .font(.caption)
                            .foregroundColor(.red)
                            .padding(.horizontal)
                    }

                    Spacer(minLength: 20)
                }
            }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("关闭") { dismiss() }
                        .foregroundColor(.secondary)
                }
            }
        }
    }

    // MARK: - Subscription Options

    @ViewBuilder
    private var subscriptionOptions: some View {
        if subscriptionManager.isLoading {
            ProgressView("加载订阅信息...")
                .padding()
        } else if subscriptionManager.products.isEmpty {
            // 产品未加载（开发阶段或网络问题）
            VStack(spacing: 12) {
                Text("订阅信息加载中，请稍后重试")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Button {
                    Task { await subscriptionManager.loadProducts() }
                } label: {
                    Text("重新加载")
                        .font(.caption)
                        .foregroundColor(.accentColor)
                }
            }
            .padding()
        } else {
            let sorted = subscriptionManager.products.sorted { a, b in
                let aVal = a.subscription?.subscriptionPeriod.value ?? 0
                let bVal = b.subscription?.subscriptionPeriod.value ?? 0
                return aVal < bVal
            }
            let monthlyProduct = sorted.first { p in
                p.subscription?.subscriptionPeriod.unit == .month
            }
            let monthlyPrice = monthlyProduct?.price ?? 0

            VStack(spacing: 10) {
                ForEach(Array(sorted.enumerated()), id: \.element.id) { index, product in
                    Button {
                        purchaseProduct(product)
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 6) {
                                    Text(product.displayName)
                                        .font(.body)
                                        .fontWeight(.medium)
                                    // 年付方案标注「推荐」
                                    if isYearly(product) {
                                        Text("推荐")
                                            .font(.caption2)
                                            .fontWeight(.semibold)
                                            .padding(.horizontal, 6)
                                            .padding(.vertical, 1)
                                            .background(Color.accentColor)
                                            .foregroundColor(.white)
                                            .cornerRadius(4)
                                    }
                                }
                                // 价格 + 周期 + 节省信息
                                priceText(for: product, monthlyPrice: monthlyPrice)
                            }
                            Spacer()
                            Text(product.displayPrice)
                                .font(.headline)
                                .foregroundColor(.accentColor)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(
                            isYearly(product)
                                ? Color.accentColor.opacity(0.12)
                                : Color.accentColor.opacity(0.08)
                        )
                        .cornerRadius(12)
                        .overlay(
                            isYearly(product)
                                ? RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color.accentColor.opacity(0.3), lineWidth: 1)
                                : nil
                        )
                    }
                    .disabled(isPurchasing)
                }
            }
            .padding(.horizontal, 24)
        }
    }

    // MARK: - Feature Row

    private func featureRow(icon: String, title: String, desc: String) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(.accentColor)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                Text(desc)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
    }

    // MARK: - Actions

    private func purchaseProduct(_ product: Product) {
        isPurchasing = true
        purchaseError = nil

        Task {
            do {
                let success = try await subscriptionManager.purchase(product)
                if success {
                    dismiss()
                }
            } catch {
                purchaseError = "购买失败：\(error.localizedDescription)"
            }
            isPurchasing = false
        }
    }

    // MARK: - Pricing Helpers

    /// 判断是否为月付方案
    private func isMonthly(_ product: Product) -> Bool {
        guard let period = product.subscription?.subscriptionPeriod else { return false }
        return period.unit == .month && period.value == 1
    }

    /// 判断是否为年付方案
    private func isYearly(_ product: Product) -> Bool {
        guard let period = product.subscription?.subscriptionPeriod else { return false }
        return period.unit == .year && period.value == 1
    }

    /// 价格周期文案：月付显示「¥18/月」，年付显示「约 ¥16.5/月 · 省 8%」
    @ViewBuilder
    private func priceText(for product: Product, monthlyPrice: Decimal) -> some View {
        if isYearly(product) {
            Text(yearlyPriceText(product: product, monthlyPrice: monthlyPrice))
                .font(.caption)
                .foregroundColor(.secondary)
        } else if isMonthly(product) {
            Text("¥\(NSDecimalNumber(decimal: product.price).stringValue)/月")
                .font(.caption)
                .foregroundColor(.secondary)
        } else {
            Text(product.description)
                .font(.caption)
                .foregroundColor(.secondary)
        }
    }

    /// 计算年付方案的周期文案
    private func yearlyPriceText(product: Product, monthlyPrice: Decimal) -> String {
        let yearlyPrice = product.price
        let monthlyEquiv = yearlyPrice / 12
        let monthlyDouble = NSDecimalNumber(decimal: monthlyEquiv).doubleValue
        var savingsPercent: Double = 0
        if monthlyPrice > 0 {
            let monthlyDecimal = NSDecimalNumber(decimal: monthlyPrice).doubleValue
            let yearlyDecimal = NSDecimalNumber(decimal: yearlyPrice).doubleValue
            savingsPercent = (monthlyDecimal * 12 - yearlyDecimal) / (monthlyDecimal * 12) * 100
        }
        let base = "约 ¥\(String(format: "%.1f", monthlyDouble))/月"
        return savingsPercent > 0 ? "\(base) · 省 \(Int(savingsPercent))%" : base
    }
}

#Preview {
    PaywallView()
}
