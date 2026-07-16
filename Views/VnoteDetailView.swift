// Knowledge/Views/VnoteDetailView.swift
import SwiftUI
import SwiftData
import AVFoundation

/// Vnote 详情页 — AI 整理内容 + 转写文本 + 录音回放 + 时间戳高亮 + 沉淀知识库
struct VnoteDetailView: View {
    let entry: VnoteEntry

    @Environment(\.modelContext) private var modelContext
    @State private var audioPlayer: AVAudioPlayer?
    @State private var isPlaying = false
    @State private var currentTime: TimeInterval = 0
    @State private var playbackTimer: Timer?
    @State private var highlightedWordIndex: Int = -1

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // 头部信息
                header

                // 录音播放器
                audioPlayerSection

                // AI 整理内容
                if !entry.aiContent.isEmpty {
                    aiContentSection
                }

                Divider()

                // 转写文本（含高亮）
                transcriptionSection

                Divider()

                // 沉淀到知识库
                knowledgeSyncSection
            }
            .padding(16)
        }
        .navigationTitle(entry.title.isEmpty ? "未命名速记" : entry.title)
        .navigationBarTitleDisplayMode(.inline)
        .onDisappear {
            stopPlayback()
        }
    }

    // MARK: - 头部

    private var header: some View {
        HStack(spacing: 8) {
            Image(systemName: entry.category.iconName)
                .foregroundColor(categoryColor(entry.category))
            Text(entry.category.displayName)
                .font(.subheadline)
                .padding(.horizontal, 8)
                .padding(.vertical, 2)
                .foregroundColor(.white)
                .background(Capsule().fill(categoryColor(entry.category)))

            Spacer()

            HStack(spacing: 3) {
                Image(systemName: "clock")
                    .font(.system(size: 10))
                Text(entry.durationText)
                    .font(.caption)
            }
            .foregroundColor(.secondary)

            Text(entry.createdAt, format: .dateTime.month(.abbreviated).day().hour().minute())
                .font(.caption)
                .foregroundColor(.secondary.opacity(0.6))
        }
    }

    // MARK: - 播放器

    private var audioPlayerSection: some View {
        VStack(spacing: 12) {
            HStack(spacing: 16) {
                // 播放/暂停按钮
                Button {
                    togglePlayback()
                } label: {
                    Image(systemName: isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 44))
                        .foregroundColor(.primary)
                }

                // 进度条
                VStack(spacing: 4) {
                    Slider(
                        value: Binding(
                            get: { currentTime },
                            set: { seekTo($0) }
                        ),
                        in: 0...max(entry.audioDuration, 0.1)
                    )

                    HStack {
                        Text(formatTime(currentTime))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(formatTime(entry.audioDuration))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }
            }

            // Premium 高亮提示
            if entry.isPremiumSTT {
                HStack(spacing: 4) {
                    Image(systemName: "text.magnifyingglass")
                        .font(.system(size: 10))
                    Text("播放时文字逐词高亮跟随")
                        .font(.caption2)
                }
                .foregroundColor(.blue.opacity(0.7))
            }
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 12).fill(Color.secondary.opacity(0.05)))
    }

    // MARK: - AI 内容

    private var aiContentSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "sparkles")
                    .font(.system(size: 12))
                Text("AI 整理")
                    .font(.caption)
            }
            .foregroundColor(.secondary)

            Text(entry.aiContent)
                .font(.system(size: 15))
                .lineSpacing(4)
                .textSelection(.enabled)
        }
        .padding(12)
        .background(RoundedRectangle(cornerRadius: 10).fill(Color.secondary.opacity(0.05)))
    }

    // MARK: - 转写文本（含高亮）

    private var transcriptionSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("转写文本")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                if entry.isPremiumSTT {
                    Label("含时间戳", systemImage: "clock.badge")
                        .font(.caption2)
                        .foregroundColor(.blue.opacity(0.7))
                }
            }

            if entry.sentences.isEmpty || !entry.isPremiumSTT {
                // 免费用户：纯文本显示
                Text(entry.transcription.isEmpty ? "（无转写内容）" : entry.transcription)
                    .font(.system(size: 15))
                    .foregroundColor(entry.transcription.isEmpty ? .secondary : .primary)
                    .lineSpacing(4)
                    .textSelection(.enabled)
            } else {
                // Premium 用户：带时间戳高亮的文字
                highlightedTranscription
            }
        }
    }

    /// Premium 高亮转写：播放时当前词高亮
    private var highlightedTranscription: some View {
        let allWords = entry.sentences.flatMap { sentence in
            sentence.words.map { word -> (text: String, begin: Int, end: Int, punct: String) in
                (word.text, word.beginTime, word.endTime, word.punctuation)
            }
        }

        // 当前高亮的词索引
        let currentMs = Int(currentTime * 1000)
        let activeIndex = allWords.firstIndex(where: { w in
            currentMs >= w.begin && currentMs <= w.end
        }) ?? -1

        return FlowLayout(spacing: 4) {
            ForEach(Array(allWords.enumerated()), id: \.offset) { index, word in
                let isActive = isPlaying && index == activeIndex
                Text(word.text + word.punct)
                    .font(.system(size: 15))
                    .foregroundColor(isActive ? .white : .primary)
                    .padding(.horizontal, isActive ? 4 : 0)
                    .padding(.vertical, isActive ? 2 : 0)
                    .background(
                        isActive
                            ? RoundedRectangle(cornerRadius: 4).fill(Color.blue)
                            : nil
                    )
                    .onTapGesture {
                        // 点击词跳转播放位置
                        seekTo(Double(word.begin) / 1000.0)
                    }
            }
        }
    }

    // MARK: - 知识库沉淀

    private var knowledgeSyncSection: some View {
        Group {
            if entry.isSyncedToKnowledge {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                    Text("已沉淀到知识库")
                        .foregroundColor(.secondary)
                }
                .font(.subheadline)
                .frame(maxWidth: .infinity)
            } else {
                Button {
                    saveToKnowledge()
                } label: {
                    HStack {
                        Image(systemName: "brain.head.profile")
                        Text("沉淀到知识库")
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
                    .foregroundColor(.white)
                    .background(Capsule().fill(Color.primary))
                }
            }
        }
    }

    // MARK: - 播放控制

    private func togglePlayback() {
        if isPlaying {
            pausePlayback()
        } else {
            startPlayback()
        }
    }

    private func startPlayback() {
        guard let url = entry.audioFileURL, FileManager.default.fileExists(atPath: url.path) else {
            return
        }

        do {
            if audioPlayer == nil {
                audioPlayer = try AVAudioPlayer(contentsOf: url)
                audioPlayer?.prepareToPlay()
            }
            audioPlayer?.play()
            isPlaying = true

            playbackTimer = Timer.scheduledTimer(withTimeInterval: 0.05, repeats: true) { _ in
                guard let player = audioPlayer else { return }
                currentTime = player.currentTime
                if !player.isPlaying {
                    isPlaying = false
                    playbackTimer?.invalidate()
                    playbackTimer = nil
                }
            }
        } catch {
            print("[Vnote] Playback error: \(error.localizedDescription)")
        }
    }

    private func pausePlayback() {
        audioPlayer?.pause()
        isPlaying = false
        playbackTimer?.invalidate()
        playbackTimer = nil
    }

    private func stopPlayback() {
        audioPlayer?.stop()
        audioPlayer = nil
        isPlaying = false
        playbackTimer?.invalidate()
        playbackTimer = nil
        currentTime = 0
    }

    private func seekTo(_ time: TimeInterval) {
        audioPlayer?.currentTime = time
        currentTime = time
    }

    // MARK: - 沉淀知识库

    private func saveToKnowledge() {
        let knowledgeEntry = KnowledgeEntry(
            title: entry.title,
            content: entry.aiContent.isEmpty ? entry.transcription : entry.aiContent,
            source: .vnote,
            category: entry.category
        )
        modelContext.insert(knowledgeEntry)
        entry.isSyncedToKnowledge = true
        entry.updatedAt = Date()
        try? modelContext.save()
    }

    // MARK: - Helpers

    private func formatTime(_ seconds: TimeInterval) -> String {
        let m = Int(seconds) / 60
        let s = Int(seconds) % 60
        return String(format: "%d:%02d", m, s)
    }

    private func categoryColor(_ category: KnowledgeCategory) -> Color {
        switch category {
        case .meeting:  return .blue
        case .creative: return .orange
        case .todo:     return .green
        case .general:  return .gray
        }
    }
}

// MARK: - FlowLayout (自适应换行布局)

struct FlowLayout: Layout {
    var spacing: CGFloat = 4

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? .infinity
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }

        return CGSize(width: maxWidth, height: y + rowHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > bounds.width {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            subview.place(at: CGPoint(x: bounds.minX + x, y: bounds.minY + y), proposal: .unspecified)
            x += size.width + spacing
            rowHeight = max(rowHeight, size.height)
        }
    }
}
