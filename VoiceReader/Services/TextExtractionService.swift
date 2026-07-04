// VoiceReader/Services/TextExtractionService.swift
import Foundation
import PDFKit
import Vision
import UIKit

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

        let rawText: String
        switch fileExtension {
        case "pdf":
            rawText = try extractFromPDF(url: url)
        case "md", "markdown":
            rawText = try extractFromMarkdown(url: url)
        case "txt":
            rawText = try extractFromPlainText(url: url)
        case "docx", "xlsx", "pptx":
            rawText = try extractFromOfficeDocument(url: url)
        default:
            throw ExtractionError.unsupportedFileType(fileExtension)
        }

        let trimmed = rawText.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw ExtractionError.extractionFailed("文件中没有可提取的文本内容")
        }
        return rawText
    }

    // MARK: - PDF

    private func extractFromPDF(url: URL) throws -> String {
        guard let pdfDocument = PDFDocument(url: url) else {
            throw ExtractionError.extractionFailed("无法打开 PDF 文件")
        }

        // 先尝试直接提取文字
        var fullText = ""
        for pageIndex in 0..<pdfDocument.pageCount {
            guard let page = pdfDocument.page(at: pageIndex),
                  let pageText = page.string else { continue }
            fullText += pageText + "\n"
        }

        let trimmed = fullText.trimmingCharacters(in: .whitespacesAndNewlines)
        if !trimmed.isEmpty {
            return fullText
        }

        // 文字型提取为空，尝试 OCR
        print("📖 文字提取为空，启动 OCR 识别…")
        return try extractFromPDFWithOCR(pdfDocument: pdfDocument)
    }

    // MARK: - OCR（Apple Vision）

    private func extractFromPDFWithOCR(pdfDocument: PDFDocument) throws -> String {
        var fullText = ""

        for pageIndex in 0..<pdfDocument.pageCount {
            guard let page = pdfDocument.page(at: pageIndex) else { continue }

            // 渲染 PDF 页面为图片
            let pageRect = page.bounds(for: .mediaBox)
            let renderer = UIGraphicsImageRenderer(size: pageRect.size)
            let pageImage = renderer.image { ctx in
                UIColor.white.setFill()
                ctx.fill(pageRect)
                ctx.cgContext.translateBy(x: 0, y: pageRect.height)
                ctx.cgContext.scaleBy(x: 1.0, y: -1.0)
                page.draw(with: .mediaBox, to: ctx.cgContext)
            }

            guard let cgImage = pageImage.cgImage else { continue }

            // Vision 文字识别
            let request = VNRecognizeTextRequest()
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.recognitionLanguages = ["zh-Hans", "zh-Hant", "en"]

            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            do {
                try handler.perform([request])
            } catch {
                print("⚠️ 第 \(pageIndex + 1) 页 OCR 失败: \(error.localizedDescription)")
                continue
            }

            guard let observations = request.results else { continue }

            var pageText = ""
            for observation in observations {
                guard let candidate = observation.topCandidates(1).first else { continue }
                pageText += candidate.string + "\n"
            }

            if !pageText.isEmpty {
                fullText += pageText + "\n"
            }
        }

        let trimmed = fullText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw ExtractionError.extractionFailed("OCR 未能识别出文字，图片质量可能过低")
        }

        print("✅ OCR 完成，识别出 \(trimmed.count) 个字符")
        return fullText
    }

    // MARK: - Markdown

    private func extractFromMarkdown(url: URL) throws -> String {
        let raw = try String(contentsOf: url, encoding: .utf8)
        guard !raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ExtractionError.extractionFailed("文件内容为空")
        }
        return stripMarkdown(raw)
    }

    /// 去掉 Markdown 语法标记，保留纯文本
    private func stripMarkdown(_ text: String) -> String {
        var result = text

        // 1. 去掉 YAML front matter（--- ... ---）
        if let frontMatterRange = result.range(of: "---\n", options: .caseInsensitive) {
            let after = result[frontMatterRange.upperBound...]
            if let closingRange = after.range(of: "\n---\n") ?? after.range(of: "\n---") {
                result = String(after[closingRange.upperBound...])
            }
        }

        // 2. 标题 # ## ### ...
        result = result.replacingOccurrences(of: "(?m)^#{1,6}\\s+", with: "", options: .regularExpression)

        // 3. 加粗 **text** 和 __text__
        result = result.replacingOccurrences(of: "\\*{2}(.+?)\\*{2}", with: "$1", options: .regularExpression)
        result = result.replacingOccurrences(of: "_{2}(.+?)_{2}", with: "$1", options: .regularExpression)

        // 4. 斜体 *text* 和 _text_
        result = result.replacingOccurrences(of: "(?<![*])\\*(?!\\*)(.+?)(?<!\\*)\\*(?![*])", with: "$1", options: .regularExpression)
        result = result.replacingOccurrences(of: "(?<!_)_(?!_)(.+?)(?<!_)_(?!_)", with: "$1", options: .regularExpression)

        // 5. 删除线 ~~text~~
        result = result.replacingOccurrences(of: "~~(.+?)~~", with: "$1", options: .regularExpression)

        // 6. 行内代码 `code`
        result = result.replacingOccurrences(of: "`{1,2}(.+?)`{1,2}", with: "$1", options: .regularExpression)

        // 7. 代码块 ```...```
        result = result.replacingOccurrences(of: "```[\\s\\S]*?```", with: "", options: .regularExpression)

        // 8. 链接 [text](url) → text
        result = result.replacingOccurrences(of: "\\[(.+?)\\]\\([^)]*\\)", with: "$1", options: .regularExpression)

        // 9. 图片 ![alt](url) → alt
        result = result.replacingOccurrences(of: "!\\[(.*?)\\]\\([^)]*\\)", with: "$1", options: .regularExpression)

        // 10. 引用 > 
        result = result.replacingOccurrences(of: "(?m)^>\\s?", with: "", options: .regularExpression)

        // 11. 无序列表 - * +
        result = result.replacingOccurrences(of: "(?m)^[\\-\\*\\+]\\s+", with: "", options: .regularExpression)

        // 12. 有序列表 1. 2. ...
        result = result.replacingOccurrences(of: "(?m)^\\d+\\.\\s+", with: "", options: .regularExpression)

        // 13. 水平线 --- *** ___
        result = result.replacingOccurrences(of: "(?m)^[-*_]{3,}\\s*$", with: "", options: .regularExpression)

        // 14. HTML 标签
        result = result.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)

        // 15. 清理多余空行
        result = result.replacingOccurrences(of: "\n{3,}", with: "\n\n", options: .regularExpression)

        return result.trimmingCharacters(in: .whitespacesAndNewlines)
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
