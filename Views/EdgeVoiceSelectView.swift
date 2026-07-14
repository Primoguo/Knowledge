// Knowledge/Views/EdgeVoiceSelectView.swift
import SwiftUI
import AVFoundation

/// Edge TTS 音色选择界面（中文音色优先展示）
struct EdgeVoiceSelectView: View {
    @ObservedObject var speakerVM: SpeakerViewModel
    @Environment(\.dismiss) private var dismiss
    @State private var selectedVoiceId: String = "zh-CN-XiaoxiaoNeural"
    @State private var isTesting = false

    // 动态音色列表
    @State private var mandarinVoices: [EdgeTTSService.EdgeVoice] = EdgeTTSService.EdgeVoice.recommendedChinese
    @State private var cantoneseVoices: [EdgeTTSService.EdgeVoice] = EdgeTTSService.EdgeVoice.recommendedCantonese
    @State private var dialectVoices: [EdgeTTSService.EdgeVoice] = []
    @State private var isLoading = true
    @State private var loadError: String?

    private let service = EdgeTTSService.shared

    var body: some View {
        NavigationStack {
            List {
                // 加载状态
                if isLoading {
                    Section {
                        HStack {
                            ProgressView()
                            Text("正在获取可用音色...").foregroundColor(.secondary)
                        }
                    }
                } else {
                    // 普通话音色
                    if !mandarinVoices.isEmpty {
                        Section {
                            ForEach(mandarinVoices) { voice in
                                voiceRow(voice)
                            }
                        } header: {
                            Label("普通话", systemImage: "waveform")
                        }
                    }

                    // 粤语音色
                    if !cantoneseVoices.isEmpty {
                        Section {
                            ForEach(cantoneseVoices) { voice in
                                voiceRow(voice)
                            }
                        } header: {
                            Label("粤语", systemImage: "waveform")
                        }
                    }

                    // 方言音色
                    if !dialectVoices.isEmpty {
                        Section {
                            ForEach(dialectVoices) { voice in
                                voiceRow(voice)
                            }
                        } header: {
                            Label("方言", systemImage: "waveform")
                        }
                    }

                    // 加载失败提示
                    if let error = loadError {
                        Section {
                            Label(error, systemImage: "exclamationmark.triangle")
                                .foregroundColor(.orange)
                                .font(.caption)
                        }
                    }
                }
            }
            .navigationTitle("云端音色")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("确定") {
                        applyVoice()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .onAppear {
                if let current = speakerVM.voiceConfig.edgeVoiceId {
                    selectedVoiceId = current
                }
                loadVoices()
            }
        }
    }

    // MARK: - Voice Row

    @ViewBuilder
    private func voiceRow(_ voice: EdgeTTSService.EdgeVoice) -> some View {
        Button(action: { selectedVoiceId = voice.id }) {
            HStack(spacing: 12) {
                // 性别图标
                Image(systemName: voice.gender == "Female" ? "person.fill" : "person.fill")
                    .font(.system(size: 14))
                    .foregroundColor(voice.gender == "Female" ? .pink.opacity(0.8) : .blue.opacity(0.8))
                    .frame(width: 24)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 6) {
                        Text(voice.name)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                        if let tag = voice.tag {
                            Text(tag)
                                .font(.caption2)
                                .padding(.horizontal, 5)
                                .padding(.vertical, 1)
                                .background(tagColor(tag))
                                .cornerRadius(3)
                                .foregroundColor(tagTextColor(tag))
                        }
                    }
                    Text(voice.id)
                        .font(.caption)
                        .foregroundColor(.secondary)
                }

                Spacer()

                // 试听按钮
                Button(action: { testVoice(voice) }) {
                    Image(systemName: isTesting ? "waveform" : "play.circle")
                        .font(.system(size: 20))
                        .foregroundColor(.accentColor)
                }
                .buttonStyle(.plain)
                .disabled(isTesting)

                // 选中标记
                if selectedVoiceId == voice.id {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.accentColor)
                } else {
                    Image(systemName: "circle")
                        .foregroundColor(.gray.opacity(0.3))
                }
            }
        }
        .buttonStyle(.plain)
    }

    // MARK: - Actions

    /// 从服务器动态加载可用音色列表
    private func loadVoices() {
        isLoading = true
        loadError = nil
        Task {
            do {
                let voices = try await service.fetchAvailableVoices()

                // 按 Locale 分组
                var mandarin: [EdgeTTSService.EdgeVoice] = []
                var cantonese: [EdgeTTSService.EdgeVoice] = []
                var dialect: [EdgeTTSService.EdgeVoice] = []

                for v in voices {
                    if v.id.hasPrefix("zh-HK") {
                        cantonese.append(v)
                    } else if v.id.contains("liaoning") || v.id.contains("shaanxi") || v.id.hasPrefix("zh-TW") {
                        dialect.append(v)
                    } else {
                        mandarin.append(v)
                    }
                }

                await MainActor.run {
                    self.mandarinVoices = mandarin
                    self.cantoneseVoices = cantonese
                    self.dialectVoices = dialect
                    self.isLoading = false

                    // 检查当前选中的音色是否仍在可用列表中
                    if !voices.contains(where: { $0.id == selectedVoiceId }) {
                        // 音色已下线，回退到默认
                        selectedVoiceId = "zh-CN-XiaoxiaoNeural"
                        loadError = "\"\(selectedVoiceId)\" 已下线，已切换到默认音色"
                    }
                }
                print("🎤 加载了 \(voices.count) 个可用音色")
            } catch {
                await MainActor.run {
                    self.isLoading = false
                    self.loadError = "无法加载音色列表，显示本地缓存"
                }
                print("⚠️ 加载音色列表失败: \(error)")
            }
        }
    }

    private func applyVoice() {
        var config = speakerVM.voiceConfig
        config.engine = .edgeTTS
        config.edgeVoiceId = selectedVoiceId
        speakerVM.switchEngine(to: .edgeTTS)
        speakerVM.updateConfig(config)
    }

    private func testVoice(_ voice: EdgeTTSService.EdgeVoice) {
        guard !isTesting else { return }
        isTesting = true

        Task {
            do {
                let audioData = try await service.synthesize(
                    text: "你好，这是\(voice.name)的声音效果。",
                    voice: voice.id,
                    rate: speakerVM.voiceConfig.rate
                )

                // 播放试听
                let tempURL = FileManager.default.temporaryDirectory
                    .appendingPathComponent("edge_test_\(UUID().uuidString).mp3")
                try audioData.write(to: tempURL)

                let player = try AVAudioPlayer(contentsOf: tempURL)
                player.play()

                // 等待播放完成
                try await Task.sleep(nanoseconds: UInt64(player.duration * 1_000_000_000 + 500_000_000))

                isTesting = false
            } catch {
                isTesting = false
                print("试听失败: \(error)")
            }
        }
    }

    // MARK: - Tag Colors

    private func tagColor(_ tag: String) -> Color {
        switch tag {
        case "推荐": return Color.accentColor.opacity(0.15)
        case "新闻": return Color.blue.opacity(0.15)
        case "粤语": return Color.orange.opacity(0.15)
        case "辽宁", "台湾", "陕西": return Color.purple.opacity(0.15)
        default: return Color.gray.opacity(0.15)
        }
    }

    private func tagTextColor(_ tag: String) -> Color {
        switch tag {
        case "推荐": return .accentColor
        case "新闻": return .blue
        case "粤语": return .orange
        case "辽宁", "台湾", "陕西": return .purple
        default: return .secondary
        }
    }
}
