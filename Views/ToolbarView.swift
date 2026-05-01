//
//  ToolbarView.swift
//  TranslateReader
//
//  Toolbar with file, navigation, language, translation, and speech controls
//

import SwiftUI

struct ToolbarView: ToolbarContent {
    @EnvironmentObject var appState: AppState
    @State private var showExportMenu = false
    
    var body: some ToolbarContent {
        // MARK: - File Controls
        ToolbarItemGroup(placement: .navigation) {
            Button(action: { appState.showFileImporter = true }) {
                Label("Open", systemImage: "folder")
            }
            .help("Open EPUB or PDF file")
        }
        
        // MARK: - Navigation Controls
        ToolbarItemGroup(placement: .primaryAction) {
            Button(action: { appState.goToPreviousPage() }) {
                Label("Previous", systemImage: "chevron.left")
            }
            .disabled(!appState.canGoBack)
            .help("Previous page")
            
            Text(appState.currentPageDisplay)
                .font(.caption)
                .foregroundColor(.secondary)
                .frame(minWidth: 100)
            
            Button(action: { appState.goToNextPage() }) {
                Label("Next", systemImage: "chevron.right")
            }
            .disabled(!appState.canGoForward)
            .help("Next page")
        }
        
        // MARK: - Language Selection
        ToolbarItem(placement: .automatic) {
            Picker("Language", selection: $appState.targetLanguage) {
                ForEach(TargetLanguage.allCases) { language in
                    Text(language.displayName).tag(language)
                }
            }
            .frame(width: 150)
            .help("Target language for translation")
        }
        
        // MARK: - Translation Controls
        ToolbarItemGroup(placement: .automatic) {
            Button(action: {
                Task {
                    await appState.translateCurrentPage()
                }
            }) {
                if appState.isTranslating {
                    ProgressView()
                        .scaleEffect(0.7)
                } else {
                    Label("Translate", systemImage: "globe")
                }
            }
            .disabled(appState.isTranslating || appState.originalText.isEmpty)
            .help("Translate current page")
            
            Toggle(isOn: $appState.autoTranslate) {
                Label("Auto", systemImage: "arrow.triangle.2.circlepath")
            }
            .toggleStyle(.button)
            .help("Auto-translate when changing pages")
        }
        
        // MARK: - OCR Control (PDF only)
        ToolbarItem(placement: .automatic) {
            if appState.needsOCR {
                Button(action: {
                    Task {
                        await appState.runOCR()
                    }
                }) {
                    if appState.isOCRRunning {
                        ProgressView()
                            .scaleEffect(0.7)
                    } else {
                        Label("OCR", systemImage: "text.viewfinder")
                    }
                }
                .disabled(appState.isOCRRunning)
                .help("Run OCR to extract text from image-based PDF")
            }
        }
        
        // MARK: - Speech Controls
        ToolbarItemGroup(placement: .automatic) {
            Divider()
            
            SpeechControlsView()
        }
        
        // MARK: - Export
        ToolbarItem(placement: .automatic) {
            Menu {
                Button(action: { exportTranslation(format: .txt) }) {
                    Label("Export as TXT", systemImage: "doc.text")
                }
                
                Button(action: { exportTranslation(format: .markdown) }) {
                    Label("Export as Markdown", systemImage: "doc.richtext")
                }
                
                if appState.currentBook?.type == .epub {
                    Divider()
                    Button(action: {
                        Task { await appState.exportTranslatedBookAsEPUB() }
                    }) {
                        if appState.isExportingBookAsEPUB {
                            Label("Exporting book…", systemImage: "arrow.down.doc")
                        } else {
                            Label("Export book as EPUB", systemImage: "book.closed")
                        }
                    }
                    .disabled(appState.isExportingBookAsEPUB)
                }
            } label: {
                Label("Export", systemImage: "square.and.arrow.up")
            }
            .disabled(!appState.hasBook || (appState.currentBook?.type != .epub && appState.translatedText.isEmpty) || appState.isExportingBookAsEPUB)
            .help("Export translated text")
        }
        
        // MARK: - Settings
        ToolbarItem(placement: .automatic) {
            Menu {
                // Font size
                Menu("Font Size") {
                    Button("Small (14pt)") { appState.fontSize = 14 }
                    Button("Medium (16pt)") { appState.fontSize = 16 }
                    Button("Large (18pt)") { appState.fontSize = 18 }
                    Button("Extra Large (20pt)") { appState.fontSize = 20 }
                }
                
                Divider()
                
                // Clear cache
                Button(action: { appState.cacheService.clearAll() }) {
                    Label("Clear Cache", systemImage: "trash")
                }
            } label: {
                Label("Settings", systemImage: "gear")
            }
        }
    }
    
    // MARK: - Export Handler
    
    private func exportTranslation(format: ExportFormat) {
        guard let book = appState.currentBook else { return }
        
        let success = appState.exportService.exportWithSaveDialog(
            text: appState.translatedText,
            title: "\(book.title)_page\(appState.currentPageIndex + 1)",
            format: format
        )
        
        if !success {
            appState.showErrorMessage("Export failed or was cancelled")
        }
    }
}
