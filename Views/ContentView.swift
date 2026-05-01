//
//  ContentView.swift
//  TranslateReader
//
//  Main view with two-column layout: original content (left) and translation (right)
//

import SwiftUI
import UniformTypeIdentifiers

// Define EPUB UTType
extension UTType {
    static var epub: UTType {
        UTType(importedAs: "org.idpf.epub-container")
    }
}

struct ContentView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        NavigationSplitView {
            // Sidebar - could be used for TOC in future
            sidebarView
        } detail: {
            // Main content area
            mainContentView
        }
        // Force NavigationSplitView to rebuild when book changes
        .id(appState.currentBook?.id ?? "empty")
        .navigationTitle(appState.currentBook?.title ?? "TranslateReader")
        .toolbar {
            ToolbarView()
        }
        .fileImporter(
            isPresented: $appState.showFileImporter,
            allowedContentTypes: [.epub, .pdf],
            allowsMultipleSelection: false
        ) { result in
            handleFileImport(result)
        }
        .alert("Error", isPresented: $appState.showError) {
            Button("OK") {
                appState.clearError()
            }
        } message: {
            Text(appState.errorMessage ?? "Unknown error")
        }
        .onAppear {
            appState.loadVoicePreference()
        }
        .onDisappear {
            appState.cleanup()
        }
    }
    
    // MARK: - Sidebar View
    
    @ViewBuilder
    private var sidebarView: some View {
        if let book = appState.currentBook {
            VStack(alignment: .leading, spacing: 0) {
                Text("Contents")
                    .font(.headline)
                    .padding(.horizontal)
                    .padding(.vertical, 12)
                
                List(selection: Binding(
                    get: { appState.currentPageIndex },
                    set: { appState.goToPage($0) }
                )) {
                    ForEach(0..<book.pageCount, id: \.self) { index in
                        if book.type == .epub, index < book.spineItems.count {
                            let title = book.spineItems[index].title ?? "Chapter \(index + 1)"
                            let indent = calculateIndentLevel(for: title)
                            
                            HStack(spacing: 0) {
                                // Indentation
                                if indent > 0 {
                                    Spacer()
                                        .frame(width: CGFloat(indent) * 16)
                                }
                                
                                Text(title)
                                    .font(indent == 0 ? .body.weight(.medium) : .body)
                                    .foregroundColor(indent == 0 ? .primary : .secondary)
                                    .lineLimit(2)
                                
                                Spacer()
                            }
                            .tag(index)
                        } else {
                            Text("Page \(index + 1)")
                                .tag(index)
                        }
                    }
                }
                .listStyle(.sidebar)
            }
            .frame(minWidth: 200, idealWidth: 280)
        } else {
            VStack {
                Image(systemName: "book.closed")
                    .font(.system(size: 48))
                    .foregroundColor(.secondary)
                Text("No file open")
                    .foregroundColor(.secondary)
            }
            .frame(minWidth: 200)
        }
    }
    
    /// Calculate indentation level based on title numbering (e.g., "2.1" = level 1, "2.1.1" = level 2)
    private func calculateIndentLevel(for title: String) -> Int {
        let trimmed = title.trimmingCharacters(in: .whitespaces)
        
        // Check for numbered sections like "2.1", "2.1.1", etc.
        let pattern = #"^(\d+)(\.(\d+))*(\.(\d+))*"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: trimmed, range: NSRange(trimmed.startIndex..., in: trimmed)) else {
            return 0  // No number prefix = top level
        }
        
        let matchedString = String(trimmed[Range(match.range, in: trimmed)!])
        let dotCount = matchedString.filter { $0 == "." }.count
        
        return dotCount  // Number of dots = indent level
    }
    
    // MARK: - Main Content View
    
    @ViewBuilder
    private var mainContentView: some View {
        if appState.isLoading {
            loadingView
        } else if let book = appState.currentBook {
            HSplitView {
                // Left column: Original content
                originalContentView(book: book)
                    .frame(minWidth: 300)
                
                // Right column: Translation
                TranslationPanelView()
                    .frame(minWidth: 300)
            }
        } else {
            emptyStateView
        }
    }
    
    // MARK: - Original Content View
    
    @ViewBuilder
    private func originalContentView(book: BookModel) -> some View {
        VStack(spacing: 0) {
            // Header
            HStack {
                Text("Original")
                    .font(.headline)
                Spacer()
                Text(appState.currentPageDisplay)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color(nsColor: .windowBackgroundColor))
            
            Divider()
            
            // Content
            switch book.type {
            case .epub:
                EPUBWebView(book: book, pageIndex: appState.currentPageIndex)
            case .pdf:
                PDFViewWrapper(book: book, pageIndex: appState.currentPageIndex)
            }
        }
    }
    
    // MARK: - Loading View
    
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Loading file...")
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Empty State View
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Image(systemName: "doc.text.magnifyingglass")
                .font(.system(size: 64))
                .foregroundColor(.secondary)
            
            Text("Open an EPUB or PDF file to get started")
                .font(.title2)
                .foregroundColor(.secondary)
            
            Button(action: { appState.showFileImporter = true }) {
                Label("Open File", systemImage: "folder")
            }
            .buttonStyle(.borderedProminent)
            .controlSize(.large)
            
            Text("Supported formats: EPUB, PDF")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - File Import Handler
    
    private func handleFileImport(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            guard let url = urls.first else { return }
            
            // Start accessing security-scoped resource
            let accessing = url.startAccessingSecurityScopedResource()
            
            Task {
                await appState.openFile(url: url)
                
                if accessing {
                    url.stopAccessingSecurityScopedResource()
                }
            }
            
        case .failure(let error):
            appState.showErrorMessage(error.localizedDescription)
        }
    }
}

// MARK: - Preview

#Preview {
    ContentView()
        .environmentObject(AppState())
        .frame(width: 1000, height: 600)
}
