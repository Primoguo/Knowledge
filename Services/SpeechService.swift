// Knowledge/Services/SpeechService.swift
import Foundation
import AVFoundation

final class SpeechService: NSObject, SpeechSynthesizerProtocol, AVSpeechSynthesizerDelegate {

    private(set) var state: PlaybackState = .idle
    var onPositionChange: ((Int) -> Void)?
    var onRangeChange: ((NSRange) -> Void)?
    var onError: ((Error) -> Void)?

    private let synthesizer = AVSpeechSynthesizer()
    private var fullText: String = ""
    private var config: VoiceConfig = .defaultConfig
    private var currentRange = NSRange(location: 0, length: 0)
    private var isManuallyStopped = false

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
        self.isManuallyStopped = false

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
        utterance.rate = config.rate
        utterance.pitchMultiplier = config.pitchMultiplier
        utterance.volume = config.volume

        if let identifier = config.voiceIdentifier {
            utterance.voice = AVSpeechSynthesisVoice(identifier: identifier)
        } else {
            utterance.voice = AVSpeechSynthesisVoice(language: config.language)
        }

        synthesizer.speak(utterance)
        updateState(.playing)
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
        isManuallyStopped = true
        synthesizer.stopSpeaking(at: .immediate)
        updateState(.idle)
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
        guard !isManuallyStopped else { return }
        let nextPosition = currentRange.location + currentRange.length
        let nsText = fullText as NSString
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
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
