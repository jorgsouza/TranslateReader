//
//  Constants.swift
//  TranslateReader
//
//  App-wide constants and enums
//

import Foundation

// MARK: - Target Languages
enum TargetLanguage: String, CaseIterable, Identifiable {
    case portuguese = "pt-BR"
    case english = "en"
    case spanish = "es"
    case french = "fr"
    case german = "de"
    
    var id: String { rawValue }
    
    var displayName: String {
        switch self {
        case .portuguese: return "Português (BR)"
        case .english: return "English"
        case .spanish: return "Español"
        case .french: return "Français"
        case .german: return "Deutsch"
        }
    }
    
    var localeIdentifier: String {
        switch self {
        case .portuguese: return "pt-BR"
        case .english: return "en-US"
        case .spanish: return "es-ES"
        case .french: return "fr-FR"
        case .german: return "de-DE"
        }
    }
    
    var voiceLanguage: String {
        switch self {
        case .portuguese: return "pt-BR"
        case .english: return "en-US"
        case .spanish: return "es-ES"
        case .french: return "fr-FR"
        case .german: return "de-DE"
        }
    }
}

// MARK: - Book Types
enum BookType: String {
    case epub
    case pdf
}

// MARK: - App Constants
struct AppConstants {
    static let appName = "TranslateReader"
    static let cacheDirectoryName = "Cache"
    static let maxChunkSize = 1800
    static let defaultSpeechRate: Float = 0.5
    static let minSpeechRate: Float = 0.1
    static let maxSpeechRate: Float = 1.0
    
    // Supported file extensions
    static let supportedExtensions = ["epub", "pdf"]
    
    // Cache keys
    static let translationCacheFile = "translations.json"
}

// MARK: - Error Types
enum TranslateReaderError: LocalizedError {
    case fileNotFound
    case invalidEPUB
    case invalidPDF
    case extractionFailed
    case parsingFailed
    case translationFailed
    case translationUnavailable
    case ocrFailed
    case cacheError
    case exportFailed
    
    var errorDescription: String? {
        switch self {
        case .fileNotFound: return "File not found"
        case .invalidEPUB: return "Invalid EPUB file"
        case .invalidPDF: return "Invalid PDF file"
        case .extractionFailed: return "Failed to extract EPUB"
        case .parsingFailed: return "Failed to parse document"
        case .translationFailed: return "Translation failed"
        case .translationUnavailable: return "Translation not available on this macOS version"
        case .ocrFailed: return "OCR processing failed"
        case .cacheError: return "Cache operation failed"
        case .exportFailed: return "Export failed"
        }
    }
}
