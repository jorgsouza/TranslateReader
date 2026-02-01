//
//  LibraryService.swift
//  TranslateReader
//
//  Service for detecting and accessing book libraries (Kindle, Apple Books)
//

import Foundation

/// Represents a book found in an external library
struct LibraryBook: Identifiable, Hashable {
    let id: String
    let title: String
    let url: URL
    let source: LibrarySource
    let fileType: String
    let isProtected: Bool  // DRM protected
    
    var canOpen: Bool {
        !isProtected && (fileType == "epub" || fileType == "pdf")
    }
    
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
    }
    
    static func == (lhs: LibraryBook, rhs: LibraryBook) -> Bool {
        lhs.id == rhs.id
    }
}

/// Available library sources
enum LibrarySource: String, CaseIterable {
    case kindle = "Kindle"
    case appleBooks = "Apple Books"
    case custom = "Custom"
    
    var icon: String {
        switch self {
        case .kindle: return "flame"
        case .appleBooks: return "book.closed"
        case .custom: return "folder"
        }
    }
}

/// Service for accessing external book libraries
class LibraryService {
    
    // MARK: - Singleton
    static let shared = LibraryService()
    
    private init() {}
    
    // MARK: - Library Paths
    
    private var kindleContentPath: URL? {
        // Kindle moderno (versão App Store) usa Containers
        let containerPath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Containers/com.amazon.Lassen/Data/Library/eBooks")
        if FileManager.default.fileExists(atPath: containerPath.path) {
            return containerPath
        }
        
        // Kindle antigo (versão standalone)
        let legacyPath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Application Support/Kindle/My Kindle Content")
        return FileManager.default.fileExists(atPath: legacyPath.path) ? legacyPath : nil
    }
    
    private var appleBooksPath: URL? {
        // Apple Books stores books in a complex structure
        let path = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Containers/com.apple.BKAgentService/Data/Documents/iBooks/Books")
        if FileManager.default.fileExists(atPath: path.path) {
            return path
        }
        // Alternative path for older versions
        let altPath = FileManager.default.homeDirectoryForCurrentUser
            .appendingPathComponent("Library/Mobile Documents/iCloud~com~apple~iBooks/Documents")
        return FileManager.default.fileExists(atPath: altPath.path) ? altPath : nil
    }
    
    // MARK: - Check Installation
    
    func isKindleInstalled() -> Bool {
        FileManager.default.fileExists(atPath: "/Applications/Kindle.app")
    }
    
    func isAppleBooksInstalled() -> Bool {
        FileManager.default.fileExists(atPath: "/System/Applications/Books.app")
    }
    
    func hasKindleLibrary() -> Bool {
        kindleContentPath != nil
    }
    
    func hasAppleBooksLibrary() -> Bool {
        appleBooksPath != nil
    }
    
    // MARK: - Get Available Sources
    
    func getAvailableSources() -> [LibrarySource] {
        var sources: [LibrarySource] = []
        
        if hasKindleLibrary() {
            sources.append(.kindle)
        }
        if hasAppleBooksLibrary() {
            sources.append(.appleBooks)
        }
        
        return sources
    }
    
    // MARK: - Scan Libraries
    
    func scanKindleLibrary() -> [LibraryBook] {
        guard let path = kindleContentPath else { return [] }
        return scanDirectory(path, source: .kindle)
    }
    
    func scanAppleBooksLibrary() -> [LibraryBook] {
        guard let path = appleBooksPath else { return [] }
        return scanDirectory(path, source: .appleBooks)
    }
    
    func scanAllLibraries() -> [LibraryBook] {
        var books: [LibraryBook] = []
        books.append(contentsOf: scanKindleLibrary())
        books.append(contentsOf: scanAppleBooksLibrary())
        return books.sorted { $0.title < $1.title }
    }
    
    // MARK: - Directory Scanning
    
    private func scanDirectory(_ directory: URL, source: LibrarySource) -> [LibraryBook] {
        var books: [LibraryBook] = []
        
        let fileManager = FileManager.default
        guard let enumerator = fileManager.enumerator(
            at: directory,
            includingPropertiesForKeys: [.isRegularFileKey],
            options: [.skipsHiddenFiles]
        ) else {
            return []
        }
        
        // Suportar formatos do Kindle moderno (KFX) também
        let supportedExtensions = ["epub", "pdf", "mobi", "azw", "azw3", "azw8", "azw9", "kfx"]
        
        // Para Kindle, rastrear livros por ASIN (pasta pai) para evitar duplicatas
        var seenASINs: Set<String> = []
        
        for case let fileURL as URL in enumerator {
            let ext = fileURL.pathExtension.lowercased()
            
            // Ignorar arquivos auxiliares
            if ext.hasSuffix(".md") || ext.hasSuffix(".res") {
                continue
            }
            
            guard supportedExtensions.contains(ext) else { continue }
            
            // Para Kindle, usar a pasta ASIN como identificador único
            if source == .kindle {
                let parentDir = fileURL.deletingLastPathComponent().deletingLastPathComponent().lastPathComponent
                if parentDir.hasPrefix("B0") && parentDir.count == 10 {
                    if seenASINs.contains(parentDir) {
                        continue
                    }
                    seenASINs.insert(parentDir)
                }
            }
            
            let title = extractTitle(from: fileURL, source: source)
            let isProtected = isLikelyDRMProtected(ext: ext, source: source)
            
            let book = LibraryBook(
                id: fileURL.path,
                title: title,
                url: fileURL,
                source: source,
                fileType: ext,
                isProtected: isProtected
            )
            books.append(book)
        }
        
        return books
    }
    
    // MARK: - Helpers
    
    private func extractTitle(from url: URL, source: LibrarySource = .custom) -> String {
        // Para Kindle moderno, tentar obter título do ASIN
        if source == .kindle {
            let parentDir = url.deletingLastPathComponent().deletingLastPathComponent().lastPathComponent
            if parentDir.hasPrefix("B0") && parentDir.count == 10 {
                // Retornar ASIN como identificador - título real requer API da Amazon
                return "Kindle Book (\(parentDir))"
            }
        }
        
        // Try to extract a readable title from the filename
        var title = url.deletingPathExtension().lastPathComponent
        
        // Remove common patterns like ASIN codes
        // Example: "B00ABC123_EBOK" -> "B00ABC123"
        if let range = title.range(of: "_EBOK") {
            title = String(title[..<range.lowerBound])
        }
        
        // Remove prefixes like CR!
        if title.hasPrefix("CR!") {
            title = String(title.dropFirst(3))
        }
        
        // Replace underscores with spaces
        title = title.replacingOccurrences(of: "_", with: " ")
        
        // Clean up multiple spaces
        while title.contains("  ") {
            title = title.replacingOccurrences(of: "  ", with: " ")
        }
        
        return title.trimmingCharacters(in: .whitespaces)
    }
    
    private func isLikelyDRMProtected(ext: String, source: LibrarySource) -> Bool {
        // Kindle formats are typically DRM protected
        let drmFormats = ["azw", "azw3", "azw8", "azw9", "kfx"]
        
        if drmFormats.contains(ext) {
            return true
        }
        
        // MOBI files from Kindle are often protected
        if ext == "mobi" && source == .kindle {
            return true  // Assume protected, user can try anyway
        }
        
        // EPUB and PDF are usually not protected (when sent by user)
        return false
    }
    
    // MARK: - Custom Folders
    
    private var customFolders: [URL] {
        get {
            guard let data = UserDefaults.standard.data(forKey: "customLibraryFolders"),
                  let urls = try? JSONDecoder().decode([URL].self, from: data) else {
                return []
            }
            return urls
        }
        set {
            if let data = try? JSONEncoder().encode(newValue) {
                UserDefaults.standard.set(data, forKey: "customLibraryFolders")
            }
        }
    }
    
    func addCustomFolder(_ url: URL) {
        var folders = customFolders
        if !folders.contains(url) {
            folders.append(url)
            customFolders = folders
        }
    }
    
    func removeCustomFolder(_ url: URL) {
        customFolders = customFolders.filter { $0 != url }
    }
    
    func getCustomFolders() -> [URL] {
        customFolders
    }
    
    func scanCustomFolders() -> [LibraryBook] {
        var books: [LibraryBook] = []
        for folder in customFolders {
            books.append(contentsOf: scanDirectory(folder, source: .custom))
        }
        return books
    }
}
