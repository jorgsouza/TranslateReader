//
//  PDFViewWrapper.swift
//  TranslateReader
//
//  PDFKit PDFView wrapper for rendering PDF pages
//

import SwiftUI
import PDFKit

struct PDFViewWrapper: NSViewRepresentable {
    let book: BookModel
    let pageIndex: Int
    
    func makeNSView(context: Context) -> PDFView {
        let pdfView = PDFView()
        
        // Configure PDF view
        pdfView.autoScales = true
        pdfView.displayMode = .singlePage
        pdfView.displayDirection = .vertical
        pdfView.displaysPageBreaks = false
        pdfView.pageShadowsEnabled = false
        
        // Background color
        pdfView.backgroundColor = NSColor.textBackgroundColor
        
        // Set document
        if let document = book.pdfDocument {
            pdfView.document = document
        }
        
        return pdfView
    }
    
    func updateNSView(_ pdfView: PDFView, context: Context) {
        // Update document if needed
        if pdfView.document !== book.pdfDocument {
            pdfView.document = book.pdfDocument
        }
        
        // Navigate to the specified page
        goToPage(pdfView, index: pageIndex)
    }
    
    // MARK: - Page Navigation
    
    private func goToPage(_ pdfView: PDFView, index: Int) {
        guard let document = pdfView.document,
              index >= 0 && index < document.pageCount,
              let page = document.page(at: index) else {
            return
        }
        
        pdfView.go(to: page)
    }
}

// MARK: - PDF View with Selection Support

struct PDFViewWithSelection: NSViewRepresentable {
    let book: BookModel
    let pageIndex: Int
    @Binding var selectedText: String
    
    func makeNSView(context: Context) -> PDFView {
        let pdfView = PDFView()
        
        pdfView.autoScales = true
        pdfView.displayMode = .singlePage
        pdfView.displayDirection = .vertical
        pdfView.displaysPageBreaks = false
        
        if let document = book.pdfDocument {
            pdfView.document = document
        }
        
        // Set up notification observer for selection changes
        NotificationCenter.default.addObserver(
            context.coordinator,
            selector: #selector(Coordinator.selectionChanged(_:)),
            name: .PDFViewSelectionChanged,
            object: pdfView
        )
        
        return pdfView
    }
    
    func updateNSView(_ pdfView: PDFView, context: Context) {
        if pdfView.document !== book.pdfDocument {
            pdfView.document = book.pdfDocument
        }
        
        goToPage(pdfView, index: pageIndex)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    private func goToPage(_ pdfView: PDFView, index: Int) {
        guard let document = pdfView.document,
              index >= 0 && index < document.pageCount,
              let page = document.page(at: index) else {
            return
        }
        
        pdfView.go(to: page)
    }
    
    // MARK: - Coordinator
    
    class Coordinator: NSObject {
        let parent: PDFViewWithSelection
        
        init(_ parent: PDFViewWithSelection) {
            self.parent = parent
        }
        
        @objc func selectionChanged(_ notification: Notification) {
            guard let pdfView = notification.object as? PDFView,
                  let selection = pdfView.currentSelection else {
                return
            }
            
            DispatchQueue.main.async {
                self.parent.selectedText = selection.string ?? ""
            }
        }
    }
}

// MARK: - PDF Thumbnail View

struct PDFThumbnailView: NSViewRepresentable {
    let document: PDFDocument?
    let pageIndex: Int
    
    func makeNSView(context: Context) -> NSImageView {
        let imageView = NSImageView()
        imageView.imageScaling = .scaleProportionallyUpOrDown
        return imageView
    }
    
    func updateNSView(_ imageView: NSImageView, context: Context) {
        guard let document = document,
              pageIndex >= 0 && pageIndex < document.pageCount,
              let page = document.page(at: pageIndex) else {
            imageView.image = nil
            return
        }
        
        // Generate thumbnail
        let pageRect = page.bounds(for: .mediaBox)
        let scale: CGFloat = 150.0 / pageRect.width
        let size = CGSize(width: pageRect.width * scale, height: pageRect.height * scale)
        
        imageView.image = page.thumbnail(of: size, for: .mediaBox)
    }
}

// MARK: - Preview

#Preview {
    VStack {
        Text("PDFViewWrapper requires a valid PDF document")
    }
    .frame(width: 400, height: 300)
}
