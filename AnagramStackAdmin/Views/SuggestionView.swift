//
//  SuggestionView.swift
//  AnagramStackAdmin
//
//  View for displaying letter suggestions with viability scores
//

import SwiftUI

struct SuggestionView: View {
    let currentLetters: String
    let targetLetterCount: Int
    @StateObject private var engine: LetterSuggestionEngine
    @State private var hasGenerated = false

    init(currentLetters: String, targetLetterCount: Int, dictionary: WordDictionary = .shared) {
        self.currentLetters = currentLetters
        self.targetLetterCount = targetLetterCount
        _engine = StateObject(wrappedValue: LetterSuggestionEngine(dictionary: dictionary))
    }

    var body: some View {
        VStack(spacing: 16) {
            // Header
            VStack(spacing: 8) {
                Text("Letter Suggestions")
                    .font(.title2)
                    .fontWeight(.semibold)

                Text("Current: \(currentLetters) → Target: \(targetLetterCount) letters")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }

            if engine.isGenerating {
                ProgressView("Generating suggestions...")
                    .padding()
            } else if hasGenerated {
                // Suggestions list
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(engine.suggestions) { suggestion in
                            SuggestionCard(suggestion: suggestion)
                        }
                    }
                    .padding()
                }
            } else {
                // Generate button
                Button("Generate Suggestions") {
                    Task {
                        await engine.generateSuggestions(
                            from: currentLetters,
                            targetLetterCount: targetLetterCount
                        )
                        hasGenerated = true
                    }
                }
                .buttonStyle(.borderedProminent)
                .padding()
            }
        }
        .frame(minWidth: 400, minHeight: 500)
    }
}

struct SuggestionCard: View {
    let suggestion: LetterSuggestion

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with letter and score
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Text("Add Letter:")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        Text(String(suggestion.letter))
                            .font(.title)
                            .fontWeight(.bold)
                            .foregroundColor(.primary)
                    }

                    Text("→ \(suggestion.resultingLetters)")
                        .font(.headline)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 4) {
                    Text(String(format: "%.0f%%", suggestion.viabilityScore * 100))
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(scoreColor)

                    Text("Viability")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            // Score breakdown
            HStack(spacing: 16) {
                ScoreIndicator(
                    title: "Vowels",
                    value: suggestion.vowelRatio,
                    format: "%.0f%%"
                )

                ScoreIndicator(
                    title: "Letter Freq",
                    value: suggestion.letterFrequencyScore,
                    format: "%.0f%%"
                )

                Spacer()

                if suggestion.nextLevelViable {
                    Label("Next Level OK", systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundColor(.green)
                } else {
                    Label("Limited Options", systemImage: "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }

            Divider()

            // Valid words
            VStack(alignment: .leading, spacing: 4) {
                Text("Valid Words (\(suggestion.validWords.count))")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)

                let displayWords = suggestion.validWords.prefix(10)
                let remaining = suggestion.validWords.count - displayWords.count

                Text(displayWords.joined(separator: ", "))
                    .font(.caption)
                    .foregroundColor(.secondary)

                if remaining > 0 {
                    Text("+ \(remaining) more")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .italic()
                }
            }
        }
        .padding()
        .background(backgroundColor)
        .cornerRadius(12)
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(scoreColor, lineWidth: 2)
        )
    }

    private var scoreColor: Color {
        if suggestion.viabilityScore >= 0.7 {
            return .green
        } else if suggestion.viabilityScore >= 0.4 {
            return .orange
        } else {
            return .red
        }
    }

    private var backgroundColor: Color {
        scoreColor.opacity(0.1)
    }
}

struct ScoreIndicator: View {
    let title: String
    let value: Double
    let format: String

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(.caption2)
                .foregroundColor(.secondary)

            Text(String(format: format, value * 100))
                .font(.caption)
                .fontWeight(.medium)
        }
    }
}

// MARK: - Preview

#Preview {
    SuggestionView(currentLetters: "CAT", targetLetterCount: 4)
        .frame(width: 500, height: 600)
}
