// Knowledge/Models/Document.swift
import Foundation
import SwiftData

/// 支持的文档类型
enum DocumentType: String, Codable, CaseIterable {
    case pdf
    case epub
    case docx
    case xlsx
    case pptx
    case txt
    case md
    case markdown
    case webpage
    case unknown

    init(fileExtension: String) {
        self = DocumentType.allCases.first { $0.rawValue == fileExtension.lowercased() } ?? .unknown
    }

    var displayName: String {
        switch self {
        case .webpage: return "网页"
        default:       return rawValue.uppercased()
        }
    }

    var iconName: String {
        switch self {
        case .pdf:     return "doc.richtext"
        case .epub:    return "book"
        case .docx:    return "doc.text"
        case .xlsx:    return "tablecells"
        case .pptx:    return "chart.bar.doc.horizontal"
        case .webpage: return "globe"
        default:       return "doc"
        }
    }

    var iconColor: String {
        switch self {
        case .pdf:     return "red"
        case .epub:    return "purple"
        case .docx:    return "blue"
        case .xlsx:    return "green"
        case .pptx:    return "orange"
        case .webpage: return "teal"
        default:       return "gray"
        }
    }
}

@Model
final class Document {
    var id: UUID = UUID()
    var title: String = ""
    var fileName: String = ""
    var fileTypeRaw: String = ""
    /// 文档正文（可能很大，CloudKit 同步时用外部存储）
    @Attribute(.externalStorage) var extractedText: String = ""
    var currentPosition: Int = 0
    var lastOpenedDate: Date = Date()
    var createdAt: Date = Date()
    var isFavorite: Bool = false
    /// AI 生成的文档摘要
    var summary: String?
    /// 播客音频文件路径（V3.0）
    var podcastAudioPath: String?

    // MARK: - 计算属性（不持久化）

    /// 文档类型枚举
    var fileType: DocumentType {
        get { DocumentType(fileExtension: fileTypeRaw) }
        set { fileTypeRaw = newValue.rawValue }
    }

    /// 文本总长度（字符数）
    var totalLength: Int {
        (extractedText as NSString).length
    }

    /// 阅读进度（0.0 ~ 1.0）
    var progress: Double {
        guard totalLength > 0 else { return 0 }
        return Double(currentPosition) / Double(totalLength)
    }

    init(
        id: UUID = UUID(),
        title: String,
        fileName: String,
        fileType: DocumentType = .unknown,
        extractedText: String = "",
        currentPosition: Int = 0,
        lastOpenedDate: Date = Date(),
        createdAt: Date = Date(),
        isFavorite: Bool = false,
        summary: String? = nil,
        podcastAudioPath: String? = nil
    ) {
        self.id = id
        self.title = title
        self.fileName = fileName
        self.fileTypeRaw = fileType.rawValue
        self.extractedText = extractedText
        self.currentPosition = currentPosition
        self.lastOpenedDate = lastOpenedDate
        self.createdAt = createdAt
        self.isFavorite = isFavorite
        self.summary = summary
        self.podcastAudioPath = podcastAudioPath
    }
}
