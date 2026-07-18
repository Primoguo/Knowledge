// Knowledge/Models/KnowledgeChat.swift
import Foundation
import SwiftData

/// 知识库 AI 对话持久化模型（按知识条目存储）
@Model
final class KnowledgeChat {
    var entryId: UUID = UUID()
    var messagesData: Data = Data()
    var updatedAt: Date = Date()

    init(entryId: UUID, entries: [ChatEntry] = []) {
        self.entryId = entryId
        self.messagesData = (try? JSONEncoder().encode(entries)) ?? Data()
        self.updatedAt = Date()
    }

    /// 解码消息列表
    var entries: [ChatEntry] {
        get { (try? JSONDecoder().decode([ChatEntry].self, from: messagesData)) ?? [] }
        set {
            messagesData = (try? JSONEncoder().encode(newValue)) ?? Data()
            updatedAt = Date()
        }
    }
}
