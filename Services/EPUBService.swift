//
//  EPUBService.swift
//  TranslateReader
//
//  Service for parsing and extracting EPUB files
//

import Foundation
import Compression

class EPUBService {
    
    // MARK: - Open EPUB
    
    /// Opens an EPUB file, extracts it, and returns a BookModel
    func openEPUB(url: URL) async throws -> BookModel {
        // Create temp directory for extraction
        let tempDir = FileHelper.tempDirectory.appendingPathComponent(UUID().uuidString)
        try FileHelper.createDirectory(at: tempDir)
        
        // Extract EPUB (which is a ZIP file)
        try await extractEPUB(from: url, to: tempDir)
        
        // Find and parse container.xml to get OPF path
        let containerURL = tempDir.appendingPathComponent("META-INF/container.xml")
        guard FileHelper.fileExists(at: containerURL) else {
            throw TranslateReaderError.invalidEPUB
        }
        
        let containerParser = ContainerParser()
        let opfRelativePath = try containerParser.parse(url: containerURL)
        let opfURL = tempDir.appendingPathComponent(opfRelativePath)
        
        // Parse OPF to get manifest and spine
        let opfParser = OPFParser()
        var manifest = try opfParser.parse(url: opfURL)
        
        // Get base path (OPF directory)
        let basePath = opfURL.deletingLastPathComponent()
        
        // Parse TOC to get chapter titles
        manifest.tocItems = parseTOC(manifest: manifest, basePath: basePath)
        
        // Convert to spine items (now with titles from TOC)
        var spineItems = manifest.toSpineItems()
        
        // For items without titles, try to extract from HTML
        spineItems = enrichSpineItemsWithHTMLTitles(spineItems, basePath: basePath)
        
        return BookModel(
            epub: url,
            title: manifest.metadata.title,
            spineItems: spineItems,
            extractedPath: tempDir,
            basePath: basePath
        )
    }
    
    // MARK: - Parse TOC
    
    /// Parses the Table of Contents from NCX (EPUB2) or NAV (EPUB3)
    private func parseTOC(manifest: EPUBManifest, basePath: URL) -> [TOCItem] {
        // Try EPUB3 NAV first (preferred)
        if let navHref = manifest.navHref {
            let navURL = basePath.appendingPathComponent(navHref)
            let navParser = NAVParser()
            let items = navParser.parse(url: navURL)
            if !items.isEmpty {
                return items
            }
        }
        
        // Fall back to EPUB2 NCX
        if let ncxHref = manifest.ncxHref {
            let ncxURL = basePath.appendingPathComponent(ncxHref)
            let ncxParser = NCXParser()
            let items = ncxParser.parse(url: ncxURL)
            if !items.isEmpty {
                return items
            }
        }
        
        // Last resort: try to find any NCX or NAV file
        return findAndParseTOCFallback(basePath: basePath)
    }
    
    // MARK: - Enrich Spine Items with HTML Titles
    
    /// For spine items without titles, try to extract title from HTML content
    private func enrichSpineItemsWithHTMLTitles(_ items: [SpineItem], basePath: URL) -> [SpineItem] {
        return items.map { item in
            // If already has title, keep it
            if item.title != nil {
                return item
            }
            
            // Try to extract title from HTML file
            let fileURL = basePath.appendingPathComponent(item.href)
            if let title = extractTitleFromHTML(url: fileURL) {
                return SpineItem(
                    id: item.id,
                    href: item.href,
                    mediaType: item.mediaType,
                    title: title
                )
            }
            
            return item
        }
    }
    
    /// Extracts title from HTML file using <title>, <h1>, or <h2> tags
    private func extractTitleFromHTML(url: URL) -> String? {
        guard let content = FileHelper.readFile(at: url) else { return nil }
        
        // Try <title> tag first
        if let title = extractTag(from: content, tag: "title") {
            let cleanTitle = cleanHTMLTitle(title)
            if !cleanTitle.isEmpty && cleanTitle.count < 100 {
                return cleanTitle
            }
        }
        
        // Try <h1> tag
        if let title = extractTag(from: content, tag: "h1") {
            let cleanTitle = cleanHTMLTitle(title)
            if !cleanTitle.isEmpty && cleanTitle.count < 100 {
                return cleanTitle
            }
        }
        
        // Try <h2> tag
        if let title = extractTag(from: content, tag: "h2") {
            let cleanTitle = cleanHTMLTitle(title)
            if !cleanTitle.isEmpty && cleanTitle.count < 100 {
                return cleanTitle
            }
        }
        
        // Try dc:title or epub:title
        let dcTitlePattern = #"<dc:title[^>]*>([^<]+)</dc:title>"#
        if let regex = try? NSRegularExpression(pattern: dcTitlePattern, options: .caseInsensitive),
           let match = regex.firstMatch(in: content, range: NSRange(content.startIndex..., in: content)),
           let range = Range(match.range(at: 1), in: content) {
            let title = cleanHTMLTitle(String(content[range]))
            if !title.isEmpty {
                return title
            }
        }
        
        return nil
    }
    
    /// Extracts content from an HTML tag
    private func extractTag(from content: String, tag: String) -> String? {
        // Pattern to match the tag and its content
        let pattern = "<\(tag)[^>]*>([\\s\\S]*?)</\(tag)>"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let match = regex.firstMatch(in: content, range: NSRange(content.startIndex..., in: content)),
              let range = Range(match.range(at: 1), in: content) else {
            return nil
        }
        return String(content[range])
    }
    
    /// Cleans HTML from title text
    private func cleanHTMLTitle(_ text: String) -> String {
        var clean = text
        
        // Remove HTML tags
        let tagPattern = #"<[^>]+>"#
        clean = clean.replacingOccurrences(of: tagPattern, with: "", options: .regularExpression)
        
        // Decode HTML entities
        clean = decodeHTMLEntities(clean)
        
        // Clean whitespace
        clean = clean.components(separatedBy: .whitespacesAndNewlines)
            .filter { !$0.isEmpty }
            .joined(separator: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        
        return clean
    }
    
    /// Fallback: search for TOC files in the EPUB
    private func findAndParseTOCFallback(basePath: URL) -> [TOCItem] {
        let fileManager = FileManager.default
        
        // Common TOC file names
        let tocFiles = ["toc.ncx", "nav.xhtml", "toc.xhtml", "navigation.xhtml"]
        
        for filename in tocFiles {
            let fileURL = basePath.appendingPathComponent(filename)
            if fileManager.fileExists(atPath: fileURL.path) {
                if filename.hasSuffix(".ncx") {
                    let parser = NCXParser()
                    let items = parser.parse(url: fileURL)
                    if !items.isEmpty { return items }
                } else {
                    let parser = NAVParser()
                    let items = parser.parse(url: fileURL)
                    if !items.isEmpty { return items }
                }
            }
        }
        
        // Try to find recursively
        if let enumerator = fileManager.enumerator(at: basePath, includingPropertiesForKeys: nil) {
            while let fileURL = enumerator.nextObject() as? URL {
                let filename = fileURL.lastPathComponent.lowercased()
                if filename == "toc.ncx" {
                    let parser = NCXParser()
                    let items = parser.parse(url: fileURL)
                    if !items.isEmpty { return items }
                } else if filename.contains("nav") && filename.hasSuffix(".xhtml") {
                    let parser = NAVParser()
                    let items = parser.parse(url: fileURL)
                    if !items.isEmpty { return items }
                }
            }
        }
        
        return []
    }
    
    // MARK: - Extract EPUB (ZIP)
    
    /// Extracts EPUB (ZIP) contents to destination directory
    private func extractEPUB(from sourceURL: URL, to destinationURL: URL) async throws {
        // Use Process to call unzip (available on macOS)
        // This is the most reliable way without external dependencies
        try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<Void, Error>) in
            let process = Process()
            process.executableURL = URL(fileURLWithPath: "/usr/bin/unzip")
            process.arguments = ["-o", "-q", sourceURL.path, "-d", destinationURL.path]
            
            process.terminationHandler = { process in
                if process.terminationStatus == 0 {
                    continuation.resume()
                } else {
                    continuation.resume(throwing: TranslateReaderError.extractionFailed)
                }
            }
            
            do {
                try process.run()
            } catch {
                continuation.resume(throwing: TranslateReaderError.extractionFailed)
            }
        }
    }
    
    // MARK: - Get HTML / Body Content
    
    /// Returns raw HTML for a spine item (chapter).
    func getHTMLContent(for book: BookModel, at index: Int) -> String? {
        guard book.type == .epub,
              let contentURL = book.epubContentURL(at: index) else { return nil }
        return FileHelper.readFile(at: contentURL)
    }
    
    /// Extracts the inner content of <body>...</body> from full HTML.
    func getBodyContent(from html: String) -> String? {
        let pattern = #"<body[^>]*>([\s\S]*?)</body>"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive),
              let match = regex.firstMatch(in: html, range: NSRange(html.startIndex..., in: html)),
              match.numberOfRanges > 1,
              let range = Range(match.range(at: 1), in: html) else { return nil }
        return String(html[range])
    }
    
    /// Body block: either text (plain) or image (raw HTML of <img>).
    enum BodyBlock {
        case text(String)
        case image(html: String)
    }
    
    /// Splits body HTML into alternating text and image blocks so images can be preserved when translating.
    func getBodyBlocks(from bodyHTML: String) -> [BodyBlock] {
        var blocks: [BodyBlock] = []
        let imgPattern = #"<img[^>]*>"#
        guard let regex = try? NSRegularExpression(pattern: imgPattern, options: .caseInsensitive) else {
            let plain = stripHTMLTags(from: "<body>\(bodyHTML)</body>")
            if !plain.isEmpty { blocks.append(.text(plain)) }
            return blocks
        }
        let range = NSRange(bodyHTML.startIndex..., in: bodyHTML)
        var lastEnd = bodyHTML.startIndex
        regex.enumerateMatches(in: bodyHTML, range: range) { match, _, _ in
            guard let m = match, let r = Range(m.range, in: bodyHTML) else { return }
            let before = String(bodyHTML[lastEnd..<r.lowerBound])
            let plain = stripHTMLTags(from: "<div>\(before)</div>").trimmingCharacters(in: .whitespacesAndNewlines)
            if !plain.isEmpty { blocks.append(.text(plain)) }
            blocks.append(.image(html: String(bodyHTML[r])))
            lastEnd = r.upperBound
        }
        let after = String(bodyHTML[lastEnd...])
        let plainAfter = stripHTMLTags(from: "<div>\(after)</div>").trimmingCharacters(in: .whitespacesAndNewlines)
        if !plainAfter.isEmpty { blocks.append(.text(plainAfter)) }
        return blocks
    }
    
    // MARK: - Get Text Content
    
    /// Extracts text content from an EPUB spine item
    func getTextContent(for book: BookModel, at index: Int) -> String {
        guard book.type == .epub,
              let contentURL = book.epubContentURL(at: index),
              let htmlContent = FileHelper.readFile(at: contentURL) else {
            return ""
        }
        
        return stripHTMLTags(from: htmlContent)
    }
    
    /// Strips HTML tags and extracts plain text
    private func stripHTMLTags(from html: String) -> String {
        var text = html
        
        // Remove script and style content
        let scriptPattern = #"<script[^>]*>[\s\S]*?</script>"#
        let stylePattern = #"<style[^>]*>[\s\S]*?</style>"#
        
        text = text.replacingOccurrences(of: scriptPattern, with: "", options: .regularExpression)
        text = text.replacingOccurrences(of: stylePattern, with: "", options: .regularExpression)
        
        // Replace common block elements with newlines
        let blockElements = ["</p>", "</div>", "</h1>", "</h2>", "</h3>", "</h4>", "</h5>", "</h6>", 
                           "<br>", "<br/>", "<br />", "</li>", "</blockquote>"]
        for element in blockElements {
            text = text.replacingOccurrences(of: element, with: "\n", options: .caseInsensitive)
        }
        
        // Remove all remaining HTML tags
        let tagPattern = #"<[^>]+>"#
        text = text.replacingOccurrences(of: tagPattern, with: "", options: .regularExpression)
        
        // Decode HTML entities
        text = decodeHTMLEntities(text)
        
        // Clean up whitespace
        text = text.components(separatedBy: .newlines)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
            .joined(separator: "\n\n")
        
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    /// Decodes common HTML entities
    private func decodeHTMLEntities(_ text: String) -> String {
        var result = text
        
        let entities: [String: String] = [
            "&nbsp;": " ",
            "&amp;": "&",
            "&lt;": "<",
            "&gt;": ">",
            "&quot;": "\"",
            "&apos;": "'",
            "&#39;": "'",
            "&mdash;": "—",
            "&ndash;": "–",
            "&hellip;": "…",
            "&ldquo;": "\u{201C}",
            "&rdquo;": "\u{201D}",
            "&lsquo;": "\u{2018}",
            "&rsquo;": "\u{2019}",
            "&copy;": "©",
            "&reg;": "®",
            "&trade;": "™"
        ]
        
        for (entity, char) in entities {
            result = result.replacingOccurrences(of: entity, with: char)
        }
        
        // Handle numeric entities
        let numericPattern = #"&#(\d+);"#
        if let regex = try? NSRegularExpression(pattern: numericPattern) {
            let range = NSRange(result.startIndex..., in: result)
            result = regex.stringByReplacingMatches(
                in: result,
                range: range,
                withTemplate: ""
            )
        }
        
        return result
    }
    
    // MARK: - Cleanup
    
    /// Removes extracted EPUB files
    func cleanup(book: BookModel) {
        if let extractedPath = book.extractedPath {
            FileHelper.removeDirectory(at: extractedPath)
        }
    }
}
