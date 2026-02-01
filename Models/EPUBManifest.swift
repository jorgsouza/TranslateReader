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
    let properties: String?  // For EPUB3 nav detection
}

// MARK: - EPUB Metadata
struct EPUBMetadata {
    var title: String = "Unknown Title"
    var creator: String = "Unknown Author"
    var language: String = "en"
}

// MARK: - TOC Item (from NCX or NAV)
struct TOCItem {
    let title: String
    let href: String          // Path to content file (may include fragment #id)
    let contentHref: String   // Path without fragment
    let children: [TOCItem]
    
    init(title: String, href: String, children: [TOCItem] = []) {
        self.title = title
        self.href = href
        // Remove fragment identifier for matching
        self.contentHref = href.components(separatedBy: "#").first ?? href
        self.children = children
    }
}

// MARK: - EPUB Manifest (parsed OPF)
struct EPUBManifest {
    var metadata: EPUBMetadata = EPUBMetadata()
    var manifestItems: [String: ManifestItem] = [:]  // id -> item
    var spineItemRefs: [String] = []                  // Ordered list of idrefs
    var ncxHref: String?                              // Path to toc.ncx (EPUB2)
    var navHref: String?                              // Path to nav.xhtml (EPUB3)
    var tocItems: [TOCItem] = []                      // Parsed TOC entries
    
    /// Converts to SpineItems array for use in BookModel
    /// Maps TOC titles to spine items based on href matching
    func toSpineItems() -> [SpineItem] {
        // Create a flat map of href -> title from TOC
        let titleMap = buildTitleMap(from: tocItems)
        
        return spineItemRefs.compactMap { idref in
            guard let item = manifestItems[idref] else { return nil }
            
            // Try to find title from TOC
            let title = findTitle(for: item.href, in: titleMap)
            
            return SpineItem(
                id: item.id,
                href: item.href,
                mediaType: item.mediaType,
                title: title
            )
        }
    }
    
    /// Builds a flat dictionary of href -> title from hierarchical TOC
    /// Stores multiple variations of each href for flexible matching
    private func buildTitleMap(from items: [TOCItem]) -> [String: String] {
        var map: [String: String] = [:]
        
        func normalizeHref(_ href: String) -> [String] {
            var variations: [String] = []
            let cleanHref = href
                .replacingOccurrences(of: "./", with: "")
                .replacingOccurrences(of: "../", with: "")
            
            variations.append(href)
            variations.append(cleanHref)
            
            // Without fragment
            let withoutFragment = cleanHref.components(separatedBy: "#").first ?? cleanHref
            variations.append(withoutFragment)
            
            // Just filename
            let filename = (withoutFragment as NSString).lastPathComponent
            variations.append(filename)
            
            // Filename without extension
            let nameWithoutExt = (filename as NSString).deletingPathExtension
            variations.append(nameWithoutExt)
            
            // Common path variations
            if !cleanHref.hasPrefix("Text/") && !cleanHref.hasPrefix("OEBPS/") {
                variations.append("Text/\(cleanHref)")
                variations.append("OEBPS/\(cleanHref)")
                variations.append("text/\(cleanHref)")
            }
            
            return variations
        }
        
        func process(_ items: [TOCItem]) {
            for item in items {
                let variations = normalizeHref(item.href)
                for variation in variations {
                    if map[variation] == nil {
                        map[variation] = item.title
                    }
                    // Also store lowercase version
                    if map[variation.lowercased()] == nil {
                        map[variation.lowercased()] = item.title
                    }
                }
                process(item.children)
            }
        }
        
        process(items)
        return map
    }
    
    /// Finds the title for a given href using multiple matching strategies
    private func findTitle(for href: String, in titleMap: [String: String]) -> String? {
        // Strategy 1: Direct match
        if let title = titleMap[href] {
            return title
        }
        
        // Strategy 2: Clean href (remove ./ and ../)
        let cleanHref = href
            .replacingOccurrences(of: "./", with: "")
            .replacingOccurrences(of: "../", with: "")
        if let title = titleMap[cleanHref] {
            return title
        }
        
        // Strategy 3: Lowercase match
        if let title = titleMap[href.lowercased()] ?? titleMap[cleanHref.lowercased()] {
            return title
        }
        
        // Strategy 4: Without path prefix
        let filename = (cleanHref as NSString).lastPathComponent
        if let title = titleMap[filename] ?? titleMap[filename.lowercased()] {
            return title
        }
        
        // Strategy 5: Filename without extension
        let nameWithoutExt = (filename as NSString).deletingPathExtension
        if let title = titleMap[nameWithoutExt] ?? titleMap[nameWithoutExt.lowercased()] {
            return title
        }
        
        // Strategy 6: Search all keys for partial match
        for (key, value) in titleMap {
            let keyFilename = (key as NSString).lastPathComponent
            let keyWithoutExt = (keyFilename as NSString).deletingPathExtension
            
            // Match by filename
            if keyFilename.lowercased() == filename.lowercased() {
                return value
            }
            
            // Match by name without extension
            if keyWithoutExt.lowercased() == nameWithoutExt.lowercased() {
                return value
            }
            
            // Match if href ends with key or key ends with href
            if cleanHref.lowercased().hasSuffix(key.lowercased()) ||
               key.lowercased().hasSuffix(cleanHref.lowercased()) {
                return value
            }
        }
        
        return nil
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
        
        // Find NCX and NAV references
        findTOCReferences()
        
        return manifest
    }
    
    /// Finds NCX (EPUB2) and NAV (EPUB3) references in manifest
    private func findTOCReferences() {
        for (_, item) in manifest.manifestItems {
            // EPUB2: NCX file
            if item.mediaType == "application/x-dtbncx+xml" {
                manifest.ncxHref = item.href
            }
            // EPUB3: Navigation document
            if let props = item.properties, props.contains("nav") {
                manifest.navHref = item.href
            }
            // Fallback: check for nav.xhtml or toc.xhtml
            if manifest.navHref == nil {
                let hrefLower = item.href.lowercased()
                if (hrefLower.contains("nav") || hrefLower.contains("toc")) && 
                   (item.mediaType.contains("xhtml") || item.mediaType.contains("html")) {
                    manifest.navHref = item.href
                }
            }
        }
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
                let properties = attributeDict["properties"]
                let item = ManifestItem(id: id, href: href, mediaType: mediaType, properties: properties)
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

// MARK: - NCX Parser (EPUB2 Table of Contents)
class NCXParser: NSObject, XMLParserDelegate {
    private var tocItems: [TOCItem] = []
    private var currentText = ""
    
    // State tracking
    private var inNavPoint = false
    private var inNavLabel = false
    
    // Current item being built
    private var currentTitle = ""
    private var currentHref = ""
    
    // Depth tracking for nested navPoints
    private var navPointDepth = 0
    
    /// Parses an NCX file and returns TOC items (flat list)
    func parse(url: URL) -> [TOCItem] {
        guard let parser = XMLParser(contentsOf: url) else {
            return []
        }
        
        parser.delegate = self
        parser.parse()
        
        return tocItems
    }
    
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?,
                qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        let element = elementName.lowercased()
        
        switch element {
        case "navpoint":
            navPointDepth += 1
            inNavPoint = true
            currentTitle = ""
            currentHref = ""
        case "navlabel":
            inNavLabel = true
            currentText = ""
        case "text":
            currentText = ""
        case "content":
            if inNavPoint, let src = attributeDict["src"] {
                currentHref = src
            }
        default:
            break
        }
    }
    
    func parser(_ parser: XMLParser, foundCharacters string: String) {
        currentText += string
    }
    
    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?,
                qualifiedName qName: String?) {
        let element = elementName.lowercased()
        
        switch element {
        case "navpoint":
            // Save the item when we close the navPoint
            if inNavPoint && !currentTitle.isEmpty && !currentHref.isEmpty {
                let item = TOCItem(title: currentTitle, href: currentHref)
                tocItems.append(item)
            }
            navPointDepth -= 1
            if navPointDepth == 0 {
                inNavPoint = false
            }
        case "navlabel":
            inNavLabel = false
        case "text":
            if inNavLabel {
                let trimmed = currentText.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmed.isEmpty {
                    currentTitle = trimmed
                }
            }
        default:
            break
        }
    }
}

// MARK: - NAV Parser (EPUB3 Navigation Document)
class NAVParser: NSObject, XMLParserDelegate {
    private var tocItems: [TOCItem] = []
    private var currentText = ""
    
    // State tracking
    private var inNav = false
    private var inTocNav = false  // <nav epub:type="toc">
    private var inOl = false
    private var inLi = false
    private var inAnchor = false
    
    // Current item being built
    private var currentTitle = ""
    private var currentHref = ""
    
    // Stack for nested lists
    private var olDepth = 0
    private var itemStack: [TOCItem] = []
    private var childrenStack: [[TOCItem]] = [[]]
    
    /// Parses a NAV document and returns TOC items
    func parse(url: URL) -> [TOCItem] {
        guard let data = try? Data(contentsOf: url),
              let content = String(data: data, encoding: .utf8) else {
            return []
        }
        
        // Try to parse as XML first
        if let parser = XMLParser(contentsOf: url) {
            parser.delegate = self
            parser.parse()
            
            if !tocItems.isEmpty {
                return tocItems
            }
        }
        
        // Fallback: regex-based parsing for malformed HTML
        return parseWithRegex(content)
    }
    
    /// Regex-based fallback parser for nav.xhtml
    private func parseWithRegex(_ content: String) -> [TOCItem] {
        var items: [TOCItem] = []
        
        // Find the TOC nav section
        let navPattern = #"<nav[^>]*epub:type\s*=\s*["\']toc["\'][^>]*>([\s\S]*?)</nav>"#
        guard let navRegex = try? NSRegularExpression(pattern: navPattern, options: .caseInsensitive),
              let navMatch = navRegex.firstMatch(in: content, range: NSRange(content.startIndex..., in: content)),
              let navRange = Range(navMatch.range(at: 1), in: content) else {
            // Try simpler nav pattern
            return parseSimpleNav(content)
        }
        
        let navContent = String(content[navRange])
        
        // Extract links from the nav content
        let linkPattern = #"<a[^>]*href\s*=\s*["\']([^"\']+)["\'][^>]*>([^<]+)</a>"#
        guard let linkRegex = try? NSRegularExpression(pattern: linkPattern, options: .caseInsensitive) else {
            return items
        }
        
        let matches = linkRegex.matches(in: navContent, range: NSRange(navContent.startIndex..., in: navContent))
        for match in matches {
            if let hrefRange = Range(match.range(at: 1), in: navContent),
               let titleRange = Range(match.range(at: 2), in: navContent) {
                let href = String(navContent[hrefRange])
                let title = String(navContent[titleRange])
                    .trimmingCharacters(in: .whitespacesAndNewlines)
                    .replacingOccurrences(of: "&amp;", with: "&")
                    .replacingOccurrences(of: "&lt;", with: "<")
                    .replacingOccurrences(of: "&gt;", with: ">")
                
                if !title.isEmpty {
                    items.append(TOCItem(title: title, href: href))
                }
            }
        }
        
        return items
    }
    
    /// Simple nav parsing for basic structures
    private func parseSimpleNav(_ content: String) -> [TOCItem] {
        var items: [TOCItem] = []
        
        // Just find all anchor tags with href
        let linkPattern = #"<a[^>]*href\s*=\s*["\']([^"\']+)["\'][^>]*>([\s\S]*?)</a>"#
        guard let linkRegex = try? NSRegularExpression(pattern: linkPattern, options: .caseInsensitive) else {
            return items
        }
        
        let matches = linkRegex.matches(in: content, range: NSRange(content.startIndex..., in: content))
        for match in matches {
            if let hrefRange = Range(match.range(at: 1), in: content),
               let titleRange = Range(match.range(at: 2), in: content) {
                let href = String(content[hrefRange])
                var title = String(content[titleRange])
                
                // Strip any remaining HTML tags from title
                let tagPattern = #"<[^>]+>"#
                title = title.replacingOccurrences(of: tagPattern, with: "", options: .regularExpression)
                title = title.trimmingCharacters(in: .whitespacesAndNewlines)
                    .replacingOccurrences(of: "&amp;", with: "&")
                    .replacingOccurrences(of: "&nbsp;", with: " ")
                
                // Skip empty titles or non-content links
                if !title.isEmpty && !href.hasPrefix("#") && !href.hasPrefix("http") {
                    items.append(TOCItem(title: title, href: href))
                }
            }
        }
        
        return items
    }
    
    // MARK: - XMLParserDelegate
    
    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?,
                qualifiedName qName: String?, attributes attributeDict: [String : String] = [:]) {
        let element = elementName.lowercased()
        currentText = ""
        
        switch element {
        case "nav":
            inNav = true
            // Check for epub:type="toc"
            let epubType = attributeDict["epub:type"] ?? attributeDict["type"] ?? ""
            if epubType.contains("toc") {
                inTocNav = true
            }
        case "ol":
            if inTocNav {
                olDepth += 1
                inOl = true
                childrenStack.append([])
            }
        case "li":
            if inOl {
                inLi = true
                currentTitle = ""
                currentHref = ""
            }
        case "a":
            if inLi {
                inAnchor = true
                if let href = attributeDict["href"] {
                    currentHref = href
                }
            }
        default:
            break
        }
    }
    
    func parser(_ parser: XMLParser, foundCharacters string: String) {
        currentText += string
    }
    
    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?,
                qualifiedName qName: String?) {
        let element = elementName.lowercased()
        let trimmedText = currentText.trimmingCharacters(in: .whitespacesAndNewlines)
        
        switch element {
        case "nav":
            inNav = false
            inTocNav = false
        case "ol":
            if inTocNav && olDepth > 0 {
                olDepth -= 1
                if olDepth == 0 {
                    inOl = false
                    // Get the collected items from the top-level list
                    if let topItems = childrenStack.popLast() {
                        tocItems.append(contentsOf: topItems)
                    }
                } else {
                    // Pop children and attach to parent
                    if let children = childrenStack.popLast(), childrenStack.count > 0 {
                        // The last item in the parent's children list should get these as its children
                        // This is simplified - real nesting would need more complex handling
                    }
                }
            }
        case "li":
            if inLi && !currentTitle.isEmpty {
                let item = TOCItem(title: currentTitle, href: currentHref)
                if var currentChildren = childrenStack.popLast() {
                    currentChildren.append(item)
                    childrenStack.append(currentChildren)
                }
            }
            inLi = false
        case "a":
            if inAnchor && !trimmedText.isEmpty {
                currentTitle = trimmedText
            }
            inAnchor = false
        default:
            break
        }
        
        currentText = ""
    }
}
