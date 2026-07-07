// Knowledge/Models/VoiceConfig.swift
import Foundation

/// 语音合成引擎类型
enum TTSEngine: String, Codable, CaseIterable {
    case system = "system"           // iOS 17+ Neural TTS（默认）
    case knowledgeVoice = "knowledgeVoice"  // CosyVoice API（高级功能）
    case legacySystem = "legacySystem"      // 传统系统 TTS（降级兼容）

    var displayName: String {
        switch self {
        case .system: return "Apple Neural TTS"
        case .knowledgeVoice: return "Knowledge Voice"
        case .legacySystem: return "传统系统 TTS"
        }
    }

    var description: String {
        switch self {
        case .system: return "iOS 17+ 神经网络增强版，音质自然，离线可用 "
        case .knowledgeVoice: return "AI 云端合成，支持语音克隆，需配置 API Key"
        case .legacySystem: return "兼容旧版本 iOS，音质较基础"
        }
    }
    
    /// 是否支持当前设备
    var isSupported: Bool {
        switch self {
        case .system:
            // Apple Neural TTS 需要 iOS 17+
            if #available(iOS 17.0, *) {
                return true
            } else {
                return false
            }
        case .knowledgeVoice, .legacySystem:
            // Knowledge Voice 和传统 TTS 所有版本都支持
            return true
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
    /// Knowledge Voice 克隆音色 ID
    var clonedVoiceId: String?
    /// Knowledge Voice 预设音色 ID
    var presetVoiceId: String?

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
