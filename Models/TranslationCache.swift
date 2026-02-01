//
//  TranslationCache.swift
//  TranslateReader
//
//  Model for translation cache entries
//

import Foundation

// MARK: - Cache Entry
struct TranslationCacheEntry: Codable, Identifiable {
    let id: String           // Generated cache key
    let bookId: String
    let contentId: String    // Chapter href or page identifier
    let pageIndex: Int
    let targetLanguage: String
    let originalText: String
    let translatedText: String
    let timestamp: Date
    
    init(bookId: String, contentId: String, pageIndex: Int, targetLanguage: String,
         originalText: String, translatedText: String) {
        self.id = TranslationCacheEntry.generateKey(
            bookId: bookId,
            contentId: contentId,
            pageIndex: pageIndex,
            targetLanguage: targetLanguage
        )
        self.bookId = bookId
        self.contentId = contentId
        self.pageIndex = pageIndex
        self.targetLanguage = targetLanguage
        self.originalText = originalText
        self.translatedText = translatedText
        self.timestamp = Date()
    }
    
    /// Generates a unique cache key
    static func generateKey(bookId: String, contentId: String, pageIndex: Int, targetLanguage: String) -> String {
        "\(bookId)_\(contentId)_\(pageIndex)_\(targetLanguage)"
    }
}

// MARK: - Cache Storage
struct TranslationCacheStorage: Codable {
    var entries: [String: TranslationCacheEntry] = [:]
    
    mutating func add(_ entry: TranslationCacheEntry) {
        entries[entry.id] = entry
    }
    
    func get(key: String) -> TranslationCacheEntry? {
        entries[key]
    }
    
    mutating func remove(key: String) {
        entries.removeValue(forKey: key)
    }
    
    mutating func clear() {
        entries.removeAll()
    }
    
    /// Removes entries older than specified days
    mutating func pruneOldEntries(olderThanDays days: Int = 30) {
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        entries = entries.filter { $0.value.timestamp > cutoffDate }
    }
}
