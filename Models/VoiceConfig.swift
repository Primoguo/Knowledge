// Knowledge/Models/VoiceConfig.swift
import Foundation

/// 语音合成引擎类型
enum TTSEngine: String, Codable, CaseIterable {
    case system = "system"           // iOS 17+ Neural TTS（默认）
    case edgeTTS = "edgeTTS"         // Edge TTS 云端（免费）
    case legacySystem = "legacySystem"      // 传统系统 TTS（降级兼容）

    var displayName: String {
        switch self {
        case .system: return "Apple Neural TTS"
        case .edgeTTS: return "Knowledge 云端语音"
        case .legacySystem: return "传统系统 TTS"
        }
    }

    var description: String {
        switch self {
        case .system: return "iOS 17+ 神经网络增强版，音质自然，离线可用 "
        case .edgeTTS: return "微软 Neural 云端合成，中文音色丰富，免费使用"
        case .legacySystem: return "兼容旧版本 iOS，音质较基础"
        }
    }
    
    /// 是否支持当前设备
    var isSupported: Bool {
        switch self {
        case .system:
            if #available(iOS 17.0, *) {
                return true
            } else {
                return false
            }
        case .edgeTTS, .legacySystem:
            return true
        }
    }
    
    /// 是否需要网络
    var requiresNetwork: Bool {
        switch self {
        case .edgeTTS: return true
        case .system, .legacySystem: return false
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
    /// Edge TTS 音色 ID（如 zh-CN-XiaoxiaoNeural）
    var edgeVoiceId: String?

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
