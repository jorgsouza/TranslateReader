//
//  EPUBManifest.swift
//  TranslateReader
//
//  EPUB manifest structure and OPF parser
//

import Foundation

// MARK: - Manifest Item
struct ManifestItem {
    let id: String
    let href: String
    let mediaType: String
}

// MARK: - EPUB Metadata
struct EPUBMetadata {
    var title: String = "Unknown Title"
    var creator: String = "Unknown Author"
    var language: String = "en"
}

// MARK: - EPUB Manifest (parsed OPF)
struct EPUBManifest {
    var metadata: EPUBMetadata = EPUBMetadata()
    var manifestItems: [String: ManifestItem] = [:]  // id -> item
    var spineItemRefs: [String] = []                  // Ordered list of idrefs
    
    /// Converts to SpineItems array for use in BookModel
    func toSpineItems() -> [SpineItem] {
        spineItemRefs.compactMap { idref in
            guard let item = manifestItems[idref] else { return nil }
            return SpineItem(
                id: item.id,
                href: item.href,
                mediaType: item.mediaType,
                title: nil
            )
        }
    }
}

// MARK: - OPF Parser
class OPFParser: NSObject, XMLParserDelegate {
    private var manifest = EPUBManifest()
    private var currentElement = ""
    private var currentText = ""
    
    // Track which section we're in
    private var inMetadata = false
    private var inManifest = false
    private var inSpine = false
    
    /// Parses an OPF file and returns the manifest
    func parse(url: URL) throws -> EPUBManifest {
        guard let parser = XMLParser(contentsOf: url) else {
            throw TranslateReaderError.parsingFailed
        }
        
        parser.delegate = self
        parser.parse()
        
        if manifest.spineItemRefs.isEmpty {
            throw TranslateReaderError.invalidEPUB
        }
        
        return manifest
    }
    
    // MARK: - XMLParserDelegate
    
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, 
                qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        currentElement = elementName.lowercased()
        currentText = ""
        
        // Track sections
        if elementName.lowercased().contains("metadata") {
            inMetadata = true
        } else if elementName.lowercased() == "manifest" {
            inManifest = true
        } else if elementName.lowercased() == "spine" {
            inSpine = true
        }
        
        // Parse manifest items
        if inManifest && elementName.lowercased() == "item" {
            if let id = attributeDict["id"],
               let href = attributeDict["href"],
               let mediaType = attributeDict["media-type"] {
                let item = ManifestItem(id: id, href: href, mediaType: mediaType)
                manifest.manifestItems[id] = item
            }
        }
        
        // Parse spine itemrefs
        if inSpine && elementName.lowercased() == "itemref" {
            if let idref = attributeDict["idref"] {
                manifest.spineItemRefs.append(idref)
            }
        }
    }
    
    func parser(_ parser: XMLParser, foundCharacters string: String) {
        currentText += string
    }
    
    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, 
                qualifiedName qName: String?) {
        let trimmedText = currentText.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // Parse metadata
        if inMetadata {
            let element = elementName.lowercased()
            if element.contains("title") && !trimmedText.isEmpty {
                manifest.metadata.title = trimmedText
            } else if element.contains("creator") && !trimmedText.isEmpty {
                manifest.metadata.creator = trimmedText
            } else if element.contains("language") && !trimmedText.isEmpty {
                manifest.metadata.language = trimmedText
            }
        }
        
        // Track section end
        if elementName.lowercased().contains("metadata") {
            inMetadata = false
        } else if elementName.lowercased() == "manifest" {
            inManifest = false
        } else if elementName.lowercased() == "spine" {
            inSpine = false
        }
        
        currentElement = ""
        currentText = ""
    }
}

// MARK: - Container.xml Parser
class ContainerParser: NSObject, XMLParserDelegate {
    private var opfPath: String?
    
    /// Parses container.xml to find the OPF file path
    func parse(url: URL) throws -> String {
        guard let parser = XMLParser(contentsOf: url) else {
            throw TranslateReaderError.parsingFailed
        }
        
        parser.delegate = self
        parser.parse()
        
        guard let path = opfPath else {
            throw TranslateReaderError.invalidEPUB
        }
        
        return path
    }
    
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, 
                qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        if elementName.lowercased() == "rootfile" {
            if let fullPath = attributeDict["full-path"] {
                opfPath = fullPath
            }
        }
    }
}
