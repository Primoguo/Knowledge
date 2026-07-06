// Knowledge/Models/CompanionMessage.swift
import Foundation

/// AI 伴读对话消息模型
struct CompanionMessage: Identifiable {
    let id = UUID()
    let content: String
    let isUser: Bool
    var isLoading = false
}
