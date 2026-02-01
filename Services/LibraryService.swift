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
    case appleBooks = "Apple Books"
    case custom = "Minhas Pastas"
    
    var icon: String {
        switch self {
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
    
    func isAppleBooksInstalled() -> Bool {
        FileManager.default.fileExists(atPath: "/System/Applications/Books.app")
    }
    
    func hasAppleBooksLibrary() -> Bool {
        appleBooksPath != nil
    }
    
    // MARK: - Get Available Sources
    
    func getAvailableSources() -> [LibrarySource] {
        var sources: [LibrarySource] = []
        
        if hasAppleBooksLibrary() {
            sources.append(.appleBooks)
        }
        
        // Sempre mostrar opção de pastas personalizadas
        sources.append(.custom)
        
        return sources
    }
    
    // MARK: - Scan Libraries
    
    func scanAppleBooksLibrary() -> [LibraryBook] {
        guard let path = appleBooksPath else { return [] }
        return scanDirectory(path, source: .appleBooks)
    }
    
    func scanAllLibraries() -> [LibraryBook] {
        var books: [LibraryBook] = []
        books.append(contentsOf: scanAppleBooksLibrary())
        books.append(contentsOf: scanCustomFolders())
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
        
        // Apenas formatos que podemos abrir (EPUB e PDF)
        let supportedExtensions = ["epub", "pdf"]
        
        for case let fileURL as URL in enumerator {
            let ext = fileURL.pathExtension.lowercased()
            guard supportedExtensions.contains(ext) else { continue }
            
            let title = extractTitle(from: fileURL)
            
            let book = LibraryBook(
                id: fileURL.path,
                title: title,
                url: fileURL,
                source: source,
                fileType: ext,
                isProtected: false  // EPUB e PDF não são protegidos
            )
            books.append(book)
        }
        
        return books
    }
    
    // MARK: - Helpers
    
    private func extractTitle(from url: URL) -> String {
        // Extrair título do nome do arquivo
        var title = url.deletingPathExtension().lastPathComponent
        
        // Substituir underscores por espaços
        title = title.replacingOccurrences(of: "_", with: " ")
        
        // Limpar espaços múltiplos
        while title.contains("  ") {
            title = title.replacingOccurrences(of: "  ", with: " ")
        }
        
        return title.trimmingCharacters(in: .whitespaces)
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
