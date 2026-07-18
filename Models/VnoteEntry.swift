// Knowledge/Models/VnoteEntry.swift
import Foundation
import SwiftData

/// Vnote 语音速记条目（SwiftData 持久化）
@Model
final class VnoteEntry {
    var id: UUID = UUID()
    var title: String = ""
    var transcription: String = ""
    /// 句子时间戳数据（可能很大，CloudKit 同步时用外部存储）
    @Attribute(.externalStorage) var sentencesData: Data = Data()
    var aiContent: String = ""
    var categoryRaw: String = ""
    var audioFileName: String = ""
    var audioDuration: TimeInterval = 0
    var isPremiumSTT: Bool = false
    var isSyncedToKnowledge: Bool = false
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    // MARK: - 计算属性

    var category: KnowledgeCategory {
        get { KnowledgeCategory(rawValue: categoryRaw) ?? .general }
        set { categoryRaw = newValue.rawValue }
    }

    /// 解码句子列表（含时间戳）
    var sentences: [VnoteSentence] {
        get { (try? JSONDecoder().decode([VnoteSentence].self, from: sentencesData)) ?? [] }
        set { sentencesData = (try? JSONEncoder().encode(newValue)) ?? Data() }
    }

    /// 文本预览（前 80 字）
    var preview: String {
        let text = aiContent.isEmpty ? transcription : aiContent
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.count > 80 ? String(trimmed.prefix(80)) + "..." : trimmed
    }

    /// 时长格式化（mm:ss）
    var durationText: String {
        let minutes = Int(audioDuration) / 60
        let seconds = Int(audioDuration) % 60
        return String(format: "%d:%02d", minutes, seconds)
    }

    /// 录音文件的完整路径
    var audioFileURL: URL? {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first
        return docs?.appendingPathComponent("vnote_recordings").appendingPathComponent(audioFileName)
    }

    init(
        id: UUID = UUID(),
        title: String = "",
        transcription: String = "",
        sentences: [VnoteSentence] = [],
        aiContent: String = "",
        category: KnowledgeCategory = .general,
        audioFileName: String = "",
        audioDuration: TimeInterval = 0,
        isPremiumSTT: Bool = false,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.transcription = transcription
        self.sentencesData = (try? JSONEncoder().encode(sentences)) ?? Data()
        self.aiContent = aiContent
        self.categoryRaw = category.rawValue
        self.audioFileName = audioFileName
        self.audioDuration = audioDuration
        self.isPremiumSTT = isPremiumSTT
        self.isSyncedToKnowledge = false
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}

/// Vnote 句子（含时间戳，用于高亮回放）
struct VnoteSentence: Codable, Identifiable {
    var id: UUID = UUID()
    var text: String
    var beginTime: Int     // 毫秒
    var endTime: Int       // 毫秒
    var words: [VnoteWord]

    init(text: String, beginTime: Int = 0, endTime: Int = 0, words: [VnoteWord] = []) {
        self.text = text
        self.beginTime = beginTime
        self.endTime = endTime
        self.words = words
    }
}

/// Vnote 词级时间戳
struct VnoteWord: Codable, Identifiable {
    var id: UUID = UUID()
    var text: String
    var beginTime: Int     // 毫秒
    var endTime: Int       // 毫秒
    var punctuation: String

    init(text: String, beginTime: Int = 0, endTime: Int = 0, punctuation: String = "") {
        self.text = text
        self.beginTime = beginTime
        self.endTime = endTime
        self.punctuation = punctuation
    }
}
