//
//  LibraryView.swift
//  TranslateReader
//
//  View for browsing external book libraries (Kindle, Apple Books)
//

import SwiftUI

struct LibraryView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    
    @State private var books: [LibraryBook] = []
    @State private var isScanning = false
    @State private var selectedSource: LibrarySource? = nil
    @State private var searchText = ""
    @State private var showAddFolder = false
    @State private var customFolders: [URL] = []
    
    private let libraryService = LibraryService.shared
    
    var filteredBooks: [LibraryBook] {
        var result = books
        
        // Filter by source
        if let source = selectedSource {
            result = result.filter { $0.source == source }
        }
        
        // Filter by search
        if !searchText.isEmpty {
            result = result.filter { $0.title.localizedCaseInsensitiveContains(searchText) }
        }
        
        return result
    }
    
    var openableBooks: [LibraryBook] {
        filteredBooks.filter { $0.canOpen }
    }
    
    var protectedBooks: [LibraryBook] {
        filteredBooks.filter { !$0.canOpen }
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            headerView
            
            Divider()
            
            // Content
            if isScanning {
                scanningView
            } else if books.isEmpty {
                emptyView
            } else {
                bookListView
            }
        }
        .frame(minWidth: 500, minHeight: 400)
        .onAppear {
            scanLibraries()
            customFolders = libraryService.getCustomFolders()
        }
        .fileImporter(
            isPresented: $showAddFolder,
            allowedContentTypes: [.folder],
            allowsMultipleSelection: false
        ) { result in
            handleFolderSelection(result)
        }
    }
    
    // MARK: - Header
    
    private var headerView: some View {
        VStack(spacing: 12) {
            HStack {
                Text("📚 Biblioteca")
                    .font(.title2.bold())
                
                Spacer()
                
                Button(action: { showAddFolder = true }) {
                    Label("Adicionar Pasta", systemImage: "folder.badge.plus")
                }
                
                Button(action: scanLibraries) {
                    Label("Atualizar", systemImage: "arrow.clockwise")
                }
                .disabled(isScanning)
            }
            
            HStack {
                // Source filter
                Picker("Fonte", selection: $selectedSource) {
                    Text("Todas").tag(nil as LibrarySource?)
                    ForEach(LibrarySource.allCases, id: \.self) { source in
                        Label(source.rawValue, systemImage: source.icon)
                            .tag(source as LibrarySource?)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 400)
                
                Spacer()
                
                // Search
                TextField("Buscar...", text: $searchText)
                    .textFieldStyle(.roundedBorder)
                    .frame(width: 200)
            }
            
            // Stats
            HStack {
                Label("\(openableBooks.count) disponíveis", systemImage: "checkmark.circle.fill")
                    .foregroundColor(.green)
                
                if !protectedBooks.isEmpty {
                    Label("\(protectedBooks.count) protegidos (DRM)", systemImage: "lock.fill")
                        .foregroundColor(.orange)
                }
                
                Spacer()
            }
            .font(.caption)
        }
        .padding()
    }
    
    // MARK: - Book List
    
    private var bookListView: some View {
        List {
            if !openableBooks.isEmpty {
                Section("Livros Disponíveis") {
                    ForEach(openableBooks) { book in
                        BookRow(book: book) {
                            openBook(book)
                        }
                    }
                }
            }
            
            if !protectedBooks.isEmpty {
                Section("Protegidos com DRM (não podem ser abertos)") {
                    ForEach(protectedBooks) { book in
                        BookRow(book: book, isDisabled: true) {}
                    }
                }
            }
            
            if !customFolders.isEmpty {
                Section("Pastas Personalizadas") {
                    ForEach(customFolders, id: \.self) { folder in
                        HStack {
                            Image(systemName: "folder.fill")
                                .foregroundColor(.blue)
                            Text(folder.lastPathComponent)
                            Spacer()
                            Button(action: { removeFolder(folder) }) {
                                Image(systemName: "xmark.circle.fill")
                                    .foregroundColor(.secondary)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
        }
    }
    
    // MARK: - Empty View
    
    private var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "books.vertical")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            
            Text("Nenhuma biblioteca encontrada")
                .font(.headline)
            
            VStack(alignment: .leading, spacing: 8) {
                Text("Para usar esta funcionalidade:")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                
                HStack {
                    Image(systemName: "1.circle.fill")
                    Text("Instale o Kindle para Mac")
                }
                
                HStack {
                    Image(systemName: "2.circle.fill")
                    Text("Ou adicione uma pasta com seus EPUBs/PDFs")
                }
            }
            .padding()
            .background(Color.secondary.opacity(0.1))
            .cornerRadius(8)
            
            Button(action: { showAddFolder = true }) {
                Label("Adicionar Pasta", systemImage: "folder.badge.plus")
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Scanning View
    
    private var scanningView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.5)
            Text("Buscando livros...")
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Actions
    
    private func scanLibraries() {
        isScanning = true
        
        DispatchQueue.global(qos: .userInitiated).async {
            let scannedBooks = libraryService.scanAllLibraries() + libraryService.scanCustomFolders()
            
            DispatchQueue.main.async {
                books = scannedBooks
                isScanning = false
            }
        }
    }
    
    private func openBook(_ book: LibraryBook) {
        dismiss()
        
        Task {
            await appState.openFile(url: book.url)
        }
    }
    
    private func handleFolderSelection(_ result: Result<[URL], Error>) {
        switch result {
        case .success(let urls):
            if let url = urls.first {
                _ = url.startAccessingSecurityScopedResource()
                libraryService.addCustomFolder(url)
                customFolders = libraryService.getCustomFolders()
                scanLibraries()
            }
        case .failure(let error):
            print("Error selecting folder: \(error)")
        }
    }
    
    private func removeFolder(_ folder: URL) {
        libraryService.removeCustomFolder(folder)
        customFolders = libraryService.getCustomFolders()
        scanLibraries()
    }
}

// MARK: - Book Row

struct BookRow: View {
    let book: LibraryBook
    var isDisabled: Bool = false
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                // Icon based on file type
                Image(systemName: iconName)
                    .font(.title2)
                    .foregroundColor(iconColor)
                    .frame(width: 32)
                
                VStack(alignment: .leading, spacing: 2) {
                    Text(book.title)
                        .font(.body)
                        .lineLimit(1)
                    
                    HStack(spacing: 8) {
                        Text(book.fileType.uppercased())
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.secondary.opacity(0.2))
                            .cornerRadius(4)
                        
                        Label(book.source.rawValue, systemImage: book.source.icon)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        if book.isProtected {
                            Label("DRM", systemImage: "lock.fill")
                                .font(.caption)
                                .foregroundColor(.orange)
                        }
                    }
                }
                
                Spacer()
                
                if !isDisabled {
                    Image(systemName: "chevron.right")
                        .foregroundColor(.secondary)
                }
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(isDisabled)
        .opacity(isDisabled ? 0.5 : 1)
    }
    
    private var iconName: String {
        switch book.fileType {
        case "epub": return "book.fill"
        case "pdf": return "doc.fill"
        case "mobi", "azw", "azw3", "kfx": return "lock.doc.fill"
        default: return "doc.fill"
        }
    }
    
    private var iconColor: Color {
        if book.isProtected {
            return .orange
        }
        switch book.fileType {
        case "epub": return .blue
        case "pdf": return .red
        default: return .secondary
        }
    }
}

// MARK: - Preview

#Preview {
    LibraryView()
        .environmentObject(AppState())
        .frame(width: 600, height: 500)
}
