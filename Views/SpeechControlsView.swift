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
    @State private var showVoiceSelection = false
    
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
            .disabled(!appState.isSpeaking && !appState.isSpeechPaused)
            .help("Stop speech")
            
            // Speed control
            Button(action: { showSpeedPopover.toggle() }) {
                Label("Speed", systemImage: "speedometer")
            }
            .popover(isPresented: $showSpeedPopover) {
                speedControlPopover
            }
            .help("Adjust speech speed")
            
            // Voice selection
            Button(action: { showVoiceSelection.toggle() }) {
                Label("Voice", systemImage: "waveform.circle")
            }
            .sheet(isPresented: $showVoiceSelection) {
                VoiceSelectionView()
                    .environmentObject(appState)
            }
            .help(voiceSelectionHelp)
        }
    }
    
    private var voiceSelectionHelp: String {
        if let voice = appState.selectedVoice {
            return "Voice: \(voice.name)"
        }
        return "Select voice"
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
    @State private var showVoiceSelection = false
    
    var body: some View {
        VStack(spacing: 16) {
            // Title
            Text("Text-to-Speech")
                .font(.headline)
            
            // Voice selector button
            Button(action: { showVoiceSelection.toggle() }) {
                HStack {
                    Image(systemName: "waveform.circle.fill")
                        .foregroundColor(.accentColor)
                    
                    if let voice = appState.selectedVoice {
                        Text(voice.displayName)
                            .font(.caption)
                    } else {
                        Text("🤖 Automático")
                            .font(.caption)
                    }
                    
                    Image(systemName: "chevron.down")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(Color.secondary.opacity(0.1))
                .cornerRadius(8)
            }
            .buttonStyle(.plain)
            .sheet(isPresented: $showVoiceSelection) {
                VoiceSelectionView()
                    .environmentObject(appState)
            }
            
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
                .disabled(!appState.isSpeaking && !appState.isSpeechPaused)
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
            } else if appState.isSpeechPaused {
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
