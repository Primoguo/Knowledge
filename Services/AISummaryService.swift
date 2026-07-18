// Knowledge/Services/AISummaryService.swift
import Foundation

/// AI 文档总结服务
/// 通过服务器中转调用通义千问，API Key 仅存储在服务器端
final class AISummaryService {
    static let shared = AISummaryService()

    private let apiClient = ServerAPIClient.shared

    private init() {}

    // MARK: - System Prompt

    /// AI 总结系统提示词（专业版，基于内容类型自动适配）
    static let systemPrompt = """
    你是一名世界级 AI 信息总结专家。你的核心职责是将任何输入内容进行高质量结构化总结。

    ## 工作原则
    1. 保留事实：不修改原意，不增加不存在的信息，不猜测
    2. 去掉噪音：删除重复内容、寒暄、广告和无意义修饰
    3. 提炼重点：识别核心观点、关键结论、数据、人物、事件、因果关系、行动建议、风险与限制
    4. 保持逻辑：按背景→问题→分析→方案→结论组织
    5. 信息优先：优先保留数字、金额、日期、版本号、API、参数、专业术语
    6. 简洁表达：在不丢失信息前提下尽可能压缩，目标减少约 80% 阅读时间

    ## 工作流程
    1. 识别内容类型（新闻/技术文档/PRD/论文/会议记录/聊天记录/合同/教程等）
    2. 识别主题、写作目的、目标读者
    3. 提取主要观点、支持论据、关键数据、重要结论、待办事项、风险
    4. 输出结构化总结
    5. 自检：是否遗漏重要结论/数字/时间/待办？是否逻辑清晰？

    ## 输出格式（严格遵守，直接以【一句话总结】开头，不要任何前缀）
    【一句话总结】
    一句话概括全文核心内容

    【三句话总结】
    1. 第一点
    2. 第二点
    3. 第三点

    【核心内容】
    对核心内容的详细分析，可分段描述背景、主要观点、关键数据和核心结论。

    【要点】
    1. 关键要点一
    2. 关键要点二
    3. 关键要点三
    （3~5 条，每条一句话）

    【行动建议】
    1. 建议一
    2. 建议二
    （如内容无明确行动建议，可省略此段）

    【风险】
    1. 风险一
    2. 风险二
    （如内容无明确风险，可省略此段）

    ## 要求
    - 使用与原文相同的语言
    - 不要添加“好的”“以下是”等前缀
    - 不要使用 Markdown 格式（如 # 标题、**加粗**），使用纯文本
    - 直接以【一句话总结】开头输出
    """

    /// 合并提示词（用于将多段摘要合并为最终结构化总结）
    static let mergePrompt = """
    你是一名 AI 信息整合专家。

    以下是一篇长文档分段摘要的结果，请将它们合并为一篇完整的结构化总结。

    ## 要求
    - 去除各段之间的重复信息
    - 保持逻辑连贯，按 背景→问题→分析→方案→结论 组织
    - 保留所有关键数据、数字、人名、日期
    - 输出格式与标准总结一致（一句话总结、三句话总结、核心内容、要点、行动建议、风险）
    - 不要提及“分段”或“摘要合并”等字眼，直接输出最终总结
    - 不要添加“好的”“以下是”等前缀，直接以【一句话总结】开头
    - 不要使用 Markdown 格式，使用纯文本
    """

    // MARK: - Public API

    /// 生成文档摘要（长度自适应：≤1万字全文，>1万字分段摘要+合并）
    func generateSummary(for text: String) async throws -> SummaryResult {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)

        if trimmed.count <= 10000 {
            // 短文档：直接全文摘要
            let response = try await apiClient.requestSummary(text: trimmed, systemPrompt: Self.systemPrompt)
            return parseSummaryResponse(response)
        } else {
            // 超长文档：分段摘要 + 合并
            let segments = splitIntoSegments(text: trimmed, maxSegmentLength: 8000, overlap: 500)
            print("📄 超长文档 \(trimmed.count) 字，分为 \(segments.count) 段摘要")

            var segmentSummaries: [String] = []
            for (i, segment) in segments.enumerated() {
                print("📝 摘要第 \(i + 1)/\(segments.count) 段...")
                let response = try await apiClient.requestSummary(text: segment, systemPrompt: Self.systemPrompt)
                segmentSummaries.append(response)
            }

            // 合并所有段摘要
            print("🔗 合并 \(segmentSummaries.count) 段摘要...")
            let mergedResponse = try await apiClient.requestMergeSummaries(
                summaries: segmentSummaries,
                systemPrompt: Self.mergePrompt
            )
            return parseSummaryResponse(mergedResponse)
        }
    }

    // MARK: - Segmentation

    /// 将长文本切分为多段，每段最大 maxSegmentLength 字，段间重叠 overlap 字
    private func splitIntoSegments(text: String, maxSegmentLength: Int, overlap: Int) -> [String] {
        var segments: [String] = []
        var start = text.startIndex

        while start < text.endIndex {
            let remaining = text.distance(from: start, to: text.endIndex)
            let segLength = min(maxSegmentLength, remaining)
            let end = text.index(start, offsetBy: segLength)
            segments.append(String(text[start..<end]))

            if end >= text.endIndex { break }
            // 下一段从当前位置回退 overlap 字开始
            let nextStart = text.index(end, offsetBy: -min(overlap, segLength))
            start = nextStart
        }

        return segments
    }

    // MARK: - Parser

    private func parseSummaryResponse(_ response: String) -> SummaryResult {
        var oneLiner = extractSection(response, marker: "【一句话总结】", stopAt: ["【三句话总结】", "【核心内容】", "【要点】", "【行动建议】", "【风险】"])
        var threeLines = extractSection(response, marker: "【三句话总结】", stopAt: ["【核心内容】", "【要点】", "【行动建议】", "【风险】"])
        let coreContent = extractSection(response, marker: "【核心内容】", stopAt: ["【要点】", "【行动建议】", "【风险】"])
        let keyPoints = extractListItems(response, marker: "【要点】", stopAt: ["【行动建议】", "【风险】"])
        let actionItems = extractListItems(response, marker: "【行动建议】", stopAt: ["【要点】", "【风险】"])
        let risks = extractListItems(response, marker: "【风险】", stopAt: ["【要点】", "【行动建议】"])

        // 向后兼容旧格式 【摘要】
        if oneLiner.isEmpty {
            oneLiner = extractSection(response, marker: "【摘要】", stopAt: ["【要点】"])
        }

        // 三句话总结清理：去掉编号前缀
        if !threeLines.isEmpty {
            threeLines = threeLines.components(separatedBy: "\n")
                .map { line -> String in
                    let trimmed = line.trimmingCharacters(in: .whitespaces)
                    // 去掉 "1. " "2. " "3. " 前缀
                    if let dotIndex = trimmed.firstIndex(of: "."),
                       let _ = Int(trimmed[..<dotIndex]) {
                        return String(trimmed[trimmed.index(after: dotIndex)...]).trimmingCharacters(in: .whitespaces)
                    }
                    return trimmed
                }
                .filter { !$0.isEmpty }
                .joined(separator: "\n")
        }

        // 兆底：如果什么都没解析到
        if oneLiner.isEmpty && threeLines.isEmpty && coreContent.isEmpty && keyPoints.isEmpty {
            oneLiner = response.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        return SummaryResult(
            oneLiner: oneLiner,
            threeLines: threeLines,
            coreContent: coreContent,
            keyPoints: keyPoints,
            actionItems: actionItems,
            risks: risks
        )
    }

    // MARK: - Parser Helpers

    /// 提取标记到下一个标记之间的文本内容
    private func extractSection(_ text: String, marker: String, stopAt: [String]) -> String {
        guard let range = text.range(of: marker) else { return "" }
        let after = String(text[range.upperBound...])

        // 找到最近的停止标记
        var endPos = after.endIndex
        for stop in stopAt {
            if let r = after.range(of: stop), r.lowerBound < endPos {
                endPos = r.lowerBound
            }
        }

        return String(after[..<endPos]).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// 提取标记下的列表项（支持 1. / - / • / · 格式）
    private func extractListItems(_ text: String, marker: String, stopAt: [String]) -> [String] {
        let section = extractSection(text, marker: marker, stopAt: stopAt)
        guard !section.isEmpty else { return [] }

        var items: [String] = []
        for line in section.components(separatedBy: .newlines) {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("- ") || trimmed.hasPrefix("• ") || trimmed.hasPrefix("· ") {
                let item = String(trimmed.dropFirst(2)).trimmingCharacters(in: .whitespaces)
                if !item.isEmpty { items.append(item) }
            } else if let dotIndex = trimmed.firstIndex(of: "."),
                      let _ = Int(trimmed[..<dotIndex]) {
                let item = String(trimmed[trimmed.index(after: dotIndex)...]).trimmingCharacters(in: .whitespaces)
                if !item.isEmpty { items.append(item) }
            }
        }
        return items
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
