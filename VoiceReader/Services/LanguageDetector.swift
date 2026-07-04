// VoiceReader/Services/LanguageDetector.swift
import Foundation
import AVFoundation

/// 自动检测文档语言并匹配对应的 VoiceConfig
final class LanguageDetector {

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
        // 取文本前 500 字符做检测，足够准确且性能好
        let sample = String(text.prefix(500))

        let tagger = NSLinguisticTagger(tagSchemes: [.language], options: 0)
        tagger.string = sample
        let detectedLang = tagger.dominantLanguage ?? "unknown"

        print("🔍 检测到文档语言: \(detectedLang)")

        // 如果检测到的语言和当前配置一致，不做切换
        let currentLangCode = currentConfig.language
        if languageMatches(detectedLang, currentLangCode) {
            return currentConfig
        }

        // 查找映射
        guard let targetLang = languageMap[detectedLang] else {
            print("⚠️ 语言 \(detectedLang) 不在支持列表中，保持当前配置")
            return currentConfig
        }

        // 检查系统是否有该语言的语音
        let availableVoices = AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language.hasPrefix(String(targetLang.prefix(2))) }

        guard !availableVoices.isEmpty else {
            print("⚠️ 系统没有 \(targetLang) 的语音，保持当前配置")
            return currentConfig
        }

        // 选择最高质量的语音
        var bestVoice: AVSpeechSynthesisVoice? = availableVoices.first(where: { v in v.quality == .enhanced })
        if bestVoice == nil {
            bestVoice = availableVoices.first(where: { v in v.quality == .premium })
        }
        if bestVoice == nil {
            bestVoice = availableVoices.first
        }

        print("✅ 自动切换语音: \(targetLang) → \(bestVoice?.name ?? "默认")")

        return VoiceConfig(
            rate: currentConfig.rate,
            pitchMultiplier: currentConfig.pitchMultiplier,
            volume: currentConfig.volume,
            language: targetLang,
            voiceIdentifier: bestVoice?.identifier
        )
    }

    /// 判断检测到的语言代码是否与配置语言匹配
    private static func languageMatches(_ detected: String, _ configLang: String) -> Bool {
        // "zh-Hans" ↔ "zh-CN" / "zh-Hans-CN"
        if detected.hasPrefix("zh") && configLang.hasPrefix("zh") {
            return true
        }
        // "en" ↔ "en-US" / "en-GB"
        return configLang.hasPrefix(detected) || detected.hasPrefix(String(configLang.prefix(2)))
    }
}
