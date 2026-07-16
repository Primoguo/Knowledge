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
                        featureRow(icon: "waveform", title: "AI 高品质音色", desc: "CosyVoice 自然语音合成")
                        featureRow(icon: "mic.badge.xmark", title: "语音克隆", desc: "用自己的声音朗读文档")
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
            VStack(spacing: 10) {
                ForEach(subscriptionManager.products, id: \.id) { product in
                    Button {
                        purchaseProduct(product)
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(product.displayName)
                                    .font(.body)
                                    .fontWeight(.medium)
                                Text(product.description)
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                            Text(product.displayPrice)
                                .font(.headline)
                                .foregroundColor(.accentColor)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                        .background(Color.accentColor.opacity(0.08))
                        .cornerRadius(12)
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
}

#Preview {
    PaywallView()
}
