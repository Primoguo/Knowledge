// Knowledge/Services/VnoteAIService.swift
import Foundation

/// Vnote AI 分类 + 内容生成服务
/// 通过服务器中转调用 AI，将转写文本分类为会议纪要/创意速记/To-do，并生成结构化内容
final class VnoteAIService {
    static let shared = VnoteAIService()
    private let apiClient = ServerAPIClient.shared

    private init() {}

    // MARK: - AI 分类结果

    struct ClassificationResult {
        var category: KnowledgeCategory
        var title: String
        var content: String  // 结构化内容
    }

    // MARK: - 分类提示词

    static let classificationPrompt = """
    你是一个专业的语音速记整理助手。用户会给你一段语音转写的文字，你需要：

    1. 判断内容类别（仅从以下四个中选一个）：
       - meeting（会议纪要）：会议讨论、工作沟通、头脑风暴会议
       - creative（创意速记）：灵感、创意想法、个人思考
       - todo（To-do List）：待办事项、任务安排、行动计划
       - general（Box 收件箱）：无法明确归类的内容，放入收件箱

    2. 生成一个简短标题（10字以内）

    3. 将内容整理为结构化格式：
       - meeting：分为【讨论要点】【结论】【待办事项】
       - creative：分为【核心想法】【细节】【灵感延伸】
       - todo：用 ✅ 待办列表格式整理
       - general：用清晰的分段整理

    请严格按以下 JSON 格式返回（不要有其他文字）：
    {"category": "meeting", "title": "Q3预算讨论", "content": "整理后的内容..."}
    """

    // MARK: - 执行分类

    func classify(text: String) async throws -> ClassificationResult {
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            return ClassificationResult(category: .general, title: "语音速记", content: text)
        }

        let body: [String: Any] = [
            "text": "\(Self.classificationPrompt)\n\n---\n\n以下是用户的语音转写内容：\n\n\(String(text.prefix(6000)))",
            "systemPrompt": "你是一个专业的语音速记整理助手，严格按照 JSON 格式返回结果。"
        ]

        // 使用 /companion 端点（通用 AI 对话接口）
        let result = try await apiClient.requestCompanion(
            question: text,
            context: Self.classificationPrompt,
            history: [],
            systemPrompt: "你是一个专业的语音速记整理助手，严格按照 JSON 格式返回结果。"
        )

        return parseClassificationResult(result, fallbackText: text)
    }

    // MARK: - 解析 AI 返回

    private func parseClassificationResult(_ result: String, fallbackText: String) -> ClassificationResult {
        // 尝试解析 JSON
        if let data = result.data(using: .utf8),
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            let categoryStr = json["category"] as? String ?? "general"
            let category = KnowledgeCategory(rawValue: categoryStr) ?? .general
            let title = json["title"] as? String ?? "语音速记"
            let content = json["content"] as? String ?? fallbackText
            return ClassificationResult(category: category, title: title, content: content)
        }

        // 尝试从文本中提取 JSON 块
        let jsonPattern = #"\{[^{}]*"category"[^{}]*\}"#
        if let regex = try? NSRegularExpression(pattern: jsonPattern),
           let match = regex.firstMatch(in: result, range: NSRange(result.startIndex..., in: result)),
           let range = Range(match.range, in: result) {
            let jsonString = String(result[range])
            if let data = jsonString.data(using: .utf8),
               let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
                let categoryStr = json["category"] as? String ?? "general"
                let category = KnowledgeCategory(rawValue: categoryStr) ?? .general
                let title = json["title"] as? String ?? "语音速记"
                let content = json["content"] as? String ?? fallbackText
                return ClassificationResult(category: category, title: title, content: content)
            }
        }

        // 回退：用关键词推断分类
        let category = inferCategory(from: result)
        return ClassificationResult(category: category, title: "语音速记", content: result)
    }

    private func inferCategory(from text: String) -> KnowledgeCategory {
        let lower = text.lowercased()
        if lower.contains("会议") || lower.contains("讨论") || lower.contains("纪要") { return .meeting }
        if lower.contains("待办") || lower.contains("todo") || lower.contains("任务") { return .todo }
        if lower.contains("创意") || lower.contains("灵感") || lower.contains("想法") { return .creative }
        return .general
    }
}
