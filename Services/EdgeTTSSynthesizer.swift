// Knowledge/Services/EdgeTTSSynthesizer.swift
import Foundation
import AVFoundation

/// Edge TTS 引擎适配器，实现 SpeechSynthesizerProtocol
/// 通过 naolizhi.cn 服务器中转调用微软 Edge TTS
/// 支持段落预加载，实现无缝衔接播放
final class EdgeTTSSynthesizer: NSObject, SpeechSynthesizerProtocol {
    // MARK: - Protocol Properties

    private(set) var state: PlaybackState = .idle
    var onPositionChange: ((Int) -> Void)?
    var onRangeChange: ((NSRange) -> Void)?
    var onError: ((Error) -> Void)?

    // MARK: - Internal State

    private let service = EdgeTTSService.shared
    private var audioPlayer: AVAudioPlayer?
    private var currentSegmentIndex = 0
    private var segments: [String] = []
    private var segmentStartPositions: [Int] = []
    private var currentConfig: VoiceConfig = .defaultConfig
    private var synthesisTask: Task<Void, Never>?

    /// 预加载缓存（下一段音频数据 + 合成语速，避免段落间卡顿）
    private var prefetchedData: (index: Int, data: Data, rate: Float)?

    /// 段落播放完成的 continuation（实现 Task 等待播放结束）
    private var playbackContinuation: CheckedContinuation<Void, Never>?

    /// 当前段落合成时使用的语速（用于 rate 补偿）
    private var currentSegmentSynthesisRate: Float = 1.0

    /// 段落内偏移（seek 时非零，表示从段落中间开始）
    private var seekOffsetInSegment: Int = 0

    // MARK: - SpeechSynthesizerProtocol

    func speak(text: String, from position: Int, config: VoiceConfig) {
        stop()
        currentConfig = config

        let voice = resolveVoice(from: config)

        // 分段：每段最多 2000 字符（Edge TTS 服务器限制 5000）
        segments = splitText(text, maxLength: 2000)
        currentSegmentIndex = 0
        segmentStartPositions = calculateSegmentPositions(text: text, segments: segments)

        // 从 position 开始，跳到对应段落
        seekOffsetInSegment = 0
        if position > 0 {
            for (i, start) in segmentStartPositions.enumerated() {
                if start <= position && (i == segmentStartPositions.count - 1 || segmentStartPositions[i + 1] > position) {
                    currentSegmentIndex = i
                    seekOffsetInSegment = position - start
                    break
                }
            }
        }

        state = .playing
        startPlayback(voice: voice)
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
        prefetchTask?.cancel()
        positionTimer?.invalidate()
        positionTimer = nil
        audioPlayer?.stop()
        audioPlayer = nil
        playbackContinuation?.resume()
        playbackContinuation = nil
        prefetchedData = nil
        prefetchTask = nil
        state = .idle
    }

    func skipForward(by seconds: TimeInterval) {
        guard let player = audioPlayer else { return }
        let newTime = min(player.currentTime + seconds, player.duration)
        player.currentTime = newTime
    }

    func skipBackward(by seconds: TimeInterval) {
        guard let player = audioPlayer else { return }
        let newTime = max(player.currentTime - seconds, 0)
        player.currentTime = newTime
    }

    // MARK: - Private

    private func resolveVoice(from config: VoiceConfig) -> String {
        if let edgeVoice = config.edgeVoiceId {
            return edgeVoice
        }
        // 默认使用晓晓（中文女声，最自然）
        return "zh-CN-XiaoxiaoNeural"
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

        for segment in segments {
            positions.append(currentPos)
            currentPos += (segment as NSString).length
        }

        return positions
    }

    // MARK: - Synthesis Pipeline（预加载 + 无缝衔接）

    /// 预加载任务（后台运行，不阻塞主播放循环）
    private var prefetchTask: Task<Void, Never>?

    /// 主播放流水线：合成 → 播放 → 等待完成 → 下一段
    private func startPlayback(voice: String) {
        synthesisTask = Task { @MainActor [weak self] in
            guard let self else { return }

            for index in self.currentSegmentIndex..<self.segments.count {
                guard !Task.isCancelled, self.state == .playing else { break }

                let segment = self.segments[index]

                do {
                    // 使用预加载缓存或重新合成
                    let audioData: Data
                    if let prefetch = self.prefetchedData, prefetch.index == index {
                        audioData = prefetch.data
                        self.prefetchedData = nil
                        self.currentSegmentSynthesisRate = prefetch.rate
                    } else {
                        self.prefetchedData = nil
                        let synthRate = self.currentConfig.rate
                        audioData = try await self.service.synthesize(
                            text: segment, voice: voice, rate: synthRate
                        )
                        self.currentSegmentSynthesisRate = synthRate
                    }

                    guard !Task.isCancelled, self.state == .playing else { break }

                    // 取消上一次预加载任务
                    self.prefetchTask?.cancel()
                    self.prefetchTask = nil

                    // 写入临时文件
                    let tempURL = FileManager.default.temporaryDirectory
                        .appendingPathComponent("edgetts_\(UUID().uuidString).mp3")
                    try audioData.write(to: tempURL)

                    // 开始播放（不等待结束）
                    self.playAudio(url: tempURL, segmentIndex: index)

                    // 后台预加载下一段（不阻塞主循环）
                    if index + 1 < self.segments.count {
                        let nextSegment = self.segments[index + 1]
                        let service = self.service
                        let rate = self.currentConfig.rate
                        self.prefetchTask = Task { [weak self] in
                            if let nextData = try? await service.synthesize(
                                text: nextSegment, voice: voice, rate: rate
                            ) {
                                await MainActor.run {
                                    self?.prefetchedData = (index: index + 1, data: nextData, rate: rate)
                                }
                            }
                        }
                    }

                    // 等待当前段落播放结束（delegate 回调 resume）
                    await withCheckedContinuation { (cont: CheckedContinuation<Void, Never>) in
                        self.playbackContinuation = cont
                    }
                } catch {
                    guard !Task.isCancelled else { break }
                    self.onError?(error)
                    self.state = .idle
                    return
                }
            }

            if self.state == .playing {
                self.state = .finished
            }
        }
    }

    @MainActor
    private func playAudio(url: URL, segmentIndex: Int) {
        guard state == .playing else { return }

        do {
            audioPlayer = try AVAudioPlayer(contentsOf: url)
            audioPlayer?.delegate = self
            audioPlayer?.enableRate = true
            audioPlayer?.play()

            // 应用语速补偿：合成语速 vs 当前期望语速
            applyRateCompensation()

            let basePosition = segmentStartPositions[min(segmentIndex, segmentStartPositions.count - 1)]
            let segmentLen = segmentIndex < segments.count
                ? (segments[segmentIndex] as NSString).length
                : 0

            // seek 偏移：第一段用 seekOffsetInSegment，后续段落从 0 开始
            let offset = (segmentIndex == self.currentSegmentIndex) ? self.seekOffsetInSegment : 0

            // 如果 seek 到段落中间，估算音频跳转位置
            if offset > 0, segmentLen > 0, let player = audioPlayer, player.duration > 0 {
                let skipFraction = Double(offset) / Double(segmentLen)
                player.currentTime = player.duration * skipFraction
            }

            onPositionChange?(basePosition + offset)
            onRangeChange?(NSRange(location: basePosition + offset, length: segmentLen - offset))

            // 段落内高亮跟随：每 0.5 秒按比例更新当前位置
            startPositionUpdateTimer(basePosition: basePosition, segmentLength: segmentLen, seekOffset: offset)
        } catch {
            onError?(error)
        }
    }

    // MARK: - Rate Control

    /// 更新语速（不重启播放，立即通过 AVAudioPlayer.rate 生效）
    func updateRate(_ rate: Float) {
        currentConfig.rate = rate
        applyRateCompensation()
    }

    /// 计算并应用 AVAudioPlayer 播放速率补偿
    private func applyRateCompensation() {
        guard let player = audioPlayer, currentSegmentSynthesisRate > 0 else { return }
        let compensation = currentConfig.rate / currentSegmentSynthesisRate
        // 限制在 AVAudioPlayer 支持的范围内
        player.rate = max(0.5, min(2.0, compensation))
    }

    private var positionTimer: Timer?

    /// 段落内定时更新高亮位置（按播放时间比例估算字符位置）
    private func startPositionUpdateTimer(basePosition: Int, segmentLength: Int, seekOffset: Int = 0) {
        positionTimer?.invalidate()
        positionTimer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            guard let self, let player = self.audioPlayer, segmentLength > 0 else { return }
            let progress = player.duration > 0 ? player.currentTime / player.duration : 0
            let charOffset = seekOffset + Int(Double(segmentLength - seekOffset) * progress)
            let absPos = basePosition + charOffset
            self.onPositionChange?(absPos)
            self.onRangeChange?(NSRange(location: absPos, length: max(0, segmentLength - charOffset)))
        }
    }
}

// MARK: - AVAudioPlayerDelegate

extension EdgeTTSSynthesizer: AVAudioPlayerDelegate {
    func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
        positionTimer?.invalidate()
        // 通知 Task 循环：当前段落播放结束，继续下一段
        playbackContinuation?.resume()
        playbackContinuation = nil
    }
}
