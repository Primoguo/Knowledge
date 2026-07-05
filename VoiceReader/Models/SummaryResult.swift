// Knowledge/Models/SummaryResult.swift
import Foundation

/// AI 文档摘要结果
struct SummaryResult: Codable, Identifiable {
    var id: UUID = UUID()
    /// 摘要正文
    let content: String
    /// 关键要点列表
    let keyPoints: [String]
    /// 生成时间
    let createdAt: Date

    init(content: String, keyPoints: [String] = [], createdAt: Date = Date()) {
        self.content = content
        self.keyPoints = keyPoints
        self.createdAt = createdAt
    }

    /// 用于持久化存储
    func toJSON() -> String? {
        guard let data = try? JSONEncoder().encode(self) else { return nil }
        return String(data: data, encoding: .utf8)
    }

    /// 从持久化数据恢复
    static func fromJSON(_ json: String) -> SummaryResult? {
        guard let data = json.data(using: .utf8),
              let result = try? JSONDecoder().decode(SummaryResult.self, from: data) else { return nil }
        return result
    }
}
