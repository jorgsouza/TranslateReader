//
//  TranslationService.swift
//  TranslateReader
//
//  Service for translation using Apple's Translation framework
//

import Foundation
import SwiftUI
import NaturalLanguage

#if canImport(Translation)
import Translation
#endif

// MARK: - Translation Service Protocol

protocol TranslationServiceProtocol {
    func translate(text: String, to target: TargetLanguage) async throws -> String
}

// MARK: - Translation Service (macOS 15+)

@available(macOS 15.0, *)
class TranslationService: TranslationServiceProtocol {
    
    // MARK: - Translation
    
    /// Translates text to the target language using Translation framework
    func translate(text: String, to target: TargetLanguage) async throws -> String {
        guard !text.isEmpty else { return "" }
        
        // Chunk text if too large
        let chunks = TextChunker.chunkText(text)
        
        if chunks.count == 1 {
            return try await translateSingleChunk(chunks[0], to: target)
        } else {
            return try await translateChunks(chunks, to: target)
        }
    }
    
    /// Translates a single text chunk
    private func translateSingleChunk(_ text: String, to target: TargetLanguage) async throws -> String {
        // Detect source language
        let sourceLanguage = detectLanguage(text) ?? Locale.Language(identifier: "en")
        let targetLanguage = Locale.Language(identifier: target.localeIdentifier)
        
        // Skip if same language
        if sourceLanguage.languageCode == targetLanguage.languageCode {
            return text
        }
        
        // Use TranslationSession for translation
        if #available(macOS 26.0, *) {
            let session = try await TranslationSession(
                installedSource: sourceLanguage,
                target: targetLanguage
            )
            let response = try await session.translate(text)
            return response.targetText
        } else {
            throw TranslateReaderError.translationUnavailable
        }
    }
    
    /// Translates multiple chunks
    private func translateChunks(_ chunks: [String], to target: TargetLanguage) async throws -> String {
        var translatedChunks: [String] = []
        
        for chunk in chunks {
            let translated = try await translateSingleChunk(chunk, to: target)
            translatedChunks.append(translated)
        }
        
        return TextChunker.joinChunks(translatedChunks)
    }
    
    // MARK: - Language Detection
    
    /// Detects the language of text using NLLanguageRecognizer
    private func detectLanguage(_ text: String) -> Locale.Language? {
        let recognizer = NLLanguageRecognizer()
        recognizer.processString(text)
        
        if let language = recognizer.dominantLanguage {
            return Locale.Language(identifier: language.rawValue)
        }
        
        return nil
    }
    
    // MARK: - Availability Check
    
    /// Checks if translation is available for a language pair
    func isTranslationAvailable(from source: String, to target: String) async -> Bool {
        let sourceLanguage = Locale.Language(identifier: source)
        let targetLanguage = Locale.Language(identifier: target)
        
        let availability = LanguageAvailability()
        let status = await availability.status(from: sourceLanguage, to: targetLanguage)
        
        switch status {
        case .installed, .supported:
            return true
        case .unsupported:
            return false
        @unknown default:
            return false
        }
    }
}

// MARK: - Translation Manager

/// Manager that handles translation with version checking
class TranslationManager {
    
    static let shared = TranslationManager()
    
    private init() {}
    
    /// Translates text using the translation service
    func translate(text: String, to target: TargetLanguage) async throws -> String {
        guard isAvailable else {
            throw TranslateReaderError.translationUnavailable
        }
        
        if #available(macOS 15.0, *) {
            let service = TranslationService()
            return try await service.translate(text: text, to: target)
        } else {
            throw TranslateReaderError.translationUnavailable
        }
    }
    
    /// Checks if translation is available on this system
    var isAvailable: Bool {
        if #available(macOS 15.0, *) {
            return true
        }
        return false
    }
    
    /// Returns message if translation is unavailable
    var unavailableMessage: String {
        "Translation requires macOS 15.0 or later with Translation framework support."
    }
}
