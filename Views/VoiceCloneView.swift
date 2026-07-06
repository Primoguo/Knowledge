// Knowledge/Views/VoiceCloneView.swift
import SwiftUI
import AVFoundation

/// 语音克隆录音界面
struct VoiceCloneView: View {
    @StateObject private var recorder = VoiceRecorder()
    @State private var cloneState: CloneState = .idle
    @State private var errorMessage: String?
    @State private var clonedVoiceId: String?
    @Environment(\.dismiss) private var dismiss

    /// 引导文本（用户跟读）
    private let guideText = "春风吹拂着大地，万物复苏。阳光温柔地洒在田野上，远处传来阵阵鸟鸣，一切都显得那么宁静而美好。"

    enum CloneState {
        case idle        // 初始状态
        case recording   // 录制中
        case preview     // 预览（可回放）
        case uploading   // 上传中
        case processing  // 处理中
        case completed   // 完成
        case error       // 失败
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 28) {
                    // 状态图标
                    stateIcon
                        .padding(.top, 20)

                    // 引导文本
                    VStack(alignment: .leading, spacing: 12) {
                        Label("请朗读以下文本", systemImage: "text.quote")
                            .font(.headline)
                            .foregroundColor(.accentColor)

                        Text(guideText)
                            .font(.system(size: 18, design: .serif))
                            .lineSpacing(8)
                            .padding(20)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .background(
                                RoundedRectangle(cornerRadius: 16)
                                    .fill(Color(.systemGroupedBackground))
                            )
                            .overlay(
                                RoundedRectangle(cornerRadius: 16)
                                    .stroke(
                                        cloneState == .recording
                                            ? Color.red.opacity(0.5)
                                            : Color.clear,
                                        lineWidth: 2
                                    )
                            )
                    }
                    .padding(.horizontal, 24)

                    // 操作按钮
                    VStack(spacing: 14) {
                        switch cloneState {
                        case .idle:
                            Button(action: startRecording) {
                                Label("开始录音", systemImage: "mic.fill")
                                    .font(.headline)
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                            }
                            .buttonStyle(.borderedProminent)
                            .tint(.red)

                        case .recording:
                            HStack(spacing: 20) {
                                Button(action: stopRecording) {
                                    Label("停止", systemImage: "stop.fill")
                                        .font(.headline)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 14)
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(.red)
                            }

                        case .preview:
                            HStack(spacing: 16) {
                                Button(action: { recorder.play() }) {
                                    Label(recorder.isPlaying ? "停止播放" : "试听",
                                          systemImage: recorder.isPlaying ? "stop.fill" : "play.fill")
                                        .font(.subheadline)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 12)
                                }
                                .buttonStyle(.bordered)

                                Button(action: { startRecording() }) {
                                    Label("重录", systemImage: "arrow.clockwise")
                                        .font(.subheadline)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 12)
                                }
                                .buttonStyle(.bordered)

                                Button(action: uploadForCloning) {
                                    Label("开始克隆", systemImage: "wand.and.stars")
                                        .font(.subheadline)
                                        .frame(maxWidth: .infinity)
                                        .padding(.vertical, 12)
                                }
                                .buttonStyle(.borderedProminent)
                                .tint(.accentColor)
                            }

                        case .uploading, .processing:
                            VStack(spacing: 12) {
                                ProgressView()
                                    .scaleEffect(1.2)
                                Text(cloneState == .uploading ? "正在上传音频..." : "AI 正在学习你的声音...")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            }

                        case .completed:
                            VStack(spacing: 14) {
                                Text("🎉 你的声音已就绪！")
                                    .font(.title3)
                                    .fontWeight(.semibold)

                                if let voiceId = clonedVoiceId {
                                    Text("音色 ID: \(voiceId)")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }

                                HStack(spacing: 16) {
                                    Button("重新克隆") {
                                        cloneState = .idle
                                        clonedVoiceId = nil
                                    }
                                    .buttonStyle(.bordered)

                                    Button("完成") {
                                        dismiss()
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .tint(.accentColor)
                                }
                            }

                        case .error:
                            VStack(spacing: 14) {
                                Text(errorMessage ?? "未知错误")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                                    .multilineTextAlignment(.center)

                                HStack(spacing: 16) {
                                    Button("取消") { dismiss() }
                                        .buttonStyle(.bordered)

                                    Button("重试") {
                                        cloneState = .idle
                                        errorMessage = nil
                                    }
                                    .buttonStyle(.borderedProminent)
                                    .tint(.accentColor)
                                }
                            }
                        }
                    }
                    .padding(.horizontal, 24)
                    .padding(.bottom, 30)
                }
            }
            .navigationTitle("语音克隆")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    if cloneState != .uploading && cloneState != .processing {
                        Button("取消") { dismiss() }
                    }
                }
            }
        }
    }

    // MARK: - 状态图标

    @ViewBuilder
    private var stateIcon: some View {
        switch cloneState {
        case .idle:
            ZStack {
                Circle()
                    .fill(Color.red.opacity(0.1))
                    .frame(width: 100, height: 100)
                Image(systemName: "mic.fill")
                    .font(.system(size: 40))
                    .foregroundColor(.red)
            }
        case .recording:
            ZStack {
                Circle()
                    .fill(Color.red.opacity(0.15))
                    .frame(width: 100, height: 100)
                    .overlay(
                        Circle()
                            .stroke(Color.red.opacity(0.3), lineWidth: 3)
                            .scaleEffect(recorder.isRecording ? 1.2 : 1.0)
                            .opacity(recorder.isRecording ? 0.5 : 1.0)
                            .animation(
                                .easeInOut(duration: 0.8).repeatForever(autoreverses: true),
                                value: recorder.isRecording
                            )
                    )
                Image(systemName: "waveform")
                    .font(.system(size: 36))
                    .foregroundColor(.red)
            }
        case .preview:
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.1))
                    .frame(width: 100, height: 100)
                Image(systemName: "waveform.circle.fill")
                    .font(.system(size: 50))
                    .foregroundColor(.accentColor)
            }
        case .uploading, .processing:
            ZStack {
                Circle()
                    .fill(Color.accentColor.opacity(0.1))
                    .frame(width: 100, height: 100)
                ProgressView()
                    .scaleEffect(1.5)
            }
        case .completed:
            ZStack {
                Circle()
                    .fill(Color.green.opacity(0.1))
                    .frame(width: 100, height: 100)
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 50))
                    .foregroundColor(.green)
            }
        case .error:
            ZStack {
                Circle()
                    .fill(Color.orange.opacity(0.1))
                    .frame(width: 100, height: 100)
                Image(systemName: "exclamationmark.circle.fill")
                    .font(.system(size: 50))
                    .foregroundColor(.orange)
            }
        }
    }

    // MARK: - Actions

    private func startRecording() {
        recorder.requestPermission { granted in
            guard granted else {
                errorMessage = "需要麦克风权限才能录音"
                cloneState = .error
                return
            }
            recorder.start()
            cloneState = .recording
        }
    }

    private func stopRecording() {
        let duration = recorder.stop()
        if duration < 5.0 {
            errorMessage = "录音时长不足（\(Int(duration))秒），请录制至少 5 秒"
            cloneState = .error
            return
        }
        cloneState = .preview
    }

    private func uploadForCloning() {
        guard let audioData = recorder.audioData else {
            errorMessage = "未找到录音数据"
            cloneState = .error
            return
        }

        cloneState = .uploading
        Task {
            do {
                cloneState = .processing
                let voiceId = try await CosyVoiceService.shared.cloneVoice(
                    audioData: audioData,
                    voiceName: "我的声音-\(Date().formatted(date: .numeric, time: .shortened))"
                )
                await MainActor.run {
                    clonedVoiceId = voiceId
                    cloneState = .completed
                    saveClonedVoice(id: voiceId)
                }
            } catch {
                await MainActor.run {
                    errorMessage = error.localizedDescription
                    cloneState = .error
                }
            }
        }
    }

    private func saveClonedVoice(id voiceId: String) {
        let voice = ClonedVoice(
            id: voiceId,
            name: "我的声音",
            description: "于 \(Date().formatted(date: .abbreviated, time: .shortened)) 克隆"
        )
        var voices = VoiceStore.loadClonedVoices()
        voices.append(voice)
        VoiceStore.saveClonedVoices(voices)
        VoiceStore.saveSelectedClone(voiceId)
    }
}

// MARK: - 录音器

final class VoiceRecorder: NSObject, ObservableObject, AVAudioRecorderDelegate {
    @Published var isRecording = false
    @Published var isPlaying = false
    @Published var recordedDuration: TimeInterval = 0

    private var audioRecorder: AVAudioRecorder?
    private var audioPlayer: AVAudioPlayer?
    private var recordingURL: URL?
    private var durationTimer: Timer?

    var audioData: Data? {
        guard let url = recordingURL else { return nil }
        return try? Data(contentsOf: url)
    }

    func requestPermission(completion: @escaping (Bool) -> Void) {
        AVAudioSession.sharedInstance().requestRecordPermission(completion)
    }

    func start() {
        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playAndRecord, mode: .default)
        try? session.setActive(true)

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("voice_clone_\(UUID().uuidString).wav")

        let settings: [String: Any] = [
            AVFormatIDKey: Int(kAudioFormatLinearPCM),
            AVSampleRateKey: 24000,
            AVNumberOfChannelsKey: 1,
            AVLinearPCMBitDepthKey: 16,
            AVEncoderAudioQualityKey: AVAudioQuality.high.rawValue
        ]

        audioRecorder = try? AVAudioRecorder(url: url, settings: settings)
        audioRecorder?.delegate = self
        audioRecorder?.record()

        recordingURL = url
        isRecording = true

        durationTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: true) { [weak self] _ in
            self?.recordedDuration = self?.audioRecorder?.currentTime ?? 0
        }
    }

    func stop() -> TimeInterval {
        audioRecorder?.stop()
        isRecording = false
        durationTimer?.invalidate()
        durationTimer = nil
        return audioRecorder?.currentTime ?? 0
    }

    func play() {
        guard let url = recordingURL else { return }

        if isPlaying {
            audioPlayer?.stop()
            isPlaying = false
            return
        }

        let session = AVAudioSession.sharedInstance()
        try? session.setCategory(.playback, mode: .default)
        try? session.setActive(true)

        audioPlayer = try? AVAudioPlayer(contentsOf: url)
        audioPlayer?.play()
        isPlaying = true

        DispatchQueue.main.asyncAfter(deadline: .now() + (audioPlayer?.duration ?? 0)) { [weak self] in
            self?.isPlaying = false
        }
    }
}
