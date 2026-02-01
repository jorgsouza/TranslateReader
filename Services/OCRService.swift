//
//  OCRService.swift
//  TranslateReader
//
//  Service for OCR using Vision framework
//

import Foundation
import Vision
import AppKit

class OCRService {
    
    // MARK: - Recognize Text
    
    /// Performs OCR on an NSImage and returns recognized text
    func recognizeText(from image: NSImage) async throws -> String {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            throw TranslateReaderError.ocrFailed
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(returning: "")
                    return
                }
                
                // Extract text from observations
                let recognizedText = observations.compactMap { observation in
                    observation.topCandidates(1).first?.string
                }.joined(separator: "\n")
                
                continuation.resume(returning: recognizedText)
            }
            
            // Configure request for accurate recognition
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            
            // Set recognition languages
            request.recognitionLanguages = ["en-US", "pt-BR", "es-ES", "fr-FR", "de-DE"]
            
            // Create and perform request
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: TranslateReaderError.ocrFailed)
            }
        }
    }
    
    /// Performs OCR with progress callback
    func recognizeTextWithProgress(
        from image: NSImage,
        progressHandler: @escaping (Double) -> Void
    ) async throws -> String {
        guard let cgImage = image.cgImage(forProposedRect: nil, context: nil, hints: nil) else {
            throw TranslateReaderError.ocrFailed
        }
        
        return try await withCheckedThrowingContinuation { continuation in
            let request = VNRecognizeTextRequest { request, error in
                if let error = error {
                    continuation.resume(throwing: error)
                    return
                }
                
                guard let observations = request.results as? [VNRecognizedTextObservation] else {
                    continuation.resume(returning: "")
                    return
                }
                
                let recognizedText = observations.compactMap { observation in
                    observation.topCandidates(1).first?.string
                }.joined(separator: "\n")
                
                continuation.resume(returning: recognizedText)
            }
            
            request.recognitionLevel = .accurate
            request.usesLanguageCorrection = true
            request.recognitionLanguages = ["en-US", "pt-BR", "es-ES", "fr-FR", "de-DE"]
            
            // Progress handler
            request.progressHandler = { _, progress, _ in
                Task { @MainActor in
                    progressHandler(progress)
                }
            }
            
            let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
            
            do {
                try handler.perform([request])
            } catch {
                continuation.resume(throwing: TranslateReaderError.ocrFailed)
            }
        }
    }
    
    // MARK: - Batch OCR
    
    /// Performs OCR on multiple images
    func recognizeTextBatch(from images: [NSImage]) async throws -> [String] {
        var results: [String] = []
        
        for image in images {
            let text = try await recognizeText(from: image)
            results.append(text)
        }
        
        return results
    }
}
