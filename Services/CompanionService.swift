// Knowledge/Services/CompanionService.swift
import Foundation

/// AI 伴读服务 — 边听边问的交互式对话
/// 通过服务器中转调用通义千问，API Key 仅存储在服务器端
/// 支持多轮对话，携带当前朗读上下文 + 专业提示词
final class CompanionService {
    static let shared = CompanionService()

    private let apiClient = ServerAPIClient.shared

    /// 对话历史（多轮上下文，客户端维护，最多 10 轮）
    private var conversationHistory: [[String: String]] = []

    /// 上次伴读的文档 ID（用于判断 review 状态）
    private var lastDocumentId: String? {
        get { UserDefaults.standard.string(forKey: "companion_lastDocumentId") }
        set { UserDefaults.standard.set(newValue, forKey: "companion_lastDocumentId") }
    }

    /// 难度层级（持久化）
    var difficulty: String {
        get { UserDefaults.standard.string(forKey: "companion_difficulty") ?? "intermediate" }
        set { UserDefaults.standard.set(newValue, forKey: "companion_difficulty") }
    }

    private init() {}

    // MARK: - System Prompt

    /// AI 伴读系统提示词（专业版）
    static let systemPrompt = """
    你是一名专业的 AI 伴读助手。

    你的职责是在用户阅读、听书、学习课程或查看资料时，结合当前内容，为用户提供即时、准确、自然的讲解与答疑。

    你不是通用聊天机器人，不是搜索引擎，不是百科全书。你是一位真正陪伴用户学习的人，耐心、自然、有温度。

    ## 动态上下文
    当前阅读内容：{context}
    当前学习状态：{session_state}
    当前难度层级：{difficulty}
    用户最近问过的话题：{recent_topics}

    ## 核心回答规则
    - 直接开始回答，不要有任何前缀、寒暄或引导语
    - 不要说“根据你提供的内容”、“从上下文来看”、“上文提到”
    - 不要重复上下文原文，用自己的话表达
    - 回答必须围绕当前阅读内容，不随意扩展无关知识
    - 如果上下文中没有答案，明确告知“这部分内容里没有提到”，不要编造
    - 只回答用户当前提出的问题，不要主动总结整篇内容
    - 不要一次讲多个知识点，聚焦一个点讲透
    - 如果用户提出错误观点，温和纠正并说明原因
    - 默认使用中文

    ## 文字表达规则
    - 句子保持简短，避免复杂从句嵌套
    - 禁止输出 Markdown、标题、项目符号、代码块、表格、引用格式
    - 语气自然，可穿插“简单来说”、“换句话说”等连接词
    - 专有名词首次出现时用一句话简短说明
    - 不要使用书面化的枚举结构，保持口语流畅感

    ## 信息密度控制
    - 首次回答（用户第一次问某话题）：50～80 字，给出核心要点
    - 追问回答（用户继续追问同一话题）：30～50 字，补充细节或换个角度
    - 复杂问题：先给一句话结论，提示“想深入了解可以继续问我”
    - 绝不一次性输出超过 100 字

    ## 学习状态响应策略
    first_question（首次提问）：
    - 回答相对完整，给用户建立基本认知
    - 可在末尾抛出一个延伸方向
    - 不假设用户已有背景知识

    follow_up（连续追问）：
    - 聚焦当前疑问，不重复之前已讲过的内容
    - 可以用“刚才我们聊过”自然衔接
    - 如果用户说“没听懂”，换一种更简单的说法

    review（复习模式）：
    - 用唤起记忆的方式开场，如“上次我们聊过这部分”
    - 不重新完整讲解，通过提问帮用户巩固
    - 如果用户答错，温和地重新解释

    ## 难度自适应
    beginner：生活类比、避免术语、句子更短、一次一个概念
    intermediate：可用术语但首次需解释、适度抽象、可引入对比
    advanced：专业表达、逻辑密度更高、可引入深层原理

    ## 边界规则
    - 问题与当前内容无关时，礼貌提醒正在进行伴读
    - 要求输出代码/表格/长文时，拒绝并说明“伴读模式下我们聊简短的内容”
    - 用户情绪低落时先共情一句，再继续讲解
    """

    // MARK: - Public API

    /// 向 AI 提问（携带当前朗读上下文）
    func ask(question: String, context: String, documentId: String? = nil) async throws -> String {
        // 计算 sessionState
        let sessionState = computeSessionState(documentId: documentId)

        // 提取 recentTopics
        let recentTopics = extractRecentTopics()

        // 构建带占位符替换的 systemPrompt
        let prompt = Self.systemPrompt
            .replacingOccurrences(of: "{context}", with: context)
            .replacingOccurrences(of: "{session_state}", with: sessionState)
            .replacingOccurrences(of: "{difficulty}", with: difficulty)
            .replacingOccurrences(of: "{recent_topics}", with: recentTopics.isEmpty ? "无" : recentTopics)

        let response = try await apiClient.requestCompanion(
            question: question,
            context: context,
            history: conversationHistory,
            systemPrompt: prompt
        )

        // 记录对话历史（最多保留最近 10 轮）
        conversationHistory.append(["role": "user", "content": question])
        conversationHistory.append(["role": "assistant", "content": response])
        if conversationHistory.count > 20 {
            conversationHistory = Array(conversationHistory.suffix(20))
        }

        // 更新 lastDocumentId
        if let docId = documentId {
            lastDocumentId = docId
        }

        return response
    }

    /// 重置对话历史（切换文档时调用）
    func resetConversation() {
        conversationHistory.removeAll()
    }

    // MARK: - Private Helpers

    /// 计算学习状态
    private func computeSessionState(documentId: String?) -> String {
        let historyCount = conversationHistory.filter { $0["role"] == "user" }.count

        if historyCount == 0 {
            return "first_question"
        }

        // 同一文档且历史 ≥ 5 轮 → review
        if let docId = documentId, docId == lastDocumentId, historyCount >= 5 {
            return "review"
        }

        return "follow_up"
    }

    /// 提取最近 3 条用户问题（每条前 20 字）
    private func extractRecentTopics() -> String {
        let userMessages = conversationHistory
            .filter { $0["role"] == "user" }
            .suffix(3)
            .map { msg -> String in
                let content = msg["content"] ?? ""
                return String(content.prefix(20))
            }
        return userMessages.joined(separator: ", ")
    }
}
