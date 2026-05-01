//
//  SpeechService.swift
//  TranslateReader
//
//  Service for text-to-speech using AVSpeechSynthesizer
//

import Foundation
import AVFoundation

// MARK: - Voice Option Model

/// Represents a voice option for the user to select
struct VoiceOption: Identifiable, Hashable {
    let id: String  // voice identifier
    let name: String
    let displayName: String
    let language: String
    let gender: VoiceGender
    let quality: VoiceQuality
    let isEloquence: Bool  // May cause distorted audio on some systems
    
    enum VoiceGender: String, CaseIterable {
        case female = "Feminina"
        case male = "Masculina"
        case neutral = "Neutra"
    }
    
    enum VoiceQuality: String, CaseIterable {
        case premium = "Premium"
        case enhanced = "Enhanced"
        case standard = "Standard"
        
        var icon: String {
            switch self {
            case .premium: return "⭐️"
            case .enhanced: return "✨"
            case .standard: return ""
            }
        }
    }
    
    var qualityIcon: String {
        quality.icon
    }
}

// MARK: - Speech Service

class SpeechService: NSObject {
    
    // MARK: - Properties
    
    private let synthesizer = AVSpeechSynthesizer()
    private var currentUtterance: AVSpeechUtterance?
    
    /// Selected voice identifier (nil = auto-select best)
    var selectedVoiceIdentifier: String?
    
    /// Callback when speech finishes
    var onSpeechFinished: (() -> Void)?
    
    /// Callback when speech is paused
    var onSpeechPaused: (() -> Void)?
    
    /// Callback when speech is resumed
    var onSpeechResumed: (() -> Void)?
    
    // MARK: - Initialization
    
    override init() {
        super.init()
        synthesizer.delegate = self
    }
    
    // MARK: - Speech Control
    
    /// Speaks the given text with selected or best voice
    func speak(text: String, language: String, rate: Float) {
        // Stop any current speech
        stop()
        
        guard !text.isEmpty else { return }
        
        // Create utterance
        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = rate
        utterance.pitchMultiplier = 1.0
        utterance.volume = 1.0
        
        // Set voice - use selected voice or auto-select best
        if let voiceId = selectedVoiceIdentifier,
           let voice = AVSpeechSynthesisVoice(identifier: voiceId) {
            utterance.voice = voice
        } else if let voice = SpeechService.bestVoice(for: language) {
            utterance.voice = voice
        } else if let voice = AVSpeechSynthesisVoice(language: language) {
            utterance.voice = voice
        } else {
            utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        }
        
        currentUtterance = utterance
        synthesizer.speak(utterance)
    }
    
    /// Pauses speech
    func pause() {
        if synthesizer.isSpeaking {
            synthesizer.pauseSpeaking(at: .word)
        }
    }
    
    /// Resumes paused speech
    func resume() {
        if synthesizer.isPaused {
            synthesizer.continueSpeaking()
        }
    }
    
    /// Stops speech
    func stop() {
        if synthesizer.isSpeaking || synthesizer.isPaused {
            synthesizer.stopSpeaking(at: .immediate)
        }
        currentUtterance = nil
    }
    
    // MARK: - State
    
    /// Returns true if currently speaking
    var isSpeaking: Bool {
        synthesizer.isSpeaking && !synthesizer.isPaused
    }
    
    /// Returns true if paused
    var isPaused: Bool {
        synthesizer.isPaused
    }
    
    /// Returns true if idle
    var isIdle: Bool {
        !synthesizer.isSpeaking && !synthesizer.isPaused
    }
    
    // MARK: - Available Voices
    
    /// Returns available voices for a language
    /// - Parameter includeEloquence: When true, includes Eloquence voices (Flo, Eddy, Reed, etc.) which may have distorted audio
    static func availableVoices(for language: String, includeEloquence: Bool = false) -> [AVSpeechSynthesisVoice] {
        var voices = AVSpeechSynthesisVoice.speechVoices()
            .filter { $0.language.hasPrefix(language.prefix(2).lowercased()) }
        if !includeEloquence {
            voices = voices.filter { !$0.identifier.lowercased().contains("eloquence") }
        }
        return voices
    }
    
    /// High-quality Siri-style voice names (neural voices)
    private static let preferredVoiceNames = ["Flo", "Eddy", "Reed", "Rocko", "Sandy", "Shelley", "Grandma", "Grandpa"]
    
    /// Female voice names
    private static let femaleVoiceNames = ["Flo", "Sandy", "Shelley", "Grandma", "Luciana", "Samantha", "Victoria", "Kate", "Moira", "Tessa", "Karen", "Alice"]
    
    /// Male voice names  
    private static let maleVoiceNames = ["Eddy", "Reed", "Rocko", "Grandpa", "Daniel", "Fred", "Alex", "Tom", "Oliver", "Ralph"]
    
    /// Returns the best voice for a language (prefers Siri-style neural voices)
    static func bestVoice(for language: String, includeEloquence: Bool = false) -> AVSpeechSynthesisVoice? {
        let voices = availableVoices(for: language, includeEloquence: includeEloquence)
        
        // First priority: Siri-style neural voices (Flo, Eddy, Reed, etc.)
        for preferredName in preferredVoiceNames {
            if let siriVoice = voices.first(where: { $0.name.contains(preferredName) }) {
                return siriVoice
            }
        }
        
        // Second priority: Premium voices (macOS 13+/iOS 16+)
        if #available(macOS 13.0, iOS 16.0, *) {
            if let premiumVoice = voices.first(where: { $0.quality == .premium }) {
                return premiumVoice
            }
        }
        
        // Third priority: Enhanced voices
        if let enhancedVoice = voices.first(where: { $0.quality == .enhanced }) {
            return enhancedVoice
        }
        
        // Last resort: any available voice
        return voices.first
    }
    
    /// Returns VoiceOption list for a language (for UI selection)
    static func voiceOptions(for language: String, includeEloquence: Bool = false) -> [VoiceOption] {
        let voices = availableVoices(for: language, includeEloquence: includeEloquence)
        
        return voices.compactMap { voice -> VoiceOption? in
            let baseName = voice.name.components(separatedBy: " (").first ?? voice.name
            let isEloquence = voice.identifier.lowercased().contains("eloquence")
            
            // Determine gender
            let gender: VoiceOption.VoiceGender
            if femaleVoiceNames.contains(where: { baseName.contains($0) }) {
                gender = .female
            } else if maleVoiceNames.contains(where: { baseName.contains($0) }) {
                gender = .male
            } else {
                gender = .neutral
            }
            
            // Determine quality: Premium (neural), Enhanced, Standard (Eloquence voices often = Premium/Enhanced)
            let quality: VoiceOption.VoiceQuality
            if preferredVoiceNames.contains(where: { baseName.contains($0) }) {
                quality = .premium
            } else if voice.quality == .enhanced || voice.identifier.lowercased().contains("enhanced") {
                quality = .enhanced
            } else {
                quality = .standard
            }
            
            // Create display name
            let genderEmoji = gender == .female ? "👩" : (gender == .male ? "👨" : "🧑")
            let eloquenceTag = isEloquence ? " [Eloquence]" : ""
            let displayName = "\(genderEmoji) \(baseName)\(eloquenceTag) \(quality.icon)".trimmingCharacters(in: .whitespaces)
            
            return VoiceOption(
                id: voice.identifier,
                name: baseName,
                displayName: displayName,
                language: voice.language,
                gender: gender,
                quality: quality,
                isEloquence: isEloquence
            )
        }
        .sorted { v1, v2 in
            // Sort by quality (premium first), then by name
            if v1.quality != v2.quality {
                return v1.quality == .premium || (v1.quality == .enhanced && v2.quality == .standard)
            }
            return v1.name < v2.name
        }
    }
    
    /// Returns voice options filtered by gender
    static func voiceOptions(for language: String, gender: VoiceOption.VoiceGender, includeEloquence: Bool = false) -> [VoiceOption] {
        voiceOptions(for: language, includeEloquence: includeEloquence).filter { $0.gender == gender }
    }
    
    /// Returns only premium/enhanced voice options
    static func premiumVoiceOptions(for language: String, includeEloquence: Bool = false) -> [VoiceOption] {
        voiceOptions(for: language, includeEloquence: includeEloquence).filter { $0.quality == .premium || $0.quality == .enhanced }
    }
    
    /// Check if high-quality voices are available
    static func hasHighQualityVoice(for language: String) -> Bool {
        let voices = availableVoices(for: language)
        
        // Check for Siri-style neural voices
        let hasSiriVoice = voices.contains { voice in
            preferredVoiceNames.contains { voice.name.contains($0) }
        }
        if hasSiriVoice { return true }
        
        if #available(macOS 13.0, iOS 16.0, *) {
            if voices.contains(where: { $0.quality == .premium }) {
                return true
            }
        }
        
        return voices.contains(where: { $0.quality == .enhanced })
    }
    
    /// Preview a voice with sample text
    func previewVoice(_ voiceOption: VoiceOption, sampleText: String = "Olá! Esta é uma prévia da voz.") {
        stop()
        
        let utterance = AVSpeechUtterance(string: sampleText)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate
        utterance.pitchMultiplier = 1.0
        utterance.volume = 1.0
        
        if let voice = AVSpeechSynthesisVoice(identifier: voiceOption.id) {
            utterance.voice = voice
        }
        
        synthesizer.speak(utterance)
    }
}

// MARK: - AVSpeechSynthesizerDelegate
extension SpeechService: AVSpeechSynthesizerDelegate {
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        currentUtterance = nil
        DispatchQueue.main.async { [weak self] in
            self?.onSpeechFinished?()
        }
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didPause utterance: AVSpeechUtterance) {
        DispatchQueue.main.async { [weak self] in
            self?.onSpeechPaused?()
        }
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didContinue utterance: AVSpeechUtterance) {
        DispatchQueue.main.async { [weak self] in
            self?.onSpeechResumed?()
        }
    }
    
    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didCancel utterance: AVSpeechUtterance) {
        currentUtterance = nil
        DispatchQueue.main.async { [weak self] in
            self?.onSpeechFinished?()
        }
    }
}
