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
        let manifest = try opfParser.parse(url: opfURL)
        
        // Get base path (OPF directory)
        let basePath = opfURL.deletingLastPathComponent()
        
        // Convert to spine items
        let spineItems = manifest.toSpineItems()
        
        return BookModel(
            epub: url,
            title: manifest.metadata.title,
            spineItems: spineItems,
            extractedPath: tempDir,
            basePath: basePath
        )
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
