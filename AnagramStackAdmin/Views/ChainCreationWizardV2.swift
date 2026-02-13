//
//  ChainCreationWizardV2.swift
//  AnagramStackAdmin
//
//  Graph-based wizard using pre-computed word paths
//

import SwiftUI

struct ChainCreationWizardV2: View {
    let wordGraph: WordGraph
    let onComplete: (AnagramChain) -> Void

    @Environment(\.dismiss) private var dismiss

    @State private var chainName: String = ""
    @State private var chainDescription: String = ""
    @State private var difficulty: AnagramChain.Difficulty = .medium
    @State private var selectedWords: [String?] = [nil, nil, nil, nil, nil, nil]  // 6 levels
    @State private var selectedSignatures: [String?] = [nil, nil, nil, nil, nil, nil]

    var currentLevel: Int {
        // Find the first empty slot
        if let index = selectedWords.firstIndex(where: { $0 == nil }) {
            return index
        }
        return 6 // All filled
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 12) {
                Text("Create Anagram Chain")
                    .font(.title)

                TextField("Chain Name", text: $chainName)
                    .textFieldStyle(.roundedBorder)
                    .frame(maxWidth: 400)

                Picker("Difficulty", selection: $difficulty) {
                    ForEach(AnagramChain.Difficulty.allCases, id: \.self) { diff in
                        Text(diff.displayName).tag(diff)
                    }
                }
                .pickerStyle(.segmented)
                .frame(maxWidth: 400)
            }
            .padding()
            .background(Color(.controlBackgroundColor))

            Divider()

            // 6 Word Boxes
            HStack(spacing: 12) {
                ForEach(0..<6, id: \.self) { index in
                    VStack(spacing: 4) {
                        Text("\(index + 3) letters")
                            .font(.caption)
                            .foregroundColor(.secondary)

                        ZStack {
                            RoundedRectangle(cornerRadius: 8)
                                .fill(selectedWords[index] != nil ? Color.green.opacity(0.1) : Color.gray.opacity(0.1))
                                .frame(height: 60)

                            if let word = selectedWords[index] {
                                Text(word.uppercased())
                                    .font(.title3)
                                    .fontWeight(.bold)
                            } else if index == currentLevel {
                                Text("Select...")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            } else {
                                Text("—")
                                    .font(.title3)
                                    .foregroundColor(.gray)
                            }
                        }
                        .overlay(
                            RoundedRectangle(cornerRadius: 8)
                                .stroke(index == currentLevel ? Color.accentColor : Color.clear, lineWidth: 2)
                        )
                    }
                }
            }
            .padding()
            .background(Color(.windowBackgroundColor))

            Divider()

            // Selection Area
            ScrollView {
                VStack(spacing: 16) {
                    if currentLevel < 6 {
                        Text("Select a \(currentLevel + 3)-letter word:")
                            .font(.headline)

                        if currentLevel == 0 {
                            // Show starting words
                            startingWordSelection
                        } else {
                            // Show next letter options
                            letterAdditionSelection
                        }
                    } else {
                        // All filled - show completion message
                        completionMessage
                    }
                }
                .padding()
            }

            Divider()

            // Footer
            HStack {
                Button("Cancel") {
                    dismiss()
                }

                Spacer()

                if currentLevel > 0 {
                    Button("Clear Last") {
                        clearLast()
                    }
                }

                Button("Create Chain") {
                    createChain()
                }
                .disabled(currentLevel < 6)
                .keyboardShortcut(.return, modifiers: .command)
            }
            .padding()
            .background(Color(.controlBackgroundColor))
        }
        .frame(width: 900, height: 700)
        .onAppear {
            print("📊 Wizard opened - viableStarts count: \(wordGraph.viableStarts.count)")
        }
    }

    // MARK: - Starting Word Selection

    private var startingWordSelection: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 12) {
            ForEach(wordGraph.viableStarts.prefix(100), id: \.self) { signature in
                let words = wordGraph.words(for: signature)
                if let word = words.first {
                    Button {
                        selectWord(word, signature: signature, atLevel: 0)
                    } label: {
                        VStack(spacing: 4) {
                            Text(word.uppercased())
                                .font(.title3)
                                .fontWeight(.bold)

                            Text("\(words.count) variants")
                                .font(.caption2)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .background(selectedWords[0] == word ? Color.accentColor.opacity(0.2) : Color(.controlBackgroundColor))
                        .cornerRadius(6)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    // MARK: - Letter Addition Selection

    private var letterAdditionSelection: some View {
        Group {
            if let previousSig = selectedSignatures[currentLevel - 1] {
                let nextOptions = wordGraph.nextSignatures(from: previousSig)

                if nextOptions.isEmpty {
                    Text("No options available from '\(selectedWords[currentLevel - 1] ?? "")'")
                        .foregroundColor(.orange)
                } else {
                    VStack(spacing: 12) {
                        ForEach(nextOptions, id: \.self) { nextSig in
                            LetterOptionRow(
                                signature: nextSig,
                                previousSignature: previousSig,
                                wordGraph: wordGraph,
                                currentLength: currentLevel + 3,
                                isSelected: selectedSignatures[currentLevel] == nextSig,
                                onSelect: { word in
                                    selectWord(word, signature: nextSig, atLevel: currentLevel)
                                }
                            )
                        }
                    }
                }
            }
        }
    }

    // MARK: - Completion Message

    private var completionMessage: some View {
        VStack(spacing: 16) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 60))
                .foregroundColor(.green)

            Text("All levels selected!")
                .font(.title2)
                .fontWeight(.bold)

            Text("Click 'Create Chain' to save")
                .foregroundColor(.secondary)
        }
        .frame(maxHeight: .infinity)
    }

    // MARK: - Actions

    private func selectWord(_ word: String, signature: String, atLevel level: Int) {
        print("📝 Selected '\(word)' at level \(level + 1)")
        selectedWords[level] = word
        selectedSignatures[level] = signature

        // Clear any selections after this level
        for i in (level + 1)..<6 {
            selectedWords[i] = nil
            selectedSignatures[i] = nil
        }

        print("   Current chain: \(selectedWords.compactMap { $0 }.joined(separator: " → "))")
    }

    private func clearLast() {
        if currentLevel > 0 {
            let clearIndex = currentLevel - 1
            print("🗑️  Clearing level \(clearIndex + 1): \(selectedWords[clearIndex] ?? "")")
            selectedWords[clearIndex] = nil
            selectedSignatures[clearIndex] = nil
        }
    }

    private func createChain() {
        print("🔨 Creating chain...")

        var levels: [AnagramLevel] = []

        // Level 1: 3 letters
        if let word = selectedWords[0] {
            let level = AnagramLevel(
                letterCount: 3,
                letters: word.uppercased(),
                intendedWord: word.uppercased()
            )
            levels.append(level)
        }

        // Levels 2-6: 4-8 letters
        for i in 1..<6 {
            guard let word = selectedWords[i],
                  let prevSig = selectedSignatures[i - 1],
                  let currSig = selectedSignatures[i] else {
                print("   ⚠️  Skipping level \(i + 1): missing data")
                continue
            }

            print("   Level \(i + 1): prevSig=\(prevSig), currSig=\(currSig)")

            // Find the added letter
            var addedLetter: String = ""
            for char in currSig {
                if !prevSig.contains(char) {
                    addedLetter = String(char)
                    break
                }
            }

            print("   Level \(i + 1): word=\(word), addedLetter='\(addedLetter)'")

            let level = AnagramLevel(
                letterCount: i + 3,
                addedLetter: addedLetter.isEmpty ? nil : addedLetter,
                intendedWord: word.uppercased()
            )
            levels.append(level)

            print("   Level \(i + 1) valid: \(level.isValid())")
        }

        let chain = AnagramChain(
            name: chainName.isEmpty ? "Chain from \(selectedWords[0] ?? "unknown")" : chainName,
            description: chainDescription.isEmpty ? "Anagram chain" : chainDescription,
            difficulty: difficulty,
            levels: levels
        )

        print("✅ Chain created: \(chain.name)")
        print("   Levels: \(chain.levels.count)")
        print("   Valid: \(chain.isComplete())")

        onComplete(chain)
        dismiss()
    }
}

// MARK: - Letter Option Row

struct LetterOptionRow: View {
    let signature: String
    let previousSignature: String
    let wordGraph: WordGraph
    let currentLength: Int
    let isSelected: Bool
    let onSelect: (String) -> Void

    var addedLetter: String {
        for char in signature {
            if !previousSignature.contains(char) {
                return String(char).uppercased()
            }
        }
        return "?"
    }

    var body: some View {
        let words = wordGraph.words(for: signature)
        let canReach8 = wordGraph.canReachLength(signature: signature, currentLength: currentLength, targetLength: 8)

        HStack(spacing: 16) {
            // Added letter
            Text(addedLetter)
                .font(.title)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .frame(width: 50, height: 50)
                .background(canReach8 ? Color.green : Color.orange)
                .cornerRadius(8)

            VStack(alignment: .leading, spacing: 4) {
                // Show multiple word options
                FlowLayout(spacing: 8) {
                    ForEach(words.prefix(10), id: \.self) { word in
                        Button {
                            onSelect(word)
                        } label: {
                            Text(word.uppercased())
                                .font(.headline)
                                .padding(.horizontal, 12)
                                .padding(.vertical, 6)
                                .background(isSelected && wordGraph.representativeWord(for: signature) == word ? Color.accentColor : Color.gray.opacity(0.2))
                                .foregroundColor(isSelected && wordGraph.representativeWord(for: signature) == word ? .white : .primary)
                                .cornerRadius(6)
                        }
                        .buttonStyle(.plain)
                    }
                }

                Text("\(words.count) possible words")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Viability indicator
            if canReach8 {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.title2)
            } else {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                    .font(.title2)
            }
        }
        .padding()
        .background(Color(.controlBackgroundColor))
        .cornerRadius(8)
    }
}

// MARK: - Flow Layout Helper

struct FlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = FlowResult(
            in: proposal.replacingUnspecifiedDimensions().width,
            subviews: subviews,
            spacing: spacing
        )
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = FlowResult(
            in: bounds.width,
            subviews: subviews,
            spacing: spacing
        )
        for (index, subview) in subviews.enumerated() {
            subview.place(at: CGPoint(x: bounds.minX + result.frames[index].minX, y: bounds.minY + result.frames[index].minY), proposal: .unspecified)
        }
    }

    struct FlowResult {
        var frames: [CGRect] = []
        var size: CGSize = .zero

        init(in maxWidth: CGFloat, subviews: Subviews, spacing: CGFloat) {
            var x: CGFloat = 0
            var y: CGFloat = 0
            var lineHeight: CGFloat = 0

            for subview in subviews {
                let size = subview.sizeThatFits(.unspecified)

                if x + size.width > maxWidth && x > 0 {
                    x = 0
                    y += lineHeight + spacing
                    lineHeight = 0
                }

                frames.append(CGRect(x: x, y: y, width: size.width, height: size.height))
                lineHeight = max(lineHeight, size.height)
                x += size.width + spacing
            }

            self.size = CGSize(width: maxWidth, height: y + lineHeight)
        }
    }
}
