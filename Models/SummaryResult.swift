// Knowledge/Models/SummaryResult.swift
import Foundation

/// AI 文档摘要结果（支持简版/详版双模式）
struct SummaryResult: Codable, Identifiable {
    var id: UUID = UUID()

    /// 一句话总结（简版摘要正文）
    var oneLiner: String = ""
    /// 三句话总结
    var threeLines: String = ""
    /// 核心内容（详细分析）
    var coreContent: String = ""
    /// 关键要点列表
    var keyPoints: [String] = []
    /// 行动建议
    var actionItems: [String] = []
    /// 风险与注意事项
    var risks: [String] = []
    /// 生成时间
    let createdAt: Date

    /// 向后兼容：旧缓存使用 content 字段
    var content: String {
        oneLiner.isEmpty ? _legacyContent : oneLiner
    }
    private var _legacyContent: String = ""

    init(
        oneLiner: String = "",
        threeLines: String = "",
        coreContent: String = "",
        keyPoints: [String] = [],
        actionItems: [String] = [],
        risks: [String] = [],
        createdAt: Date = Date(),
        legacyContent: String = ""
    ) {
        self.oneLiner = oneLiner
        self.threeLines = threeLines
        self.coreContent = coreContent
        self.keyPoints = keyPoints
        self.actionItems = actionItems
        self.risks = risks
        self.createdAt = createdAt
        self._legacyContent = legacyContent
    }

    /// 简版展示内容（优先一句话总结，兼容旧缓存）
    var simpleContent: String {
        !oneLiner.isEmpty ? oneLiner : content
    }

    /// 是否有详版内容
    var hasDetailed: Bool {
        !threeLines.isEmpty || !coreContent.isEmpty || !actionItems.isEmpty || !risks.isEmpty
    }

    /// 朗读文本（根据模式）
    func readAloudText(detailed: Bool) -> String {
        if detailed {
            var parts: [String] = []
            if !oneLiner.isEmpty { parts.append(oneLiner) }
            if !threeLines.isEmpty { parts.append(threeLines) }
            if !coreContent.isEmpty { parts.append(coreContent) }
            if !keyPoints.isEmpty { parts.append(keyPoints.joined(separator: "\n")) }
            if !actionItems.isEmpty { parts.append("行动建议：" + actionItems.joined(separator: "\n")) }
            if !risks.isEmpty { parts.append("风险提示：" + risks.joined(separator: "\n")) }
            return parts.joined(separator: "\n\n")
        } else {
            let summary = simpleContent
            let points = keyPoints.joined(separator: "\n")
            return points.isEmpty ? summary : summary + "\n\n" + points
        }
    }

    // MARK: - Persistence

    func toJSON() -> String? {
        guard let data = try? JSONEncoder().encode(self) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    static func fromJSON(_ json: String) -> SummaryResult? {
        guard let data = json.data(using: .utf8),
              let result = try? JSONDecoder().decode(SummaryResult.self, from: data) else { return nil }
        return result
    }
}
