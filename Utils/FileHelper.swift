//
//  FileHelper.swift
//  TranslateReader
//
//  File system utilities
//

import Foundation
import CryptoKit

struct FileHelper {
    
    // MARK: - Directory Paths
    
    /// Returns the Application Support directory for the app
    static var applicationSupportDirectory: URL {
        let paths = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)
        let appSupport = paths[0].appendingPathComponent(AppConstants.appName)
        
        // Create directory if it doesn't exist
        if !FileManager.default.fileExists(atPath: appSupport.path) {
            try? FileManager.default.createDirectory(at: appSupport, withIntermediateDirectories: true)
        }
        
        return appSupport
    }
    
    /// Returns the cache directory
    static var cacheDirectory: URL {
        let cacheDir = applicationSupportDirectory.appendingPathComponent(AppConstants.cacheDirectoryName)
        
        if !FileManager.default.fileExists(atPath: cacheDir.path) {
            try? FileManager.default.createDirectory(at: cacheDir, withIntermediateDirectories: true)
        }
        
        return cacheDir
    }
    
    /// Returns a temporary directory for EPUB extraction
    static var tempDirectory: URL {
        FileManager.default.temporaryDirectory.appendingPathComponent(AppConstants.appName)
    }
    
    // MARK: - Book ID Generation
    
    /// Generates a unique ID for a book based on path, size, and modification date
    static func generateBookId(for url: URL) -> String {
        do {
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            let size = attributes[.size] as? Int64 ?? 0
            let modDate = attributes[.modificationDate] as? Date ?? Date()
            
            let identifier = "\(url.path)|\(size)|\(modDate.timeIntervalSince1970)"
            let data = Data(identifier.utf8)
            let hash = SHA256.hash(data: data)
            
            return hash.compactMap { String(format: "%02x", $0) }.joined()
        } catch {
            // Fallback to path-based hash
            let data = Data(url.path.utf8)
            let hash = SHA256.hash(data: data)
            return hash.compactMap { String(format: "%02x", $0) }.joined()
        }
    }
    
    // MARK: - File Operations
    
    /// Removes a directory and all its contents
    static func removeDirectory(at url: URL) {
        try? FileManager.default.removeItem(at: url)
    }
    
    /// Creates a directory if it doesn't exist
    static func createDirectory(at url: URL) throws {
        if !FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.createDirectory(at: url, withIntermediateDirectories: true)
        }
    }
    
    /// Checks if a file exists at the given path
    static func fileExists(at url: URL) -> Bool {
        FileManager.default.fileExists(atPath: url.path)
    }
    
    /// Reads the contents of a file as string
    static func readFile(at url: URL) -> String? {
        try? String(contentsOf: url, encoding: .utf8)
    }
    
    /// Writes string content to a file
    static func writeFile(content: String, to url: URL) throws {
        try content.write(to: url, atomically: true, encoding: .utf8)
    }
    
    /// Gets the file extension from a URL
    static func fileExtension(for url: URL) -> String {
        url.pathExtension.lowercased()
    }
    
    /// Determines the book type from file extension
    static func bookType(for url: URL) -> BookType? {
        let ext = fileExtension(for: url)
        switch ext {
        case "epub": return .epub
        case "pdf": return .pdf
        default: return nil
        }
    }
}
