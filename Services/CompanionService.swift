// Knowledge/Services/CompanionService.swift
import Foundation

/// AI 伴读服务 — 边听边问的交互式对话
/// 通过服务器中转调用通义千问，API Key 仅存储在服务器端
/// 支持多轮对话，携带当前朗读上下文
final class CompanionService {
    static let shared = CompanionService()

    private let apiClient = ServerAPIClient.shared

    /// 对话历史（多轮上下文，客户端维护，最多 10 轮）
    private var conversationHistory: [[String: String]] = []

    private init() {}

    // MARK: - Public API

    /// 向 AI 提问（携带当前朗读上下文）
    /// - Parameters:
    ///   - question: 用户问题
    ///   - context: 当前朗读位置前后的文本片段
    ///   - maxTokens: 最大回复 token 数，默认 300（简短回答）
    /// - Returns: AI 的回复文本
    func ask(question: String, context: String, maxTokens: Int = 300) async throws -> String {
        let response = try await apiClient.requestCompanion(
            question: question,
            context: context,
            history: conversationHistory
        )

        // 记录对话历史（最多保留最近 10 轮）
        conversationHistory.append(["role": "user", "content": question])
        conversationHistory.append(["role": "assistant", "content": response])
        if conversationHistory.count > 20 {
            conversationHistory = Array(conversationHistory.suffix(20))
        }

        return response
    }

    /// 重置对话历史（切换文档时调用）
    func resetConversation() {
        conversationHistory.removeAll()
    }
}
