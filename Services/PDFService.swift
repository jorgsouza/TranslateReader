//
//  PDFService.swift
//  TranslateReader
//
//  Service for handling PDF files using PDFKit
//

import Foundation
import PDFKit
import AppKit

class PDFService {
    
    // MARK: - Open PDF
    
    /// Opens a PDF file and returns a BookModel
    func openPDF(url: URL) throws -> BookModel {
        guard let document = PDFDocument(url: url) else {
            throw TranslateReaderError.invalidPDF
        }
        
        return BookModel(pdf: url, document: document)
    }
    
    // MARK: - Text Extraction
    
    /// Extracts text from a specific page
    func getPageText(from book: BookModel, page: Int) -> String {
        guard let document = book.pdfDocument,
              page >= 0 && page < document.pageCount,
              let pdfPage = document.page(at: page) else {
            return ""
        }
        
        return pdfPage.string ?? ""
    }
    
    /// Extracts text from all pages
    func getAllText(from book: BookModel) -> String {
        guard let document = book.pdfDocument else { return "" }
        
        var allText = ""
        for i in 0..<document.pageCount {
            if let page = document.page(at: i), let text = page.string {
                allText += text + "\n\n"
            }
        }
        
        return allText.trimmingCharacters(in: .whitespacesAndNewlines)
    }
    
    // MARK: - Page Image (for OCR)
    
    /// Renders a PDF page to an NSImage for OCR processing
    func getPageImage(from book: BookModel, page: Int, dpi: CGFloat = 150) -> NSImage? {
        guard let document = book.pdfDocument,
              page >= 0 && page < document.pageCount,
              let pdfPage = document.page(at: page) else {
            return nil
        }
        
        // Calculate size based on DPI
        let pageRect = pdfPage.bounds(for: .mediaBox)
        let scale = dpi / 72.0  // PDF points are 72 per inch
        let width = pageRect.width * scale
        let height = pageRect.height * scale
        
        // Create image representation
        let image = NSImage(size: NSSize(width: width, height: height))
        
        image.lockFocus()
        
        // Set white background
        NSColor.white.setFill()
        NSRect(x: 0, y: 0, width: width, height: height).fill()
        
        // Apply scale transform
        let transform = NSAffineTransform()
        transform.scale(by: scale)
        transform.concat()
        
        // Draw PDF page
        if let context = NSGraphicsContext.current?.cgContext {
            pdfPage.draw(with: .mediaBox, to: context)
        }
        
        image.unlockFocus()
        
        return image
    }
    
    // MARK: - Page Navigation
    
    /// Gets the total number of pages
    func pageCount(for book: BookModel) -> Int {
        book.pdfDocument?.pageCount ?? 0
    }
    
    /// Checks if a page has selectable text
    func pageHasText(book: BookModel, page: Int) -> Bool {
        let text = getPageText(from: book, page: page)
        return !text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
