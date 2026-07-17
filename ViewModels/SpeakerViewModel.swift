// Knowledge/ViewModels/SpeakerViewModel.swift
import Foundation
import Combine
import SwiftData

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
    private let edgeTTSSynthesizer = EdgeTTSSynthesizer()

    // AI 总结状态
    @Published var summaryResult: SummaryResult?
    @Published var isGeneratingSummary = false
    @Published var summaryError: String?

    /// Edge TTS 音色下线警告（非 nil 时显示提示）
    @Published var edgeVoiceWarning: String?

    @Published var companionMessages: [CompanionMessage] = []
    @Published var isAskingCompanion = false
    /// 标记伴读进入时是否暂停了朗读，退出时自动恢复
    var companionPausedPlay = false

    /// SwiftData 上下文（由 ContentView 注入）
    var modelContext: ModelContext?

    // MARK: - Internal State

    private var cancellables = Set<AnyCancellable>()
    private var currentPosition = 0
    /// 高亮更新防抖计时器（避免频繁 UI 刷新）
    private var highlightDebounceTimer: Timer?
    /// 状态轮询定时器（单独管理，避免 setupBindings 重复创建）
    private var statePollingCancellable: AnyCancellable?

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
        // 检查引擎是否支持当前设备
        if !engine.isSupported {
            print("⚠️ 引擎 \(engine.displayName) 不支持当前设备，使用默认引擎")
            return
        }
        
        let wasPlaying = (state == .playing)
        let pos = currentPosition

        // 先停止所有引擎（避免旧引擎继续播放）
        systemSynthesizer.stop()
        edgeTTSSynthesizer.stop()

        // 切换引擎指针
        switch engine {
        case .system, .legacySystem:
            synthesizer = systemSynthesizer
        case .edgeTTS:
            synthesizer = edgeTTSSynthesizer
        }
        voiceConfig.engine = engine
        saveConfig(voiceConfig)
        setupBindings()

        // 如果之前在播放，用新引擎从当前位置继续
        if wasPlaying, let doc = currentDocument {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                guard let self else { return }
                self.synthesizer.speak(text: doc.extractedText, from: pos, config: self.voiceConfig)
            }
        }
    }

    /// 轻量级引擎切换：仅切换合成器指针，不重启播放、不保存配置
    /// 用于 loadDocument 时恢复上次选择的引擎
    private func applyEngine(from config: VoiceConfig) {
        switch config.engine {
        case .system, .legacySystem:
            synthesizer = systemSynthesizer
        case .edgeTTS:
            synthesizer = edgeTTSSynthesizer
        }
        setupBindings()
    }

    /// 检查保存的 Edge TTS 音色是否仍在线，已下线则自动回退到默认
    private func checkEdgeVoiceAvailability() {
        edgeVoiceWarning = nil
        guard voiceConfig.engine == .edgeTTS, let voiceId = voiceConfig.edgeVoiceId else { return }

        Task {
            let available = await EdgeTTSService.shared.isVoiceAvailable(voiceId)
            if !available {
                let oldName = voiceId
                voiceConfig.edgeVoiceId = "zh-CN-XiaoxiaoNeural"
                saveConfig(voiceConfig)
                edgeVoiceWarning = "\(oldName) 已下线，已自动切换到“晓晓”"
                print("⚠️ Edge TTS 音色 \(oldName) 已下线，回退到晓晓")
            }
        }
    }

    // MARK: - Document Loading

    func loadDocument(_ document: Document) {
        stop()
        currentDocument = document
        // 切换文档时清除旧对话并加载新文档的历史对话
        CompanionService.shared.resetConversation()
        companionMessages = []
        if let ctx = modelContext {
            let entries = CompanionService.shared.loadConversation(documentId: document.id, context: ctx)
            companionMessages = entries.map { CompanionMessage(content: $0.content, isUser: $0.role == "user") }
        }
        let savedConfig = loadConfig()

        // 自动检测文档语言并匹配语音
        if !document.extractedText.isEmpty {
            voiceConfig = LanguageDetector.detectAndApply(for: document.extractedText, currentConfig: savedConfig)
        } else {
            voiceConfig = savedConfig
        }
        
        // 如果使用 Apple Neural TTS，确保有音色 identifier
        if voiceConfig.engine == .system, #available(iOS 17.0, *), voiceConfig.voiceIdentifier == nil {
            if let recommended = SystemVoiceManager.shared.recommendedVoice(for: voiceConfig.language) {
                voiceConfig.voiceIdentifier = recommended.identifier
            }
        }

        // 根据加载的配置切换合成器（保持上次选择的引擎）
        applyEngine(from: voiceConfig)

        // 检查 Edge TTS 音色是否仍可用
        checkEdgeVoiceAvailability()

        progress = document.progress
        currentPosition = document.currentPosition
        updatePositionText()
    }

    // MARK: - Playback Control

    func togglePlayPause() {
        switch state {
        case .idle, .paused, .finished: play()
        case .playing: pause()
        }
    }

    func play() {
        guard let doc = currentDocument, !doc.extractedText.isEmpty else { return }
        audioSession.activate()
        if state == .paused {
            synthesizer.resume()
        } else {
            // 播放结束后自动从头开始
            if state == .finished {
                currentPosition = 0
                doc.currentPosition = 0
                progress = 0
                updatePositionText()
            }
            // 使用 self.currentPosition（seek 后立即更新，比 doc.currentPosition 更可靠）
            let startPos = currentPosition > 0 ? currentPosition : doc.currentPosition
            synthesizer.speak(text: doc.extractedText, from: startPos, config: voiceConfig)
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
        // 只有真正的从头播放按钮才重置位置
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
        let wasActive = (state == .playing || state == .paused)
        print("🎯 seekTo: progress=\(String(format: "%.2f", progress)), target=\(target), wasActive=\(wasActive), state=\(state), engine=\(voiceConfig.engine.displayName)")
        // 先更新位置，再 stop/speak，避免旧回调覆盖新位置
        currentPosition = target
        updateProgress(target)
        synthesizer.stop()
        if wasActive {
            // 延迟 50ms 等待 stop 完全生效，避免 AVSpeechSynthesizer 竞态
            let seekTarget = target
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
                guard let self else { return }
                // 二次确认位置没被旧回调覆盖
                self.currentPosition = seekTarget
                self.updateProgress(seekTarget)
                self.synthesizer.speak(text: doc.extractedText, from: seekTarget, config: self.voiceConfig)
            }
        } else {
            savePosition()
        }
    }

    // MARK: - Config

    func updateConfig(_ config: VoiceConfig) {
        let oldConfig = voiceConfig
        voiceConfig = config
        saveConfig(config)

        guard state == .playing else { return }

        // 如果只有语速变了，直接改播放速率，不重启
        var rateOnlyCheck = oldConfig
        rateOnlyCheck.rate = config.rate
        if rateOnlyCheck == config {
            synthesizer.updateRate(config.rate)
            return
        }

        // 其他配置变化需要重启
        guard let doc = currentDocument else { return }
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

        // 如果已有缓存摘要，直接返回（不消耗免费次数）
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
                    // 消耗免费试用次数（仅非 Premium 用户）
                    SubscriptionManager.shared.consumeAISummaryTrial()
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
    func readSummaryAloud(detailed: Bool = false) {
        guard let result = summaryResult else { return }
        let summaryText = result.readAloudText(detailed: detailed)
        synthesizer.stop()
        synthesizer.speak(text: summaryText, from: 0, config: voiceConfig)
    }

    // MARK: - AI 伴读

    /// 向 AI 提问
    func askCompanion(question: String) async {
        // 添加用户消息
        companionMessages.append(CompanionMessage(content: question, isUser: true))
        // 添加 loading 占位
        companionMessages.append(CompanionMessage(content: "", isUser: false, isLoading: true))

        isAskingCompanion = true

        // 提取当前朗读位置上下文
        let context = extractCompanionContext()

        do {
            let response = try await CompanionService.shared.ask(
                question: question,
                context: context,
                documentId: currentDocument?.id.uuidString,
                modelContext: modelContext
            )
            await MainActor.run {
                // 移除 loading 占位，添加真实回复
                companionMessages.removeAll { $0.isLoading }
                companionMessages.append(CompanionMessage(content: response, isUser: false))
                isAskingCompanion = false
                // 消耗免费试用次数（仅非 Premium 用户，仅首次提问消耗）
                if companionMessages.filter({ $0.isUser }).count == 1 {
                    SubscriptionManager.shared.consumeAICompanionTrial()
                }
            }
        } catch {
            await MainActor.run {
                companionMessages.removeAll { $0.isLoading }
                companionMessages.append(CompanionMessage(content: "⚠️ \(error.localizedDescription)", isUser: false))
                isAskingCompanion = false
            }
        }
    }

    /// 重置伴读对话
    func resetCompanion() {
        companionMessages.removeAll()
        CompanionService.shared.resetConversation(
            documentId: currentDocument?.id,
            context: modelContext
        )
    }

    /// 提取当前朗读位置前后的文本上下文（500 字范围）
    private func extractCompanionContext() -> String {
        guard let doc = currentDocument, !doc.extractedText.isEmpty else {
            return "（暂无朗读内容）"
        }
        let text = doc.extractedText
        let pos = currentPosition
        let range = 500
        let start = max(0, pos - range)
        let end = min(text.count, pos + range)

        let startIndex = text.index(text.startIndex, offsetBy: start)
        let endIndex = text.index(text.startIndex, offsetBy: end)
        return String(text[startIndex..<endIndex])
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

        // 朗读范围同步（高亮跟随）- 使用防抖避免频繁 UI 更新
        synthesizer.onRangeChange = { [weak self] range in
            Task { @MainActor in
                guard let self else { return }
                // 取消之前的定时器
                self.highlightDebounceTimer?.invalidate()
                // 设置新的防抖定时器（100ms 后更新 UI）
                self.highlightDebounceTimer = Timer.scheduledTimer(withTimeInterval: 0.1, repeats: false) { _ in
                    self.highlightRange = range
                }
            }
        }

        // 引擎错误处理
        synthesizer.onError = { [weak self] error in
            Task { @MainActor in
                guard let self else { return }
                print("🔊 TTS 引擎错误: \(error.localizedDescription)")
                // 云端引擎出错时临时降级到系统 TTS（不保存配置，下次打开仍用用户选择的引擎）
                if self.voiceConfig.engine == .edgeTTS {
                    print("⚠️ 临时降级到 Apple Neural TTS（用户引擎选择已保留）")
                    self.synthesizer = self.systemSynthesizer
                    self.setupBindings()
                    // 用系统 TTS 重新播放当前位置
                    if let doc = self.currentDocument, self.state == .playing {
                        let pos = self.currentPosition
                        self.synthesizer.speak(text: doc.extractedText, from: pos, config: self.voiceConfig)
                    }
                }
            }
        }

        // 监听状态变化（取消旧的，只保留一个定时器）
        statePollingCancellable?.cancel()
        statePollingCancellable = Timer.publish(every: 0.1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                guard let self else { return }
                let newState = self.synthesizer.state
                if self.state != newState {
                    self.state = newState
                    if newState == .finished || newState == .idle { self.savePosition() }

                    // 荔枝成长体系：播放时追踪收听时间
                    if newState == .playing {
                        LycheeLevelManager.shared.startTracking()
                    } else {
                        LycheeLevelManager.shared.stopTracking()
                    }
                }
            }

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

    private func saveConfig(_ config: VoiceConfig) {
        if let data = try? JSONEncoder().encode(config) {
            UserDefaults.standard.set(data, forKey: "voiceConfig")
            print("💾 保存配置: engine=\(config.engine.displayName), voice=\(config.edgeVoiceId ?? config.voiceIdentifier ?? "nil")")
        }
    }

    private func loadConfig() -> VoiceConfig {
        guard let data = UserDefaults.standard.data(forKey: "voiceConfig"),
              let c = try? JSONDecoder().decode(VoiceConfig.self, from: data) else {
            print("📂 加载配置: 无缓存，使用默认")
            return .defaultConfig
        }
        print("📂 加载配置: engine=\(c.engine.displayName), voice=\(c.edgeVoiceId ?? c.voiceIdentifier ?? "nil")")
        return c
    }
}
