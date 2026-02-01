//
//  ExportService.swift
//  TranslateReader
//
//  Service for exporting translations to various formats
//

import Foundation
import AppKit

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
