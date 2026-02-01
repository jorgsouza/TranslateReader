//
//  SpeechService.swift
//  TranslateReader
//
//  Service for text-to-speech using AVSpeechSynthesizer
//

import Foundation
import AVFoundation

class SpeechService: NSObject {
    
    // MARK: - Properties
    
    private let synthesizer = AVSpeechSynthesizer()
    private var currentUtterance: AVSpeechUtterance?
    
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
    
    /// Speaks the given text
    func speak(text: String, language: String, rate: Float) {
        // Stop any current speech
        stop()
        
        guard !text.isEmpty else { return }
        
        // Create utterance
        let utterance = AVSpeechUtterance(string: text)
        utterance.rate = rate
        utterance.pitchMultiplier = 1.0
        utterance.volume = 1.0
        
        // Set voice for language
        if let voice = AVSpeechSynthesisVoice(language: language) {
            utterance.voice = voice
        } else {
            // Fallback to default voice
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
    static func availableVoices(for language: String) -> [AVSpeechSynthesisVoice] {
        AVSpeechSynthesisVoice.speechVoices().filter { $0.language.hasPrefix(language.prefix(2).lowercased()) }
    }
    
    /// Returns the best voice for a language
    static func bestVoice(for language: String) -> AVSpeechSynthesisVoice? {
        // Prefer enhanced voices
        let voices = availableVoices(for: language)
        return voices.first { $0.quality == .enhanced } ?? voices.first
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
