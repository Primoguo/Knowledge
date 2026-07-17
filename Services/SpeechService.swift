// Knowledge/Services/SpeechService.swift
import Foundation
import AVFoundation
import ObjectiveC

/// 用于给 AVSpeechUtterance 绑定 generation tag 的关联对象 key
private var utteranceGenerationKey: UInt8 = 0

final class SpeechService: NSObject, SpeechSynthesizerProtocol, AVSpeechSynthesizerDelegate {

    private(set) var state: PlaybackState = .idle
    var onPositionChange: ((Int) -> Void)?
    var onRangeChange: ((NSRange) -> Void)?
    var onError: ((Error) -> Void)?

    private let synthesizer = AVSpeechSynthesizer()
    private var fullText: String = ""
    private var config: VoiceConfig = .defaultConfig
    private var currentRange = NSRange(location: 0, length: 0)
    /// 递增计数器，防止 seek 后旧 utterance 的 didFinish 回调触发续播
    private var speakGeneration: UInt64 = 0

    private static let charsPerSecond: Int = 3

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    deinit {
        synthesizer.delegate = nil
        synthesizer.stopSpeaking(at: .immediate)
    }

    func speak(text: String, from position: Int = 0, config: VoiceConfig = .defaultConfig) {
        self.fullText = text
        self.config = config
        self.speakGeneration &+= 1
        let thisGeneration = self.speakGeneration

        let nsText = text as NSString
        guard position < nsText.length else {
            updateState(.finished)
            return
        }

        let remainingLength = nsText.length - position
        var chunkLength = min(remainingLength, 500)

        // 尝试在自然断点截断
        if position + chunkLength < nsText.length {
            let searchRange = NSRange(location: position + chunkLength - 100, length: 100)
            for marker in ["。", "！", "？", "\n\n", ". ", "! ", "? "] {
                let markerRange = nsText.range(of: marker, options: [], range: searchRange)
                if markerRange.location != NSNotFound {
                    chunkLength = markerRange.location + markerRange.length - position
                    break
                }
            }
        }

        currentRange = NSRange(location: position, length: chunkLength)
        let chunk = nsText.substring(with: currentRange)

        let utterance = AVSpeechUtterance(string: chunk)
        // 给 utterance 打上当前 generation tag
        objc_setAssociatedObject(utterance, &utteranceGenerationKey, thisGeneration, .OBJC_ASSOCIATION_RETAIN)
        utterance.rate = config.rate
        utterance.pitchMultiplier = config.pitchMultiplier
        utterance.volume = config.volume

        // 根据引擎类型选择语音质量
        if #available(iOS 17.0, *) {
            // iOS 17+ 使用 Neural TTS（增强版）
            if let identifier = config.voiceIdentifier {
                utterance.voice = AVSpeechSynthesisVoice(identifier: identifier)
            } else {
                utterance.voice = AVSpeechSynthesisVoice(language: config.language)
            }
        } else {
            // iOS < 17 降级到传统 TTS
            if let identifier = config.voiceIdentifier {
                utterance.voice = AVSpeechSynthesisVoice(identifier: identifier)
            } else {
                utterance.voice = AVSpeechSynthesisVoice(language: config.language)
            }
        }

        synthesizer.speak(utterance)
        // 只有最新一代的 speak 才更新状态（防止旧回调覆盖）
        if thisGeneration == self.speakGeneration {
            updateState(.playing)
        }
    }

    func pause() {
        guard state == .playing else { return }
        synthesizer.pauseSpeaking(at: .immediate)
        updateState(.paused)
    }

    func resume() {
        guard state == .paused else { return }
        synthesizer.continueSpeaking()
        updateState(.playing)
    }

    func stop() {
        speakGeneration &+= 1  // 使所有进行中的回调失效
        synthesizer.stopSpeaking(at: .immediate)
        updateState(.idle)
    }

    func updateRate(_ rate: Float) {
        config.rate = rate
        // AVSpeechSynthesizer 无法动态修改正在播放的 utterance 语速
        // 新的 rate 会在下一个 chunk 或 resume 时生效
    }

    func skipForward(by seconds: TimeInterval = 30) {
        let charsToSkip = Int(seconds) * Self.charsPerSecond
        let nsText = fullText as NSString
        let newPosition = min(currentRange.location + charsToSkip, nsText.length)
        synthesizer.stopSpeaking(at: .immediate)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            guard let self else { return }
            if newPosition < nsText.length {
                self.speak(text: self.fullText, from: newPosition, config: self.config)
            } else {
                self.updateState(.finished)
            }
        }
    }

    func skipBackward(by seconds: TimeInterval = 15) {
        let newPosition = max(currentRange.location - Int(seconds) * Self.charsPerSecond, 0)
        synthesizer.stopSpeaking(at: .immediate)
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) { [weak self] in
            guard let self else { return }
            self.speak(text: self.fullText, from: newPosition, config: self.config)
        }
    }

    // MARK: - AVSpeechSynthesizerDelegate

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        // 从 utterance 上读取绑定的 generation tag
        let utteranceGen = (objc_getAssociatedObject(utterance, &utteranceGenerationKey) as? UInt64) ?? 0
        let nextPosition = currentRange.location + currentRange.length
        let nsText = fullText as NSString
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            // 只有当前 generation 匹配时才续播
            guard utteranceGen == self.speakGeneration else {
                print("🔇 didFinish: utterance gen \(utteranceGen) != current \(self.speakGeneration), ignoring")
                return
            }
            if nextPosition >= nsText.length {
                self.onPositionChange?(nsText.length)
                self.updateState(.finished)
            } else {
                self.onPositionChange?(nextPosition)
                self.speak(text: self.fullText, from: nextPosition, config: self.config)
            }
        }
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, willSpeakRangeOfSpeechString characterRange: NSRange, utterance: AVSpeechUtterance) {
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            let pos = self.currentRange.location + characterRange.location
            let range = NSRange(location: self.currentRange.location + characterRange.location,
                                length: characterRange.length)
            self.onPositionChange?(pos)
            self.onRangeChange?(range)
        }
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        // 静默处理取消事件
    }

    private func updateState(_ newState: PlaybackState) {
        DispatchQueue.main.async { [weak self] in
            self?.state = newState
        }
    }
}
