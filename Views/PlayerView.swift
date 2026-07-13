// Knowledge/Views/PlayerView.swift
import SwiftUI

struct PlayerView: View {
    @ObservedObject var speakerVM: SpeakerViewModel
    @ObservedObject var subscriptionManager = SubscriptionManager.shared
    @State private var scrollProxy: ScrollViewProxy?
    @State private var showSummary = false
    @State private var showCompanion = false
    @State private var showPaywall = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if let doc = speakerVM.currentDocument {
                    VStack(spacing: 16) {
                        // 文档信息头部
                        headerView(doc: doc)
                            .padding(.horizontal, 24)
                            .padding(.top, 8)

                        // 高亮文本区域
                        highlightTextView(doc: doc)
                            .padding(.horizontal, 16)

                        // 底部控制区
                        VStack(spacing: 12) {
                            // 进度条（自定义 + 段落指示器）
                            VStack(spacing: 6) {
                                ProgressBarView(
                                    progress: speakerVM.progress,
                                    paragraphPositions: paragraphPositions(doc: doc),
                                    onSeek: { speakerVM.seekTo(progress: $0) }
                                )
                                HStack {
                                    Text(speakerVM.currentPositionText).font(.caption).foregroundColor(.secondary)
                                    Spacer()
                                    Text(formatDuration(doc.totalLength)).font(.caption).foregroundColor(.secondary)
                                }
                            }.padding(.horizontal, 24)

                            // AI 功能栏（进度条下方，始终可见）
                            if doc.extractedText.isEmpty == false {
                                aiFeatureBar
                                    .padding(.horizontal, 24)
                            }

                            // 控制按钮
                            PlayerControlsView(speakerVM: speakerVM).padding(.horizontal, 24)
                        }
                        .padding(.bottom, 8)
                    }
                } else {
                    emptyState
                }
            }
            .navigationTitle("正在播放")
            .toolbar { }
            .sheet(isPresented: $showSummary) {
                summarySheet
            }
            .sheet(isPresented: $showCompanion) {
                CompanionView(speakerVM: speakerVM)
            }
            .sheet(isPresented: $showPaywall) {
                PaywallView()
            }
        }
    }

    // MARK: - Summary Sheet

    @ViewBuilder
    private var summarySheet: some View {
        if speakerVM.isGeneratingSummary {
            SummaryLoadingView()
        } else if let error = speakerVM.summaryError {
            SummaryErrorView(message: error) {
                speakerVM.generateSummary()
            }
        } else if let result = speakerVM.summaryResult {
            SummaryCardView(result: result) {
                speakerVM.readSummaryAloud()
            }
        } else {
            // 首次进入，触发生成
            Color.clear
                .onAppear { speakerVM.generateSummary() }
        }
    }

    // MARK: - Header

    private func headerView(doc: Document) -> some View {
        HStack(spacing: 12) {
            ZStack {
                RoundedRectangle(cornerRadius: 10)
                    .fill(LinearGradient(colors: [.accentColor.opacity(0.7), .purple.opacity(0.5)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 48, height: 48)
                Image(systemName: doc.fileType.iconName).font(.title3).foregroundColor(.white)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(doc.title).font(.headline).lineLimit(1)
                Text("\(doc.fileType.displayName) · \(formatLen(doc.totalLength))")
                    .font(.caption).foregroundColor(.secondary)
            }
            Spacer()
        }
    }

    // MARK: - AI Feature Bar

    /// AI 功能按钮栏（进度条下方，始终可见）
    private var aiFeatureBar: some View {
        HStack(spacing: 12) {
            // AI 总结
            Button(action: {
                if subscriptionManager.isPremium {
                    showSummary = true
                } else {
                    showPaywall = true
                }
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                    Text("AI 总结")
                }
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.accentColor)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Color.accentColor.opacity(0.1))
                .cornerRadius(10)
            }
            .disabled(speakerVM.isGeneratingSummary)

            // AI 伴读
            Button(action: {
                if subscriptionManager.isPremium {
                    showCompanion = true
                } else {
                    showPaywall = true
                }
            }) {
                HStack(spacing: 6) {
                    Image(systemName: "bubble.left.and.bubble.right")
                    Text("AI 伴读")
                }
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.accentColor)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Color.accentColor.opacity(0.1))
                .cornerRadius(10)
            }
        }
    }

    // MARK: - Highlight Text

    /// 将文本按段落拆分，每段独立渲染，支持精准滚动跟随
    private func highlightTextView(doc: Document) -> some View {
        let paragraphs = splitIntoParagraphs(doc.extractedText)

        return ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(paragraphs.enumerated()), id: \.offset) { index, para in
                        Text(highlightedParagraph(para, globalOffset: para.offset))
                            .font(.system(size: 17, design: .serif))
                            .lineSpacing(6)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .id("para_\(index)")
                    }
                }
                .padding(.vertical, 8)
                .padding(.horizontal, 4)
            }
            .background(Color.clear)
            .cornerRadius(12)
            .onAppear { scrollProxy = proxy }
            .onChange(of: activeParagraphIndex(paragraphs: paragraphs)) { newIndex in
                guard newIndex >= 0 else { return }
                withAnimation(.easeInOut(duration: 0.3)) {
                    proxy.scrollTo("para_\(newIndex)", anchor: .top)
                }
            }
        }
    }

    /// 段落信息（文本 + 在全文中的起始偏移）
    private struct ParagraphInfo {
        let text: String
        let offset: Int  // NSString UTF-16 偏移
    }

    /// 按换行拆分文本为段落，记录每段的全文偏移
    private func splitIntoParagraphs(_ text: String) -> [ParagraphInfo] {
        let nsText = text as NSString
        var result: [ParagraphInfo] = []

        // 优先用 \n\n 分段，如果只有一段则回退到 \n
        var separator = "\n\n"
        var blocks = text.components(separatedBy: separator)
        if blocks.count <= 1 {
            separator = "\n"
            blocks = text.components(separatedBy: separator)
        }

        var offset = 0
        for block in blocks {
            let trimmed = block.trimmingCharacters(in: .whitespacesAndNewlines)
            if !trimmed.isEmpty {
                // 在原文中搜索此段落的位置
                let searchFrom = offset
                let firstChars = (trimmed as NSString).substring(
                    to: min(15, (trimmed as NSString).length)
                )
                let searchRange = NSRange(location: searchFrom, length: nsText.length - searchFrom)
                let foundRange = nsText.range(of: firstChars, range: searchRange)
                let paraOffset = foundRange.location != NSNotFound ? foundRange.location : offset

                result.append(ParagraphInfo(text: trimmed, offset: paraOffset))
            }
            offset += (block as NSString).length + (separator as NSString).length
        }

        // 如果分段失败，返回整段
        if result.isEmpty {
            result.append(ParagraphInfo(text: text, offset: 0))
        }

        return result
    }

    /// 当前高亮所在的段落索引
    private func activeParagraphIndex(paragraphs: [ParagraphInfo]) -> Int {
        let loc = speakerVM.highlightRange.location
        guard loc >= 0 else { return -1 }

        for i in (0..<paragraphs.count).reversed() {
            if loc >= paragraphs[i].offset {
                return i
            }
        }
        return 0
    }

    /// 为单个段落生成高亮 AttributedString
    private func highlightedParagraph(_ para: ParagraphInfo, globalOffset: Int) -> AttributedString {
        var attributed = AttributedString(para.text)
        attributed.foregroundColor = .primary

        let range = speakerVM.highlightRange
        let paraEnd = globalOffset + (para.text as NSString).length

        // 检查高亮范围是否与当前段落有交集
        if range.location >= 0, range.length > 0,
           range.location < paraEnd,
           range.location + range.length > globalOffset {

            // 计算段落内的局部高亮范围
            let localStart = max(0, range.location - globalOffset)
            let localEnd = min((para.text as NSString).length, range.location + range.length - globalOffset)
            let localLength = localEnd - localStart

            if localLength > 0 {
                let nsRange = NSRange(location: localStart, length: localLength)
                if let stringRange = Range(nsRange, in: para.text) {
                    let lower = AttributedString.Index(stringRange.lowerBound, within: attributed)
                    let upper = AttributedString.Index(stringRange.upperBound, within: attributed)
                    if let lower, let upper {
                        attributed[lower..<upper].foregroundColor = .primary
                        attributed[lower..<upper].font = .system(size: 17, weight: .semibold, design: .serif)
                        attributed[lower..<upper].backgroundColor = Color.accentColor.opacity(0.08)
                    }
                }
            }
        }

        return attributed
    }

    // MARK: - Empty State

    private var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "headphones").font(.system(size: 60)).foregroundColor(.secondary)
            Text("暂无播放内容").font(.title2).foregroundColor(.secondary)
            Text("在书库中选择一篇文档开始朗读").font(.subheadline).foregroundColor(.secondary)
            Spacer()
        }
    }

    // MARK: - Helpers

    /// 计算段落归一化位置（用于进度条指示器）
    private func paragraphPositions(doc: Document) -> [Double] {
        let paragraphs = splitIntoParagraphs(doc.extractedText)
        guard doc.totalLength > 0, !paragraphs.isEmpty else { return [] }
        return paragraphs.map { Double($0.offset) / Double(doc.totalLength) }
    }

    private func formatLen(_ len: Int) -> String {
        len >= 10000 ? String(format: "%.1f万字", Double(len) / 10000.0) : "\(len)字"
    }
    private func formatDuration(_ len: Int) -> String {
        let sec = len / 3; return String(format: "%02d:%02d", sec / 60, sec % 60)
    }
}
