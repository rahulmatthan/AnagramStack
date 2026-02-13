//
//  ChainCreationWizard.swift
//  AnagramStackAdmin
//
//  Wizard interface for creating anagram chains using the suggestion engine
//

import SwiftUI

struct ChainCreationWizard: View {
    @StateObject private var suggestionEngine: LetterSuggestionEngine
    @Environment(\.dismiss) private var dismiss

    let onComplete: (AnagramChain) -> Void

    @State private var startWord: String = ""
    @State private var chainName: String = ""
    @State private var chainDescription: String = ""
    @State private var difficulty: AnagramChain.Difficulty = .medium
    @State private var currentStep = 0
    @State private var levels: [AnagramLevel] = []
    @State private var suggestions: [LetterSuggestion] = []
    @State private var isGenerating = false
    @State private var errorMessage: String?

    init(dictionary: WordDictionary = .shared, onComplete: @escaping (AnagramChain) -> Void) {
        _suggestionEngine = StateObject(wrappedValue: LetterSuggestionEngine(dictionary: dictionary))
        self.onComplete = onComplete
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 8) {
                Text("Create Anagram Chain")
                    .font(.title)
                Text("Step \(currentStep + 1) of \(levels.isEmpty ? 1 : levels.count)")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding()
            .frame(maxWidth: .infinity)
            .background(Color(.controlBackgroundColor))

            Divider()

            ScrollView {
                VStack(spacing: 24) {
                    if currentStep == 0 {
                        // Step 1: Enter starting word and chain info
                        startingWordStep
                    } else if currentStep <= levels.count {
                        // Steps 2-7: Select letters for each level
                        levelSelectionStep
                    }
                }
                .padding()
            }

            Divider()

            // Footer with navigation
            HStack {
                Button("Cancel") {
                    dismiss()
                }

                Spacer()

                if currentStep > 0 {
                    Button("Back") {
                        currentStep -= 1
                    }
                }

                if currentStep == 0 && !startWord.isEmpty {
                    Button("Start") {
                        generateFirstLevel()
                    }
                    .disabled(startWord.count != 3)
                } else if currentStep > 0 && currentStep < 6 {
                    Button("Next") {
                        moveToNextStep()
                    }
                    .disabled(suggestions.isEmpty || isGenerating)
                } else if currentStep == 6 {
                    Button("Finish") {
                        completeChain()
                    }
                }
            }
            .padding()
            .background(Color(.controlBackgroundColor))
        }
        .frame(width: 700, height: 600)
    }

    // MARK: - Steps

    private var startingWordStep: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 8) {
                Text("Enter Starting Word")
                    .font(.headline)
                Text("Choose a 3-letter word to start your anagram chain")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            TextField("3-letter word (e.g., CAT)", text: $startWord)
                .textFieldStyle(.roundedBorder)
                .font(.title3)
                .onChange(of: startWord) { newValue in
                    startWord = newValue.uppercased().filter { $0.isLetter }
                    if startWord.count > 3 {
                        startWord = String(startWord.prefix(3))
                    }
                }

            if !startWord.isEmpty && startWord.count == 3 {
                if suggestionEngine.contains(startWord) {
                    Label("\"\(startWord)\" is valid!", systemImage: "checkmark.circle.fill")
                        .foregroundColor(.green)
                } else {
                    Label("\"\(startWord)\" is not in dictionary", systemImage: "xmark.circle.fill")
                        .foregroundColor(.red)
                }
            }

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text("Chain Information")
                    .font(.headline)

                TextField("Chain Name", text: $chainName)
                    .textFieldStyle(.roundedBorder)

                TextField("Description", text: $chainDescription)
                    .textFieldStyle(.roundedBorder)

                Picker("Difficulty", selection: $difficulty) {
                    ForEach(AnagramChain.Difficulty.allCases, id: \.self) { diff in
                        Text(diff.displayName).tag(diff)
                    }
                }
                .pickerStyle(.segmented)
            }

            if let error = errorMessage {
                Text(error)
                    .foregroundColor(.red)
                    .font(.caption)
            }
        }
    }

    private var levelSelectionStep: some View {
        VStack(spacing: 16) {
            // Show current progress
            VStack(alignment: .leading, spacing: 8) {
                Text("Level \(currentStep + 1) - \(currentStep + 3) Letters")
                    .font(.headline)

                if let previousLevel = levels.last {
                    Text("Previous: \(previousLevel.intendedWord ?? "")")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            if isGenerating {
                ProgressView("Analyzing possible letters...")
                    .padding()
            } else if suggestions.isEmpty {
                Text("No viable suggestions found")
                    .foregroundColor(.secondary)
            } else {
                ScrollView {
                    VStack(spacing: 12) {
                        // Show all suggestions (up to 26 letters)
                        ForEach(suggestions) { suggestion in
                            SuggestionRow(
                                suggestion: suggestion,
                                isSelected: false,
                                onSelect: {
                                    selectSuggestion(suggestion)
                                }
                            )
                        }
                    }
                    .padding()
                }
            }
        }
    }

    // MARK: - Actions

    private func generateFirstLevel() {
        guard startWord.count == 3,
              suggestionEngine.contains(startWord) else {
            errorMessage = "Please enter a valid 3-letter word"
            return
        }

        // Create first level
        let firstLevel = AnagramLevel(
            letterCount: 3,
            letters: startWord,
            intendedWord: startWord
        )
        levels = [firstLevel]

        // Move to next step and generate suggestions
        currentStep = 1
        Task {
            await generateSuggestionsForCurrentLevel()
        }
    }

    private func generateSuggestionsForCurrentLevel() async {
        guard let previousLevel = levels.last else { return }
        guard let intendedWord = previousLevel.intendedWord else { return }

        isGenerating = true
        errorMessage = nil

        let targetCount = currentStep + 3
        suggestions = await suggestionEngine.generateSuggestions(
            from: intendedWord,
            targetLetterCount: targetCount
        )

        isGenerating = false

        if suggestions.isEmpty {
            errorMessage = "No viable path found. Try a different starting word or go back and choose a different letter."
        }
    }

    private func selectSuggestion(_ suggestion: LetterSuggestion) {
        // Pick the best intended word (prefer longer words as they tend to be more recognizable)
        let intendedWord = suggestion.validWords.sorted { $0.count > $1.count }.first

        // Create new level with the selected letter
        let newLevel = AnagramLevel(
            letterCount: currentStep + 3,
            addedLetter: String(suggestion.letter),
            intendedWord: intendedWord
        )
        levels.append(newLevel)

        // Clear suggestions for next step
        suggestions = []

        // Don't auto-advance, let user click Next
    }

    private func moveToNextStep() {
        currentStep += 1

        if currentStep < 6 {
            // Generate suggestions for next level
            Task {
                await generateSuggestionsForCurrentLevel()
            }
        }
    }

    private func completeChain() {
        let chain = AnagramChain(
            name: chainName.isEmpty ? "Chain from \(startWord)" : chainName,
            description: chainDescription.isEmpty ? "Anagram chain starting with \(startWord)" : chainDescription,
            difficulty: difficulty,
            levels: levels
        )

        onComplete(chain)
        dismiss()
    }
}

struct SuggestionRow: View {
    let suggestion: LetterSuggestion
    let isSelected: Bool
    let onSelect: () -> Void

    var body: some View {
        Button {
            onSelect()
        } label: {
            HStack(spacing: 12) {
                // Letter badge
                Text(String(suggestion.letter))
                    .font(.title2)
                    .fontWeight(.bold)
                    .foregroundColor(.white)
                    .frame(width: 50, height: 50)
                    .background(viabilityColor)
                    .cornerRadius(8)

                VStack(alignment: .leading, spacing: 4) {
                    Text(suggestion.resultingLetters)
                        .font(.headline)

                    Text("\(suggestion.validWords.count) possible words")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    // Show ALL words across multiple lines (sorted with common words first)
                    Text(suggestion.validWords.joined(separator: ", "))
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .lineLimit(15)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text(String(format: "%.0f%%", suggestion.viabilityScore * 100))
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(viabilityColor)

                    Text("viable")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(isSelected ? Color.accentColor.opacity(0.1) : Color(.controlBackgroundColor))
            .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }

    private var viabilityColor: Color {
        if suggestion.viabilityScore >= 0.7 {
            return .green
        } else if suggestion.viabilityScore >= 0.4 {
            return .orange
        } else {
            return .red
        }
    }
}
