//
//  TranslateReaderApp.swift
//  TranslateReader
//
//  App entry point - macOS 14+ SwiftUI application for reading and translating EPUB/PDF files
//

import SwiftUI

@main
struct TranslateReaderApp: App {
    @StateObject private var appState = AppState()
    @State private var showLibrary = false
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(appState)
                .frame(minWidth: 1000, minHeight: 600)
                .sheet(isPresented: $showLibrary) {
                    LibraryView()
                        .environmentObject(appState)
                        .frame(minWidth: 600, minHeight: 500)
                }
        }
        .windowStyle(.titleBar)
        .commands {
            CommandGroup(replacing: .newItem) {
                Button("Open File...") {
                    appState.showFileImporter = true
                }
                .keyboardShortcut("o", modifiers: .command)
                
                Divider()
                
                Button("Library...") {
                    showLibrary = true
                }
                .keyboardShortcut("l", modifiers: .command)
            }
        }
    }
}
