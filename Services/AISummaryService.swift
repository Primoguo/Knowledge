// Knowledge/Services/AISummaryService.swift
import Foundation

/// AI 文档总结服务
/// 通过服务器中转调用通义千问，API Key 仅存储在服务器端
final class AISummaryService {
    static let shared = AISummaryService()

    private let apiClient = ServerAPIClient.shared

    private init() {}

    // MARK: - Public API

    /// 生成文档摘要
    /// - Parameters:
    ///   - text: 文档原文
    ///   - maxLength: 摘要最大长度（字符），默认 500
    /// - Returns: 摘要结果（正文 + 关键要点）
    func generateSummary(for text: String, maxLength: Int = 500) async throws -> SummaryResult {
        let response = try await apiClient.requestSummary(text: text)
        return parseSummaryResponse(response)
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
    case invalidResponse
    case apiError(statusCode: Int, message: String)
    case networkError(Error)

    var errorDescription: String? {
        switch self {
        case .invalidResponse:
            return "服务器返回数据异常，请稍后重试"
        case .apiError(let code, let msg):
            return "请求失败（\(code)）：\(msg)"
        case .networkError(let error):
            return "网络错误：\(error.localizedDescription)"
        }
    }
}
