// Knowledge/Models/ClonedVoice.swift
import Foundation

/// CosyVoice 预设音色
struct PresetVoice: Codable, Identifiable {
    var id: String
    var name: String
    var description: String
    var category: VoiceCategory
    var language: String
    var sampleAudioURL: String?

    enum VoiceCategory: String, Codable, CaseIterable {
        case male = "男声"
        case female = "女声"
        case neutral = "中性"
        case podcast = "播客风格"
        case storytelling = "故事讲述"

        var iconName: String {
            switch self {
            case .male: return "person.fill"
            case .female: return "person.fill"
            case .neutral: return "person"
            case .podcast: return "radio.fill"
            case .storytelling: return "book.fill"
            }
        }
    }
}

/// 克隆音色模型
struct ClonedVoice: Codable, Identifiable {
    var id: String  // CosyVoice 返回的 voice_id
    var name: String  // 用户自定义名称
    var description: String?
    var createdAt: Date
    /// 克隆音频的本地缓存路径
    var sampleAudioPath: String?

    init(id: String, name: String, description: String? = nil, createdAt: Date = Date(), sampleAudioPath: String? = nil) {
        self.id = id
        self.name = name
        self.description = description
        self.createdAt = createdAt
        self.sampleAudioPath = sampleAudioPath
    }
}

// MARK: - 音色持久化管理

/// 音色数据管理器（UserDefaults 持久化）
struct VoiceStore {
    private static let clonedVoicesKey = "clonedVoices"
    private static let selectedPresetKey = "selectedPresetVoiceId"
    private static let selectedCloneKey = "selectedCloneVoiceId"

    /// 保存克隆音色列表
    static func saveClonedVoices(_ voices: [ClonedVoice]) {
        if let data = try? JSONEncoder().encode(voices) {
            UserDefaults.standard.set(data, forKey: clonedVoicesKey)
        }
    }

    /// 读取克隆音色列表
    static func loadClonedVoices() -> [ClonedVoice] {
        guard let data = UserDefaults.standard.data(forKey: clonedVoicesKey),
              let voices = try? JSONDecoder().decode([ClonedVoice].self, from: data) else { return [] }
        return voices
    }

    /// 保存选中的预设音色 ID
    static func saveSelectedPreset(_ voiceId: String?) {
        UserDefaults.standard.set(voiceId, forKey: selectedPresetKey)
    }

    /// 读取选中的预设音色 ID
    static func loadSelectedPreset() -> String? {
        UserDefaults.standard.string(forKey: selectedPresetKey)
    }

    /// 保存选中的克隆音色 ID
    static func saveSelectedClone(_ voiceId: String?) {
        UserDefaults.standard.set(voiceId, forKey: selectedCloneKey)
    }

    /// 读取选中的克隆音色 ID
    static func loadSelectedClone() -> String? {
        UserDefaults.standard.string(forKey: selectedCloneKey)
    }

    // MARK: - 预设音色列表

    /// CosyVoice 内置预设音色
    static let presetVoices: [PresetVoice] = [
        PresetVoice(id: "longxiaochun", name: "龙小春", description: "沉稳大气的男声，适合新闻播报", category: .male, language: "zh-CN"),
        PresetVoice(id: "longxiaoxia", name: "龙小夏", description: "温柔知性的女声，适合朗读小说", category: .female, language: "zh-CN"),
        PresetVoice(id: "longxiaobai", name: "龙小白", description: "青春活泼的男声，适合播客主持", category: .male, language: "zh-CN"),
        PresetVoice(id: "longxiaochun_v2", name: "龙小春 V2", description: "升级版沉稳男声，更自然的语调", category: .male, language: "zh-CN"),
        PresetVoice(id: "longshu", name: "龙叔", description: "成熟的男性声线，适合深度内容", category: .male, language: "zh-CN"),
        PresetVoice(id: "longxia", name: "龙夏", description: "温暖亲切的女声，适合情感类内容", category: .female, language: "zh-CN"),
        PresetVoice(id: "longyue", name: "龙悦", description: "清脆明亮的女声，适合教育内容", category: .female, language: "zh-CN"),
        PresetVoice(id: "longchen", name: "龙晨", description: "阳光活力的男声，适合运动健康", category: .male, language: "zh-CN"),
        PresetVoice(id: "longye", name: "龙夜", description: "低沉有磁性的男声，适合夜间收听", category: .male, language: "zh-CN"),
        PresetVoice(id: "stella", name: "Stella", description: "Professional English female voice", category: .female, language: "en-US"),
        PresetVoice(id: "david", name: "David", description: "Warm English male voice", category: .male, language: "en-US"),
        PresetVoice(id: "eva", name: "Eva", description: "Natural English female voice for storytelling", category: .female, language: "en-US"),
    ]

    /// 按分类获取预设音色
    static func presetsByCategory() -> [(category: PresetVoice.VoiceCategory, voices: [PresetVoice])] {
        let grouped = Dictionary(grouping: presetVoices, by: { $0.category })
        return PresetVoice.VoiceCategory.allCases.compactMap { category in
            grouped[category].map { (category, $0) }
        }
    }
}
