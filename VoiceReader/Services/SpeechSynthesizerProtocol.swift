// VoiceReader/Services/SpeechSynthesizerProtocol.swift
import Foundation

/// 语音合成引擎抽象协议，方便单元测试 mock
protocol SpeechSynthesizerProtocol: AnyObject {
    var state: PlaybackState { get }
    var onPositionChange: ((Int) -> Void)? { get set }
    /// 当前朗读的字符范围（全文绝对位置）
    var onRangeChange: ((NSRange) -> Void)? { get set }

    func speak(text: String, from position: Int, config: VoiceConfig)
    func pause()
    func resume()
    func stop()
    func skipForward(by seconds: TimeInterval)
    func skipBackward(by seconds: TimeInterval)
}
