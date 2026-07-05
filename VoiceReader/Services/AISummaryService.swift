// Knowledge/Services/AISummaryService.swift
import Foundation

/// AI 文档总结服务（阿里云 DashScope 通义千问）
final class AISummaryService {
    static let shared = AISummaryService()

    private let apiKey: String
    private let baseURL = "https://dashscope.aliyuncs.com/api/v1/services/aigc/text-generation/generation"
    private let session: URLSession

    private init() {
        self.session = URLSession.shared
        // 优先从 UserDefaults 读取，否则使用环境变量/配置
        self.apiKey = UserDefaults.standard.string(forKey: "dashscope_api_key") ?? ""
    }

    // MARK: - Public API

    /// 生成文档摘要
    /// - Parameters:
    ///   - text: 文档原文
    ///   - maxLength: 摘要最大长度（字符），默认 500
    /// - Returns: 摘要结果（正文 + 关键要点）
    func generateSummary(for text: String, maxLength: Int = 500) async throws -> SummaryResult {
        guard !apiKey.isEmpty else {
            throw AIServiceError.missingAPIKey
        }

        let prompt = buildSummaryPrompt(text: text, maxLength: maxLength)
        let response = try await callAPI(prompt: prompt)

        return parseSummaryResponse(response)
    }

    // MARK: - Private

    private func buildSummaryPrompt(text: String, maxLength: Int) -> String {
        // 如果文本过长，截取前 8000 字符
        let truncated = String(text.prefix(8000))
        return """
        请对以下文档内容进行总结，要求：
        1. 用一段连贯的文字概括核心内容（不超过 \(maxLength) 字）
        2. 提取 3-5 个关键要点

        请按以下格式回复：
        【摘要】
        （摘要正文）

        【要点】
        - 要点1
        - 要点2
        - 要点3

        文档内容：
        \(truncated)
        """
    }

    private func callAPI(prompt: String) async throws -> String {
        var request = URLRequest(url: URL(string: baseURL)!)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue("Bearer \(apiKey)", forHTTPHeaderField: "Authorization")
        request.timeoutInterval = 60

        let body: [String: Any] = [
            "model": "qwen-plus",
            "input": [
                "messages": [
                    ["role": "user", "content": prompt]
                ]
            ],
            "parameters": [
                "result_format": "message",
                "max_tokens": 1024,
                "temperature": 0.7
            ]
        ]

        request.httpBody = try JSONSerialization.data(withJSONObject: body)

        let (data, response) = try await session.data(for: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw AIServiceError.invalidResponse
        }

        if httpResponse.statusCode == 401 || httpResponse.statusCode == 403 {
            throw AIServiceError.invalidAPIKey
        }

        guard httpResponse.statusCode == 200 else {
            let errorMsg = String(data: data, encoding: .utf8) ?? "Unknown error"
            throw AIServiceError.apiError(statusCode: httpResponse.statusCode, message: errorMsg)
        }

        guard let json = try JSONSerialization.jsonObject(with: data) as? [String: Any],
              let output = json["output"] as? [String: Any],
              let choices = output["choices"] as? [[String: Any]],
              let message = choices.first?["message"] as? [String: Any],
              let content = message["content"] as? String else {
            throw AIServiceError.invalidResponse
        }

        return content
    }

    private func parseSummaryResponse(_ response: String) -> SummaryResult {
        var summaryContent = ""
        var keyPoints: [String] = []

        // 解析【摘要】部分
        if let summaryRange = response.range(of: "【摘要】") {
            let afterSummary = String(response[summaryRange.upperBound...])
            if let pointsRange = afterSummary.range(of: "【要点】") {
                summaryContent = String(afterSummary[..<pointsRange.lowerBound])
                    .trimmingCharacters(in: .whitespacesAndNewlines)
            } else {
                summaryContent = afterSummary.trimmingCharacters(in: .whitespacesAndNewlines)
            }
        }

        // 解析【要点】部分
        if let pointsRange = response.range(of: "【要点】") {
            let pointsText = String(response[pointsRange.upperBound...])
            let lines = pointsText.components(separatedBy: .newlines)
            for line in lines {
                let trimmed = line.trimmingCharacters(in: .whitespaces)
                if trimmed.hasPrefix("- ") || trimmed.hasPrefix("• ") || trimmed.hasPrefix("· ") {
                    let point = String(trimmed.dropFirst(2)).trimmingCharacters(in: .whitespaces)
                    if !point.isEmpty {
                        keyPoints.append(point)
                    }
                } else if let dotIndex = trimmed.firstIndex(of: "."),
                          let num = Int(trimmed[..<dotIndex]) {
                    // 匹配 "1. " 格式
                    let point = String(trimmed[trimmed.index(after: dotIndex)...])
                        .trimmingCharacters(in: .whitespaces)
                    if !point.isEmpty {
                        keyPoints.append(point)
                    }
                }
            }
        }

        // 如果没有解析到任何内容，将整个回复作为摘要
        if summaryContent.isEmpty && keyPoints.isEmpty {
            summaryContent = response.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return SummaryResult(content: summaryContent, keyPoints: keyPoints)
    }
}

// MARK: - Errors

enum AIServiceError: LocalizedError {
    case missingAPIKey
    case invalidAPIKey
    case invalidResponse
    case apiError(statusCode: Int, message: String)
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .missingAPIKey:
            return "请先在设置中配置阿里云 API Key"
        case .invalidAPIKey:
            return "API Key 无效，请检查后重试"
        case .invalidResponse:
            return "服务器返回数据异常，请稍后重试"
        case .apiError(let code, let msg):
            return "请求失败（\(code)）：\(msg)"
        case .networkError(let error):
            return "网络错误：\(error.localizedDescription)"
        }
    }
}
