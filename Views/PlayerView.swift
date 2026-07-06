// Knowledge/Views/PlayerView.swift
import SwiftUI

struct PlayerView: View {
    @ObservedObject var speakerVM: SpeakerViewModel
    @State private var scrollProxy: ScrollViewProxy?
    @State private var showSummary = false

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
                            // 进度条
                            VStack(spacing: 6) {
                                Slider(value: Binding(get: { speakerVM.progress }, set: { speakerVM.seekTo(progress: $0) })).tint(.accentColor)
                                HStack {
                                    Text(speakerVM.currentPositionText).font(.caption).foregroundColor(.secondary)
                                    Spacer()
                                    Text(formatDuration(doc.totalLength)).font(.caption).foregroundColor(.secondary)
                                }
                            }.padding(.horizontal, 24)

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
            .toolbar {
                if let doc = speakerVM.currentDocument, !doc.extractedText.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(action: { showSummary = true }) {
                            Image(systemName: "sparkles")
                                .foregroundColor(.accentColor)
                        }
                        .disabled(speakerVM.isGeneratingSummary)
                    }
                }
            }
            .sheet(isPresented: $showSummary) {
                summarySheet
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

    // MARK: - Highlight Text

    private func highlightTextView(doc: Document) -> some View {
        ScrollViewReader { proxy in
            ScrollView {
                Text(highlightedAttributedText(for: doc))
                    .font(.system(size: 17, design: .serif))
                    .lineSpacing(6)
                    .padding(.vertical, 8)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .id("highlightBlock")
            }
            .background(Color(.systemGroupedBackground))
            .cornerRadius(12)
            .onAppear { scrollProxy = proxy }
            .onChange(of: speakerVM.highlightRange.location) {
                // 自动滚动到当前朗读位置
                withAnimation {
                    proxy.scrollTo("highlightBlock", anchor: .center)
                }
            }
        }
    }

    private func highlightedAttributedText(for doc: Document) -> AttributedString {
        let nsText = doc.extractedText as NSString
        let fullText = doc.extractedText
        var attributed = AttributedString(fullText)

        // 全文默认样式
        attributed.foregroundColor = .primary

        // 高亮当前朗读范围
        let range = speakerVM.highlightRange
        if range.location >= 0, range.length > 0,
           range.location < nsText.length {
            let validLength = min(range.length, nsText.length - range.location)
            let safeRange = NSRange(location: range.location, length: validLength)

            if let stringRange = Range(safeRange, in: fullText),
               let attrRange = AttributedString.Index(stringRange.lowerBound, within: attributed)
                .map({ $0..<AttributedString.Index(stringRange.upperBound, within: attributed)! }) {
                attributed[attrRange].foregroundColor = .accentColor
                attributed[attrRange].font = .system(size: 17, weight: .bold, design: .serif)
                attributed[attrRange].backgroundColor = Color.accentColor.opacity(0.1)
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

    private func formatLen(_ len: Int) -> String {
        len >= 10000 ? String(format: "%.1f万字", Double(len) / 10000.0) : "\(len)字"
    }
    private func formatDuration(_ len: Int) -> String {
        let sec = len / 3; return String(format: "%02d:%02d", sec / 60, sec % 60)
    }
}
