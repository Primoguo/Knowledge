// Knowledge/Views/SummaryCardView.swift
import SwiftUI

/// 摘要展示模式
enum SummaryMode: String, CaseIterable {
    case simple = "简版"
    case detailed = "详版"
}

/// AI 摘要展示卡片
struct SummaryCardView: View {
    let result: SummaryResult
    let onReadAloud: (Bool) -> Void
    let onStopAloud: (() -> Void)?
    @Environment(\.dismiss) private var dismiss
    @State private var dragOffset: CGFloat = 0
    @State private var isReadingAloud = false
    @State private var showShareSheet = false
    @State private var shareImage: UIImage?
    @State private var mode: SummaryMode = .simple

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // 下拉指示器（页面最顶部）
                pullHandle

                // 自定义标题栏
                HStack {
                    Button(action: shareSummary) {
                        Image(systemName: "square.and.arrow.up")
                    }

                    Spacer()

                    Text("文档总结")
                        .font(.system(size: 15, weight: .semibold))

                    Spacer()

                    Button("完成") { dismiss() }
                }
                .padding(.horizontal, 16)
                .padding(.vertical, 10)

                // 简版/详版切换（仅当有详版内容时显示）
                if result.hasDetailed {
                    Picker("模式", selection: $mode) {
                        ForEach(SummaryMode.allCases, id: \.self) { m in
                            Text(m.rawValue).tag(m)
                        }
                    }
                    .pickerStyle(.segmented)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 8)
                }

                Divider()
                    .padding(.horizontal, 16)

                ScrollView {
                    VStack(alignment: .leading, spacing: 24) {
                        if mode == .simple {
                            simpleView
                        } else {
                            detailedView
                        }

                        // 朗读按钮
                        readAloudButton
                            .padding(.top, 8)
                    }
                    .padding(24)
                }
            }
            .toolbar { }
            .offset(y: max(0, dragOffset))
            .gesture(
                DragGesture()
                    .onChanged { value in
                        if value.translation.height > 0 {
                            dragOffset = value.translation.height
                        }
                    }
                    .onEnded { value in
                        if value.translation.height > 100 {
                            dismiss()
                        } else {
                            withAnimation(.spring(response: 0.3)) {
                                dragOffset = 0
                            }
                        }
                    }
            )
            .sheet(isPresented: $showShareSheet) {
                if let img = shareImage {
                    ShareSheet(items: [img])
                }
            }
        }
    }

    // MARK: - Simple View

    private var simpleView: some View {
        VStack(alignment: .leading, spacing: 28) {
            // 一句话摘要
            VStack(alignment: .leading, spacing: 12) {
                Text("AI 摘要")
                    .font(.system(size: 13, weight: .medium))
                    .foregroundColor(.secondary)

                Text(result.simpleContent)
                    .font(.system(size: 16))
                    .lineSpacing(8)
                    .foregroundColor(.primary)
            }

            // 关键要点
            keyPointsSection
        }
    }

    // MARK: - Detailed View

    private var detailedView: some View {
        VStack(alignment: .leading, spacing: 32) {
            // 一句话总结
            if !result.oneLiner.isEmpty {
                sectionCard(title: "一句话总结", icon: "sparkles", content: result.oneLiner, highlight: true)
            }

            // 三句话总结
            if !result.threeLines.isEmpty {
                sectionCard(title: "三句话总结", icon: "text.alignleft", content: result.threeLines)
            }

            // 核心内容
            if !result.coreContent.isEmpty {
                sectionCard(title: "核心内容", icon: "doc.text", content: result.coreContent)
            }

            // 关键要点
            keyPointsSection

            // 行动建议
            if !result.actionItems.isEmpty {
                listSection(title: "行动建议", icon: "checklist", items: result.actionItems, color: .green)
            }

            // 风险
            if !result.risks.isEmpty {
                listSection(title: "风险", icon: "exclamationmark.triangle", items: result.risks, color: .orange)
            }
        }
    }

    // MARK: - Reusable Sections

    private var keyPointsSection: some View {
        Group {
            if !result.keyPoints.isEmpty {
                VStack(alignment: .leading, spacing: 12) {
                    Text("关键要点")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundColor(.secondary)

                    VStack(spacing: 0) {
                        ForEach(Array(result.keyPoints.enumerated()), id: \.offset) { index, point in
                            HStack(alignment: .top, spacing: 12) {
                                Text("\(index + 1)")
                                    .font(.system(size: 13, weight: .medium))
                                    .foregroundColor(.secondary)
                                    .frame(width: 20, alignment: .center)
                                Text(point)
                                    .font(.system(size: 15))
                                    .lineSpacing(4)
                                    .foregroundColor(.primary)
                                Spacer()
                            }
                            .padding(.vertical, 10)

                            if index < result.keyPoints.count - 1 {
                                Divider()
                            }
                        }
                    }
                }
            }
        }
    }

    private func sectionCard(title: String, icon: String, content: String, highlight: Bool = false) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.secondary)

            Text(content)
                .font(.system(size: 16))
                .lineSpacing(8)
                .foregroundColor(.primary)
        }
    }

    private func listSection(title: String, icon: String, items: [String], color: Color) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(title)
                .font(.system(size: 13, weight: .medium))
                .foregroundColor(.secondary)

            VStack(spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                    HStack(alignment: .top, spacing: 10) {
                        Text("\(index + 1).")
                            .font(.system(size: 13, weight: .medium))
                            .foregroundColor(.secondary)
                            .frame(width: 20, alignment: .leading)
                        Text(item)
                            .font(.system(size: 15))
                            .lineSpacing(4)
                        Spacer()
                    }
                    .padding(.vertical, 8)

                    if index < items.count - 1 {
                        Divider()
                    }
                }
            }
        }
    }

    // MARK: - Pull Handle

    private var pullHandle: some View {
        VStack(spacing: 2) {
            Capsule()
                .fill(Color.secondary.opacity(0.3))
                .frame(width: 36, height: 4)
                .padding(.top, 4)
                .padding(.bottom, 2)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Read Aloud Button

    private var readAloudButton: some View {
        Button(action: toggleReadAloud) {
            HStack(spacing: 10) {
                if isReadingAloud {
                    HStack(spacing: 2) {
                        ForEach(0..<4, id: \.self) { i in
                            RoundedRectangle(cornerRadius: 1)
                                .fill(Color.primary)
                                .frame(width: 3, height: 8)
                                .modifier(WaveBarAnimation(delay: Double(i) * 0.15))
                        }
                    }
                    .frame(width: 20, height: 16)

                    Text("暂停朗读")
                        .font(.system(size: 15, weight: .medium))
                } else {
                    Image(systemName: "play.fill")
                        .font(.system(size: 14))
                    Text("朗读摘要")
                        .font(.system(size: 15, weight: .medium))
                }
            }
            .foregroundColor(.primary)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 14)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.secondary.opacity(0.08))
            )
        }
        .animation(.easeInOut(duration: 0.2), value: isReadingAloud)
    }

    private func toggleReadAloud() {
        if isReadingAloud {
            isReadingAloud = false
            onStopAloud?()
        } else {
            isReadingAloud = true
            onReadAloud(mode == .detailed)
        }
    }

    // MARK: - Share

    private func shareSummary() {
        let renderer = ImageRenderer(content: SummaryShareCard(result: result, detailed: mode == .detailed))
        renderer.scale = UIScreen.main.scale
        if let uiImage = renderer.uiImage {
            shareImage = uiImage
            showShareSheet = true
        }
    }
}

// MARK: - Wave Bar Animation

struct WaveBarAnimation: ViewModifier {
    let delay: Double
    @State private var animating = false

    func body(content: Content) -> some View {
        content
            .scaleEffect(y: animating ? 1.8 : 0.5, anchor: .center)
            .animation(
                .easeInOut(duration: 0.5)
                .repeatForever(autoreverses: true)
                .delay(delay),
                value: animating
            )
            .onAppear { animating = true }
    }
}

// MARK: - Share Card (for ImageRenderer)

struct SummaryShareCard: View {
    let result: SummaryResult
    var detailed: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 20) {
            // 标题
            HStack {
                Image(systemName: "sparkles")
                    .foregroundColor(.secondary)
                Text("AI 摘要")
                    .font(.system(size: 18, weight: .semibold))
            }

            // 摘要内容
            if detailed && !result.oneLiner.isEmpty {
                // 详版分享
                if !result.oneLiner.isEmpty {
                    sectionLabel("一句话总结")
                    Text(result.oneLiner).font(.system(size: 15)).lineSpacing(6)
                }
                if !result.threeLines.isEmpty {
                    sectionLabel("三句话总结")
                    Text(result.threeLines).font(.system(size: 15)).lineSpacing(6)
                }
                if !result.coreContent.isEmpty {
                    sectionLabel("核心内容")
                    Text(result.coreContent).font(.system(size: 15)).lineSpacing(6)
                }
            } else {
                Text(result.simpleContent)
                    .font(.system(size: 15))
                    .lineSpacing(6)
                    .foregroundColor(.primary)
            }

            // 关键要点
            if !result.keyPoints.isEmpty {
                Divider()
                VStack(alignment: .leading, spacing: 10) {
                    Text("关键要点")
                        .font(.system(size: 14, weight: .semibold))
                    ForEach(Array(result.keyPoints.enumerated()), id: \.offset) { index, point in
                        HStack(alignment: .top, spacing: 8) {
                            Text("\(index + 1).").fontWeight(.medium).foregroundColor(.secondary)
                            Text(point).font(.system(size: 14))
                        }
                    }
                }
            }

            // 行动建议（详版）
            if detailed && !result.actionItems.isEmpty {
                Divider()
                VStack(alignment: .leading, spacing: 8) {
                    Text("行动建议").font(.system(size: 14, weight: .semibold))
                    ForEach(Array(result.actionItems.enumerated()), id: \.offset) { index, item in
                        HStack(alignment: .top, spacing: 8) {
                            Text("\(index + 1).").fontWeight(.medium).foregroundColor(.secondary)
                            Text(item).font(.system(size: 14))
                        }
                    }
                }
            }

            // 风险（详版）
            if detailed && !result.risks.isEmpty {
                Divider()
                VStack(alignment: .leading, spacing: 8) {
                    Text("风险").font(.system(size: 14, weight: .semibold))
                    ForEach(Array(result.risks.enumerated()), id: \.offset) { index, item in
                        HStack(alignment: .top, spacing: 8) {
                            Text("\(index + 1).").fontWeight(.medium).foregroundColor(.secondary)
                            Text(item).font(.system(size: 14))
                        }
                    }
                }
            }

            Divider()

            // 底部水印
            HStack {
                Text("挠荔枝 · Knowledge")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text(Date().formatted(date: .abbreviated, time: .omitted))
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding(24)
        .frame(width: 360)
        .background(Color(.systemBackground))
    }

    private func sectionLabel(_ title: String) -> some View {
        Text(title)
            .font(.system(size: 13, weight: .medium))
            .foregroundColor(.secondary)
            .padding(.top, 4)
    }
}

// MARK: - Share Sheet (UIKit Bridge)

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ vc: UIActivityViewController, context: Context) {}
}

// MARK: - 加载中状态

struct SummaryLoadingView: View {
    var body: some View {
        VStack(spacing: 24) {
            // 荔枝思考中
            LycheeMascotView(size: 64, state: .thinking, enableEasterEgg: false)

            Text("荔枝正在分析...")
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
            oneLiner: "本文主要讨论了人工智能在医疗领域的应用现状和未来趋势。",
            threeLines: "AI 技术正在深刻改变医疗行业的诊断和治疗方式。\n当前最大的挑战是数据隐私和算法偏见。\n预计未来 5 年内 AI 医疗市场规模将增长 3 倍。",
            coreContent: "人工智能在医疗领域的应用已覆盖影像诊断、药物研发、健康管理等多个方面。其中，AI 辅助诊断的准确率已达到 95% 以上，成为最成熟的应用场景。",
            keyPoints: [
                "AI 辅助诊断准确率已达 95% 以上",
                "医疗影像分析是最成熟的应用场景",
                "数据隐私和算法偏见仍是主要挑战"
            ],
            actionItems: ["推动 AI 诊断在基层医院的试点", "建立数据隐私合规框架"],
            risks: ["算法偏见可能导致误诊", "患者数据泄露风险"]
        ),
        onReadAloud: { _ in },
        onStopAloud: {}
    )
}
