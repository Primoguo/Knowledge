// Knowledge/Models/VoiceConfig.swift
import Foundation

/// 语音合成引擎类型
enum TTSEngine: String, Codable, CaseIterable {
    case system = "system"

    var displayName: String {
        switch self {
        case .system: return "系统 TTS"
        }
    }

    var description: String {
        switch self {
        case .system: return "iOS 系统内置语音，离线可用"
        }
    }
}

struct VoiceConfig: Equatable, Codable {
    /// 语速，范围 0.1 ~ 2.0，默认 0.5
    var rate: Float = 0.5
    var pitchMultiplier: Float = 1.0
    var volume: Float = 1.0
    var language: String = "zh-CN"
    var voiceIdentifier: String? = nil
    /// TTS 引擎选择
    var engine: TTSEngine = .system

    static let defaultConfig = VoiceConfig()

    /// 常用语速档位
    static let speedPresets: [(label: String, value: Float)] = [
        ("0.7x", 0.35),
        ("0.85x", 0.425),
        ("1x", 0.5),
        ("1.2x", 0.7),
        ("1.5x", 1.0),
        ("2x", 1.5),
        ("2.5x", 1.75),
        ("3x", 2.0),
    ]
}
