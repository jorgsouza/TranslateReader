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
    /// Body HTML with images preserved (for EPUB); used by translation panel.
    @Published var translatedBodyHTML: String? = nil
    /// Chapter directory (for resolving relative image paths and writing preview file).
    @Published var translatedBodyHTMLBaseURL: URL? = nil
    /// Book root (extracted path) so WebView can load local images via loadFileURL(allowingReadAccessTo:).
    @Published var translatedBodyHTMLReadAccessURL: URL? = nil
    
    // MARK: - Loading States
    @Published var isLoading: Bool = false
    @Published var isTranslating: Bool = false
    @Published var isOCRRunning: Bool = false
    @Published var isSpeaking: Bool = false
    @Published var isExportingBookAsEPUB: Bool = false
    
    // MARK: - Settings
    @Published var targetLanguage: TargetLanguage = .portuguese
    @Published var autoTranslate: Bool = true
    @Published var speechRate: Float = AppConstants.defaultSpeechRate
    @Published var fontSize: CGFloat = 16
    @Published var selectedVoiceId: String? {
        didSet {
            speechService.selectedVoiceIdentifier = selectedVoiceId
            // Save to UserDefaults
            if let voiceId = selectedVoiceId {
                UserDefaults.standard.set(voiceId, forKey: "selectedVoiceId")
            } else {
                UserDefaults.standard.removeObject(forKey: "selectedVoiceId")
            }
        }
    }
    
    /// Include Eloquence voices (Flo, Eddy, Reed, etc.) - may have distorted audio on some systems
    @Published var includeEloquenceVoices: Bool = UserDefaults.standard.bool(forKey: "includeEloquenceVoices") {
        didSet {
            UserDefaults.standard.set(includeEloquenceVoices, forKey: "includeEloquenceVoices")
        }
    }
    
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
        translatedBodyHTML = nil
        translatedBodyHTMLBaseURL = nil
        translatedBodyHTMLReadAccessURL = nil
        
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
        guard let book = currentBook else { return }
        
        guard translationManager.isAvailable else {
            showErrorMessage(translationManager.unavailableMessage)
            return
        }
        
        let cacheKey = TranslationCacheEntry.generateKey(
            bookId: book.id,
            contentId: book.contentId(at: currentPageIndex),
            pageIndex: currentPageIndex,
            targetLanguage: targetLanguage.rawValue
        )
        
        // Check cache first
        if let cached = cacheService.load(for: cacheKey) {
            translatedText = cached
            translatedBodyHTML = cacheService.loadBodyHTML(for: cacheKey)
            translatedBodyHTMLBaseURL = book.type == .epub ? book.epubContentURL(at: currentPageIndex)?.deletingLastPathComponent() : nil
            translatedBodyHTMLReadAccessURL = book.type == .epub ? book.basePath : nil
            return
        }
        
        // EPUB: block-based translation preserves images in translatedBodyHTML
        if book.type == .epub,
           let html = epubService.getHTMLContent(for: book, at: currentPageIndex),
           let bodyContent = epubService.getBodyContent(from: html),
           !bodyContent.isEmpty {
            let blocks = epubService.getBodyBlocks(from: bodyContent)
            if !blocks.isEmpty {
                await translateEPUBPageWithBlocks(book: book, blocks: blocks, cacheKey: cacheKey)
                return
            }
        }
        
        // Plain text path (PDF or EPUB without body blocks)
        guard !originalText.isEmpty else { return }
        isTranslating = true
        do {
            translatedText = try await translationManager.translate(
                text: originalText,
                to: targetLanguage
            )
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
            showErrorMessage(friendlyTranslationErrorMessage(error))
        }
        isTranslating = false
    }
    
    /// Translates current EPUB page by blocks and sets translatedText + translatedBodyHTML.
    private func translateEPUBPageWithBlocks(book: BookModel, blocks: [EPUBService.BodyBlock], cacheKey: String) async {
        isTranslating = true
        defer { isTranslating = false }
        var translatedSegments: [String] = []
        for block in blocks {
            switch block {
            case .text(let plain):
                if plain.isEmpty {
                    translatedSegments.append("")
                    continue
                }
                do {
                    let t = try await translationManager.translate(text: plain, to: targetLanguage)
                    translatedSegments.append(t)
                } catch {
                    showErrorMessage(friendlyTranslationErrorMessage(error))
                    return
                }
            case .image:
                break
            }
        }
        let bodyHTML = exportService.mergeBodyBlocks(blocks, translatedTexts: translatedSegments)
        let plainJoined = translatedSegments.joined(separator: "\n\n")
        translatedText = plainJoined
        translatedBodyHTML = bodyHTML
        translatedBodyHTMLBaseURL = book.epubContentURL(at: currentPageIndex)?.deletingLastPathComponent()
        translatedBodyHTMLReadAccessURL = book.basePath
        cacheService.save(
            translation: plainJoined,
            for: cacheKey,
            bookId: book.id,
            contentId: book.contentId(at: currentPageIndex),
            pageIndex: currentPageIndex,
            targetLanguage: targetLanguage.rawValue,
            originalText: originalText,
            translatedBodyHTML: bodyHTML
        )
    }
    
    /// Converts framework translation errors into a user-friendly message with hints.
    private func friendlyTranslationErrorMessage(_ error: Error) -> String {
        let text = error.localizedDescription
        if text.contains("Unable to Translate") || text.lowercased().contains("not installed") || text.contains("unavailable") {
            return "\(text)\n\nDica: Instale os pacotes de idioma em Ajustes do Sistema > Geral > Idioma e Região > Tradução (ou use o app Traduzir da Apple)."
        }
        return text
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
    
    // MARK: - Voice Selection
    
    /// Load saved voice preference from UserDefaults
    func loadVoicePreference() {
        if let savedVoiceId = UserDefaults.standard.string(forKey: "selectedVoiceId") {
            if savedVoiceId.lowercased().contains("eloquence") && !includeEloquenceVoices {
                // Eloquence not included - clear preference
                UserDefaults.standard.removeObject(forKey: "selectedVoiceId")
            } else {
                selectedVoiceId = savedVoiceId
                speechService.selectedVoiceIdentifier = savedVoiceId
            }
        }
    }
    
    /// Get available voices for current target language
    var availableVoices: [VoiceOption] {
        SpeechService.voiceOptions(for: targetLanguage.voiceLanguage, includeEloquence: includeEloquenceVoices)
    }
    
    /// Get premium/enhanced voices only
    var premiumVoices: [VoiceOption] {
        SpeechService.premiumVoiceOptions(for: targetLanguage.voiceLanguage, includeEloquence: includeEloquenceVoices)
    }
    
    /// Get female voices only
    var femaleVoices: [VoiceOption] {
        SpeechService.voiceOptions(for: targetLanguage.voiceLanguage, gender: .female, includeEloquence: includeEloquenceVoices)
    }
    
    /// Get male voices only
    var maleVoices: [VoiceOption] {
        SpeechService.voiceOptions(for: targetLanguage.voiceLanguage, gender: .male, includeEloquence: includeEloquenceVoices)
    }
    
    /// Currently selected voice option
    var selectedVoice: VoiceOption? {
        guard let voiceId = selectedVoiceId else { return nil }
        return availableVoices.first { $0.id == voiceId }
    }
    
    /// Select a voice
    func selectVoice(_ voice: VoiceOption?) {
        selectedVoiceId = voice?.id
    }
    
    /// Preview a voice
    func previewVoice(_ voice: VoiceOption) {
        let sampleText: String
        switch targetLanguage {
        case .portuguese:
            sampleText = "Olá! Esta é uma prévia da voz selecionada."
        case .english:
            sampleText = "Hello! This is a preview of the selected voice."
        case .spanish:
            sampleText = "¡Hola! Esta es una vista previa de la voz seleccionada."
        case .french:
            sampleText = "Bonjour! Ceci est un aperçu de la voix sélectionnée."
        case .german:
            sampleText = "Hallo! Dies ist eine Vorschau der ausgewählten Stimme."
        }
        speechService.previewVoice(voice, sampleText: sampleText)
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
    
    /// Translates the entire book (EPUB) and exports it as a new EPUB via save dialog.
    /// Preserves images; uses block-based translation per chapter.
    func exportTranslatedBookAsEPUB() async {
        guard let book = currentBook, book.type == .epub else { return }
        guard translationManager.isAvailable else {
            showErrorMessage(translationManager.unavailableMessage)
            return
        }
        
        isExportingBookAsEPUB = true
        defer { isExportingBookAsEPUB = false }
        
        var bodyHTMLPerChapter: [String] = []
        bodyHTMLPerChapter.reserveCapacity(book.pageCount)
        
        for index in 0..<book.pageCount {
            guard let html = epubService.getHTMLContent(for: book, at: index),
                  let bodyContent = epubService.getBodyContent(from: html) else {
                bodyHTMLPerChapter.append("")
                continue
            }
            let blocks = epubService.getBodyBlocks(from: bodyContent)
            if blocks.isEmpty {
                bodyHTMLPerChapter.append("")
                continue
            }
            var translatedSegments: [String] = []
            for block in blocks {
                switch block {
                case .text(let plain):
                    if plain.isEmpty {
                        translatedSegments.append("")
                        continue
                    }
                    do {
                        let translated = try await translationManager.translate(
                            text: plain,
                            to: targetLanguage
                        )
                        translatedSegments.append(translated)
                    } catch {
                        showErrorMessage(friendlyTranslationErrorMessage(error))
                        return
                    }
                case .image:
                    break
                }
            }
            let bodyHTML = exportService.mergeBodyBlocks(blocks, translatedTexts: translatedSegments)
            bodyHTMLPerChapter.append(bodyHTML)
        }
        
        let success = exportService.exportBookAsEPUBWithSaveDialog(
            book: book,
            bodyHTMLPerChapter: bodyHTMLPerChapter,
            suggestedTitle: book.title
        )
        if !success {
            showErrorMessage("Export failed or was cancelled")
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
