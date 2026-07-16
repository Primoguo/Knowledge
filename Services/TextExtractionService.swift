// Knowledge/Services/TextExtractionService.swift
import Foundation
import PDFKit
import Vision
import UIKit
import Compression

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
        case "epub":
            rawText = try extractFromEPUB(url: url)
        case "docx", "xlsx", "pptx":
            rawText = try extractFromOfficeDocument(url: url)
        case "webpage":
            rawText = try extractFromPlainText(url: url)
        default:
            throw ExtractionError.unsupportedFileType(fileExtension)
        }

        let trimmed = rawText.trimmingCharacters(in: CharacterSet.whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            throw ExtractionError.extractionFailed("文件中没有可提取的文本内容")
        }
        return rawText
    }

    // MARK: - 网页文本提取

    /// 从 URL 获取网页 HTML 并提取纯文本（自动识别正文，过滤导航/广告/推荐）
    func extractFromWebPage(urlString: String) async throws -> (title: String, text: String) {
        guard let url = URL(string: urlString) else {
            throw ExtractionError.extractionFailed("无效的链接地址")
        }

        // 获取网页内容
        var request = URLRequest(url: url)
        request.setValue("Mozilla/5.0 (iPhone; CPU iPhone OS 17_0 like Mac OS X) AppleWebKit/605.1.15", forHTTPHeaderField: "User-Agent")
        let (data, response) = try await URLSession.shared.data(for: request)

        // 尝试从响应中获取编码
        var encoding: String.Encoding = .utf8
        if let textEncodingName = (response as? HTTPURLResponse)?.textEncodingName {
            let cfEncoding = CFStringConvertIANACharSetNameToEncoding(textEncodingName as CFString)
            if cfEncoding != kCFStringEncodingInvalidId {
                encoding = String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(cfEncoding))
            }
        }

        guard let htmlString = String(data: data, encoding: encoding) ?? String(data: data, encoding: .utf8) else {
            throw ExtractionError.extractionFailed("无法解析网页内容")
        }

        // 提取标题（优先 og:title → <title> → 域名）
        let title = extractMetaTag("og:title", from: htmlString)
            ?? extractMetaTag("twitter:title", from: htmlString)
            ?? extractTitle(from: htmlString)
            ?? url.host
            ?? urlString

        // 核心：先定位正文区域，再提取文本
        let bodyHTML = extractBodyRegion(from: htmlString)

        // 用 NSAttributedString 解析正文区域的 HTML
        let rawText: String
        if let bodyData = bodyHTML.data(using: .utf8),
           let attributed = try? NSAttributedString(
            data: bodyData,
            options: [.documentType: NSAttributedString.DocumentType.html,
                      .characterEncoding: String.Encoding.utf8.rawValue],
            documentAttributes: nil
           ) {
            rawText = attributed.string
        } else {
            // 回退：手动去除 HTML 标签
            rawText = stripHTMLTags(htmlString)
        }

        // 后处理：清洗文本，去除导航残留、短噪音行等
        let cleaned = cleanExtractedText(rawText)

        guard !cleaned.isEmpty else {
            throw ExtractionError.extractionFailed("网页中没有可提取的正文内容")
        }

        return (title, cleaned)
    }

    /// 从 HTML 中提取 <title> 标签内容
    private func extractTitle(from html: String) -> String? {
        guard let titleStart = html.range(of: "<title>", options: .caseInsensitive),
              let titleEnd = html.range(of: "</title>", options: .caseInsensitive) else {
            return nil
        }
        let title = String(html[titleStart.upperBound..<titleEnd.lowerBound])
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return title.isEmpty ? nil : title
    }

    /// 提取 meta 标签内容（如 og:title、description 等）
    private func extractMetaTag(_ property: String, from html: String) -> String? {
        let patterns = [
            #"property="\#(property)"\s+content="([^"]*)""#,
            #"name="\#(property)"\s+content="([^"]*)""#,
        ]
        for pattern in patterns {
            if let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
               let range = Range(match.range(at: 1), in: html) {
                let value = String(html[range]).trimmingCharacters(in: .whitespacesAndNewlines)
                if !value.isEmpty { return value }
            }
        }
        return nil
    }

    /// 从 HTML 中提取正文区域
    /// 策略：优先找 <article> → 常见正文 class/id → 回退到 <body>
    private func extractBodyRegion(from html: String) -> String {
        // 1. 先去除明确无关的区域（head、script、style、nav、footer、header、aside）
        var cleaned = html
        let removeTags = ["script", "style", "noscript", "head", "nav", "footer", "header", "aside", "iframe", "form", "button"]
        for tag in removeTags {
            cleaned = cleaned.replacingOccurrences(of: "<\(tag)[^>]*>[\\s\\S]*?</\(tag)>",
                                                    with: "", options: [.regularExpression, .caseInsensitive])
        }
        // 去除 HTML 注释
        cleaned = cleaned.replacingOccurrences(of: "<!--[\\s\\S]*?-->", with: "", options: .regularExpression)

        // 2. 优先匹配 <article> 标签
        if let articleRange = findTagContent(tag: "article", in: cleaned) {
            return String(cleaned[articleRange])
        }

        // 3. 匹配常见正文容器 class/id
        let contentSelectors = [
            #"class="[^"]*(?:article-content|article_body|article-detail|rich_media_content|post-content|entry-content|content-article|detail-content|article-text|news-content|story-body|main-content|post-body|article__content)[^"]*""#,
            #"id="[^"]*(?:article-content|article_body|content|main-content|post-content|entry-content|detail|article)[^"]*""#,
        ]

        for selectorPattern in contentSelectors {
            if let regex = try? NSRegularExpression(pattern: selectorPattern, options: .caseInsensitive),
               let match = regex.firstMatch(in: cleaned, range: NSRange(cleaned.startIndex..., in: cleaned)) {
                // 找到包含该 class/id 的标签，提取其内容
                let matchPos = match.range.location
                // 向前找最近的 <div 或 <section 标签
                let before = String(cleaned.prefix(matchPos))
                if let tagStart = findLastTagOpen(in: before) {
                    let after = String(cleaned[tagStart...])
                    // 找到对应的闭合标签
                    if let tagContent = extractTagContent(from: after) {
                        return tagContent
                    }
                }
            }
        }

        // 4. 回退：尝试提取 <body> 内容（但已经去掉了 nav/footer/header/aside）
        if let bodyRange = findTagContent(tag: "body", in: cleaned) {
            return String(cleaned[bodyRange])
        }

        // 5. 最终回退：返回清洗后的全部 HTML
        return cleaned
    }

    /// 找到指定 HTML 标签的内容（不含标签本身）
    private func findTagContent(tag: String, in html: String) -> Range<String.Index>? {
        guard let openRange = html.range(of: "<\(tag)[^>]*>", options: .regularExpression) else { return nil }
        let afterOpen = openRange.upperBound
        let remaining = html[afterOpen...]

        // 简单匹配：找 </tag>
        guard let closeRange = remaining.range(of: "</\(tag)>", options: .caseInsensitive) else {
            return afterOpen..<html.endIndex
        }
        return afterOpen..<closeRange.lowerBound
    }

    /// 在字符串末尾附近找最后一个打开的标签位置
    private func findLastTagOpen(in html: String) -> String.Index? {
        guard let lastDiv = html.range(of: "<div[^>]*>", options: [.regularExpression, .backwards]) else {
            return html.range(of: "<section[^>]*>", options: [.regularExpression, .backwards])?.lowerBound
        }
        return lastDiv.lowerBound
    }

    /// 从标签内容中提取完整闭合区域（简单括号计数）
    private func extractTagContent(from html: String) -> String? {
        let tagPattern = #"<(\w+)[^>]*>"#
        guard let firstMatch = try? NSRegularExpression(pattern: tagPattern).firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
              let tagRange = Range(firstMatch.range(at: 1), in: html) else { return nil }
        let tagName = String(html[tagRange])

        var depth = 0
        let tagOpenPattern = try? NSRegularExpression(pattern: "<\(tagName)[\\s>]")
        let tagClosePattern = try? NSRegularExpression(pattern: "</\(tagName)>")

        var searchRange = NSRange(html.startIndex..., in: html)
        while let openMatch = tagOpenPattern?.firstMatch(in: html, range: searchRange) {
            if let closeMatch = tagClosePattern?.firstMatch(in: html, range: NSRange(openMatch.range.location..<html.utf16.count)) {
                depth += 1
                if depth == 1 {
                    // 跳过这个打开标签
                    let afterOpen = html.index(html.startIndex, offsetBy: openMatch.range.upperBound)
                    let beforeClose = html.index(html.startIndex, offsetBy: closeMatch.range.lowerBound)
                    return String(html[afterOpen..<beforeClose])
                }
                searchRange.location = closeMatch.range.upperBound
            } else {
                break
            }
        }
        return nil
    }

    /// 清洗提取后的文本：去除导航残留、短噪音行、多余空行、HTML 残留
    private func cleanExtractedText(_ text: String) -> String {
        // 先清理残留 HTML 标签和属性碎片
        var text = stripHTMLResidue(text)

        var lines = text.components(separatedBy: "\n")

        // 过滤规则
        let noisePatterns: [String] = [
            "首页", "资讯", "图表", "快讯", "行情", "日历", "VIP", "会员",
            "登录", "注册", "扫码", "分享", "打开APP", "下载APP",
            "大家都在搜", "热门搜索", "相关阅读", "推荐阅读",
            "风险提示", "免责声明", "免责条款", "市场有风险",
            "广告", "推广", "赞助",
            "上一篇", "下一篇", "返回首页", "回到顶部",
            "评论", "点赞", "收藏", "转发",
            "©", "Copyright", "All Rights Reserved",
            "browsehappy", "ReadPolicy", "Cookies",
            "e-module-", "compatibility", "browser-hint",
        ]

        lines = lines.filter { line in
            let trimmed = line.trimmingCharacters(in: .whitespacesAndNewlines)
            // 跳过空行（后续统一处理）
            if trimmed.isEmpty { return true }
            // 跳过纯数字/符号行（页码、分隔线等）
            if trimmed.range(of: #"^[\d\s\-_=*#~\.·•|/\\]+$"#, options: .regularExpression) != nil {
                return trimmed.count > 5  // 保留长数字行（可能是数据）
            }
            // 跳过噪声匹配行
            for pattern in noisePatterns {
                if trimmed.contains(pattern) {
                    return false
                }
            }
            // 跳过 URL
            if trimmed.hasPrefix("http://") || trimmed.hasPrefix("https://") {
                return false
            }
            return true
        }

        // 合并连续空行
        let cleaned = lines.joined(separator: "\n")
        let result = cleaned.replacingOccurrences(of: "\n{3,}", with: "\n\n", options: .regularExpression)
        return result.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// 清理文本中残留的 HTML 标签碎片和属性泄漏
    private func stripHTMLResidue(_ text: String) -> String {
        var result = text

        // 1. 去除完整 HTML 标签（包括带属性的）
        result = result.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)

        // 2. 去除 class="..." / id="..." / data-*="..." 等属性碎片（标签未闭合时泄漏）
        result = result.replacingOccurrences(
            of: #"(?:class|id|data-[a-z-]+|style|role|aria-[a-z-]+)\s*=\s*"[^"]*""#,
            with: "", options: [.regularExpression, .caseInsensitive])

        // 3. 去除 class='...' / id='...' 单引号版本
        result = result.replacingOccurrences(
            of: #"(?:class|id|data-[a-z-]+|style|role|aria-[a-z-]+)\s*=\s*'[^']*'"#,
            with: "", options: [.regularExpression, .caseInsensitive])

        // 4. 去除残留的 HTML 实体
        let entities: [(String, String)] = [
            ("&nbsp;", " "), ("&amp;", "&"), ("&lt;", "<"), ("&gt;", ">"),
            ("&quot;", "\""), ("&#39;", "'"), ("&hellip;", "…"),
            ("&mdash;", "—"), ("&ndash;", "–"), ("&copy;", "©"),
            ("&ldquo;", "\u{201C}"), ("&rdquo;", "\u{201D}"),
            ("&lsquo;", "\u{2018}"), ("&rsquo;", "\u{2019}"),
            ("&#x27;", "'"), ("&apos;", "'"),
        ]
        for (entity, replacement) in entities {
            result = result.replacingOccurrences(of: entity, with: replacement)
        }
        // 数字实体 &#123; &#x7B;
        result = result.replacingOccurrences(of: "&#x[0-9a-fA-F]+;", with: "", options: .regularExpression)
        result = result.replacingOccurrences(of: "&#\\d+;", with: "", options: .regularExpression)

        // 5. 去除不完整的标签碎片（如孤立的 </div 或 <div）
        result = result.replacingOccurrences(of: "</?\\w+\\s*", with: "", options: .regularExpression)

        // 6. 清理多余空白
        result = result.replacingOccurrences(of: "[ \\t]{2,}", with: " ", options: .regularExpression)

        return result
    }

    /// 手动去除 HTML 标签
    private func stripHTMLTags(_ html: String) -> String {
        var text = html
        
        // 1. 去除 script/style/noscript/head 标签及内容
        text = text.replacingOccurrences(of: "<script[^>]*>[\\s\\S]*?</script>", with: "", options: [.regularExpression, .caseInsensitive])
        text = text.replacingOccurrences(of: "<style[^>]*>[\\s\\S]*?</style>", with: "", options: [.regularExpression, .caseInsensitive])
        text = text.replacingOccurrences(of: "<noscript[^>]*>[\\s\\S]*?</noscript>", with: "", options: [.regularExpression, .caseInsensitive])
        text = text.replacingOccurrences(of: "<head[^>]*>[\\s\\S]*?</head>", with: "", options: [.regularExpression, .caseInsensitive])
        
        // 2. 去除常见导航/菜单/广告/弹窗相关标签
        let navTags = ["nav", "header", "footer", "aside", "menu", "sidebar", "dialog", "modal", "popup", "banner", "advertisement"]
        for tag in navTags {
            text = text.replacingOccurrences(of: "<\(tag)[^>]*>[\\s\\S]*?</\(tag)>", with: "", options: [.regularExpression, .caseInsensitive])
        }
        
        // 3. 去除常见导航类名（class 属性包含 nav/menu/header 等）
        let navClassPatterns = [
            #"<div[^>]*class="[^"]*(?:nav|menu|header|footer|sidebar|popup|modal|banner|advertisement)[^"]*"[^>]*>[\s\S]*?</div>"#,
            #"<ul[^>]*class="[^"]*(?:nav|menu|breadcrumb|pagination)[^"]*"[^>]*>[\s\S]*?</ul>"#,
            #"<li[^>]*class="[^"]*(?:nav|menu)[^"]*"[^>]*>[\s\S]*?</li>"#,
        ]
        for pattern in navClassPatterns {
            text = text.replacingOccurrences(of: pattern, with: "", options: [.regularExpression, .caseInsensitive])
        }
        
        // 4. 去除 HTML 注释
        text = text.replacingOccurrences(of: "<!--[\\s\\S]*?-->", with: "", options: .regularExpression)
        
        // 5. 将块级元素替换为换行
        text = text.replacingOccurrences(of: "</?(div|p|h[1-6]|li|tr|article|section|main|blockquote|pre|figure|figcaption)[^>]*>", with: "\n", options: [.regularExpression, .caseInsensitive])
        text = text.replacingOccurrences(of: "</?(br|hr)[^>]*>", with: "\n", options: [.regularExpression, .caseInsensitive])
        
        // 6. 去除所有剩余 HTML 标签
        text = text.replacingOccurrences(of: "<[^>]+>", with: "", options: .regularExpression)
        
        // 7. 解码 HTML 实体
        text = text.replacingOccurrences(of: "&nbsp;", with: " ")
        text = text.replacingOccurrences(of: "&amp;", with: "&")
        text = text.replacingOccurrences(of: "&lt;", with: "<")
        text = text.replacingOccurrences(of: "&gt;", with: ">")
        text = text.replacingOccurrences(of: "&quot;", with: "\"")
        text = text.replacingOccurrences(of: "&#39;", with: "'")
        text = text.replacingOccurrences(of: "&ldquo;", with: "\u{201C}")
        text = text.replacingOccurrences(of: "&rdquo;", with: "\u{201D}")
        text = text.replacingOccurrences(of: "&lsquo;", with: "\u{2018}")
        text = text.replacingOccurrences(of: "&rsquo;", with: "\u{2019}")
        text = text.replacingOccurrences(of: "&hellip;", with: "\u{2026}")
        text = text.replacingOccurrences(of: "&mdash;", with: "\u{2014}")
        text = text.replacingOccurrences(of: "&ndash;", with: "\u{2013}")
        
        // 8. 去除多余空行和空白
        text = text.replacingOccurrences(of: "\n{3,}", with: "\n\n", options: .regularExpression)
        text = text.replacingOccurrences(of: "[ \\t]+\n", with: "\n", options: .regularExpression)
        text = text.replacingOccurrences(of: "\n[ \\t]+", with: "\n", options: .regularExpression)
        
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
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

    // MARK: - EPUB

    private func extractFromEPUB(url: URL) throws -> String {
        // 解压 EPUB（ZIP 格式）
        let tempDir = FileManager.default.temporaryDirectory
            .appendingPathComponent("epub_\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: tempDir) }

        try unzipEPUB(at: url, to: tempDir)

        // 读取 META-INF/container.xml 找到 content.opf 路径
        let containerURL = tempDir.appendingPathComponent("META-INF/container.xml")
        guard let containerData = try? Data(contentsOf: containerURL),
              let containerXML = String(data: containerData, encoding: .utf8) else {
            throw ExtractionError.extractionFailed("无法解析 EPUB 容器文件")
        }

        // 用正则提取 rootfile full-path
        guard let rootfileMatch = containerXML.range(of: #"full-path="([^"]+)""#, options: .regularExpression) else {
            throw ExtractionError.extractionFailed("无法找到 EPUB 内容描述文件")
        }
        let rootfileAttr = String(containerXML[rootfileMatch])
        guard let pathStart = rootfileAttr.range(of: #""("#, options: .regularExpression),
              let pathEnd = rootfileAttr[pathStart.upperBound...].range(of: "\"") else {
            throw ExtractionError.extractionFailed("EPUB 文件路径解析失败")
        }
        let opfRelativePath = String(rootfileAttr[pathStart.upperBound..<pathEnd.lowerBound])

        // 读取 .opf 文件，提取 spine 中的内容文件列表
        let opfURL = tempDir.appendingPathComponent(opfRelativePath)
        let opfDir = opfURL.deletingLastPathComponent()
        guard let opfData = try? Data(contentsOf: opfURL),
              let opfXML = String(data: opfData, encoding: .utf8) else {
            throw ExtractionError.extractionFailed("无法解析 EPUB 内容清单")
        }

        // 提取所有 <itemref idref="..." /> 中的 idref
        var idrefs: [String] = []
        let itemrefPattern = #"idref="([^"]+)""#
        if let regex = try? NSRegularExpression(pattern: itemrefPattern) {
            let matches = regex.matches(in: opfXML, range: NSRange(opfXML.startIndex..., in: opfXML))
            for match in matches {
                if let range = Range(match.range(at: 1), in: opfXML) {
                    idrefs.append(String(opfXML[range]))
                }
            }
        }

        // 从 <manifest> 中根据 idref 找到对应的 href
        var contentFiles: [String] = []
        for idref in idrefs {
            let idPattern = #"id=""# + NSRegularExpression.escapedPattern(for: idref) + #""[^>]*href="([^"]+)""#
            if let regex = try? NSRegularExpression(pattern: idPattern) {
                if let match = regex.firstMatch(in: opfXML, range: NSRange(opfXML.startIndex..., in: opfXML)),
                   let range = Range(match.range(at: 1), in: opfXML) {
                    contentFiles.append(String(opfXML[range]))
                }
            }
        }

        // 按顺序读取所有内容文件，提取文本
        var fullText = ""
        for file in contentFiles {
            let fileURL = opfDir.appendingPathComponent(file)
            guard let htmlData = try? Data(contentsOf: fileURL) else { continue }

            // 用 NSAttributedString 解析 HTML 提取纯文本
            if let attributed = try? NSAttributedString(
                data: htmlData,
                options: [.documentType: NSAttributedString.DocumentType.html,
                          .characterEncoding: String.Encoding.utf8.rawValue],
                documentAttributes: nil
            ) {
                let text = attributed.string.trimmingCharacters(in: .whitespacesAndNewlines)
                if !text.isEmpty {
                    fullText += text + "\n\n"
                }
            }
        }

        guard !fullText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw ExtractionError.extractionFailed("EPUB 文件中没有可提取的文本内容")
        }

        return fullText
    }

    // MARK: - ZIP 解压（纯 Swift，零依赖）

    private func unzipEPUB(at sourceURL: URL, to destinationURL: URL) throws {
        let data = try Data(contentsOf: sourceURL)
        try FileManager.default.createDirectory(at: destinationURL, withIntermediateDirectories: true)

        let endOfCentralDirSignature: UInt32 = 0x06054b50
        let centralDirSignature: UInt32 = 0x02014b50
        let localFileSignature: UInt32 = 0x04034b50

        // 找到 End of Central Directory Record
        guard data.count > 22 else { throw ExtractionError.extractionFailed("无效的 ZIP 文件") }

        var eocdOffset = data.count - 22
        var found = false
        while eocdOffset >= 0 {
            if data.readUInt32(at: eocdOffset) == endOfCentralDirSignature {
                found = true
                break
            }
            eocdOffset -= 1
        }
        guard found else { throw ExtractionError.extractionFailed("无法找到 ZIP 中央目录") }

        let centralDirOffset = Int(data.readUInt32(at: eocdOffset + 16))
        let totalEntries = Int(data.readUInt16(at: eocdOffset + 10))

        // 遍历 Central Directory 条目
        var cdOffset = centralDirOffset
        for _ in 0..<totalEntries {
            guard data.readUInt32(at: cdOffset) == centralDirSignature else { break }

            let compressionMethod = data.readUInt16(at: cdOffset + 10)
            let compressedSize = Int(data.readUInt32(at: cdOffset + 20))
            let uncompressedSize = Int(data.readUInt32(at: cdOffset + 24))
            let fileNameLength = Int(data.readUInt16(at: cdOffset + 28))
            let extraFieldLength = Int(data.readUInt16(at: cdOffset + 30))
            let commentLength = Int(data.readUInt16(at: cdOffset + 32))
            let localHeaderOffset = Int(data.readUInt32(at: cdOffset + 42))

            let fileNameData = data.subdata(in: cdOffset + 46..<cdOffset + 46 + fileNameLength)
            guard let fileName = String(data: fileNameData, encoding: .utf8) else {
                cdOffset += 46 + fileNameLength + extraFieldLength + commentLength
                continue
            }

            // 跳过目录条目
            if fileName.hasSuffix("/") {
                let dirURL = destinationURL.appendingPathComponent(fileName)
                try? FileManager.default.createDirectory(at: dirURL, withIntermediateDirectories: true)
                cdOffset += 46 + fileNameLength + extraFieldLength + commentLength
                continue
            }

            // 找到 Local File Header
            let lhOffset = localHeaderOffset
            guard data.readUInt32(at: lhOffset) == localFileSignature else {
                cdOffset += 46 + fileNameLength + extraFieldLength + commentLength
                continue
            }

            let lhFileNameLength = Int(data.readUInt16(at: lhOffset + 26))
            let lhExtraFieldLength = Int(data.readUInt16(at: lhOffset + 28))
            let dataStart = lhOffset + 30 + lhFileNameLength + lhExtraFieldLength

            // 提取文件数据
            let fileData: Data
            if compressionMethod == 0 {
                // 无压缩（Store）
                fileData = data.subdata(in: dataStart..<dataStart + compressedSize)
            } else if compressionMethod == 8 {
                // Deflate 压缩
                let compressedData = data.subdata(in: dataStart..<dataStart + compressedSize)
                fileData = try inflate(data: compressedData, expectedSize: uncompressedSize)
            } else {
                // 不支持的压缩方式，跳过
                cdOffset += 46 + fileNameLength + extraFieldLength + commentLength
                continue
            }

            // 写入文件
            let fileURL = destinationURL.appendingPathComponent(fileName)
            let fileDir = fileURL.deletingLastPathComponent()
            try? FileManager.default.createDirectory(at: fileDir, withIntermediateDirectories: true)
            try fileData.write(to: fileURL)

            cdOffset += 46 + fileNameLength + extraFieldLength + commentLength
        }
    }

    /// Deflate 解压
    private func inflate(data: Data, expectedSize: Int) throws -> Data {
        let bufferSize = max(expectedSize, data.count * 4)
        var result = Data(count: bufferSize)

        let bytesWritten = data.withUnsafeBytes { (src: UnsafeRawBufferPointer) -> Int in
            result.withUnsafeMutableBytes { (dst: UnsafeMutableRawBufferPointer) -> Int in
                guard let srcBase = src.baseAddress, let dstBase = dst.baseAddress else {
                    return 0
                }
                return compression_decode_buffer(
                    dstBase, dst.count,
                    srcBase, src.count,
                    nil,
                    COMPRESSION_ZLIB
                )
            }
        }

        guard bytesWritten > 0 else {
            throw ExtractionError.extractionFailed("ZIP 解压失败")
        }

        return result.prefix(bytesWritten)
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

// MARK: - Data 扩展（ZIP 解析用）

private extension Data {
    func readUInt16(at offset: Int) -> UInt16 {
        guard offset + 1 < count else { return 0 }
        return self[offset..<offset+2].withUnsafeBytes { $0.load(as: UInt16.self).littleEndian }
    }

    func readUInt32(at offset: Int) -> UInt32 {
        guard offset + 3 < count else { return 0 }
        return self[offset..<offset+4].withUnsafeBytes { $0.load(as: UInt32.self).littleEndian }
    }
}
