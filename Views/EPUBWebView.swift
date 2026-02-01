//
//  EPUBWebView.swift
//  TranslateReader
//
//  WKWebView wrapper for rendering EPUB HTML content
//

import SwiftUI
import WebKit

struct EPUBWebView: NSViewRepresentable {
    let book: BookModel
    let pageIndex: Int
    
    func makeNSView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        
        // Allow file access for local EPUB content
        configuration.preferences.setValue(true, forKey: "allowFileAccessFromFileURLs")
        
        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        
        // Disable scrollbars (handled by SwiftUI)
        webView.enclosingScrollView?.hasVerticalScroller = false
        webView.enclosingScrollView?.hasHorizontalScroller = false
        
        return webView
    }
    
    func updateNSView(_ webView: WKWebView, context: Context) {
        loadContent(in: webView)
    }
    
    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }
    
    // MARK: - Load Content
    
    private func loadContent(in webView: WKWebView) {
        guard let contentURL = book.epubContentURL(at: pageIndex),
              let basePath = book.basePath else {
            loadErrorPage(in: webView)
            return
        }
        
        // Load the HTML file with proper base URL for relative resources
        webView.loadFileURL(contentURL, allowingReadAccessTo: basePath)
    }
    
    private func loadErrorPage(in webView: WKWebView) {
        let html = """
        <!DOCTYPE html>
        <html>
        <head>
            <style>
                body {
                    font-family: -apple-system, BlinkMacSystemFont, sans-serif;
                    display: flex;
                    justify-content: center;
                    align-items: center;
                    height: 100vh;
                    margin: 0;
                    background-color: #f5f5f5;
                }
                .error {
                    text-align: center;
                    color: #666;
                }
            </style>
        </head>
        <body>
            <div class="error">
                <h2>Content Not Available</h2>
                <p>Unable to load this chapter.</p>
            </div>
        </body>
        </html>
        """
        webView.loadHTMLString(html, baseURL: nil)
    }
    
    // MARK: - Coordinator
    
    class Coordinator: NSObject, WKNavigationDelegate {
        let parent: EPUBWebView
        
        init(_ parent: EPUBWebView) {
            self.parent = parent
        }
        
        // Intercept navigation to handle internal links
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
            // Allow file URLs (local EPUB content)
            if navigationAction.request.url?.isFileURL == true {
                decisionHandler(.allow)
                return
            }
            
            // Cancel external links
            decisionHandler(.cancel)
        }
        
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            print("WebView navigation failed: \(error.localizedDescription)")
        }
        
        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            print("WebView provisional navigation failed: \(error.localizedDescription)")
        }
    }
}

// MARK: - EPUB Content Styling

extension EPUBWebView {
    /// Injects custom CSS for better reading experience
    static func customReaderCSS(fontSize: CGFloat = 16) -> String {
        """
        <style>
            body {
                font-family: Georgia, 'Times New Roman', serif;
                font-size: \(fontSize)px;
                line-height: 1.6;
                max-width: 800px;
                margin: 0 auto;
                padding: 20px;
                background-color: #fefefe;
                color: #333;
            }
            
            h1, h2, h3, h4, h5, h6 {
                font-family: -apple-system, BlinkMacSystemFont, sans-serif;
                color: #222;
                margin-top: 1.5em;
            }
            
            p {
                text-align: justify;
                margin-bottom: 1em;
            }
            
            img {
                max-width: 100%;
                height: auto;
            }
            
            a {
                color: #0066cc;
                text-decoration: none;
            }
            
            blockquote {
                border-left: 3px solid #ccc;
                margin-left: 0;
                padding-left: 1em;
                font-style: italic;
            }
            
            @media (prefers-color-scheme: dark) {
                body {
                    background-color: #1e1e1e;
                    color: #e0e0e0;
                }
                h1, h2, h3, h4, h5, h6 {
                    color: #f0f0f0;
                }
                a {
                    color: #6699ff;
                }
            }
        </style>
        """
    }
}

// MARK: - Preview

#Preview {
    Text("EPUBWebView requires a valid EPUB file")
        .frame(width: 400, height: 300)
}
