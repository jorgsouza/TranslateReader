//
//  BookModel.swift
//  TranslateReader
//
//  Model representing an opened book (EPUB or PDF)
//

import Foundation
import PDFKit

// MARK: - SpineItem (EPUB chapter reference)
struct SpineItem: Identifiable, Equatable {
    let id: String          // idref from spine
    let href: String        // Path to the content file
    let mediaType: String   // MIME type (usually application/xhtml+xml)
    let title: String?      // Optional title from TOC
    
    var isHTML: Bool {
        mediaType.contains("html") || mediaType.contains("xhtml")
    }
}

// MARK: - BookModel
struct BookModel: Identifiable {
    let id: String              // Unique hash based on path + size + modDate
    let type: BookType
    let url: URL                // Original file URL
    let title: String
    
    // EPUB specific
    var spineItems: [SpineItem] = []
    var extractedPath: URL?     // Temp directory where EPUB was extracted
    var basePath: URL?          // Base path for content files (OPF directory)
    
    // PDF specific
    var pdfDocument: PDFDocument?
    
    // Common
    var pageCount: Int {
        switch type {
        case .epub:
            return spineItems.count
        case .pdf:
            return pdfDocument?.pageCount ?? 0
        }
    }
    
    // MARK: - Initializers
    
    /// Initialize an EPUB book
    init(epub url: URL, title: String, spineItems: [SpineItem], extractedPath: URL, basePath: URL) {
        self.id = FileHelper.generateBookId(for: url)
        self.type = .epub
        self.url = url
        self.title = title
        self.spineItems = spineItems
        self.extractedPath = extractedPath
        self.basePath = basePath
        self.pdfDocument = nil
    }
    
    /// Initialize a PDF book
    init(pdf url: URL, document: PDFDocument) {
        self.id = FileHelper.generateBookId(for: url)
        self.type = .pdf
        self.url = url
        self.title = url.deletingPathExtension().lastPathComponent
        self.pdfDocument = document
        self.spineItems = []
        self.extractedPath = nil
        self.basePath = nil
    }
    
    // MARK: - Content Access
    
    /// Returns the content ID for caching purposes
    func contentId(at index: Int) -> String {
        switch type {
        case .epub:
            guard index < spineItems.count else { return "unknown" }
            return spineItems[index].href
        case .pdf:
            return "pdfPage_\(index)"
        }
    }
    
    /// Returns the URL for the EPUB content file at given index
    func epubContentURL(at index: Int) -> URL? {
        guard type == .epub,
              index < spineItems.count,
              let basePath = basePath else { return nil }
        
        return basePath.appendingPathComponent(spineItems[index].href)
    }
}

// MARK: - Equatable
extension BookModel: Equatable {
    static func == (lhs: BookModel, rhs: BookModel) -> Bool {
        lhs.id == rhs.id
    }
}
