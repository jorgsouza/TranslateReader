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
        .onDisappear {
            appState.cleanup()
        }
    }
    
    // MARK: - Sidebar View
    
    @ViewBuilder
    private var sidebarView: some View {
        if let book = appState.currentBook {
            VStack(alignment: .leading, spacing: 8) {
                Text("Contents")
                    .font(.headline)
                    .padding(.horizontal)
                    .padding(.top)
                
                List(selection: Binding(
                    get: { appState.currentPageIndex },
                    set: { appState.goToPage($0) }
                )) {
                    ForEach(0..<book.pageCount, id: \.self) { index in
                        HStack {
                            if book.type == .epub, index < book.spineItems.count {
                                Text(book.spineItems[index].title ?? "Chapter \(index + 1)")
                            } else {
                                Text("Page \(index + 1)")
                            }
                            Spacer()
                            if index == appState.currentPageIndex {
                                Image(systemName: "checkmark")
                                    .foregroundColor(.accentColor)
                            }
                        }
                        .tag(index)
                    }
                }
            }
            .frame(minWidth: 150)
        } else {
            VStack {
                Image(systemName: "book.closed")
                    .font(.system(size: 48))
                    .foregroundColor(.secondary)
                Text("No file open")
                    .foregroundColor(.secondary)
            }
            .frame(minWidth: 150)
        }
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
