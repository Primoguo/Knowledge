// Knowledge/Views/VnoteRecorderView.swift
import SwiftUI
import SwiftData

/// Vnote 录音页 — 录音 + STT 转写 + AI 分类 + 保存
struct VnoteRecorderView: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.modelContext) private var modelContext
    @StateObject private var recorder = AudioRecorderService()
    @State private var phase: RecorderPhase = .idle
    @State private var errorMessage: String?
    @State private var showPremiumPaywall = false

    private let sttService = SpeechRecognitionService.shared
    private let aiService = VnoteAIService.shared

    enum RecorderPhase {
        case idle       // 准备录音
        case recording  // 录音中
        case processing // STT + AI 处理中
        case done       // 完成，显示结果
    }

    // 处理完成后的数据
    @State private var resultEntry: VnoteEntry?

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Spacer()

                switch phase {
                case .idle, .recording:
                    recordingUI
                case .processing:
                    processingUI
                case .done:
                    if let entry = resultEntry {
                        doneUI(entry)
                    }
                }

                Spacer()
            }
            .navigationTitle("新建速记")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("取消") {
                        recorder.cancelRecording()
                        dismiss()
                    }
                    .disabled(phase == .processing)
                }
                if phase == .done, resultEntry != nil {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button("完成") { dismiss() }
                            .fontWeight(.semibold)
                    }
                }
            }
            .alert("提示", isPresented: .constant(errorMessage != nil)) {
                Button("确定") { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
        }
    }

    // MARK: - 录音 UI

    private var recordingUI: some View {
        VStack(spacing: 40) {
            // 音量波形
            waveformView

            // 时长
            Text(formatDuration(recorder.duration))
                .font(.system(size: 48, weight: .light, design: .monospaced))
                .foregroundColor(.primary)

            // 录音按钮
            recordButton

            // 提示
            Text(phase == .idle ? "点击开始录音" : "录音中...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
    }

    private var waveformView: some View {
        HStack(spacing: 3) {
            ForEach(0..<30, id: \.self) { i in
                let height = recorder.isRecording
                    ? CGFloat(recorder.meterLevel) * 60 + CGFloat.random(in: 4...12)
                    : 4
                RoundedRectangle(cornerRadius: 2)
                    .fill(recorder.isRecording ? Color.primary : Color.secondary.opacity(0.2))
                    .frame(width: 4, height: max(4, height))
            }
        }
        .frame(height: 80)
        .animation(.easeInOut(duration: 0.1), value: recorder.meterLevel)
    }

    private var recordButton: some View {
        Button {
            if recorder.isRecording {
                stopAndProcess()
            } else {
                startRecording()
            }
        } label: {
            ZStack {
                Circle()
                    .fill(recorder.isRecording ? Color.red : Color.primary)
                    .frame(width: 80, height: 80)

                Image(systemName: recorder.isRecording ? "stop.fill" : "mic.fill")
                    .font(.system(size: 32))
                    .foregroundColor(recorder.isRecording ? .white : .white)
            }
        }
    }

    // MARK: - 处理中 UI

    private var processingUI: some View {
        VStack(spacing: 24) {
            ProgressView()
                .scaleEffect(1.5)
            Text("正在转写和整理...")
                .font(.headline)
                .foregroundColor(.secondary)
            Text("语音识别 → AI 分类 → 生成内容")
                .font(.subheadline)
                .foregroundColor(.secondary.opacity(0.6))
        }
    }

    // MARK: - 完成 UI

    private func doneUI(_ entry: VnoteEntry) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                // 分类标签
                HStack(spacing: 8) {
                    Image(systemName: entry.category.iconName)
                        .foregroundColor(categoryColor(entry.category))
                    Text(entry.category.displayName)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(entry.durationText)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                // 标题
                Text(entry.title.isEmpty ? "未命名速记" : entry.title)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(Color(red: 26/255, green: 26/255, blue: 26/255))

                // AI 整理内容
                if !entry.aiContent.isEmpty {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("AI 整理")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(entry.aiContent)
                            .font(.system(size: 15))
                            .lineSpacing(4)
                    }
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: 10).fill(Color.secondary.opacity(0.05)))
                }

                Divider()

                // 转写文本
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
                    Text(entry.transcription.isEmpty ? "（无内容）" : entry.transcription)
                        .font(.system(size: 15))
                        .foregroundColor(entry.transcription.isEmpty ? .secondary : .primary)
                        .lineSpacing(4)
                }

                // 沉淀到知识库按钮
                if !entry.isSyncedToKnowledge {
                    Button {
                        saveToKnowledge(entry)
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
                    .padding(.top, 8)
                } else {
                    HStack {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundColor(.green)
                        Text("已沉淀到知识库")
                            .foregroundColor(.secondary)
                    }
                    .font(.subheadline)
                    .frame(maxWidth: .infinity)
                    .padding(.top, 8)
                }
            }
            .padding(16)
        }
    }

    // MARK: - Actions

    private func startRecording() {
        Task {
            do {
                try await recorder.startRecording()
                phase = .recording
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func stopAndProcess() {
        let duration = recorder.duration
        guard let audioURL = recorder.stopRecording() else {
            errorMessage = "录音保存失败"
            return
        }

        // 录音太短
        if duration < 1 {
            errorMessage = "录音时间太短，请重新录制"
            try? FileManager.default.removeItem(at: audioURL)
            return
        }

        phase = .processing

        Task {
            do {
                // 1. STT 转写（先用免费，后续可切 Premium）
                let isPremium = false  // 后续根据 SubscriptionManager.isPremium 决定
                let sttResult = try await sttService.transcribe(audioURL: audioURL, isPremium: isPremium)

                // 2. AI 分类
                let classification = try await aiService.classify(text: sttResult.text)

                // 3. 创建 VnoteEntry
                let entry = VnoteEntry(
                    title: classification.title,
                    transcription: sttResult.text,
                    sentences: sttResult.sentences,
                    aiContent: classification.content,
                    category: classification.category,
                    audioFileName: audioURL.lastPathComponent,
                    audioDuration: duration,
                    isPremiumSTT: sttResult.isPremium
                )

                await MainActor.run {
                    modelContext.insert(entry)
                    try? modelContext.save()
                    resultEntry = entry
                    phase = .done
                }
            } catch {
                await MainActor.run {
                    // STT 失败时仍保存录音，只是没有转写
                    let entry = VnoteEntry(
                        title: "语音速记",
                        transcription: "",
                        aiContent: "",
                        category: .general,
                        audioFileName: audioURL.lastPathComponent,
                        audioDuration: duration,
                        isPremiumSTT: false
                    )
                    modelContext.insert(entry)
                    try? modelContext.save()
                    resultEntry = entry
                    phase = .done
                    errorMessage = "语音识别失败：\(error.localizedDescription)\n录音已保存，可稍后重试识别"
                }
            }
        }
    }

    private func saveToKnowledge(_ entry: VnoteEntry) {
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

    private func formatDuration(_ duration: TimeInterval) -> String {
        let minutes = Int(duration) / 60
        let seconds = Int(duration) % 60
        return String(format: "%02d:%02d", minutes, seconds)
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
