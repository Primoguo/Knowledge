// VoiceReader/Services/TextExtractionService.swift
import Foundation
import PDFKit

final class TextExtractionService {

    enum ExtractionError: LocalizedError {
        case unsupportedFileType(String)
        case fileNotFound
        case extractionFailed(String)

        var errorDescription: String? {
            switch self {
            case .unsupportedFileType(let type):
                return "不支持的文件类型: \(type)"
            case .fileNotFound:
                return "文件未找到"
            case .extractionFailed(let reason):
                return "文本提取失败: \(reason)"
            }
        }
    }

    func extractText(from url: URL) throws -> String {
        let fileExtension = url.pathExtension.lowercased()

        switch fileExtension {
        case "pdf":
            return try extractFromPDF(url: url)
        case "txt", "md", "markdown":
            return try extractFromPlainText(url: url)
        case "docx", "xlsx", "pptx":
            return try extractFromOfficeDocument(url: url)
        default:
            throw ExtractionError.unsupportedFileType(fileExtension)
        }
    }

    // MARK: - PDF
    private func extractFromPDF(url: URL) throws -> String {
        guard let pdfDocument = PDFDocument(url: url) else {
            throw ExtractionError.extractionFailed("无法打开 PDF 文件")
        }

        var fullText = ""
        for pageIndex in 0..<pdfDocument.pageCount {
            guard let page = pdfDocument.page(at: pageIndex),
                  let pageText = page.string else { continue }
            fullText += pageText + "\n"
        }

        let trimmed = fullText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw ExtractionError.extractionFailed("PDF 中没有可提取的文本内容，可能是扫描版 PDF")
        }
        return fullText
    }

    // MARK: - 纯文本
    private func extractFromPlainText(url: URL) throws -> String {
        let text = try String(contentsOf: url, encoding: .utf8)
        guard !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ExtractionError.extractionFailed("文件内容为空")
        }
        return text
    }

    // MARK: - Office 文档
    private func extractFromOfficeDocument(url: URL) throws -> String {
        guard url.startAccessingSecurityScopedResource() else {
            throw ExtractionError.extractionFailed("无法访问文件")
        }
        defer { url.stopAccessingSecurityScopedResource() }

        do {
            let attributedString = try NSAttributedString(
                url: url,
                options: [.documentType: NSAttributedString.DocumentType.rtf],
                documentAttributes: nil
            )
            let text = attributedString.string
            guard !text.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines).isEmpty else {
                throw ExtractionError.extractionFailed("文档内容为空")
            }
            return text
        } catch {
            throw ExtractionError.extractionFailed("文档解析失败: \(error.localizedDescription)")
        }
    }
}
