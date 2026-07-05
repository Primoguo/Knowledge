// Knowledge/ViewModels/SpeakerViewModel.swift
import Foundation
import Combine

/// 主 ViewModel（Facade），对外暴露统一接口
/// 内部将播放控制和文档管理委托给子组件
@MainActor
final class SpeakerViewModel: ObservableObject {

    // MARK: - Published

    @Published var state: PlaybackState = .idle
    @Published var currentDocument: Document?
    @Published var progress: Double = 0.0
    @Published var currentPositionText: String = "00:00"
    @Published var voiceConfig: VoiceConfig = .defaultConfig
    /// 当前朗读的字符范围（全文绝对位置），用于 UI 高亮
    @Published var highlightRange: NSRange = NSRange(location: 0, length: 0)

    // MARK: - Dependencies（可注入，方便测试）

    private var synthesizer: SpeechSynthesizerProtocol
    private let nowPlaying: NowPlayingService
    private let audioSession: AudioSessionService
    private let errorHandler: ErrorHandler

    // 持有引擎实例
    private let systemSynthesizer = SpeechService()
    private let cosyVoiceSynthesizer = CosyVoiceSynthesizer()

    // AI 总结状态
    @Published var summaryResult: SummaryResult?
    @Published var isGeneratingSummary = false
    @Published var summaryError: String?

    // MARK: - Internal State

    private var cancellables = Set<AnyCancellable>()
    private var currentPosition = 0

    // MARK: - Init

    init(
        synthesizer: SpeechSynthesizerProtocol? = nil,
        nowPlaying: NowPlayingService = .shared,
        audioSession: AudioSessionService = .shared,
        errorHandler: ErrorHandler = .shared
    ) {
        self.synthesizer = synthesizer ?? SpeechService()
        self.nowPlaying = nowPlaying
        self.audioSession = audioSession
        self.errorHandler = errorHandler
        setupBindings()
    }

    /// 根据配置切换语音引擎
    func switchEngine(to engine: TTSEngine) {
        switch engine {
        case .system:
            synthesizer = systemSynthesizer
        case .knowledgeVoice:
            synthesizer = cosyVoiceSynthesizer
        }
        voiceConfig.engine = engine
        saveConfig(voiceConfig)
        setupBindings()

        // 如果正在播放，用新引擎重新开始
        if state == .playing, let doc = currentDocument {
            let pos = currentPosition
            synthesizer.stop()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                guard let self else { return }
                self.synthesizer.speak(text: doc.extractedText, from: pos, config: self.voiceConfig)
            }
        }
    }

    // MARK: - Document Loading

    func loadDocument(_ document: Document) {
        stop()
        currentDocument = document
        let savedConfig = loadConfig()

        // 自动检测文档语言并匹配语音
        if !document.extractedText.isEmpty {
            voiceConfig = LanguageDetector.detectAndApply(for: document.extractedText, currentConfig: savedConfig)
        } else {
            voiceConfig = savedConfig
        }

        progress = document.progress
        currentPosition = document.currentPosition
        updatePositionText()
    }

    // MARK: - Playback Control

    func togglePlayPause() {
        switch state {
        case .idle, .paused: play()
        case .playing: pause()
        case .finished: replay()
        }
    }

    func play() {
        guard let doc = currentDocument, !doc.extractedText.isEmpty else { return }
        audioSession.activate()
        if state == .paused {
            synthesizer.resume()
        } else {
            synthesizer.speak(text: doc.extractedText, from: doc.currentPosition, config: voiceConfig)
        }
        updateNowPlaying()
    }

    func pause() {
        synthesizer.pause()
        savePosition()
    }

    func stop() {
        synthesizer.stop()
        audioSession.deactivate()
        nowPlaying.clear()
        savePosition()
    }

    func replay() {
        guard let doc = currentDocument else { return }
        doc.currentPosition = 0
        currentPosition = 0
        savePosition()
        play()
    }

    func skipForward() { synthesizer.skipForward(by: 30) }
    func skipBackward() { synthesizer.skipBackward(by: 15) }

    func seekTo(progress: Double) {
        guard let doc = currentDocument else { return }
        let target = Int(Double(doc.totalLength) * progress)
        synthesizer.stop()
        if state == .playing || state == .paused {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
                guard let self else { return }
                self.synthesizer.speak(text: doc.extractedText, from: target, config: self.voiceConfig)
            }
        } else {
            currentPosition = target
            updateProgress(target)
            savePosition()
        }
    }

    // MARK: - Config

    func updateConfig(_ config: VoiceConfig) {
        voiceConfig = config
        saveConfig(config)
        guard state == .playing, let doc = currentDocument else { return }
        let pos = currentPosition
        synthesizer.stop()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            guard let self else { return }
            self.synthesizer.speak(text: doc.extractedText, from: pos, config: config)
        }
    }

    // MARK: - AI Summary

    /// 为当前文档生成 AI 摘要
    func generateSummary() {
        guard let doc = currentDocument, !doc.extractedText.isEmpty else { return }

        // 如果已有缓存摘要，直接返回
        if let cached = doc.summary, let result = SummaryResult.fromJSON(cached) {
            summaryResult = result
            return
        }

        isGeneratingSummary = true
        summaryError = nil

        Task {
            do {
                let result = try await AISummaryService.shared.generateSummary(for: doc.extractedText)
                await MainActor.run {
                    summaryResult = result
                    isGeneratingSummary = false
                    // 缓存到 Document
                    doc.summary = result.toJSON()
                }
            } catch {
                await MainActor.run {
                    summaryError = error.localizedDescription
                    isGeneratingSummary = false
                }
            }
        }
    }

    /// 朗读 AI 摘要
    func readSummaryAloud() {
        guard let result = summaryResult else { return }
        let summaryText = result.content + "\n\n" + result.keyPoints.joined(separator: "\n")
        synthesizer.stop()
        synthesizer.speak(text: summaryText, from: 0, config: voiceConfig)
    }

    // MARK: - Private: Bindings

    private func setupBindings() {
        // 播放位置同步
        synthesizer.onPositionChange = { [weak self] pos in
            Task { @MainActor in
                guard let self else { return }
                self.currentPosition = pos
                self.updateProgress(pos)
                self.updateNowPlaying()
            }
        }

        // 朗读范围同步（高亮跟随）
        synthesizer.onRangeChange = { [weak self] range in
            Task { @MainActor in
                self?.highlightRange = range
            }
        }

        // 引擎错误处理
        synthesizer.onError = { [weak self] error in
            Task { @MainActor in
                guard let self else { return }
                print("🔊 TTS 引擎错误: \(error.localizedDescription)")
                // Knowledge Voice 出错时降级到系统 TTS
                if self.voiceConfig.engine == .knowledgeVoice {
                    print("⬇️ 降级到系统 TTS")
                    self.voiceConfig.engine = .system
                    self.synthesizer = self.systemSynthesizer
                    self.setupBindings()
                    self.saveConfig(self.voiceConfig)
                }
            }
        }

        // 监听状态变化（通过 Combine）
        Timer.publish(every: 0.1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self else { return }
                let newState = self.synthesizer.state
                if self.state != newState {
                    self.state = newState
                    if newState == .finished || newState == .idle { self.savePosition() }
                }
            }
            .store(in: &cancellables)

        // 远程控制
        nowPlaying.onPlayPause = { [weak self] in Task { @MainActor in self?.togglePlayPause() } }
        nowPlaying.onSkipForward = { [weak self] in Task { @MainActor in self?.skipForward() } }
        nowPlaying.onSkipBackward = { [weak self] in Task { @MainActor in self?.skipBackward() } }
    }

    // MARK: - Private: Helpers

    private func updateProgress(_ position: Int) {
        guard let doc = currentDocument else { return }
        doc.currentPosition = position
        if doc.totalLength > 0 {
            progress = Double(position) / Double(doc.totalLength)
        }
        updatePositionText()
    }

    private func updatePositionText() {
        let sec = currentPosition / 3
        currentPositionText = String(format: "%02d:%02d", sec / 60, sec % 60)
    }

    private func updateNowPlaying() {
        guard let doc = currentDocument else { return }
        let totalSec = doc.totalLength / 3
        let elapsedSec = currentPosition / 3
        nowPlaying.update(
            title: doc.title,
            duration: TimeInterval(totalSec),
            elapsed: TimeInterval(elapsedSec),
            rate: state == .playing ? 1.0 : 0.0
        )
    }

    private func savePosition() {
        guard let doc = currentDocument else { return }
        doc.currentPosition = currentPosition
        doc.lastOpenedDate = Date()
    }

    private func loadConfig() -> VoiceConfig {
        guard let data = UserDefaults.standard.data(forKey: "voiceConfig"),
              let c = try? JSONDecoder().decode(VoiceConfig.self, from: data) else { return .defaultConfig }
        return c
    }

    private func saveConfig(_ config: VoiceConfig) {
        if let data = try? JSONEncoder().encode(config) {
            UserDefaults.standard.set(data, forKey: "voiceConfig")
        }
    }
}
