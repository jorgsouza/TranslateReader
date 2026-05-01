//
//  VoiceSelectionView.swift
//  TranslateReader
//
//  Voice selection interface for choosing TTS voices
//

import SwiftUI

struct VoiceSelectionView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) private var dismiss
    
    @State private var selectedGenderFilter: VoiceOption.VoiceGender? = nil
    @State private var selectedQualityFilter: VoiceOption.VoiceQuality? = nil
    @State private var searchText: String = ""
    
    var body: some View {
        VStack(spacing: 0) {
            // Header
            header
            
            Divider()
            
            // Filter tabs
            filterTabs
            
            Divider()
            
            // Voice list
            voiceList
            
            Divider()
            
            // Footer with actions
            footer
        }
        .frame(width: 420, height: 560)
    }
    
    // MARK: - Header
    
    private var header: some View {
        VStack(spacing: 8) {
            HStack {
                Image(systemName: "waveform.circle.fill")
                    .font(.title)
                    .foregroundColor(.accentColor)
                
                Text("Selecionar Voz")
                    .font(.title2)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button(action: { dismiss() }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundColor(.secondary)
                }
                .buttonStyle(.plain)
            }
            
            // Current selection
            if let voice = appState.selectedVoice {
                HStack {
                    Text("Atual:")
                        .foregroundColor(.secondary)
                    Text(voice.displayName)
                        .fontWeight(.medium)
                    Spacer()
                }
                .font(.caption)
            } else {
                HStack {
                    Text("Atual:")
                        .foregroundColor(.secondary)
                    Text("Automático (melhor voz)")
                        .fontWeight(.medium)
                        .foregroundColor(.accentColor)
                    Spacer()
                }
                .font(.caption)
            }
        }
        .padding()
    }
    
    // MARK: - Filter Tabs
    
    private var filterTabs: some View {
        VStack(spacing: 10) {
            // Quality filter
            HStack(spacing: 8) {
                Text("Qualidade:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                FilterButton(
                    title: "Todas",
                    icon: "list.bullet",
                    isSelected: selectedQualityFilter == nil
                ) {
                    selectedQualityFilter = nil
                }
                
                FilterButton(
                    title: "⭐️ Premium",
                    icon: "star.fill",
                    isSelected: selectedQualityFilter == .premium
                ) {
                    selectedQualityFilter = .premium
                }
                
                FilterButton(
                    title: "✨ Enhanced",
                    icon: "sparkles",
                    isSelected: selectedQualityFilter == .enhanced
                ) {
                    selectedQualityFilter = .enhanced
                }
                
                FilterButton(
                    title: "Standard",
                    icon: "waveform",
                    isSelected: selectedQualityFilter == .standard
                ) {
                    selectedQualityFilter = .standard
                }
            }
            
            // Gender filter
            HStack(spacing: 8) {
                Text("Gênero:")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                FilterButton(
                    title: "Todas",
                    icon: "person.2.fill",
                    isSelected: selectedGenderFilter == nil
                ) {
                    selectedGenderFilter = nil
                }
                
                FilterButton(
                    title: "Femininas",
                    icon: "person.fill",
                    isSelected: selectedGenderFilter == .female
                ) {
                    selectedGenderFilter = .female
                }
                
                FilterButton(
                    title: "Masculinas",
                    icon: "person.fill",
                    isSelected: selectedGenderFilter == .male
                ) {
                    selectedGenderFilter = .male
                }
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 10)
    }
    
    // MARK: - Voice List
    
    private var voiceList: some View {
        ScrollView {
            LazyVStack(spacing: 8) {
                // Auto option
                VoiceRow(
                    voice: nil,
                    isSelected: appState.selectedVoiceId == nil,
                    onSelect: {
                        appState.selectVoice(nil)
                    },
                    onPreview: nil
                )
                
                // Divider
                HStack {
                    Text("Vozes Disponíveis")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
                .padding(.horizontal)
                .padding(.top, 8)
                
                // Voice options
                ForEach(filteredVoices) { voice in
                    VoiceRow(
                        voice: voice,
                        isSelected: appState.selectedVoiceId == voice.id,
                        onSelect: {
                            appState.selectVoice(voice)
                        },
                        onPreview: {
                            appState.previewVoice(voice)
                        }
                    )
                }
            }
            .padding()
        }
    }
    
    // MARK: - Footer
    
    private var footer: some View {
        VStack(spacing: 12) {
            // Include Eloquence toggle
            Toggle(isOn: $appState.includeEloquenceVoices) {
                VStack(alignment: .leading, spacing: 2) {
                    Text("Incluir vozes Eloquence (Flo, Eddy, Reed...)")
                        .font(.caption)
                    Text("Mais vozes para testar — pode ter áudio distorcido em alguns sistemas")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            .toggleStyle(.switch)
            
            HStack {
                // Info text
                VStack(alignment: .leading) {
                    Text("⭐️ Premium = Neural (Siri)")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text("✨ Enhanced = Melhorada")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                    Text("Standard = Básica")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                Button("Concluído") {
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
            }
        }
        .padding()
    }
    
    // MARK: - Filtered Voices
    
    private var filteredVoices: [VoiceOption] {
        var voices = appState.availableVoices
        
        if let quality = selectedQualityFilter {
            voices = voices.filter { $0.quality == quality }
        }
        
        if let gender = selectedGenderFilter {
            voices = voices.filter { $0.gender == gender }
        }
        
        return voices
    }
}

// MARK: - Filter Button

struct FilterButton: View {
    let title: String
    let icon: String
    let isSelected: Bool
    let action: () -> Void
    
    var body: some View {
        Button(action: action) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption)
                Text(title)
                    .font(.caption)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(isSelected ? Color.accentColor : Color.secondary.opacity(0.2))
            .foregroundColor(isSelected ? .white : .primary)
            .cornerRadius(16)
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Voice Row

struct VoiceRow: View {
    let voice: VoiceOption?
    let isSelected: Bool
    let onSelect: () -> Void
    let onPreview: (() -> Void)?
    
    var body: some View {
        HStack {
            // Selection indicator
            Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                .foregroundColor(isSelected ? .accentColor : .secondary)
                .font(.title3)
            
            // Voice info
            VStack(alignment: .leading, spacing: 2) {
                if let voice = voice {
                    Text(voice.displayName)
                        .fontWeight(isSelected ? .semibold : .regular)
                    
                    HStack(spacing: 8) {
                        Text(voice.gender.rawValue)
                            .font(.caption2)
                            .foregroundColor(.secondary)
                        
                        Text(voice.quality.rawValue)
                            .font(.caption2)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(qualityColor(voice.quality).opacity(0.2))
                            .foregroundColor(qualityColor(voice.quality))
                            .cornerRadius(4)
                    }
                } else {
                    Text("🤖 Automático")
                        .fontWeight(isSelected ? .semibold : .regular)
                    
                    Text("Seleciona a melhor voz disponível")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
            
            // Preview button
            if let onPreview = onPreview {
                Button(action: onPreview) {
                    Image(systemName: "play.circle.fill")
                        .font(.title2)
                        .foregroundColor(.accentColor)
                }
                .buttonStyle(.plain)
                .help("Ouvir prévia")
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .background(isSelected ? Color.accentColor.opacity(0.1) : Color.clear)
        .cornerRadius(8)
        .contentShape(Rectangle())
        .onTapGesture {
            onSelect()
        }
    }
    
    private func qualityColor(_ quality: VoiceOption.VoiceQuality) -> Color {
        switch quality {
        case .premium: return .orange
        case .enhanced: return .blue
        case .standard: return .gray
        }
    }
}

// MARK: - Preview

#Preview {
    VoiceSelectionView()
        .environmentObject(AppState())
}
