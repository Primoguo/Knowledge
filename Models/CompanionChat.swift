// Knowledge/Models/CompanionChat.swift
import Foundation
import SwiftData

/// 单条对话记录（Codable，存储为 JSON Data）
struct ChatEntry: Codable, Identifiable {
    let id: UUID
    let role: String       // "user" / "assistant"
    let content: String
    let timestamp: Date

    init(role: String, content: String, timestamp: Date = Date()) {
        self.id = UUID()
        self.role = role
        self.content = content
        self.timestamp = timestamp
    }
}

/// AI 伴读对话持久化模型（按文档存储）
@Model
final class CompanionChat {
    var documentId: UUID
    var messagesData: Data          // [ChatEntry] 的 JSON 编码
    var updatedAt: Date

    init(documentId: UUID, entries: [ChatEntry] = []) {
        self.documentId = documentId
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
