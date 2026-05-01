//
//  HTMLWebView.swift
//  TranslateReader
//
//  WKWebView for translated HTML. Prefers loading from file (so images load natively
//  without size limits); falls back to data URLs when file load isn't available.
//

import SwiftUI
import WebKit

struct HTMLWebView: NSViewRepresentable {
    let html: String
    var baseURL: URL? = nil
    /// When set with baseURL, HTML is loaded from a file so images load from disk (no data URL truncation).
    var readAccessTo: URL? = nil
    var fontSize: CGFloat = 16
    
    private func wrapBody(_ body: String) -> String {
        """
        <!DOCTYPE html>
        <html>
        <head>
            <meta charset="utf-8">
            <style>
                body { font-family: -apple-system, BlinkMacSystemFont, sans-serif; font-size: \(Int(fontSize))px; line-height: 1.5; padding: 16px; margin: 0; }
                img { max-width: 100%; height: auto; display: block; }
            </style>
        </head>
        <body>
        \(body)
        </body>
        </html>
        """
    }
    
    /// HTML with images as data URLs (fallback when file load not used).
    private var fullHTMLWithDataURLs: String {
        wrapBody(htmlWithInlineImages(html, baseURL: baseURL))
    }
    
    func makeNSView(context: Context) -> WKWebView {
        let config = WKWebViewConfiguration()
        config.preferences.setValue(true, forKey: "allowFileAccessFromFileURLs")
        let webView = WKWebView(frame: .zero, configuration: config)
        webView.setValue(false, forKey: "drawsBackground")
        return webView
    }
    
    func updateNSView(_ webView: WKWebView, context: Context) {
        if let base = baseURL, let readAccess = readAccessTo {
            let rawHTML = wrapBody(html)
            let previewURL = base.appendingPathComponent("_tr_preview.html")
            do {
                try rawHTML.write(to: previewURL, atomically: true, encoding: .utf8)
                webView.loadFileURL(previewURL, allowingReadAccessTo: readAccess)
            } catch {
                webView.loadHTMLString(fullHTMLWithDataURLs, baseURL: nil)
            }
        } else {
            webView.loadHTMLString(fullHTMLWithDataURLs, baseURL: nil)
        }
    }
    
    /// Replaces every img src with a data: URL (base64) so images load without file access.
    private func htmlWithInlineImages(_ html: String, baseURL: URL?) -> String {
        // Match <img ... src="..." ...> or <img ... src="..." .../> (self-closing). Allow src to be first attribute.
        let pattern = #"<img\s+([^>]*?)src\s*=\s*["']([^"']+)["']([^>]*?)/?>"#
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive]) else { return html }
        let range = NSRange(html.startIndex..., in: html)
        let matches = regex.matches(in: html, range: range)
        var result = html
        let bases = imageResolutionBases(chapterBase: baseURL, bookRoot: readAccessTo)
        for match in matches.reversed() {
            guard match.numberOfRanges >= 3,
                  let srcRange = Range(match.range(at: 2), in: html) else { continue }
            let src = String(html[srcRange]).trimmingCharacters(in: .whitespaces)
            // Skip data: URLs (already inline)
            if src.hasPrefix("data:") { continue }
            guard let resolved = resolveImageURL(src, bases: bases),
                  let dataURL = dataURLForImage(at: resolved) else { continue }
            let fullRange = match.range(at: 0)
            let startIdx = result.index(result.startIndex, offsetBy: fullRange.location)
            let endIdx = result.index(result.startIndex, offsetBy: fullRange.location + fullRange.length)
            let group1 = String(html[Range(match.range(at: 1), in: html)!])
            let group3 = String(html[Range(match.range(at: 3), in: html)!])
            let newTag = "<img \(group1)src=\"\(dataURL)\"\(group3)>"
            result.replaceSubrange(startIdx..<endIdx, with: newTag)
        }
        return result
    }
    
    /// Build list of base URLs to try when resolving image paths (chapter dir, book root, common EPUB subdirs).
    private func imageResolutionBases(chapterBase: URL?, bookRoot: URL?) -> [URL] {
        var list: [URL] = []
        if let b = chapterBase { list.append(b) }
        guard let root = bookRoot else { return list }
        list.append(root)
        for sub in ["OEBPS", "OPS", "content", "Text", "xhtml", "images"] {
            list.append(root.appendingPathComponent(sub))
        }
        return list
    }
    
    /// Resolves image href to a file URL by trying each base; returns first URL where file exists.
    private func resolveImageURL(_ href: String, bases: [URL]) -> URL? {
        let trimmed = href.trimmingCharacters(in: .whitespaces)
        if trimmed.hasPrefix("data:") { return nil }
        if trimmed.hasPrefix("file://"), let u = URL(string: trimmed), FileManager.default.fileExists(atPath: u.path) {
            return u
        }
        for base in bases {
            let url = URL(fileURLWithPath: base.appendingPathComponent(trimmed).path).standardized
            if FileManager.default.fileExists(atPath: url.path) {
                return url
            }
        }
        return nil
    }
    
    private func resolveURL(_ href: String, base: URL) -> URL {
        let trimmed = href.trimmingCharacters(in: .whitespaces)
        if trimmed.hasPrefix("file://"), let u = URL(string: trimmed) {
            return u
        }
        let withBase = base.appendingPathComponent(trimmed)
        return URL(fileURLWithPath: withBase.path).standardized
    }
    
    private func dataURLForImage(at url: URL) -> String? {
        guard FileManager.default.fileExists(atPath: url.path),
              let data = try? Data(contentsOf: url) else { return nil }
        let ext = url.pathExtension.lowercased()
        let mime = mimeType(for: ext)
        let b64 = data.base64EncodedString()
        return "data:\(mime);base64,\(b64)"
    }
    
    private func mimeType(for ext: String) -> String {
        switch ext {
        case "jpg", "jpeg": return "image/jpeg"
        case "png": return "image/png"
        case "gif": return "image/gif"
        case "svg": return "image/svg+xml"
        case "webp": return "image/webp"
        default: return "image/png"
        }
    }
}
