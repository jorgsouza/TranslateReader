//
//  TranslationPanelView.swift
//  TranslateReader
//
//  Panel displaying translated text with formatting options
//

import SwiftUI

struct TranslationPanelView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView
            
            Divider()
            
            // Content
            contentView
            
            // Footer with speech controls (optional alternative)
            // footerView
        }
        .background(Color(nsColor: .textBackgroundColor))
    }
    
    // MARK: - Header
    
    private var headerView: some View {
        HStack {
            Text("Translation")
                .font(.headline)
            
            Spacer()
            
            // Language badge
            Text(appState.targetLanguage.displayName)
                .font(.caption)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.accentColor.opacity(0.2))
                .cornerRadius(4)
            
            // Font size controls
            HStack(spacing: 4) {
                Button(action: decreaseFontSize) {
                    Image(systemName: "textformat.size.smaller")
                }
                .buttonStyle(.borderless)
                .disabled(appState.fontSize <= 12)
                
                Button(action: increaseFontSize) {
                    Image(systemName: "textformat.size.larger")
                }
                .buttonStyle(.borderless)
                .disabled(appState.fontSize >= 24)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(nsColor: .windowBackgroundColor))
    }
    
    // MARK: - Content
    
    @ViewBuilder
    private var contentView: some View {
        if appState.isTranslating {
            translatingView
        } else if !appState.translatedText.isEmpty {
            translatedTextView
        } else if appState.originalText.isEmpty {
            emptyStateView
        } else {
            waitingForTranslationView
        }
    }
    
    // MARK: - Translating State
    
    private var translatingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            
            Text("Translating...")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("This may take a moment for longer texts")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Translated Text
    
    private var translatedTextView: some View {
        ScrollView {
            Text(appState.translatedText)
                .font(.system(size: appState.fontSize))
                .lineSpacing(6)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding()
        }
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 12) {
            Image(systemName: "doc.text")
                .font(.system(size: 40))
                .foregroundColor(.secondary)
            
            Text("No content to translate")
                .font(.headline)
                .foregroundColor(.secondary)
            
            Text("Open a file to get started")
                .font(.caption)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Waiting for Translation
    
    private var waitingForTranslationView: some View {
        VStack(spacing: 16) {
            Image(systemName: "globe")
                .font(.system(size: 40))
                .foregroundColor(.secondary)
            
            Text("Ready to translate")
                .font(.headline)
                .foregroundColor(.secondary)
            
            if appState.autoTranslate {
                Text("Auto-translate is enabled")
                    .font(.caption)
                    .foregroundColor(.secondary)
            } else {
                Button(action: {
                    Task {
                        await appState.translateCurrentPage()
                    }
                }) {
                    Label("Translate Now", systemImage: "globe")
                }
                .buttonStyle(.borderedProminent)
            }
            
            // Show OCR hint if needed
            if appState.needsOCR {
                VStack(spacing: 8) {
                    Divider()
                        .padding(.vertical)
                    
                    Text("This PDF appears to be image-based")
                        .font(.caption)
                        .foregroundColor(.orange)
                    
                    Button(action: {
                        Task {
                            await appState.runOCR()
                        }
                    }) {
                        Label("Run OCR to extract text", systemImage: "text.viewfinder")
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Footer (Optional)
    
    private var footerView: some View {
        VStack(spacing: 0) {
            Divider()
            
            HStack {
                // Word count
                if !appState.translatedText.isEmpty {
                    let wordCount = appState.translatedText.split(separator: " ").count
                    Text("\(wordCount) words")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Speech controls inline
                if !appState.translatedText.isEmpty {
                    HStack(spacing: 8) {
                        Button(action: { appState.toggleSpeech() }) {
                            Image(systemName: appState.isSpeaking ? "pause.fill" : "play.fill")
                        }
                        .buttonStyle(.borderless)
                        
                        Button(action: { appState.stopSpeech() }) {
                            Image(systemName: "stop.fill")
                        }
                        .buttonStyle(.borderless)
                        .disabled(!appState.isSpeaking && !appState.isSpeechPaused)
                    }
                }
            }
            .padding(.horizontal)
            .padding(.vertical, 8)
            .background(Color(nsColor: .windowBackgroundColor))
        }
    }
    
    // MARK: - Font Size Actions
    
    private func increaseFontSize() {
        appState.fontSize = min(appState.fontSize + 2, 24)
    }
    
    private func decreaseFontSize() {
        appState.fontSize = max(appState.fontSize - 2, 12)
    }
}

// MARK: - Preview

#Preview {
    TranslationPanelView()
        .environmentObject(AppState())
        .frame(width: 400, height: 500)
}
