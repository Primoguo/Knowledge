// Knowledge/Views/SummaryCardView.swift
import SwiftUI

/// AI 摘要展示卡片
struct SummaryCardView: View {
    let result: SummaryResult
    let onReadAloud: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    // 摘要正文
                    VStack(alignment: .leading, spacing: 10) {
                        Label("AI 摘要", systemImage: "sparkles")
                            .font(.headline)
                            .foregroundColor(.accentColor)

                        Text(result.content)
                            .font(.body)
                            .lineSpacing(6)
                            .foregroundColor(.primary)
                            .padding(16)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color.accentColor.opacity(0.05))
                            )
                    }

                    // 关键要点
                    if !result.keyPoints.isEmpty {
                        VStack(alignment: .leading, spacing: 10) {
                            Label("关键要点", systemImage: "list.bullet.rectangle")
                                .font(.headline)
                                .foregroundColor(.accentColor)

                            VStack(spacing: 12) {
                                ForEach(Array(result.keyPoints.enumerated()), id: \.offset) { index, point in
                                    HStack(alignment: .top, spacing: 12) {
                                        ZStack {
                                            Circle()
                                                .fill(Color.accentColor.opacity(0.15))
                                                .frame(width: 24, height: 24)
                                            Text("\(index + 1)")
                                                .font(.caption)
                                                .fontWeight(.bold)
                                                .foregroundColor(.accentColor)
                                        }
                                        Text(point)
                                            .font(.subheadline)
                                            .lineSpacing(4)
                                            .foregroundColor(.primary)
                                        Spacer()
                                    }
                                }
                            }
                            .padding(16)
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .fill(Color(.systemGroupedBackground))
                            )
                        }
                    }

                    // 操作按钮
                    VStack(spacing: 12) {
                        Button(action: onReadAloud) {
                            Label("朗读摘要", systemImage: "play.circle.fill")
                                .font(.headline)
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 14)
                        }
                        .buttonStyle(.borderedProminent)
                        .tint(.accentColor)
                    }
                    .padding(.top, 8)
                }
                .padding(24)
            }
            .navigationTitle("文档总结")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") { dismiss() }
                }
            }
        }
    }
}

// MARK: - 加载中状态

struct SummaryLoadingView: View {
    @State private var animationProgress: CGFloat = 0
    private let timer = Timer.publish(every: 0.02, on: .main, in: .common).autoconnect()

    var body: some View {
        VStack(spacing: 24) {
            // 动画图标
            ZStack {
                Circle()
                    .stroke(Color.accentColor.opacity(0.15), lineWidth: 4)
                    .frame(width: 80, height: 80)

                Circle()
                    .trim(from: 0, to: animationProgress)
                    .stroke(
                        LinearGradient(
                            colors: [.accentColor, .purple],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        ),
                        style: StrokeStyle(lineWidth: 4, lineCap: .round)
                    )
                    .frame(width: 80, height: 80)
                    .rotationEffect(.degrees(-90))

                Image(systemName: "sparkles")
                    .font(.title2)
                    .foregroundColor(.accentColor)
            }
            .onReceive(timer) { _ in
                withAnimation(.linear(duration: 0.02)) {
                    animationProgress = (animationProgress + 0.008).truncatingRemainder(dividingBy: 1.0)
                }
            }

            Text("正在生成摘要...")
                .font(.headline)
                .foregroundColor(.primary)

            Text("AI 正在分析文档内容，请稍候")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .padding(40)
    }
}

// MARK: - 错误状态

struct SummaryErrorView: View {
    let message: String
    let onRetry: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        VStack(spacing: 24) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 48))
                .foregroundColor(.orange)

            Text("生成失败")
                .font(.title3)
                .fontWeight(.semibold)

            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            VStack(spacing: 12) {
                Button(action: onRetry) {
                    Label("重试", systemImage: "arrow.clockwise")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.borderedProminent)
                .tint(.accentColor)

                Button("取消") { dismiss() }
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal, 32)
        }
        .padding(40)
    }
}

#Preview {
    SummaryCardView(
        result: SummaryResult(
            content: "本文主要讨论了人工智能在医疗领域的应用现状和未来趋势...",
            keyPoints: [
                "AI 辅助诊断准确率已达 95% 以上",
                "医疗影像分析是最成熟的应用场景",
                "数据隐私和算法偏见仍是主要挑战"
            ]
        ),
        onReadAloud: {}
    )
}
