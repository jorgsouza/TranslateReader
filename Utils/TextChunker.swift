//
//  TextChunker.swift
//  TranslateReader
//
//  Utility to split text into chunks for translation
//

import Foundation

struct TextChunker {
    
    /// Splits text into chunks of approximately maxSize characters, respecting paragraph boundaries
    /// - Parameters:
    ///   - text: The text to split
    ///   - maxSize: Maximum size of each chunk (default: 1800 characters)
    /// - Returns: Array of text chunks
    static func chunkText(_ text: String, maxSize: Int = AppConstants.maxChunkSize) -> [String] {
        guard !text.isEmpty else { return [] }
        guard text.count > maxSize else { return [text] }
        
        var chunks: [String] = []
        
        // Split by paragraphs first (double newline)
        let paragraphs = text.components(separatedBy: "\n\n")
        var currentChunk = ""
        
        for paragraph in paragraphs {
            let trimmedParagraph = paragraph.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !trimmedParagraph.isEmpty else { continue }
            
            // If adding this paragraph would exceed maxSize
            if currentChunk.count + trimmedParagraph.count + 2 > maxSize {
                // Save current chunk if not empty
                if !currentChunk.isEmpty {
                    chunks.append(currentChunk.trimmingCharacters(in: .whitespacesAndNewlines))
                    currentChunk = ""
                }
                
                // If the paragraph itself is larger than maxSize, split it by sentences
                if trimmedParagraph.count > maxSize {
                    let sentenceChunks = splitBySentences(trimmedParagraph, maxSize: maxSize)
                    chunks.append(contentsOf: sentenceChunks)
                } else {
                    currentChunk = trimmedParagraph
                }
            } else {
                // Add paragraph to current chunk
                if currentChunk.isEmpty {
                    currentChunk = trimmedParagraph
                } else {
                    currentChunk += "\n\n" + trimmedParagraph
                }
            }
        }
        
        // Don't forget the last chunk
        if !currentChunk.isEmpty {
            chunks.append(currentChunk.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        
        return chunks
    }
    
    /// Splits a long paragraph by sentences
    private static func splitBySentences(_ text: String, maxSize: Int) -> [String] {
        var chunks: [String] = []
        var currentChunk = ""
        
        // Split by sentence-ending punctuation followed by space
        let sentencePattern = #"(?<=[.!?])\s+"#
        let sentences = text.components(separatedBy: try! NSRegularExpression(pattern: sentencePattern))
        
        // Fallback: split by periods if regex fails
        let sentenceList = sentences.count > 1 ? sentences : text.components(separatedBy: ". ")
        
        for sentence in sentenceList {
            let trimmedSentence = sentence.trimmingCharacters(in: .whitespaces)
            guard !trimmedSentence.isEmpty else { continue }
            
            if currentChunk.count + trimmedSentence.count + 1 > maxSize {
                if !currentChunk.isEmpty {
                    chunks.append(currentChunk.trimmingCharacters(in: .whitespaces))
                    currentChunk = ""
                }
                
                // If sentence is still too long, force split
                if trimmedSentence.count > maxSize {
                    let forceSplit = forceSplitText(trimmedSentence, maxSize: maxSize)
                    chunks.append(contentsOf: forceSplit)
                } else {
                    currentChunk = trimmedSentence
                }
            } else {
                if currentChunk.isEmpty {
                    currentChunk = trimmedSentence
                } else {
                    currentChunk += " " + trimmedSentence
                }
            }
        }
        
        if !currentChunk.isEmpty {
            chunks.append(currentChunk.trimmingCharacters(in: .whitespaces))
        }
        
        return chunks
    }
    
    /// Force splits text at word boundaries when paragraphs and sentences are too long
    private static func forceSplitText(_ text: String, maxSize: Int) -> [String] {
        var chunks: [String] = []
        var currentChunk = ""
        
        let words = text.components(separatedBy: .whitespaces)
        
        for word in words {
            if currentChunk.count + word.count + 1 > maxSize {
                if !currentChunk.isEmpty {
                    chunks.append(currentChunk)
                    currentChunk = ""
                }
            }
            
            if currentChunk.isEmpty {
                currentChunk = word
            } else {
                currentChunk += " " + word
            }
        }
        
        if !currentChunk.isEmpty {
            chunks.append(currentChunk)
        }
        
        return chunks
    }
    
    /// Joins translated chunks back into a single text
    static func joinChunks(_ chunks: [String]) -> String {
        chunks.joined(separator: "\n\n")
    }
}

// MARK: - String Extension for Sentence Splitting
extension String {
    func components(separatedBy regex: NSRegularExpression) -> [String] {
        let range = NSRange(startIndex..., in: self)
        var results: [String] = []
        var lastEnd = startIndex
        
        regex.enumerateMatches(in: self, range: range) { match, _, _ in
            guard let match = match else { return }
            let matchRange = Range(match.range, in: self)!
            let substring = String(self[lastEnd..<matchRange.lowerBound])
            if !substring.isEmpty {
                results.append(substring)
            }
            lastEnd = matchRange.upperBound
        }
        
        // Add remaining text
        let remaining = String(self[lastEnd...])
        if !remaining.isEmpty {
            results.append(remaining)
        }
        
        return results
    }
}
