//
//  ExportService.swift
//  TranslateReader
//
//  Service for exporting translations to various formats
//

import Foundation
import AppKit
import UniformTypeIdentifiers

class ExportService {
    
    // MARK: - Export to TXT
    
    /// Exports text to a .txt file
    func exportToTXT(text: String, filename: String) -> URL? {
        let sanitizedFilename = sanitizeFilename(filename)
        let outputURL = FileHelper.cacheDirectory.appendingPathComponent("\(sanitizedFilename).txt")
        
        do {
            try text.write(to: outputURL, atomically: true, encoding: .utf8)
            return outputURL
        } catch {
            print("Failed to export TXT: \(error)")
            return nil
        }
    }
    
    // MARK: - Export to Markdown
    
    /// Exports text to a .md file with formatting
    func exportToMarkdown(text: String, title: String, filename: String) -> URL? {
        let sanitizedFilename = sanitizeFilename(filename)
        let outputURL = FileHelper.cacheDirectory.appendingPathComponent("\(sanitizedFilename).md")
        
        // Create markdown content
        let markdown = """
        # \(title)
        
        ---
        
        *Exported from TranslateReader*
        
        *Date: \(formattedDate())*
        
        ---
        
        \(text)
        """
        
        do {
            try markdown.write(to: outputURL, atomically: true, encoding: .utf8)
            return outputURL
        } catch {
            print("Failed to export Markdown: \(error)")
            return nil
        }
    }
    
    // MARK: - Save Dialog
    
    /// Shows a save dialog and saves the file
    @MainActor
    func exportWithSaveDialog(text: String, title: String, format: ExportFormat) -> Bool {
        let panel = NSSavePanel()
        panel.title = "Export Translation"
        panel.nameFieldStringValue = sanitizeFilename(title)
        
        switch format {
        case .txt:
            panel.allowedContentTypes = [.plainText]
            panel.nameFieldStringValue += ".txt"
        case .markdown:
            panel.allowedContentTypes = [.text]
            panel.nameFieldStringValue += ".md"
        }
        
        guard panel.runModal() == .OK, let url = panel.url else {
            return false
        }
        
        do {
            let content: String
            switch format {
            case .txt:
                content = text
            case .markdown:
                content = """
                # \(title)
                
                ---
                
                *Exported from TranslateReader*
                
                *Date: \(formattedDate())*
                
                ---
                
                \(text)
                """
            }
            
            try content.write(to: url, atomically: true, encoding: .utf8)
            return true
        } catch {
            print("Failed to export: \(error)")
            return false
        }
    }
    
    // MARK: - Helpers
    
    /// Sanitizes filename by removing invalid characters
    private func sanitizeFilename(_ filename: String) -> String {
        let invalidChars = CharacterSet(charactersIn: "/\\:*?\"<>|")
        return filename.components(separatedBy: invalidChars).joined(separator: "_")
    }
    
    /// Returns formatted current date
    private func formattedDate() -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .long
        formatter.timeStyle = .short
        return formatter.string(from: Date())
    }
    
    // MARK: - Export Full Book as EPUB
    
    /// Exports the entire book as a new EPUB with translated content, preserving original structure.
    /// - Parameters:
    ///   - book: The EPUB book (must have extractedPath and basePath).
    ///   - bodyHTMLPerChapter: New body HTML (with <p> and <img> etc.) per spine item, in order; count must match book.pageCount.
    ///   - outputURL: Where to write the .epub file.
    /// - Returns: true on success.
    func exportBookAsEPUB(book: BookModel, bodyHTMLPerChapter: [String], outputURL: URL) -> Bool {
        guard book.type == .epub,
              let extractedPath = book.extractedPath,
              let basePath = book.basePath,
              bodyHTMLPerChapter.count == book.pageCount else {
            return false
        }
        
        let fileManager = FileManager.default
        let tempDir = fileManager.temporaryDirectory.appendingPathComponent("TranslateReader-Export-\(UUID().uuidString)")
        
        defer { try? fileManager.removeItem(at: tempDir) }
        
        do {
            try fileManager.createDirectory(at: tempDir, withIntermediateDirectories: true)
            try copyDirectory(from: extractedPath, to: tempDir)
        } catch {
            print("Export EPUB: failed to copy: \(error)")
            return false
        }
        
        for index in 0..<book.pageCount {
            let item = book.spineItems[index]
            guard item.isHTML else { continue }
            
            let contentURL = basePath.appendingPathComponent(item.href)
            let relativePath = pathRelativeTo(base: extractedPath, path: contentURL)
            let fileInTemp = tempDir.appendingPathComponent(relativePath)
            
            guard fileManager.fileExists(atPath: fileInTemp.path),
                  var html = try? String(contentsOf: fileInTemp, encoding: .utf8) else {
                continue
            }
            
            let bodyHTML = bodyHTMLPerChapter[index]
            html = replaceBodyInHTML(html, newBodyContent: bodyHTML)
            
            do {
                try html.write(to: fileInTemp, atomically: true, encoding: .utf8)
            } catch {
                print("Export EPUB: failed to write \(item.href): \(error)")
                return false
            }
        }
        
        return createEPUBZip(from: tempDir, outputURL: outputURL)
    }
    
    /// Copies a directory recursively.
    private func copyDirectory(from src: URL, to dst: URL) throws {
        let fileManager = FileManager.default
        let contents = try fileManager.contentsOfDirectory(at: src, includingPropertiesForKeys: nil)
        for item in contents {
            let destItem = dst.appendingPathComponent(item.lastPathComponent)
            if (try? item.resourceValues(forKeys: [.isDirectoryKey]))?.isDirectory == true {
                try fileManager.createDirectory(at: destItem, withIntermediateDirectories: true)
                try copyDirectory(from: item, to: destItem)
            } else {
                try fileManager.copyItem(at: item, to: destItem)
            }
        }
    }
    
    /// Path of `path` relative to `base` (both as file URLs).
    private func pathRelativeTo(base: URL, path: URL) -> String {
        let baseComps = base.pathComponents
        let pathComps = path.pathComponents
        let common = min(baseComps.count, pathComps.count)
        var i = 0
        while i < common && baseComps[i] == pathComps[i] { i += 1 }
        let rel = pathComps.dropFirst(i)
        return rel.joined(separator: "/")
    }
    
    /// Converts plain translated text to HTML body content (paragraphs).
    private func translatedTextToBodyHTML(_ text: String) -> String {
        let escaped = escapeHTML(text)
        let paragraphs = escaped.components(separatedBy: "\n\n")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .map { "<p>\($0)</p>" }
        return paragraphs.joined(separator: "\n")
    }
    
    /// Merges body blocks with translated text segments; preserves image blocks as-is.
    func mergeBodyBlocks(_ blocks: [EPUBService.BodyBlock], translatedTexts: [String]) -> String {
        var out: [String] = []
        var textIndex = 0
        for block in blocks {
            switch block {
            case .text:
                if textIndex < translatedTexts.count {
                    out.append(translatedTextToBodyHTML(translatedTexts[textIndex]))
                    textIndex += 1
                }
            case .image(html: let imgHTML):
                out.append(imgHTML)
            }
        }
        return out.joined(separator: "\n")
    }
    
    private func escapeHTML(_ text: String) -> String {
        return text
            .replacingOccurrences(of: "&", with: "&amp;")
            .replacingOccurrences(of: "<", with: "&lt;")
            .replacingOccurrences(of: ">", with: "&gt;")
    }
    
    /// Replaces the content inside <body>...</body> with newBodyContent.
    private func replaceBodyInHTML(_ html: String, newBodyContent: String) -> String {
        let pattern = #"<body[^>]*>[\s\S]*?</body>"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: .caseInsensitive) else {
            return html
        }
        let range = NSRange(html.startIndex..., in: html)
        guard let match = regex.firstMatch(in: html, range: range) else {
            return html
        }
        let fullRange = match.range(at: 0)
        let matchStart = html.index(html.startIndex, offsetBy: fullRange.location)
        let matchEnd = html.index(html.startIndex, offsetBy: fullRange.location + fullRange.length)
        let segment = String(html[matchStart..<matchEnd])
        guard let tagEnd = segment.firstIndex(of: ">"),
              let bodyCloseRange = segment.range(of: "</body>", options: .caseInsensitive) else {
            return html
        }
        let beforeEnd = segment.index(after: tagEnd)
        let part1 = String(html[..<matchStart])
        let part2 = String(segment[..<beforeEnd])
        let part3 = String(segment[bodyCloseRange.lowerBound...])
        let part4 = String(html[matchEnd...])
        return part1 + part2 + newBodyContent + part3 + part4
    }
    
    /// Creates an EPUB (ZIP) with mimetype first and uncompressed per spec.
    private func createEPUBZip(from directory: URL, outputURL: URL) -> Bool {
        let fileManager = FileManager.default
        let epubInTemp = directory.appendingPathComponent("_out.epub")
        
        // EPUB spec: mimetype must be first and stored (no compression).
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
        process.currentDirectoryURL = directory
        process.arguments = ["-0", "-X", "_out.epub", "mimetype"]
        do {
            try process.run()
            process.waitUntilExit()
            if process.terminationStatus != 0 { return false }
        } catch {
            return false
        }
        
        // Add rest of files (skip _out.epub and mimetype to avoid re-adding).
        let addProcess = Process()
        addProcess.executableURL = URL(fileURLWithPath: "/usr/bin/zip")
        addProcess.currentDirectoryURL = directory
        addProcess.arguments = ["-r", "-X", "_out.epub", ".", "-x", "_out.epub", "-x", "mimetype"]
        do {
            try addProcess.run()
            addProcess.waitUntilExit()
            if addProcess.terminationStatus != 0 { return false }
        } catch {
            return false
        }
        
        do {
            if fileManager.fileExists(atPath: outputURL.path) {
                try fileManager.removeItem(at: outputURL)
            }
            try fileManager.moveItem(at: epubInTemp, to: outputURL)
            return true
        } catch {
            return false
        }
    }
    
    /// Shows save panel and exports full book as EPUB (call after translating all chapters).
    @MainActor
    func exportBookAsEPUBWithSaveDialog(book: BookModel, bodyHTMLPerChapter: [String], suggestedTitle: String) -> Bool {
        guard book.type == .epub, bodyHTMLPerChapter.count == book.pageCount else { return false }
        
        let panel = NSSavePanel()
        panel.title = "Export Translated Book as EPUB"
        panel.nameFieldStringValue = sanitizeFilename(suggestedTitle) + "_translated.epub"
        panel.allowedContentTypes = [UTType.epub]
        
        guard panel.runModal() == .OK, let url = panel.url else {
            return false
        }
        
        return exportBookAsEPUB(book: book, bodyHTMLPerChapter: bodyHTMLPerChapter, outputURL: url)
    }
}

// MARK: - DOCX Export Note
/*
 DOCX Export Implementation Note:
 
 DOCX (Office Open XML) is a complex format that requires creating a ZIP file
 containing multiple XML files with specific structure:
 
 document.docx/
 ├── [Content_Types].xml
 ├── _rels/
 │   └── .rels
 ├── word/
 │   ├── document.xml
 │   ├── styles.xml
 │   └── _rels/
 │       └── document.xml.rels
 
 To implement DOCX export without external libraries:
 
 1. Create the required XML files with proper namespaces:
    - [Content_Types].xml: Defines content types
    - word/document.xml: Main document content
    - word/styles.xml: Document styles
 
 2. Use Foundation's FileWrapper or Compression framework to create the ZIP
 
 3. The main document.xml structure:
    <?xml version="1.0" encoding="UTF-8" standalone="yes"?>
    <w:document xmlns:w="http://schemas.openxmlformats.org/wordprocessingml/2006/main">
      <w:body>
        <w:p>
          <w:r>
            <w:t>Your text here</w:t>
          </w:r>
        </w:p>
      </w:body>
    </w:document>
 
 This is a significant undertaking. For MVP, recommend using:
 - .txt for plain export
 - .md for formatted export
 - Third-party library like CoreXLSX (adapted) for DOCX if needed later
 */
