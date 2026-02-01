# TranslateReader

A macOS application for reading and translating EPUB and PDF files with text-to-speech support.

## Requirements

- **macOS 14.0 (Sonoma)** or later
- Xcode 15.0 or later

## Features

- **EPUB Support**: Open and read EPUB files with chapter navigation
- **PDF Support**: View PDFs with page navigation
- **OCR**: Extract text from image-based PDFs using Vision framework
- **Translation**: Translate content to Portuguese (BR), English, Spanish, French, or German
- **Text-to-Speech**: Listen to translated text with adjustable speed
- **Caching**: Translations are cached for faster access
- **Export**: Export translations to TXT or Markdown files

## How to Build and Run

### Option 1: Create New Xcode Project

1. Open Xcode 15+
2. Create a new project: **File → New → Project**
3. Select **macOS → App**
4. Configure:
   - Product Name: `TranslateReader`
   - Interface: **SwiftUI**
   - Language: **Swift**
   - Deployment Target: **macOS 14.0**

5. Copy all Swift files into the project maintaining the folder structure:
   ```
   TranslateReader/
   ├── TranslateReaderApp.swift
   ├── Models/
   ├── Views/
   ├── Services/
   └── Utils/
   ```

6. Replace `Info.plist` with the provided one (or merge the content types)

7. Configure entitlements:
   - Select project → Signing & Capabilities
   - Add **App Sandbox**
   - Enable: "User Selected File" → Read Access
   - Enable: "Network" → Outgoing Connections (for translation)
   - Enable: "Downloads Folder" → Read/Write

8. Build and Run (⌘R)

### Option 2: Use Package Structure

The files are organized for easy import. Simply drag the folders into your Xcode project.

## Project Structure

```
TranslateReader/
├── TranslateReaderApp.swift          # App entry point
├── Info.plist                        # App configuration
├── TranslateReader.entitlements      # Sandbox permissions
│
├── Models/
│   ├── BookModel.swift               # Book data model
│   ├── EPUBManifest.swift            # EPUB OPF parser
│   ├── TranslationCache.swift        # Cache model
│   └── AppState.swift                # Global app state
│
├── Views/
│   ├── ContentView.swift             # Main two-column layout
│   ├── ToolbarView.swift             # Toolbar controls
│   ├── EPUBWebView.swift             # WKWebView for EPUB
│   ├── PDFViewWrapper.swift          # PDFView wrapper
│   ├── TranslationPanelView.swift    # Translation display
│   └── SpeechControlsView.swift      # TTS controls
│
├── Services/
│   ├── EPUBService.swift             # EPUB extraction/parsing
│   ├── PDFService.swift              # PDF handling
│   ├── OCRService.swift              # Vision OCR
│   ├── TranslationService.swift      # Apple Translation API
│   ├── CacheService.swift            # Translation cache
│   ├── SpeechService.swift           # AVSpeechSynthesizer
│   └── ExportService.swift           # Export to TXT/MD
│
└── Utils/
    ├── Constants.swift               # App constants
    ├── FileHelper.swift              # File utilities
    └── TextChunker.swift             # Text splitting
```

## Permissions Required

The app requires the following entitlements:

| Permission | Purpose |
|------------|---------|
| `app-sandbox` | Required for Mac App Store |
| `files.user-selected.read-only` | Open files via fileImporter |
| `files.downloads.read-write` | Export translations |
| `network.client` | Download translation language packs |

## Usage

1. **Open File**: Click "Open" or use ⌘O to select an EPUB or PDF file
2. **Navigate**: Use arrow buttons or sidebar to navigate pages/chapters
3. **Translate**: Select target language and click "Translate" (or enable auto-translate)
4. **Listen**: Use play/pause controls to hear the translation read aloud
5. **Export**: Save translations as TXT or Markdown files

## Known Limitations

- **Translation**: Requires macOS 14.0+ (shows fallback message on older versions)
- **EPUB**: Complex EPUB features (DRM, fixed-layout) not supported
- **OCR**: Performance depends on image quality
- **DOCX Export**: Not implemented (requires complex ZIP+XML handling)

## Frameworks Used

| Framework | Usage |
|-----------|-------|
| SwiftUI | User interface |
| WebKit | EPUB HTML rendering |
| PDFKit | PDF display and text extraction |
| Vision | OCR text recognition |
| Translation | Apple's translation service |
| AVFoundation | Text-to-speech |

## Troubleshooting

### Translation Not Available
- Ensure macOS 14.0 or later is installed
- Check internet connection (language packs may need downloading)
- Go to System Settings → General → Language & Region → Translation Languages

### EPUB Not Loading
- Verify the EPUB is not DRM-protected
- Check that the file is a valid EPUB (ZIP with proper structure)

### OCR Not Working
- Ensure the PDF page contains images (not blank)
- Try adjusting the DPI in PDFService if quality is poor

## License

MIT License - Feel free to use and modify.
