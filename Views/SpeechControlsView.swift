//
//  SpeechControlsView.swift
//  TranslateReader
//
//  Speech playback controls for text-to-speech
//

import SwiftUI

struct SpeechControlsView: View {
    @EnvironmentObject var appState: AppState
    @State private var showSpeedPopover = false
    
    var body: some View {
        HStack(spacing: 4) {
            // Play/Pause button
            Button(action: { appState.toggleSpeech() }) {
                Label(
                    appState.isSpeaking ? "Pause" : "Play",
                    systemImage: appState.isSpeaking ? "pause.fill" : "play.fill"
                )
            }
            .disabled(appState.translatedText.isEmpty)
            .help(appState.isSpeaking ? "Pause speech" : "Read translation aloud")
            
            // Stop button
            Button(action: { appState.stopSpeech() }) {
                Label("Stop", systemImage: "stop.fill")
            }
            .disabled(!appState.isSpeaking && !appState.speechService.isPaused)
            .help("Stop speech")
            
            // Speed control
            Button(action: { showSpeedPopover.toggle() }) {
                Label("Speed", systemImage: "speedometer")
            }
            .popover(isPresented: $showSpeedPopover) {
                speedControlPopover
            }
            .help("Adjust speech speed")
        }
    }
    
    // MARK: - Speed Control Popover
    
    private var speedControlPopover: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Speech Speed")
                .font(.headline)
            
            HStack {
                Image(systemName: "tortoise")
                    .foregroundColor(.secondary)
                
                Slider(
                    value: $appState.speechRate,
                    in: AppConstants.minSpeechRate...AppConstants.maxSpeechRate,
                    step: 0.1
                ) { editing in
                    if !editing {
                        appState.updateSpeechRate(appState.speechRate)
                    }
                }
                .frame(width: 150)
                
                Image(systemName: "hare")
                    .foregroundColor(.secondary)
            }
            
            Text("Rate: \(String(format: "%.1f", appState.speechRate))x")
                .font(.caption)
                .foregroundColor(.secondary)
            
            // Preset buttons
            HStack(spacing: 8) {
                ForEach([0.3, 0.5, 0.75, 1.0], id: \.self) { rate in
                    Button("\(String(format: "%.1f", rate))x") {
                        appState.speechRate = Float(rate)
                        appState.updateSpeechRate(Float(rate))
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }
            }
        }
        .padding()
        .frame(width: 250)
    }
}

// MARK: - Standalone Speech Panel (alternative layout)

struct SpeechPanelView: View {
    @EnvironmentObject var appState: AppState
    
    var body: some View {
        VStack(spacing: 16) {
            // Title
            Text("Text-to-Speech")
                .font(.headline)
            
            // Controls
            HStack(spacing: 20) {
                // Play/Pause
                Button(action: { appState.toggleSpeech() }) {
                    Image(systemName: appState.isSpeaking ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 40))
                }
                .buttonStyle(.plain)
                .disabled(appState.translatedText.isEmpty)
                
                // Stop
                Button(action: { appState.stopSpeech() }) {
                    Image(systemName: "stop.circle.fill")
                        .font(.system(size: 40))
                }
                .buttonStyle(.plain)
                .disabled(!appState.isSpeaking && !appState.speechService.isPaused)
            }
            
            // Speed slider
            VStack(alignment: .leading, spacing: 4) {
                Text("Speed: \(String(format: "%.1f", appState.speechRate))x")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                HStack {
                    Image(systemName: "tortoise")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Slider(
                        value: $appState.speechRate,
                        in: AppConstants.minSpeechRate...AppConstants.maxSpeechRate,
                        step: 0.1
                    ) { editing in
                        if !editing {
                            appState.updateSpeechRate(appState.speechRate)
                        }
                    }
                    
                    Image(systemName: "hare")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            
            // Status
            if appState.isSpeaking {
                HStack {
                    ProgressView()
                        .scaleEffect(0.7)
                    Text("Speaking...")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            } else if appState.speechService.isPaused {
                Text("Paused")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(nsColor: .windowBackgroundColor))
        .cornerRadius(8)
    }
}

// MARK: - Preview

#Preview {
    HStack {
        SpeechControlsView()
            .environmentObject(AppState())
    }
    .padding()
}
