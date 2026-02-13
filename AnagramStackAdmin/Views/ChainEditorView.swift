//
//  ChainEditorView.swift
//  AnagramStackAdmin
//
//  Master-detail view for editing anagram chains
//

import SwiftUI
import UniformTypeIdentifiers

struct ChainEditorView: View {
    let wordGraph: WordGraph

    @StateObject private var viewModel: ChainEditorViewModel
    @State private var showingWizard = false

    init(wordGraph: WordGraph) {
        self.wordGraph = wordGraph
        _viewModel = StateObject(wrappedValue: ChainEditorViewModel(dictionary: .shared))
    }

    var body: some View {
        NavigationSplitView {
            // Sidebar - List of chains
            chainList
        } detail: {
            // Detail - Chain editor
            if let chain = viewModel.selectedChain {
                chainDetail(for: chain)
            } else {
                emptyState
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

    // MARK: - Chain List (Sidebar)

    private var chainList: some View {
        List(selection: $viewModel.selectedChain) {
            ForEach(viewModel.chains) { chain in
                ChainListRow(chain: chain)
                    .tag(chain)
                    .contextMenu {
                        Button("Duplicate") {
                            viewModel.duplicateChain(chain)
                        }
                        Button("Delete", role: .destructive) {
                            viewModel.deleteChain(chain)
                        }
                    }
            }
        }
        .navigationTitle("Anagram Chains")
        .toolbar {
            ToolbarItem(placement: .primaryAction) {
                HStack {
                    Menu {
                        Button {
                            showingWizard = true
                        } label: {
                            Label("Create with Wizard", systemImage: "wand.and.stars")
                        }

                        Button {
                            viewModel.createNewChain()
                        } label: {
                            Label("Create Manually", systemImage: "plus")
                        }
                    } label: {
                        Label("New Chain", systemImage: "plus")
                    }

                    Button {
                        exportAllChains()
                    } label: {
                        Label("Export All", systemImage: "square.and.arrow.up")
                    }
                }
            }

            ToolbarItem(placement: .navigation) {
                Button {
                    viewModel.loadChains()
                } label: {
                    Label("Refresh", systemImage: "arrow.clockwise")
                }
            }
        }
    }

    // MARK: - Chain Detail

    private func chainDetail(for chain: AnagramChain) -> some View {
        VStack(spacing: 0) {
            // Header with chain info
            chainHeader(for: chain)

            Divider()

            // Levels editor
            ScrollView {
                VStack(spacing: 16) {
                    ForEach(Array(chain.levels.enumerated()), id: \.element.id) { index, level in
                        LevelCard(
                            level: level,
                            levelNumber: index + 1,
                            onUpdate: { updatedLevel in
                                viewModel.updateLevel(at: index, level: updatedLevel)
                            },
                            onDelete: {
                                viewModel.removeLevel(at: index)
                            },
                            dictionary: WordDictionary.shared
                        )
                    }

                    // Add level button
                    if chain.levels.count < 6 {
                        addLevelButton
                    }

                    // Validation status
                    validationView(for: chain)
                }
                .padding()
            }

            Divider()

            // Footer with actions
            chainFooter
        }
        .navigationTitle(chain.name)
    }

    private func chainHeader(for chain: AnagramChain) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            TextField("Chain Name", text: binding(for: \.name))
                .font(.title2)
                .textFieldStyle(.plain)

            TextField("Description", text: binding(for: \.description))
                .font(.subheadline)
                .foregroundColor(.secondary)
                .textFieldStyle(.plain)

            Picker("Difficulty", selection: binding(for: \.difficulty)) {
                ForEach(AnagramChain.Difficulty.allCases, id: \.self) { difficulty in
                    Text(difficulty.displayName).tag(difficulty)
                }
            }
            .pickerStyle(.segmented)
            .labelsHidden()

            HStack {
                Text("Progress: \(chain.levels.count)/6 levels")
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                if chain.isComplete() {
                    Label("Complete", systemImage: "checkmark.circle.fill")
                        .font(.caption)
                        .foregroundColor(.green)
                }
            }
        }
        .padding()
        .background(Color(.controlBackgroundColor))
    }

    private var addLevelButton: some View {
        Button {
            if let chain = viewModel.selectedChain {
                let nextCount = chain.levels.count + 3

                // First level gets letters, others get addedLetter
                if chain.levels.isEmpty {
                    viewModel.addLevel(
                        letterCount: 3,
                        letters: "",
                        intendedWord: nil
                    )
                } else {
                    viewModel.addLevel(
                        letterCount: nextCount,
                        addedLetter: "",
                        intendedWord: nil
                    )
                }
            }
        } label: {
            Label("Add Level", systemImage: "plus.circle")
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color.accentColor.opacity(0.1))
                .cornerRadius(8)
        }
        .buttonStyle(.plain)
    }

    private func validationView(for chain: AnagramChain) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Validation")
                .font(.headline)

            let errors = chain.validationErrors()

            if errors.isEmpty {
                Label("Chain is valid and ready to export", systemImage: "checkmark.circle.fill")
                    .foregroundColor(.green)
            } else {
                ForEach(errors, id: \.self) { error in
                    Label(error, systemImage: "exclamationmark.triangle.fill")
                        .foregroundColor(.orange)
                        .font(.caption)
                }
            }
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.controlBackgroundColor))
        .cornerRadius(8)
    }

    private var chainFooter: some View {
        HStack {
            Button("Export All Chains") {
                exportAllChains()
            }

            Button("Sync to iOS App") {
                syncToIOSApp()
            }

            Spacer()

            Button("Copy JSON") {
                copyJSONToClipboard()
            }
            .disabled(!viewModel.isChainComplete)

            Button("Export...") {
                exportChain()
            }
            .disabled(!viewModel.isChainComplete)

            Button("Save") {
                viewModel.saveChain()
            }
            .keyboardShortcut("s", modifiers: .command)
        }
        .padding()
        .background(Color(.controlBackgroundColor))
    }

    private func copyJSONToClipboard() {
        guard let chain = viewModel.selectedChain else { return }

        do {
            let jsonData = try chain.toJSON()
            if let jsonString = String(data: jsonData, encoding: .utf8) {
                let pasteboard = NSPasteboard.general
                pasteboard.clearContents()
                pasteboard.setString(jsonString, forType: .string)
                print("✅ JSON copied to clipboard!")
                print("📋 Length: \(jsonString.count) characters")
            }
        } catch {
            print("❌ Failed to generate JSON: \(error)")
        }
    }

    private func syncToIOSApp() {
        print("🔄 Syncing chains to iOS app...")

        // Source: Desktop export folder
        let desktopURL = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask)[0]
        let sourceURL = desktopURL.appendingPathComponent("AnagramChains")

        // Destination: iOS app's Resources (via shell script)
        let scriptPath = "/Users/rahul/Coding/AnagramStack/sync-chains-desktop.sh"

        // Check if source folder exists
        guard FileManager.default.fileExists(atPath: sourceURL.path) else {
            let alert = NSAlert()
            alert.messageText = "Export First"
            alert.informativeText = "Click 'Export All Chains' first to create chain files on Desktop."
            alert.alertStyle = .warning
            alert.runModal()
            return
        }

        // Run shell script to sync
        let process = Process()
        process.executableURL = URL(fileURLWithPath: "/bin/bash")
        process.arguments = [scriptPath]

        let pipe = Pipe()
        process.standardOutput = pipe
        process.standardError = pipe

        do {
            try process.run()
            process.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            if let output = String(data: data, encoding: .utf8) {
                print(output)
            }

            if process.terminationStatus == 0 {
                let alert = NSAlert()
                alert.messageText = "Sync Complete!"
                alert.informativeText = "Chains synced to iOS app.\n\nRebuild the iOS app in Xcode to use them!"
                alert.alertStyle = .informational
                alert.runModal()
            } else {
                let alert = NSAlert()
                alert.messageText = "Sync Failed"
                alert.informativeText = "Check console for details."
                alert.alertStyle = .critical
                alert.runModal()
            }
        } catch {
            print("❌ Failed to run sync script: \(error)")

            let alert = NSAlert()
            alert.messageText = "Sync Failed"
            alert.informativeText = error.localizedDescription
            alert.alertStyle = .critical
            alert.runModal()
        }
    }

    private func exportAllChains() {
        print("📦 Exporting all chains...")
        print("   Total chains in list: \(viewModel.chains.count)")

        // Export to Desktop (has permissions)
        let desktopURL = FileManager.default.urls(for: .desktopDirectory, in: .userDomainMask)[0]
        let exportURL = desktopURL.appendingPathComponent("AnagramChains")

        do {
            try FileManager.default.createDirectory(at: exportURL, withIntermediateDirectories: true)
            print("✅ Created export directory: \(exportURL.path)")
        } catch {
            print("❌ Failed to create directory: \(error)")
            return
        }

        // Export all valid chains
        var exportCount = 0
        for (index, chain) in viewModel.chains.enumerated() {
            print("\n📋 Chain \(index + 1): \(chain.name)")
            print("   Levels: \(chain.levels.count)")
            print("   Is complete: \(chain.isComplete())")

            if !chain.isComplete() {
                let errors = chain.validationErrors()
                print("   ❌ Validation errors:")
                for error in errors {
                    print("      - \(error)")
                }
                print("⏭️  Skipping incomplete chain: \(chain.name)")
                continue
            }

            let filename = "chain-\(String(format: "%03d", index + 1)).json"
            let fileURL = exportURL.appendingPathComponent(filename)

            do {
                try chain.save(to: fileURL)
                print("✅ Exported: \(filename) - \(chain.name)")
                exportCount += 1
            } catch {
                print("❌ Failed to export \(chain.name): \(error)")
            }
        }

        print("\n🎉 Export complete! \(exportCount) chains exported to:")
        print("   \(exportURL.path)")

        // Show success alert
        let alert = NSAlert()
        alert.messageText = "Export Complete"
        alert.informativeText = "Exported \(exportCount) chain(s) to:\n\(exportURL.path)"
        alert.alertStyle = .informational
        alert.runModal()
    }

    // MARK: - Empty State

    private var emptyState: some View {
        ContentUnavailableView(
            "No Chain Selected",
            systemImage: "link",
            description: Text("Select a chain from the sidebar or create a new one")
        )
    }

    // MARK: - Helper Methods

    private func binding<T>(for keyPath: WritableKeyPath<AnagramChain, T>) -> Binding<T> {
        Binding(
            get: {
                guard let chain = viewModel.selectedChain else {
                    fatalError("No selected chain")
                }
                return chain[keyPath: keyPath]
            },
            set: { newValue in
                guard var chain = viewModel.selectedChain else { return }
                chain[keyPath: keyPath] = newValue
                viewModel.updateChain(chain)
            }
        )
    }

    private func exportChain() {
        print("🔍 exportChain() called")
        guard let chain = viewModel.selectedChain else {
            print("❌ No chain selected")
            return
        }

        print("📋 Chain: \(chain.name)")
        print("💾 Opening save panel...")

        let panel = NSSavePanel()
        panel.allowedContentTypes = [.json]
        panel.nameFieldStringValue = "chain-\(chain.name.replacingOccurrences(of: " ", with: "-")).json"
        panel.canCreateDirectories = true

        print("🎯 About to call runModal()...")
        let response = panel.runModal()
        print("✅ runModal() returned: \(response.rawValue)")

        if response == .OK, let url = panel.url {
            print("💾 Saving to: \(url.path)")
            viewModel.exportChain(to: url)
            print("✅ Export complete!")
        } else {
            print("❌ User cancelled")
        }
    }
}

// MARK: - Supporting Views

struct ChainListRow: View {
    let chain: AnagramChain

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(chain.name)
                .font(.headline)

            HStack {
                Text(chain.difficulty.displayName)
                    .font(.caption)
                    .foregroundColor(.secondary)

                Spacer()

                Text("\(chain.levels.count)/6")
                    .font(.caption)
                    .foregroundColor(.secondary)

                if chain.isComplete() {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                        .font(.caption)
                }
            }
        }
        .padding(.vertical, 4)
    }
}

struct LevelCard: View {
    let level: AnagramLevel
    let levelNumber: Int
    let onUpdate: (AnagramLevel) -> Void
    let onDelete: () -> Void
    let dictionary: WordDictionary

    @State private var letters: String
    @State private var addedLetter: String
    @State private var intendedWord: String
    @State private var showingSuggestions = false
    @State private var validWordsPreview: [String] = []

    init(level: AnagramLevel, levelNumber: Int, onUpdate: @escaping (AnagramLevel) -> Void, onDelete: @escaping () -> Void, dictionary: WordDictionary) {
        self.level = level
        self.levelNumber = levelNumber
        self.onUpdate = onUpdate
        self.onDelete = onDelete
        self.dictionary = dictionary
        _letters = State(initialValue: level.letters ?? "")
        _addedLetter = State(initialValue: level.addedLetter ?? "")
        _intendedWord = State(initialValue: level.intendedWord ?? "")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Level \(levelNumber) - \(level.letterCount) Letters")
                    .font(.headline)

                Spacer()

                if level.isValid() {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.green)
                }

                Button(role: .destructive) {
                    onDelete()
                } label: {
                    Image(systemName: "trash")
                }
                .buttonStyle(.borderless)
            }

            // First level: enter letters
            if levelNumber == 1 {
                TextField("Starting Letters (3)", text: $letters)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: letters) { _ in
                        updateLevel()
                        updateValidWordsPreview()
                    }
            } else {
                // Subsequent levels: enter added letter only
                TextField("Added Letter", text: $addedLetter)
                    .textFieldStyle(.roundedBorder)
                    .onChange(of: addedLetter) { _ in
                        updateLevel()
                    }
            }

            TextField("Intended Word (suggestion)", text: $intendedWord)
                .textFieldStyle(.roundedBorder)
                .onChange(of: intendedWord) { _ in
                    updateLevel()
                }

            // Show preview of possible words for first level
            if levelNumber == 1 && !validWordsPreview.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Possible words (\(validWordsPreview.count))")
                        .font(.caption)
                        .foregroundColor(.secondary)

                    Text(validWordsPreview.prefix(10).joined(separator: ", "))
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.controlBackgroundColor))
        .cornerRadius(8)
        .onAppear {
            if levelNumber == 1 && !letters.isEmpty {
                updateValidWordsPreview()
            }
        }
    }

    private func updateLevel() {
        var updated = level

        if levelNumber == 1 {
            updated = AnagramLevel(
                id: level.id,
                letterCount: level.letterCount,
                letters: letters.isEmpty ? nil : letters,
                intendedWord: intendedWord.isEmpty ? nil : intendedWord
            )
        } else {
            updated = AnagramLevel(
                id: level.id,
                letterCount: level.letterCount,
                addedLetter: addedLetter.isEmpty ? nil : addedLetter,
                intendedWord: intendedWord.isEmpty ? nil : intendedWord
            )
        }

        onUpdate(updated)
    }

    private func updateValidWordsPreview() {
        if !letters.isEmpty {
            validWordsPreview = dictionary.findAnagrams(from: letters)
        } else {
            validWordsPreview = []
        }
    }
}
