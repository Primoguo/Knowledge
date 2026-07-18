// Knowledge/Models/KnowledgeEntry.swift
import Foundation
import SwiftData

/// 知识条目来源类型
enum KnowledgeSource: String, Codable, CaseIterable {
    case summary    // 来自文档摘要沉淀
    case vnote      // 来自 Vnote 语音速记沉淀
    case manual     // 手动添加

    var displayName: String {
        switch self {
        case .summary: return "文档摘要"
        case .vnote:   return "语音速记"
        case .manual:  return "手动添加"
        }
    }

    var iconName: String {
        switch self {
        case .summary: return "doc.text"
        case .vnote:   return "mic.fill"
        case .manual:  return "square.and.pencil"
        }
    }
}

/// AI 分类类型（Vnote 用）
enum KnowledgeCategory: String, Codable, CaseIterable {
    case meeting    // 会议纪要
    case creative   // 创意速记
    case todo       // To-do List
    case general    // Box（收件箱，未分类）

    var displayName: String {
        switch self {
        case .meeting:  return "会议纪要"
        case .creative: return "创意速记"
        case .todo:     return "To-do"
        case .general:  return "Box"
        }
    }

    var iconName: String {
        switch self {
        case .meeting:  return "person.2.fill"
        case .creative: return "lightbulb.fill"
        case .todo:     return "checklist"
        case .general:  return "tray.fill"
        }
    }

    var color: String {
        switch self {
        case .meeting:  return "blue"
        case .creative: return "orange"
        case .todo:     return "green"
        case .general:  return "gray"
        }
    }
}

/// 知识库条目（SwiftData 持久化）
@Model
final class KnowledgeEntry {
    var id: UUID = UUID()
    var title: String = ""
    var content: String = ""
    var sourceRaw: String = ""
    var categoryRaw: String = ""
    var sourceDocumentId: UUID?
    var createdAt: Date = Date()
    var updatedAt: Date = Date()

    // MARK: - 计算属性

    var source: KnowledgeSource {
        get { KnowledgeSource(rawValue: sourceRaw) ?? .manual }
        set { sourceRaw = newValue.rawValue }
    }

    var category: KnowledgeCategory {
        get { KnowledgeCategory(rawValue: categoryRaw) ?? .general }
        set { categoryRaw = newValue.rawValue }
    }

    /// 摘要预览（前 100 字）
    var preview: String {
        let trimmed = content.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.count > 100 ? String(trimmed.prefix(100)) + "..." : trimmed
    }

    init(
        id: UUID = UUID(),
        title: String,
        content: String,
        source: KnowledgeSource = .manual,
        category: KnowledgeCategory = .general,
        sourceDocumentId: UUID? = nil,
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.title = title
        self.content = content
        self.sourceRaw = source.rawValue
        self.categoryRaw = category.rawValue
        self.sourceDocumentId = sourceDocumentId
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }
}
