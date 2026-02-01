//
//  AppState.swift
//  TranslateReader
//
//  Global application state as ObservableObject
//

import SwiftUI
import Combine

@MainActor
class AppState: ObservableObject {
    // MARK: - Book State
    @Published var currentBook: BookModel?
    @Published var currentPageIndex: Int = 0
    
    // MARK: - Text Content
    @Published var originalText: String = ""
    @Published var translatedText: String = ""
    
    // MARK: - Loading States
    @Published var isLoading: Bool = false
    @Published var isTranslating: Bool = false
    @Published var isOCRRunning: Bool = false
    @Published var isSpeaking: Bool = false
    
    // MARK: - Settings
    @Published var targetLanguage: TargetLanguage = .portuguese
    @Published var autoTranslate: Bool = true
    @Published var speechRate: Float = AppConstants.defaultSpeechRate
    @Published var fontSize: CGFloat = 16
    
    // MARK: - UI State
    @Published var showFileImporter: Bool = false
    @Published var errorMessage: String?
    @Published var showError: Bool = false
    
    // MARK: - Services (initialized eagerly to avoid lazy var issues during view updates)
    let epubService = EPUBService()
    let pdfService = PDFService()
    let ocrService = OCRService()
    let cacheService = CacheService()
    let speechService = SpeechService()
    let exportService = ExportService()
    
    // Translation manager handles version compatibility
    let translationManager = TranslationManager.shared
    
    // MARK: - Computed Properties
    
    var hasBook: Bool {
        currentBook != nil
    }
    
    var canGoBack: Bool {
        currentPageIndex > 0
    }
    
    var canGoForward: Bool {
        guard let book = currentBook else { return false }
        return currentPageIndex < book.pageCount - 1
    }
    
    var currentPageDisplay: String {
        guard let book = currentBook else { return "No file" }
        return "Page \(currentPageIndex + 1) of \(book.pageCount)"
    }
    
    var needsOCR: Bool {
        currentBook?.type == .pdf && originalText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
    
    var isSpeechPaused: Bool {
        speechService.isPaused
    }
    
    var isSpeechIdle: Bool {
        speechService.isIdle
    }
    
    // MARK: - Navigation
    
    func goToNextPage() {
        guard canGoForward else { return }
        currentPageIndex += 1
        loadCurrentPage()
    }
    
    func goToPreviousPage() {
        guard canGoBack else { return }
        currentPageIndex -= 1
        loadCurrentPage()
    }
    
    func goToPage(_ index: Int) {
        guard let book = currentBook,
              index >= 0 && index < book.pageCount else { return }
        currentPageIndex = index
        loadCurrentPage()
    }
    
    // MARK: - File Loading
    
    func openFile(url: URL) async {
        isLoading = true
        errorMessage = nil
        translatedText = ""
        originalText = ""
        currentPageIndex = 0
        
        do {
            guard let bookType = FileHelper.bookType(for: url) else {
                throw TranslateReaderError.fileNotFound
            }
            
            switch bookType {
            case .epub:
                currentBook = try await epubService.openEPUB(url: url)
            case .pdf:
                currentBook = try pdfService.openPDF(url: url)
            }
            
            loadCurrentPage()
        } catch {
            showErrorMessage(error.localizedDescription)
        }
        
        isLoading = false
    }
    
    // MARK: - Page Loading
    
    func loadCurrentPage() {
        guard let book = currentBook else { return }
        
        // Clear previous translation
        translatedText = ""
        
        // Extract text based on book type
        switch book.type {
        case .epub:
            originalText = epubService.getTextContent(for: book, at: currentPageIndex)
        case .pdf:
            originalText = pdfService.getPageText(from: book, page: currentPageIndex)
        }
        
        // Auto-translate if enabled
        if autoTranslate && !originalText.isEmpty {
            Task {
                await translateCurrentPage()
            }
        }
    }
    
    // MARK: - Translation
    
    func translateCurrentPage() async {
        guard let book = currentBook, !originalText.isEmpty else { return }
        
        // Check if translation is available
        guard translationManager.isAvailable else {
            showErrorMessage(translationManager.unavailableMessage)
            return
        }
        
        // Check cache first
        let cacheKey = TranslationCacheEntry.generateKey(
            bookId: book.id,
            contentId: book.contentId(at: currentPageIndex),
            pageIndex: currentPageIndex,
            targetLanguage: targetLanguage.rawValue
        )
        
        if let cached = cacheService.load(for: cacheKey) {
            translatedText = cached
            return
        }
        
        // Perform translation
        isTranslating = true
        
        do {
            translatedText = try await translationManager.translate(
                text: originalText,
                to: targetLanguage
            )
            
            // Cache the result
            cacheService.save(
                translation: translatedText,
                for: cacheKey,
                bookId: book.id,
                contentId: book.contentId(at: currentPageIndex),
                pageIndex: currentPageIndex,
                targetLanguage: targetLanguage.rawValue,
                originalText: originalText
            )
        } catch {
            showErrorMessage(error.localizedDescription)
        }
        
        isTranslating = false
    }
    
    // MARK: - OCR
    
    func runOCR() async {
        guard let book = currentBook, book.type == .pdf else { return }
        
        isOCRRunning = true
        
        do {
            if let image = pdfService.getPageImage(from: book, page: currentPageIndex) {
                originalText = try await ocrService.recognizeText(from: image)
                
                // Auto-translate if enabled
                if autoTranslate && !originalText.isEmpty {
                    await translateCurrentPage()
                }
            }
        } catch {
            showErrorMessage(error.localizedDescription)
        }
        
        isOCRRunning = false
    }
    
    // MARK: - Speech
    
    func toggleSpeech() {
        if isSpeaking {
            speechService.pause()
            isSpeaking = false
        } else if !translatedText.isEmpty {
            speechService.speak(
                text: translatedText,
                language: targetLanguage.voiceLanguage,
                rate: speechRate
            )
            isSpeaking = true
        }
    }
    
    func stopSpeech() {
        speechService.stop()
        isSpeaking = false
    }
    
    func updateSpeechRate(_ rate: Float) {
        speechRate = rate
        if isSpeaking {
            // Restart with new rate
            stopSpeech()
            toggleSpeech()
        }
    }
    
    // MARK: - Export
    
    func exportTranslation(format: ExportFormat) -> URL? {
        guard let book = currentBook, !translatedText.isEmpty else { return nil }
        
        let filename = "\(book.title)_page\(currentPageIndex + 1)"
        
        switch format {
        case .txt:
            return exportService.exportToTXT(text: translatedText, filename: filename)
        case .markdown:
            return exportService.exportToMarkdown(
                text: translatedText,
                title: book.title,
                filename: filename
            )
        }
    }
    
    // MARK: - Error Handling
    
    func showErrorMessage(_ message: String) {
        errorMessage = message
        showError = true
    }
    
    func clearError() {
        errorMessage = nil
        showError = false
    }
    
    // MARK: - Cleanup
    
    func cleanup() {
        // Stop speech
        stopSpeech()
        
        // Clean up extracted EPUB files
        if let book = currentBook, let extractedPath = book.extractedPath {
            FileHelper.removeDirectory(at: extractedPath)
        }
        
        currentBook = nil
        originalText = ""
        translatedText = ""
        currentPageIndex = 0
    }
}

// MARK: - Export Format
enum ExportFormat: String, CaseIterable {
    case txt = "Plain Text (.txt)"
    case markdown = "Markdown (.md)"
}
