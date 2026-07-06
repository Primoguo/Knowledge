// Knowledge/Services/LanguageDetector.swift
import Foundation
import AVFoundation

/// 自动检测文档语言并匹配对应的 VoiceConfig
enum LanguageDetector {

    /// 语言代码 → VoiceConfig language 映射
    private static let languageMap: [String: String] = [
        "zh-Hans": "zh-CN",
        "zh-Hant": "zh-HK",
        "en": "en-US",
        "ja": "ja-JP",
        "ko": "ko-KR",
        "fr": "fr-FR",
        "de": "de-DE",
        "es": "es-ES",
        "pt": "pt-BR",
        "it": "it-IT",
        "ru": "ru-RU",
        "ar": "ar-SA",
        "th": "th-TH",
        "vi": "vi-VN",
        "id": "id-ID",
        "tr": "tr-TR",
        "nl": "nl-NL",
        "pl": "pl-PL",
    ]

    /// 检测文本的主导语言，返回适合的 VoiceConfig
    /// 如果检测到的语言不在支持列表中，返回用户当前配置（不做切换）
    static func detectAndApply(for text: String, currentConfig: VoiceConfig) -> VoiceConfig {
        let sample = String(text.prefix(500))

        let tagger = NSLinguisticTagger(tagSchemes: [.language], options: 0)
        tagger.string = sample
        let detectedLang = tagger.dominantLanguage ?? "unknown"

        ErrorHandler.shared.log("检测到文档语言: \(detectedLang)", level: .info)

        let currentLangCode = currentConfig.language
        if languageMatches(detectedLang, currentLangCode) {
            return currentConfig
        }

        guard let targetLang = languageMap[detectedLang] else {
            ErrorHandler.shared.log("语言 \(detectedLang) 不在支持列表中，保持当前配置", level: .warn)
            return currentConfig
        }

        let availableVoices = AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language.hasPrefix(String(targetLang.prefix(2))) }

        guard !availableVoices.isEmpty else {
            ErrorHandler.shared.log("系统没有 \(targetLang) 的语音，保持当前配置", level: .warn)
            return currentConfig
        }

        var bestVoice: AVSpeechSynthesisVoice? = availableVoices.first(where: { v in v.quality == .enhanced })
        if bestVoice == nil {
            bestVoice = availableVoices.first(where: { v in v.quality == .premium })
        }
        if bestVoice == nil {
            bestVoice = availableVoices.first
        }

        ErrorHandler.shared.log("自动切换语音: \(targetLang) → \(bestVoice?.name ?? "默认")", level: .info)

        return VoiceConfig(
            rate: currentConfig.rate,
            pitchMultiplier: currentConfig.pitchMultiplier,
            volume: currentConfig.volume,
            language: targetLang,
            voiceIdentifier: bestVoice?.identifier
        )
    }

    private static func languageMatches(_ detected: String, _ configLang: String) -> Bool {
        if detected.hasPrefix("zh") && configLang.hasPrefix("zh") { return true }
        return configLang.hasPrefix(detected) || detected.hasPrefix(String(configLang.prefix(2)))
    }
}
