//
//  CacheService.swift
//  TranslateReader
//
//  Service for caching translations in memory and disk
//

import Foundation

class CacheService {
    
    // MARK: - Properties
    
    /// In-memory cache for quick access
    private var memoryCache: [String: String] = [:]
    
    /// Disk storage
    private var diskStorage: TranslationCacheStorage
    
    /// Cache file URL
    private let cacheFileURL: URL
    
    /// Serial queue for thread-safe disk operations
    private let diskQueue = DispatchQueue(label: "com.translatereader.cache")
    
    // MARK: - Initialization
    
    init() {
        cacheFileURL = FileHelper.cacheDirectory.appendingPathComponent(AppConstants.translationCacheFile)
        diskStorage = CacheService.loadFromDisk(url: cacheFileURL) ?? TranslationCacheStorage()
        
        // Populate memory cache from disk
        for (key, entry) in diskStorage.entries {
            memoryCache[key] = entry.translatedText
        }
        
        // Prune old entries on startup
        diskStorage.pruneOldEntries()
        saveToDisk()
    }
    
    // MARK: - Cache Operations
    
    /// Saves a translation to cache (optionally with body HTML for EPUB display).
    func save(translation: String, for key: String, bookId: String, contentId: String,
              pageIndex: Int, targetLanguage: String, originalText: String, translatedBodyHTML: String? = nil) {
        // Save to memory
        memoryCache[key] = translation
        
        // Save to disk
        let entry = TranslationCacheEntry(
            bookId: bookId,
            contentId: contentId,
            pageIndex: pageIndex,
            targetLanguage: targetLanguage,
            originalText: originalText,
            translatedText: translation,
            translatedBodyHTML: translatedBodyHTML
        )
        
        diskQueue.async { [weak self] in
            self?.diskStorage.add(entry)
            self?.saveToDisk()
        }
    }
    
    /// Loads a translation from cache
    func load(for key: String) -> String? {
        // Check memory first
        if let cached = memoryCache[key] {
            return cached
        }
        
        // Check disk
        if let entry = diskStorage.get(key: key) {
            // Populate memory cache
            memoryCache[key] = entry.translatedText
            return entry.translatedText
        }
        
        return nil
    }
    
    /// Loads optional body HTML (with images) for EPUB translation display.
    func loadBodyHTML(for key: String) -> String? {
        diskStorage.get(key: key)?.translatedBodyHTML
    }
    
    /// Checks if a translation exists in cache
    func exists(for key: String) -> Bool {
        memoryCache[key] != nil || diskStorage.get(key: key) != nil
    }
    
    /// Removes a specific cache entry
    func remove(for key: String) {
        memoryCache.removeValue(forKey: key)
        
        diskQueue.async { [weak self] in
            self?.diskStorage.remove(key: key)
            self?.saveToDisk()
        }
    }
    
    /// Clears all cache
    func clearAll() {
        memoryCache.removeAll()
        
        diskQueue.async { [weak self] in
            self?.diskStorage.clear()
            self?.saveToDisk()
        }
    }
    
    /// Clears cache for a specific book
    func clearBook(bookId: String) {
        // Remove from memory
        let keysToRemove = memoryCache.keys.filter { $0.hasPrefix(bookId) }
        for key in keysToRemove {
            memoryCache.removeValue(forKey: key)
        }
        
        // Remove from disk
        diskQueue.async { [weak self] in
            guard let self = self else { return }
            let entriesToRemove = self.diskStorage.entries.filter { $0.value.bookId == bookId }
            for key in entriesToRemove.keys {
                self.diskStorage.remove(key: key)
            }
            self.saveToDisk()
        }
    }
    
    // MARK: - Disk Operations
    
    /// Saves cache to disk
    private func saveToDisk() {
        do {
            let data = try JSONEncoder().encode(diskStorage)
            try data.write(to: cacheFileURL)
        } catch {
            print("Failed to save cache to disk: \(error)")
        }
    }
    
    /// Loads cache from disk
    private static func loadFromDisk(url: URL) -> TranslationCacheStorage? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(TranslationCacheStorage.self, from: data)
    }
    
    // MARK: - Statistics
    
    /// Returns the number of cached entries
    var entryCount: Int {
        diskStorage.entries.count
    }
    
    /// Returns the cache size in bytes
    var cacheSize: Int {
        guard let data = try? Data(contentsOf: cacheFileURL) else { return 0 }
        return data.count
    }
    
    /// Returns human-readable cache size
    var cacheSizeFormatted: String {
        let bytes = cacheSize
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useKB, .useMB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: Int64(bytes))
    }
}
