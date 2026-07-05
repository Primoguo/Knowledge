// Knowledge/Services/CosyVoiceSynthesizer.swift
import Foundation
import AVFoundation

/// CosyVoice 引擎适配器，实现 SpeechSynthesizerProtocol
/// 将阿里云 CosyVoice HTTP API 封装为符合引擎协议的形式
final class CosyVoiceSynthesizer: NSObject, SpeechSynthesizerProtocol {
    // MARK: - Protocol Properties

    private(set) var state: PlaybackState = .idle
    var onPositionChange: ((Int) -> Void)?
    var onRangeChange: ((NSRange) -> Void)?
    var onError: ((Error) -> Void)?

    // MARK: - Internal State

    private let service = CosyVoiceService.shared
    private var audioPlayer: AVAudioPlayer?
    private var currentSegmentIndex = 0
    private var segments: [String] = []
    private var segmentStartPositions: [Int] = []  // 每段在全文中的起始位置
    private var currentConfig: VoiceConfig = .defaultConfig
    private var synthesisTask: Task<Void, Never>?
    private var isSynthesizing = false

    // MARK: - SpeechSynthesizerProtocol

    func speak(text: String, from position: Int, config: VoiceConfig) {
        stop()
        currentConfig = config

        let voiceId = resolveVoiceId(from: config)

        // 分段：每段最多 500 字符
        segments = splitText(text, maxLength: 500)
        currentSegmentIndex = 0
        segmentStartPositions = calculateSegmentPositions(text: text, segments: segments)

        // 从 position 开始，跳到对应段落
        if position > 0 {
            for (i, start) in segmentStartPositions.enumerated() {
                if start <= position && (i == segmentStartPositions.count - 1 || segmentStartPositions[i + 1] > position) {
                    currentSegmentIndex = i
                    break
                }
            }
        }

        state = .playing
        synthesizeAndPlay(from: voiceId)
    }

    func pause() {
        audioPlayer?.pause()
        state = .paused
    }

    func resume() {
        audioPlayer?.play()
        state = .playing
    }

    func stop() {
        synthesisTask?.cancel()
        audioPlayer?.stop()
        audioPlayer = nil
        state = .idle
        isSynthesizing = false
    }

    func skipForward(by seconds: TimeInterval) {
        guard let player = audioPlayer else { return }
        let newTime = min(player.currentTime + seconds, player.duration)
        player.currentTime = newTime
        // 估算位置
        let pos = estimatePosition(from: player)
        onPositionChange?(pos)
    }

    func skipBackward(by seconds: TimeInterval) {
        guard let player = audioPlayer else { return }
        let newTime = max(player.currentTime - seconds, 0)
        player.currentTime = newTime
        let pos = estimatePosition(from: player)
        onPositionChange?(pos)
    }

    // MARK: - Private

    private func resolveVoiceId(from config: VoiceConfig) -> String {
        if let cloneId = config.clonedVoiceId {
            return cloneId
        }
        if let presetId = config.presetVoiceId {
            return presetId
        }
        // 默认使用龙小春
        return "longxiaochun"
    }

    private func splitText(_ text: String, maxLength: Int) -> [String] {
        guard text.count > maxLength else { return [text] }

        var result: [String] = []
        var currentIndex = text.startIndex

        while currentIndex < text.endIndex {
            let endIndex = text.index(currentIndex, offsetBy: min(maxLength, text.distance(from: currentIndex, to: text.endIndex)), limitedBy: text.endIndex) ?? text.endIndex

            // 尝试在自然断点处截断
            var actualEnd = endIndex
            if endIndex < text.endIndex {
                let lookBack = text[..<endIndex]
                if let lastPeriod = lookBack.lastIndex(of: "。") ?? lookBack.lastIndex(of: "！") ?? lookBack.lastIndex(of: "？") {
                    actualEnd = text.index(after: lastPeriod)
                } else if let lastNewline = lookBack.lastIndex(of: "\n") {
                    actualEnd = text.index(after: lastNewline)
                } else if let lastComma = lookBack.lastIndex(of: "，") {
                    actualEnd = text.index(after: lastComma)
                } else if let lastSpace = lookBack.lastIndex(of: " ") {
                    actualEnd = text.index(after: lastSpace)
                }
            }

            let segment = String(text[currentIndex..<actualEnd])
            if !segment.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                result.append(segment)
            }
            currentIndex = actualEnd
        }

        return result
    }

    private func calculateSegmentPositions(text: String, segments: [String]) -> [Int] {
        var positions: [Int] = []
        var currentPos = 0
        let nsText = text as NSString

        for segment in segments {
            positions.append(currentPos)
            currentPos += (segment as NSString).length
        }

        return positions
    }

    private func synthesizeAndPlay(from voiceId: String) {
        guard !isSynthesizing else { return }
        isSynthesizing = true

        synthesisTask = Task { [weak self] in
            guard let self else { return }

            for index in self.currentSegmentIndex..<self.segments.count {
                guard !Task.isCancelled else { return }
                guard self.state == .playing else { return }

                let segment = self.segments[index]

                do {
                    let audioData = try await self.service.synthesize(
                        text: segment,
                        voiceId: voiceId,
                        rate: self.currentConfig.rate
                    )

                    guard !Task.isCancelled, self.state == .playing else { return }

                    // 保存临时文件并播放
                    let tempURL = FileManager.default.temporaryDirectory
                        .appendingPathComponent("cosyvoice_\(UUID().uuidString).mp3")
                    try audioData.write(to: tempURL)

                    await self.playAudio(url: tempURL, segmentIndex: index)
                } catch {
                    guard !Task.isCancelled else { return }
                    await MainActor.run {
                        self.onError?(error)
                        // 降级到系统 TTS
                        self.state = .idle
                    }
                    return
                }
            }

            await MainActor.run {
                self.state = .finished
                self.isSynthesizing = false
            }
        }
    }

    @MainActor
    private func playAudio(url: URL, segmentIndex: Int) {
        guard state == .playing else { return }

        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.delegate = self
            audioPlayer?.play()

            // 发送位置和范围更新
            let basePosition = segmentStartPositions[min(segmentIndex, segmentStartPositions.count - 1)]
            onPositionChange?(basePosition)

            if segmentIndex < segments.count {
                let segmentLen = (segments[segmentIndex] as NSString).length
                onRangeChange?(NSRange(location: basePosition, length: segmentLen))
            }

            // 定时更新位置
            startPositionTimer(basePosition: basePosition)
        } catch {
            onError?(error)
        }
    }

    private var positionTimer: Timer?

    private func startPositionTimer(basePosition: Int) {
        positionTimer?.invalidate()
        positionTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            guard let self, let player = self.audioPlayer else { return }
            let pos = self.estimatePosition(from: player, basePosition: basePosition)
            self.onPositionChange?(pos)
        }
    }

    private func estimatePosition(from player: AVAudioPlayer, basePosition: Int = 0) -> Int {
        // 粗略估算：每秒约 3 个字符
        let elapsedSeconds = Int(player.currentTime)
        let estimatedChars = elapsedSeconds * 3
        return basePosition + estimatedChars
    }
}

// MARK: - AVAudioPlayerDelegate

extension CosyVoiceSynthesizer: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        guard flag else { return }
        positionTimer?.invalidate()

        // 自动播放下一个段落
        currentSegmentIndex += 1
        if currentSegmentIndex < segments.count, state == .playing {
            let voiceId = resolveVoiceId(from: currentConfig)
            Task { @MainActor [weak self] in
                self?.synthesizeAndPlay(from: voiceId)
            }
        } else if currentSegmentIndex >= segments.count {
            state = .finished
            isSynthesizing = false
        }
    }
}
