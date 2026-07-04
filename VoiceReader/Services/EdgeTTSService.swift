// VoiceReader/Services/EdgeTTSService.swift
import Foundation
import AVFoundation

/// Edge TTS 语音合成引擎（微软免费 TTS）
/// 通过 WebSocket 连接微软语音服务，流式接收音频并播放
final class EdgeTTSService: NSObject, SpeechSynthesizerProtocol {

    // MARK: - SpeechSynthesizerProtocol

    private(set) var state: PlaybackState = .idle
    var onPositionChange: ((Int) -> Void)?
    var onRangeChange: ((NSRange) -> Void)?

    // MARK: - Internal State

    private var fullText: String = ""
    private var config: VoiceConfig = .defaultConfig
    private var currentPosition = 0
    private var isManuallyStopped = false

    // Audio playback
    private var audioPlayer: AVAudioPlayer?
    private var audioData = Data()

    // WebSocket
    private var webSocketTask: URLSessionWebSocketTask?
    private let urlSession: URLSession
    private var isConnected = false
    private var pendingSSML: String?

    // Chunking
    private var chunkIndex = 0
    private var totalChunks = 0
    private let maxCharsPerChunk = 1000

    // Estimated timing
    private static let charsPerSecond: Int = 4
    private var estimatedChunkDuration: TimeInterval = 0

    // Edge TTS voice mapping
    static let voiceMap: [String: String] = [
        "zh-CN": "zh-CN-XiaoxiaoNeural",
        "zh-HK": "zh-HK-HiuMaanNeural",
        "en-US": "en-US-JennyNeural",
        "en-GB": "en-GB-SoniaNeural",
        "ja-JP": "ja-JP-NanamiNeural",
        "ko-KR": "ko-KR-SunHiNeural",
    ]

    // MARK: - Init

    override init() {
        let config = URLSessionConfiguration.default
        config.timeoutIntervalForRequest = 30
        config.timeoutIntervalForResource = 120
        self.urlSession = URLSession(configuration: config)
        super.init()
    }

    deinit {
        stop()
    }

    // MARK: - Public API

    func speak(text: String, from position: Int, config: VoiceConfig) {
        stop()

        self.fullText = text
        self.config = config
        self.currentPosition = position
        self.isManuallyStopped = false
        self.chunkIndex = 0

        let nsText = text as NSString
        guard position < nsText.length else {
            updateState(.finished)
            return
        }

        // 估算总字符数
        let remainingText = nsText.substring(from: position)
        self.totalChunks = max(1, (remainingText.count + maxCharsPerChunk - 1) / maxCharsPerChunk)

        // 开始第一个 chunk
        speakNextChunk()
    }

    func pause() {
        guard state == .playing else { return }
        audioPlayer?.pause()
        updateState(.paused)
    }

    func resume() {
        guard state == .paused else { return }
        audioPlayer?.play()
        updateState(.playing)
    }

    func stop() {
        isManuallyStopped = true
        webSocketTask?.cancel(with: .normalClosure, reason: nil)
        webSocketTask = nil
        isConnected = false
        audioPlayer?.stop()
        audioPlayer = nil
        audioData = Data()
        pendingSSML = nil
        updateState(.idle)
    }

    func skipForward(by seconds: TimeInterval) {
        let charsToSkip = Int(seconds) * Self.charsPerSecond
        let nsText = fullText as NSString
        let newPos = min(currentPosition + charsToSkip, nsText.length)
        stop()
        if newPos < nsText.length {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
                self?.speak(text: self?.fullText ?? "", from: newPos, config: self?.config ?? .defaultConfig)
            }
        } else {
            updateState(.finished)
        }
    }

    func skipBackward(by seconds: TimeInterval) {
        let newPos = max(currentPosition - Int(seconds) * Self.charsPerSecond, 0)
        stop()
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) { [weak self] in
            self?.speak(text: self?.fullText ?? "", from: newPos, config: self?.config ?? .defaultConfig)
        }
    }

    // MARK: - Private: Chunk Management

    private func speakNextChunk() {
        guard !isManuallyStopped else { return }

        let nsText = fullText as NSString
        let start = currentPosition

        guard start < nsText.length else {
            updateState(.finished)
            return
        }

        let remaining = nsText.length - start
        var chunkLength = min(remaining, maxCharsPerChunk)

        // 在自然断点截断
        if start + chunkLength < nsText.length {
            let searchStart = max(start + chunkLength - 150, start)
            let searchLength = min(150, nsText.length - searchStart)
            let searchRange = NSRange(location: searchStart, length: searchLength)
            for marker in ["。", "！", "？", "\n\n", ". ", "! ", "? "] {
                let markerRange = nsText.range(of: marker, options: [], range: searchRange)
                if markerRange.location != NSNotFound {
                    chunkLength = markerRange.location + markerRange.length - start
                    break
                }
            }
        }

        let chunk = nsText.substring(with: NSRange(location: start, length: chunkLength))
        let chunkRange = NSRange(location: start, length: chunkLength)

        // 估算这个 chunk 的播放时长（Edge TTS 平均每秒约 4-5 个汉字）
        self.estimatedChunkDuration = Double(chunkLength) / Double(Self.charsPerSecond)

        // 生成 SSML
        let voiceName = Self.voiceMap[config.language] ?? Self.voiceMap["zh-CN"]!
        let rateStr: String
        let edgeRate = config.rate / 0.5 // 归一化：0.5 对应 1.0x
        if edgeRate <= 0.3 {
            rateStr = "-50%"
        } else if edgeRate >= 3.0 {
            rateStr = "+100%"
        } else {
            let pct = Int((edgeRate - 1.0) * 100)
            rateStr = pct >= 0 ? "+\(pct)%" : "\(pct)%"
        }

        let ssml = """
        <speak version="1.0" xmlns="http://www.w3.org/2001/10/synthesis" xmlns:mstts="http://www.w3.org/2001/mstts" xml:lang="\(config.language)">
            <voice name="\(voiceName)">
                <prosody rate="\(rateStr)" pitch="\(config.pitchMultiplier > 1 ? "+\(Int((config.pitchMultiplier - 1) * 100))%" : config.pitchMultiplier < 1 ? "\(Int((config.pitchMultiplier - 1) * 100))%" : "+0%")">
                    \(chunk.xmlEscaped)
                </prosody>
            </voice>
        </speak>
        """

        // 发送到 Edge TTS
        synthesize(ssml: ssml, chunkRange: chunkRange)
    }

    private func moveToNextChunk() {
        let nsText = fullText as NSString
        let nextStart = currentPosition
        if nextStart >= nsText.length {
            onPositionChange?(nsText.length)
            updateState(.finished)
        } else {
            speakNextChunk()
        }
    }

    // MARK: - WebSocket Communication

    private func synthesize(ssml: String, chunkRange: NSRange) {
        // Edge TTS WebSocket endpoint
        let urlString = "wss://speech.platform.bing.com/consumer/speech/synthesize/readaloud/edge/v1?TrustedClientToken=6A5AA1D4EAFF4E9FB37E23D68491D6F4"

        guard let url = URL(string: urlString) else {
            updateState(.idle)
            return
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 60

        webSocketTask = urlSession.webSocketTask(with: request)
        webSocketTask?.resume()

        isConnected = true
        audioData = Data()
        pendingSSML = ssml

        // 发送配置消息
        let configMessage = """
        Content-Type:application/json; charset=utf-8\r\nPath:speech.config\r\n\r\n
        {"context":{"synthesis":{"audio":{"metadataoptions":{"sentenceBoundaryEnabled":false,"wordBoundaryEnabled":true},"outputFormat":"audio-24khz-48kbitrate-mono-mp3"}}}}
        """

        webSocketTask?.send(.string(configMessage)) { [weak self] error in
            if let error = error {
                print("🔊 Edge TTS config error: \(error)")
                self?.handleError()
                return
            }
            // 发送 SSML
            let ssmlMessage = "X-RequestId:\(UUID().uuidString)\r\nContent-Type:application/ssml+xml\r\nPath:ssml\r\n\r\n\(ssml)"
            self?.webSocketTask?.send(.string(ssmlMessage)) { error in
                if let error = error {
                    print("🔊 Edge TTS SSML error: \(error)")
                    self?.handleError()
                    return
                }
                // 开始接收音频数据
                self?.receiveAudioData(chunkRange: chunkRange)
            }
        }
    }

    private func receiveAudioData(chunkRange: NSRange) {
        webSocketTask?.receive { [weak self] result in
            guard let self else { return }

            switch result {
            case .success(let message):
                switch message {
                case .data(let data):
                    // 检查是否是音频数据（包含 Path:audio 标记）
                    if let str = String(data: data, encoding: .utf8), str.contains("Path:audio") {
                        // 提取音频数据（跳过 headers）
                        if let audioStart = self.findAudioDataStart(in: data) {
                            self.audioData.append(data.subdata(in: audioStart..<data.count))
                        } else {
                            self.audioData.append(data)
                        }
                    } else if data.count > 100 {
                        // 可能是纯音频数据
                        self.audioData.append(data)
                    } else if let str = String(data: data, encoding: .utf8), str.contains("Path:turn.end") {
                        // 音频流结束，开始播放
                        self.playAudioData(chunkRange: chunkRange)
                        return
                    }
                    // 继续接收
                    self.receiveAudioData(chunkRange: chunkRange)

                case .string(let str):
                    if str.contains("Path:turn.end") {
                        self.playAudioData(chunkRange: chunkRange)
                        return
                    }
                    self.receiveAudioData(chunkRange: chunkRange)

                @unknown default:
                    self.receiveAudioData(chunkRange: chunkRange)
                }

            case .failure(let error):
                print("🔊 Edge TTS receive error: \(error)")
                // 如果已经有音频数据，尝试播放
                if !self.audioData.isEmpty {
                    self.playAudioData(chunkRange: chunkRange)
                } else {
                    self.handleError()
                }
            }
        }
    }

    private func findAudioDataStart(in data: Data) -> Int? {
        guard let str = String(data: data, encoding: .utf8) else { return nil }
        if let audioHeaderEnd = str.range(of: "Path:audio\r\n") {
            let offset = str.distance(from: str.startIndex, to: audioHeaderEnd.upperBound)
            // 跳过 Content-Type header
            let remaining = str[audioHeaderEnd.upperBound...]
            if let ctEnd = remaining.range(of: "\r\n\r\n") {
                let totalOffset = offset + str.distance(from: remaining.startIndex, to: ctEnd.upperBound)
                return totalOffset
            }
            return offset
        }
        return nil
    }

    private func playAudioData(chunkRange: NSRange) {
        guard !isManuallyStopped, !audioData.isEmpty else {
            cleanupConnection()
            moveToNextChunk()
            return
        }

        // 更新状态和位置
        currentPosition = chunkRange.location + chunkRange.length
        onPositionChange?(chunkRange.location)

        // 通知范围变化（模拟高亮整个 chunk）
        onRangeChange?(chunkRange)

        do {
            // 配置音频会话
            try AVAudioSession.sharedInstance().setCategory(.playback, mode: .spokenAudio, options: [.allowBluetoothHFP, .allowAirPlay])
            try AVAudioSession.sharedInstance().setActive(true)

            audioPlayer = try AVAudioPlayer(data: audioData)
            audioPlayer?.volume = config.volume
            audioPlayer?.delegate = audioDelegate
            audioPlayer?.prepareToPlay()
            audioPlayer?.play()
            updateState(.playing)

            // 启动位置追踪 Timer
            startPositionTracking(chunkRange: chunkRange)
        } catch {
            print("🔊 Edge TTS playback error: \(error)")
            cleanupConnection()
            moveToNextChunk()
        }
    }

    // MARK: - Position Tracking

    private var positionTimer: Timer?

    private func startPositionTracking(chunkRange: NSRange) {
        positionTimer?.invalidate()
        let startTime = Date()
        let chunkLength = chunkRange.length
        let startPos = chunkRange.location

        positionTimer = Timer.scheduledTimer(withTimeInterval: 0.2, repeats: true) { [weak self] timer in
            guard let self else { timer.invalidate(); return }
            let elapsed = Date().timeIntervalSince(startTime)
            let progress = min(elapsed / self.estimatedChunkDuration, 1.0)
            let currentPos = startPos + Int(Double(chunkLength) * progress)
            self.onPositionChange?(min(currentPos, startPos + chunkLength))
        }
    }

    // MARK: - Audio Delegate (internal class)

    private lazy var audioDelegate = AudioPlayerDelegate(service: self)

    private final class AudioPlayerDelegate: NSObject, AVAudioPlayerDelegate {
        weak var service: EdgeTTSService?

        init(service: EdgeTTSService) {
            self.service = service
        }

        func audioPlayerDidFinishPlaying(_ player: AVAudioPlayer, successfully flag: Bool) {
            guard let service else { return }
            service.positionTimer?.invalidate()
            service.positionTimer = nil
            service.audioPlayer = nil
            service.audioData = Data()
            service.cleanupConnection()
            service.moveToNextChunk()
        }

        func audioPlayerDecodeErrorDidOccur(_ player: AVAudioPlayer, error: Error?) {
            print("🔊 Edge TTS decode error: \(error?.localizedDescription ?? "unknown")")
            guard let service else { return }
            service.positionTimer?.invalidate()
            service.positionTimer = nil
            service.audioPlayer = nil
            service.audioData = Data()
            service.cleanupConnection()
            service.moveToNextChunk()
        }
    }

    // MARK: - Helpers

    private func handleError() {
        cleanupConnection()
        // 如果还没有播放过任何内容，标记为错误状态
        if chunkIndex == 0 && audioData.isEmpty {
            updateState(.idle)
        } else {
            moveToNextChunk()
        }
    }

    private func cleanupConnection() {
        webSocketTask?.cancel(with: .normalClosure, reason: nil)
        webSocketTask = nil
        isConnected = false
    }

    private func updateState(_ newState: PlaybackState) {
        DispatchQueue.main.async { [weak self] in
            self?.state = newState
        }
    }
}

// MARK: - String Extension for XML Escaping

private extension String {
    var xmlEscaped: String {
        self.replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
            .replacingOccurrences(of: "\"", with: "&quot;")
            .replacingOccurrences(of: "'", with: "&apos;")
    }
}
