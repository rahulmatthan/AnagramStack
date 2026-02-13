//
//  SimpleAdminView.swift
//  AnagramStackAdmin
//
//  Simplified admin interface for managing hundreds of chains
//

import SwiftUI

struct SimpleAdminView: View {
    let wordGraph: WordGraph
    @Binding var showingWizard: Bool
    @StateObject private var viewModel: ChainEditorViewModel
    @State private var searchText = ""
    @State private var isExporting = false
    @State private var isPushing = false

    init(wordGraph: WordGraph, showingWizard: Binding<Bool>) {
        self.wordGraph = wordGraph
        _showingWizard = showingWizard
        _viewModel = StateObject(wrappedValue: ChainEditorViewModel(dictionary: .shared))
    }

    var filteredChains: [AnagramChain] {
        if searchText.isEmpty {
            return viewModel.chains
        }
        return viewModel.chains.filter { chain in
            chain.name.localizedCaseInsensitiveContains(searchText)
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // ACTION HEADER
            HStack(spacing: 16) {
                Button {
                    showingWizard = true
                } label: {
                    Label("Create Chain", systemImage: "plus.circle.fill")
                        .font(.headline)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .keyboardShortcut("n", modifiers: .command)

                Divider()
                    .frame(height: 30)

                Button {
                    exportAllChains()
                } label: {
                    if isExporting {
                        ProgressView()
                            .scaleEffect(0.7)
                            .frame(width: 16, height: 16)
                        Text("Exporting...")
                    } else {
                        Label("Export All Chains", systemImage: "square.and.arrow.down")
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .disabled(isExporting || viewModel.chains.isEmpty)

                Button {
                    commitAndPush()
                } label: {
                    if isPushing {
                        ProgressView()
                            .scaleEffect(0.7)
                            .frame(width: 16, height: 16)
                        Text("Pushing...")
                    } else {
                        Label("Commit & Push", systemImage: "arrow.up.circle.fill")
                    }
                }
                .buttonStyle(.bordered)
                .controlSize(.large)
                .disabled(isPushing)
                .tint(.green)

                Spacer()

                Text("\(viewModel.chains.count) chains")
                    .font(.headline)
                    .foregroundColor(.secondary)
            }
            .padding()
            .background(Color(.windowBackgroundColor))

            Divider()

            // MAIN CONTENT
            NavigationSplitView {
            // SIDEBAR
            VStack(spacing: 0) {
                // Search bar
                HStack {
                    Image(systemName: "magnifyingglass")
                        .foregroundColor(.secondary)
                    TextField("Search chains...", text: $searchText)
                        .textFieldStyle(.plain)
                }
                .padding(8)
                .background(Color(.controlBackgroundColor))
                .cornerRadius(6)
                .padding()

                // Chain list
                List(selection: $viewModel.selectedChain) {
                    ForEach(filteredChains) { chain in
                        ChainRow(chain: chain)
                            .tag(chain)
                            .contextMenu {
                                Button("Delete", role: .destructive) {
                                    viewModel.deleteChain(chain)
                                }
                            }
                    }
                }
                .listStyle(.sidebar)
            }
            .navigationTitle("Chains (\(viewModel.chains.count))")
        } detail: {
            // DETAIL VIEW
            if let chain = viewModel.selectedChain {
                ChainDetailView(chain: chain, viewModel: viewModel)
            } else {
                ContentUnavailableView(
                    "No Chain Selected",
                    systemImage: "link",
                    description: Text("Select a chain or create a new one")
                )
            }
        }
            .sheet(isPresented: $showingWizard) {
                ChainCreationWizardV2(wordGraph: wordGraph) { chain in
                    viewModel.chains.append(chain)
                    viewModel.selectedChain = chain
                    viewModel.saveChain()
                }
            }
            .alert("Error", isPresented: $viewModel.showingError) {
                Button("OK", role: .cancel) { }
            } message: {
                Text(viewModel.errorMessage ?? "Unknown error")
            }
        }
    }

    // MARK: - Actions

    private func exportAllChains() {
        Task { @MainActor in
            isExporting = true
            defer { isExporting = false }

            let exportURL = URL(fileURLWithPath: "/Users/rahul/Coding/anagram-chains-data/chains")

            do {
                try FileManager.default.createDirectory(at: exportURL, withIntermediateDirectories: true)

                var exportCount = 0
                for (index, chain) in viewModel.chains.enumerated() where chain.isComplete() {
                    let filename = String(format: "chain-%03d.json", index + 1)
                    let fileURL = exportURL.appendingPathComponent(filename)
                    try chain.save(to: fileURL)
                    exportCount += 1
                }

                // Update manifest
                await updateManifest(chainCount: exportCount)

                let alert = NSAlert()
                alert.messageText = "Export Complete ✅"
                alert.informativeText = "Exported \(exportCount) chain(s) to git repository.\n\nClick 'Commit & Push' to upload to GitHub."
                alert.alertStyle = .informational
                alert.runModal()

            } catch {
                let alert = NSAlert()
                alert.messageText = "Export Failed"
                alert.informativeText = error.localizedDescription
                alert.alertStyle = .critical
                alert.runModal()
            }
        }
    }

    private func commitAndPush() {
        Task { @MainActor in
            isPushing = true
            defer { isPushing = false }

            let repoPath = "/Users/rahul/Coding/anagram-chains-data"

            let commands = [
                "cd \(repoPath) && git add .",
                "cd \(repoPath) && git commit -m \"Update chains - $(date +%Y-%m-%d)\"",
                "cd \(repoPath) && git push"
            ]

            var allOutput = ""

            for command in commands {
                let process = Process()
                process.executableURL = URL(fileURLWithPath: "/bin/bash")
                process.arguments = ["-c", command]

                let pipe = Pipe()
                process.standardOutput = pipe
                process.standardError = pipe

                do {
                    try process.run()
                    process.waitUntilExit()

                    let data = pipe.fileHandleForReading.readDataToEndOfFile()
                    if let output = String(data: data, encoding: .utf8) {
                        allOutput += output + "\n"
                    }

                    // If git commit fails (nothing to commit), that's ok
                    // If git push fails, show error
                    if command.contains("push") && process.terminationStatus != 0 {
                        let alert = NSAlert()
                        alert.messageText = "Push Failed"
                        alert.informativeText = "Make sure you've set up the GitHub repository.\n\nOutput:\n\(allOutput)"
                        alert.alertStyle = .warning
                        alert.runModal()
                        return
                    }

                } catch {
                    let alert = NSAlert()
                    alert.messageText = "Git Command Failed"
                    alert.informativeText = error.localizedDescription
                    alert.alertStyle = .critical
                    alert.runModal()
                    return
                }
            }

            let alert = NSAlert()
            alert.messageText = "Pushed to GitHub! 🚀"
            alert.informativeText = "Chains are now live on GitHub.\n\niOS app will auto-fetch on next launch."
            alert.alertStyle = .informational
            alert.runModal()
        }
    }

    private func updateManifest(chainCount: Int) async {
        let manifestURL = URL(fileURLWithPath: "/Users/rahul/Coding/anagram-chains-data/manifest.json")
        let chainsFolder = URL(fileURLWithPath: "/Users/rahul/Coding/anagram-chains-data/chains")

        do {
            let chainFiles = try FileManager.default.contentsOfDirectory(at: chainsFolder, includingPropertiesForKeys: nil)
                .filter { $0.pathExtension == "json" }
                .sorted { $0.lastPathComponent < $1.lastPathComponent }

            var manifestChains: [[String: Any]] = []

            for (index, fileURL) in chainFiles.enumerated() {
                if let data = try? Data(contentsOf: fileURL),
                   let chain = try? JSONDecoder().decode(AnagramChain.self, from: data) {

                    let entry: [String: Any] = [
                        "id": "chain-\(String(format: "%03d", index + 1))",
                        "name": chain.name,
                        "description": chain.description,
                        "difficulty": chain.difficulty.rawValue,
                        "letterCount": 6,
                        "url": "https://raw.githubusercontent.com/rahulmatthan/anagram-chains-data/master/chains/\(fileURL.lastPathComponent)"
                    ]
                    manifestChains.append(entry)
                }
            }

            let manifest: [String: Any] = [
                "version": "1.0",
                "lastUpdated": ISO8601DateFormatter().string(from: Date()),
                "chains": manifestChains
            ]

            let manifestData = try JSONSerialization.data(withJSONObject: manifest, options: [.prettyPrinted, .sortedKeys])
            try manifestData.write(to: manifestURL)

        } catch {
            print("⚠️ Failed to update manifest: \(error)")
        }
    }
}

// MARK: - Chain Row

struct ChainRow: View {
    let chain: AnagramChain

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text(chain.name)
                    .font(.headline)

                HStack(spacing: 8) {
                    Text(chain.difficulty.displayName)
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text("•")
                        .foregroundColor(.secondary)

                    Text("\(chain.levels.count)/6 levels")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }

            Spacer()

            if chain.isComplete() {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
            }
        }
        .padding(.vertical, 4)
    }
}

// MARK: - Chain Detail View

struct ChainDetailView: View {
    let chain: AnagramChain
    @ObservedObject var viewModel: ChainEditorViewModel

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 12) {
                HStack {
                    VStack(alignment: .leading) {
                        Text(chain.name)
                            .font(.title)
                            .fontWeight(.bold)

                        Text(chain.description.isEmpty ? "No description" : chain.description)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }

                    Spacer()

                    if chain.isComplete() {
                        Label("Valid", systemImage: "checkmark.circle.fill")
                            .foregroundColor(.green)
                            .font(.headline)
                    } else {
                        Label("Invalid", systemImage: "exclamationmark.triangle.fill")
                            .foregroundColor(.orange)
                            .font(.headline)
                    }
                }

                Divider()

                HStack(spacing: 16) {
                    InfoPill(label: "Difficulty", value: chain.difficulty.displayName)
                    InfoPill(label: "Levels", value: "\(chain.levels.count)/6")
                    InfoPill(label: "Letters", value: "3→8")
                }
            }
            .padding()
            .background(Color(.controlBackgroundColor))

            Divider()

            // Levels
            ScrollView {
                VStack(spacing: 16) {
                    ForEach(Array(chain.levels.enumerated()), id: \.element.id) { index, level in
                        SimpleLevelCard(
                            level: level,
                            number: index + 1,
                            chain: chain,
                            viewModel: viewModel
                        )
                    }
                }
                .padding()
            }

            Divider()

            // Actions
            HStack(spacing: 12) {
                Button {
                    if let chain = viewModel.selectedChain {
                        let pasteboard = NSPasteboard.general
                        if let data = try? chain.toJSON(),
                           let json = String(data: data, encoding: .utf8) {
                            pasteboard.clearContents()
                            pasteboard.setString(json, forType: .string)
                        }
                    }
                } label: {
                    Label("Copy JSON", systemImage: "doc.on.clipboard")
                }
                .buttonStyle(.bordered)
                .disabled(!chain.isComplete())

                Spacer()

                Button {
                    viewModel.deleteChain(chain)
                } label: {
                    Label("Delete Chain", systemImage: "trash")
                }
                .buttonStyle(.bordered)
                .tint(.red)
            }
            .padding()
            .background(Color(.controlBackgroundColor))
        }
    }
}

// MARK: - Simple Level Card

struct SimpleLevelCard: View {
    let level: AnagramLevel
    let number: Int
    let chain: AnagramChain
    @ObservedObject var viewModel: ChainEditorViewModel
    @State private var showingEditor = false

    var body: some View {
        HStack(spacing: 16) {
            // Level number
            Text("\(number)")
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(.white)
                .frame(width: 50, height: 50)
                .background(level.isValid() ? Color.green : Color.orange)
                .cornerRadius(8)

            VStack(alignment: .leading, spacing: 4) {
                Text("\(level.letterCount) Letters")
                    .font(.headline)

                if let word = level.intendedWord {
                    Text(word)
                        .font(.title3)
                        .fontWeight(.semibold)
                } else {
                    Text("No word specified")
                        .foregroundColor(.secondary)
                }

                if let letter = level.addedLetter {
                    Text("Added letter: \(letter)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                } else if number > 1 {
                    Text("Missing added letter")
                        .font(.caption)
                        .foregroundColor(.orange)
                }
            }

            Spacer()

            if level.isValid() {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(.green)
                    .font(.title2)
            } else {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundColor(.orange)
                    .font(.title2)
            }

            // Edit button
            Button {
                showingEditor = true
            } label: {
                Image(systemName: "pencil.circle")
                    .font(.title2)
                    .foregroundColor(.blue)
            }
            .buttonStyle(.plain)
        }
        .padding()
        .background(Color(.controlBackgroundColor))
        .cornerRadius(8)
        .sheet(isPresented: $showingEditor) {
            LevelQuickEditView(
                level: level,
                levelNumber: number,
                chain: chain,
                viewModel: viewModel
            )
        }
    }
}

// MARK: - Quick Level Editor

struct LevelQuickEditView: View {
    let level: AnagramLevel
    let levelNumber: Int
    let chain: AnagramChain
    @ObservedObject var viewModel: ChainEditorViewModel
    @Environment(\.dismiss) private var dismiss

    @State private var addedLetter: String
    @State private var intendedWord: String

    init(level: AnagramLevel, levelNumber: Int, chain: AnagramChain, viewModel: ChainEditorViewModel) {
        self.level = level
        self.levelNumber = levelNumber
        self.chain = chain
        self.viewModel = viewModel
        _addedLetter = State(initialValue: level.addedLetter ?? "")
        _intendedWord = State(initialValue: level.intendedWord ?? "")
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(spacing: 8) {
                Text("Edit Level \(levelNumber)")
                    .font(.title2)
                    .fontWeight(.bold)

                Text("\(level.letterCount) Letters")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
            }
            .padding(.top, 24)
            .padding(.bottom, 20)
            .frame(maxWidth: .infinity)
            .background(Color(.controlBackgroundColor))

            // Form Area
            VStack(alignment: .leading, spacing: 20) {
                if levelNumber == 1 {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Starting Letters")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        TextField("", text: .constant(level.letters ?? ""))
                            .textFieldStyle(.roundedBorder)
                            .disabled(true)
                            .font(.system(size: 16))
                    }
                } else {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Added Letter")
                            .font(.headline)
                            .foregroundColor(.secondary)
                        TextField("Enter single letter", text: $addedLetter)
                            .textFieldStyle(.roundedBorder)
                            .textCase(.uppercase)
                            .autocorrectionDisabled()
                            .font(.system(size: 16, weight: .medium))
                    }
                }

                VStack(alignment: .leading, spacing: 8) {
                    Text("Intended Word")
                        .font(.headline)
                        .foregroundColor(.secondary)
                    TextField("Enter word", text: $intendedWord)
                        .textFieldStyle(.roundedBorder)
                        .textCase(.uppercase)
                        .autocorrectionDisabled()
                        .font(.system(size: 16, weight: .medium))
                }
            }
            .padding(24)

            Spacer()

            // Footer
            Divider()

            HStack(spacing: 12) {
                Button("Cancel") {
                    dismiss()
                }
                .keyboardShortcut(.cancelAction)
                .controlSize(.large)

                Spacer()

                Button("Save Changes") {
                    saveChanges()
                    dismiss()
                }
                .buttonStyle(.borderedProminent)
                .keyboardShortcut(.defaultAction)
                .controlSize(.large)
            }
            .padding(20)
            .background(Color(.controlBackgroundColor))
        }
        .frame(width: 450, height: 350)
    }

    private func saveChanges() {
        guard let chainIndex = viewModel.chains.firstIndex(where: { $0.id == chain.id }) else {
            print("❌ Chain not found")
            return
        }

        var updatedChain = viewModel.chains[chainIndex]

        // Find and update the specific level
        if let levelIndex = updatedChain.levels.firstIndex(where: { $0.id == level.id }) {
            var updatedLevel = updatedChain.levels[levelIndex]

            // Update the fields
            if levelNumber > 1 {
                updatedLevel.addedLetter = addedLetter.isEmpty ? nil : addedLetter.uppercased()
            }
            updatedLevel.intendedWord = intendedWord.isEmpty ? nil : intendedWord.uppercased()

            // Replace the level in the chain
            updatedChain.levels[levelIndex] = updatedLevel

            // Update the chain in viewModel
            viewModel.chains[chainIndex] = updatedChain
            viewModel.saveChain()

            print("✅ Saved: Level \(levelNumber) - addedLetter=\(addedLetter), intendedWord=\(intendedWord)")
        }
    }
}

// MARK: - Info Pill

struct InfoPill: View {
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 4) {
            Text(label)
                .font(.caption)
                .foregroundColor(.secondary)
            Text(value)
                .font(.subheadline)
                .fontWeight(.semibold)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 6)
        .background(Color(.windowBackgroundColor))
        .cornerRadius(6)
    }
}
