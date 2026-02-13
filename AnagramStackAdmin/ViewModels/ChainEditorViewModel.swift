//
//  ChainEditorViewModel.swift
//  AnagramStackAdmin
//
//  ViewModel for editing anagram chains
//

import Foundation
import SwiftUI
import Combine

@MainActor
class ChainEditorViewModel: ObservableObject {
    // MARK: - Published Properties

    @Published var chains: [AnagramChain] = []
    @Published var selectedChain: AnagramChain?
    @Published var isCreatingNew = false
    @Published var errorMessage: String?
    @Published var showingError = false

    // MARK: - Dependencies

    private let dictionary: WordDictionary

    // MARK: - Initialization

    init(dictionary: WordDictionary = .shared) {
        self.dictionary = dictionary
        loadChains()
    }

    // MARK: - Chain Management

    /// Create a new empty chain
    func createNewChain() {
        let newChain = AnagramChain(
            name: "New Chain",
            description: "Enter description",
            difficulty: .medium,
            levels: []
        )
        chains.append(newChain)
        selectedChain = newChain
        isCreatingNew = true
    }

    /// Update the selected chain
    func updateChain(_ chain: AnagramChain) {
        if let index = chains.firstIndex(where: { $0.id == chain.id }) {
            chains[index] = chain
            selectedChain = chain
        }
    }

    /// Delete a chain
    func deleteChain(_ chain: AnagramChain) {
        chains.removeAll { $0.id == chain.id }
        if selectedChain?.id == chain.id {
            selectedChain = nil
        }

        // Delete from disk
        if let url = chainFileURL(for: chain) {
            try? FileManager.default.removeItem(at: url)
        }
    }

    /// Duplicate a chain
    func duplicateChain(_ chain: AnagramChain) {
        var duplicate = chain
        duplicate = AnagramChain(
            name: chain.name + " (Copy)",
            description: chain.description,
            difficulty: chain.difficulty,
            levels: chain.levels,
            version: chain.version
        )
        chains.append(duplicate)
        selectedChain = duplicate
    }

    // MARK: - Level Management

    /// Add a new level to the selected chain
    func addLevel(letterCount: Int, letters: String? = nil, addedLetter: String? = nil, intendedWord: String?) {
        guard var chain = selectedChain else { return }

        let newLevel = AnagramLevel(
            letterCount: letterCount,
            letters: letters,
            addedLetter: addedLetter,
            intendedWord: intendedWord
        )

        chain.levels.append(newLevel)
        chain.modifiedDate = Date()
        updateChain(chain)
    }

    /// Update a level in the selected chain
    func updateLevel(at index: Int, level: AnagramLevel) {
        guard var chain = selectedChain, index < chain.levels.count else { return }

        chain.levels[index] = level
        chain.modifiedDate = Date()
        updateChain(chain)
    }

    /// Remove a level from the selected chain
    func removeLevel(at index: Int) {
        guard var chain = selectedChain, index < chain.levels.count else { return }

        chain.levels.remove(at: index)
        chain.modifiedDate = Date()
        updateChain(chain)
    }

    /// Reorder levels
    func moveLevels(from source: IndexSet, to destination: Int) {
        guard var chain = selectedChain else { return }

        chain.levels.move(fromOffsets: source, toOffset: destination)
        chain.modifiedDate = Date()
        updateChain(chain)
    }

    // MARK: - Validation

    /// Validate the selected chain
    func validateChain() -> [String] {
        guard let chain = selectedChain else {
            return ["No chain selected"]
        }
        return chain.validationErrors()
    }

    /// Check if chain is complete
    var isChainComplete: Bool {
        selectedChain?.isComplete() ?? false
    }

    // MARK: - File Management

    /// Get the chains directory URL
    private var chainsDirectory: URL {
        let documentsPath = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).first!
        let chainsPath = documentsPath.appendingPathComponent("chains")

        // Create directory if it doesn't exist
        if !FileManager.default.fileExists(atPath: chainsPath.path) {
            try? FileManager.default.createDirectory(at: chainsPath, withIntermediateDirectories: true)
        }

        return chainsPath
    }

    /// Get file URL for a specific chain
    private func chainFileURL(for chain: AnagramChain) -> URL? {
        let filename = "chain-\(chain.id.uuidString).json"
        return chainsDirectory.appendingPathComponent(filename)
    }

    /// Load all chains from disk
    func loadChains() {
        chains.removeAll()

        guard let urls = try? FileManager.default.contentsOfDirectory(
            at: chainsDirectory,
            includingPropertiesForKeys: nil,
            options: [.skipsHiddenFiles]
        ) else { return }

        for url in urls where url.pathExtension == "json" {
            do {
                let chain = try AnagramChain.load(from: url)
                chains.append(chain)
            } catch {
                print("Failed to load chain from \(url): \(error)")
            }
        }

        // Sort by modified date
        chains.sort { $0.modifiedDate > $1.modifiedDate }
    }

    /// Save the selected chain to disk
    func saveChain() {
        guard let chain = selectedChain,
              let url = chainFileURL(for: chain) else {
            showError("Cannot save: No chain selected")
            return
        }

        do {
            try chain.save(to: url)
        } catch {
            showError("Failed to save chain: \(error.localizedDescription)")
        }
    }

    /// Export chain to a specific location
    func exportChain(to url: URL) {
        print("🔍 ChainEditorViewModel.exportChain() called")
        print("   URL: \(url.path)")

        guard let chain = selectedChain else {
            print("❌ No chain selected")
            showError("No chain selected")
            return
        }

        print("📋 Chain to export: \(chain.name), levels: \(chain.levels.count)")

        do {
            print("💾 Attempting to save...")
            try chain.save(to: url)
            print("✅ Save successful!")
        } catch {
            print("❌ Save failed: \(error)")
            showError("Failed to export chain: \(error.localizedDescription)")
        }
    }

    /// Import chain from a file
    func importChain(from url: URL) {
        do {
            let chain = try AnagramChain.load(from: url)
            chains.append(chain)
            selectedChain = chain
        } catch {
            showError("Failed to import chain: \(error.localizedDescription)")
        }
    }

    // MARK: - Dictionary Helpers

    /// Validate a word exists in dictionary
    func validateWord(_ word: String) -> Bool {
        return dictionary.contains(word)
    }

    /// Find all valid words from letters
    func findValidWords(from letters: String) -> [String] {
        return dictionary.findAnagrams(from: letters)
    }

    // MARK: - Error Handling

    private func showError(_ message: String) {
        errorMessage = message
        showingError = true
    }
}
