// Knowledge/Services/SystemVoiceManager.swift
import Foundation
import AVFoundation

/// 系统语音管理器 - 提供 iOS 17+ Neural TTS 音色选择
@MainActor
final class SystemVoiceManager {
    
    static let shared = SystemVoiceManager()
    
    /// 获取所有可用的中文 Neural 音色（iOS 17+）
    var availableChineseVoices: [AVSpeechSynthesisVoice] {
        guard #available(iOS 17.0, *) else { return [] }
        
        return AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language.hasPrefix("zh-") || $0.language.hasPrefix("cmn-") }
            .sorted { $0.name < $1.name }
    }
    
    /// 获取所有可用的英文 Neural 音色（iOS 17+）
    var availableEnglishVoices: [AVSpeechSynthesisVoice] {
        guard #available(iOS 17.0, *) else { return [] }
        
        return AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language.hasPrefix("en-") }
            .sorted { $0.name < $1.name }
    }
    
    /// 根据语言代码获取推荐音色
    func recommendedVoice(for language: String) -> AVSpeechSynthesisVoice? {
        guard #available(iOS 17.0, *) else {
            return AVSpeechSynthesisVoice(language: language)
        }
        
        // 优先选择 Neural 增强版
        let voices = AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language == language }
        
        // 尝试找 Enhanced 或 Premium 版本
        if let enhanced = voices.first(where: { 
            $0.quality == .enhanced || $0.name.contains("Enhanced") || $0.name.contains("Premium")
        }) {
            return enhanced
        }
        
        // 其次选择默认
        return voices.first ?? AVSpeechSynthesisVoice(language: language)
    }
    
    /// 检查指定 identifier 是否为 Neural 音色
    func isNeuralVoice(identifier: String) -> Bool {
        guard #available(iOS 17.0, *) else { return false }
        
        if let voice = AVSpeechSynthesisVoice(identifier: identifier) {
            return voice.quality == .enhanced || voice.quality == .premium
        }
        return false
    }
}

/// 系统音色信息（用于 UI 展示）
struct SystemVoiceInfo: Identifiable, Equatable {
    let id: String          // voice.identifier
    let name: String        // 显示名称
    let language: String    // 语言代码
    let quality: String     // 音质描述
    let isNeural: Bool      // 是否为 Neural 音色
    
    init(voice: AVSpeechSynthesisVoice) {
        self.id = voice.identifier
        self.name = voice.name
        self.language = voice.language
        self.isNeural = #available(iOS 17.0, *) ? (voice.quality == .enhanced || voice.quality == .premium) : false
        
        if #available(iOS 17.0, *) {
            switch voice.quality {
            case .enhanced:
                self.quality = "增强版"
            case .premium:
                self.quality = "高级版"
            case .default:
                self.quality = "标准版"
            @unknown default:
                self.quality = "未知"
            }
        } else {
            self.quality = "标准版"
        }
    }
}
