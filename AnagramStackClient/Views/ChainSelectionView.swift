//
//  ChainSelectionView.swift
//  AnagramStackClient
//
//  Pack-based manifest with one expanded unlocked pack
//

import SwiftUI

struct ChainSelectionView: View {
    let chains: [AnagramChain]
    @EnvironmentObject var appState: ClientAppState
    @AppStorage("com.anagramstack.savedProgressByChain") private var savedProgressBlob: Data = Data()
    @AppStorage("com.anagramstack.chainOrder") private var chainOrderBlob: Data = Data()
    @State private var orderedChainIds: [UUID] = []

    struct ChainPack: Identifiable {
        enum State {
            case completed
            case unlocked
            case locked
        }

        let index: Int
        let chains: [AnagramChain]
        let completedCount: Int
        let state: State

        var id: Int { index }
        var title: String { "Pack \(index + 1)" }
        var progress: Double {
            guard !chains.isEmpty else { return 0 }
            return Double(completedCount) / Double(chains.count)
        }
    }

    private var packs: [ChainPack] {
        _ = savedProgressBlob

        let chunks = orderedChains.chunked(into: 5)
        var result: [ChainPack] = []
        var allPreviousCompleted = true

        for (index, chunk) in chunks.enumerated() {
            let completedCount = chunk.filter { SavedProgress.isCompleted(for: $0) }.count
            let isCompleted = !chunk.isEmpty && completedCount == chunk.count
            let state: ChainPack.State

            if isCompleted {
                state = .completed
            } else if allPreviousCompleted {
                state = .unlocked
            } else {
                state = .locked
            }

            result.append(
                ChainPack(
                    index: index,
                    chains: chunk,
                    completedCount: completedCount,
                    state: state
                )
            )

            allPreviousCompleted = allPreviousCompleted && isCompleted
        }

        return result
    }

    private var completedPacks: [ChainPack] {
        packs.filter { $0.state == .completed }
    }

    private var unlockedPack: ChainPack? {
        packs.first { $0.state == .unlocked }
    }

    private var lockedPacks: [ChainPack] {
        packs.filter { $0.state == .locked }
    }

    var body: some View {
        NavigationStack {
            if chains.isEmpty {
                emptyState
            } else {
                ZStack {
                    LinearGradient(
                        colors: [
                            BrandPalette.backgroundTop,
                            BrandPalette.backgroundBottom.opacity(0.92)
                        ],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                    .ignoresSafeArea()

                    ScrollView {
                        VStack(alignment: .leading, spacing: 12) {
                            if !completedPacks.isEmpty {
                                VStack(alignment: .leading, spacing: 8) {
                                    Text("Completed")
                                        .font(.headline)
                                        .foregroundColor(.secondary)

                                    ForEach(completedPacks) { pack in
                                        NavigationLink {
                                            CompletedPackDetailView(pack: pack)
                                        } label: {
                                            CollapsedPackBubble(pack: pack)
                                        }
                                        .buttonStyle(.plain)
                                    }
                                }
                            }

                            if let pack = unlockedPack {
                                ExpandedUnlockedPackBubble(pack: pack)
                            } else if !packs.isEmpty {
                                Text("All packs completed")
                                    .font(.headline)
                                    .padding(.top, 8)
                            }

                            if !lockedPacks.isEmpty {
                                VStack(alignment: .leading, spacing: 8) {
                                    ForEach(lockedPacks) { pack in
                                        CollapsedPackBubble(pack: pack)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                    }
                }
                .refreshable {
                    await refreshChains()
                }
                .navigationTitle("Anagram Stack")
                .navigationDestination(for: AnagramChain.self) { chain in
                    GameView(chain: chain)
                        #if os(iOS)
                        .navigationBarTitleDisplayMode(.inline)
                        #endif
                }
                .onAppear {
                    synchronizeChainOrder()
                }
                .onChange(of: chains.map(\.id)) { _, _ in
                    synchronizeChainOrder()
                }
            }
        }
    }

    private func refreshChains() async {
        await appState.fetchChains()
    }

    private var emptyState: some View {
        ContentUnavailableView(
            "No Chains Available",
            systemImage: "link.badge.plus",
            description: Text("Download chains to get started")
        )
    }

    private var orderedChains: [AnagramChain] {
        let byId = Dictionary(uniqueKeysWithValues: chains.map { ($0.id, $0) })
        return orderedChainIds.compactMap { byId[$0] }
    }

    private func synchronizeChainOrder() {
        let currentChains = chains.sorted { lhs, rhs in
            if lhs.modifiedDate != rhs.modifiedDate {
                return lhs.modifiedDate < rhs.modifiedDate
            }
            return lhs.name < rhs.name
        }

        let currentIds = Set(currentChains.map(\.id))
        var storedIds = decodeChainOrder()
            .filter { currentIds.contains($0) }

        let storedSet = Set(storedIds)
        let missingIds = currentChains.map(\.id).filter { !storedSet.contains($0) }
        storedIds.append(contentsOf: missingIds)

        orderedChainIds = storedIds
        chainOrderBlob = encodeChainOrder(storedIds)
    }

    private func decodeChainOrder() -> [UUID] {
        guard !chainOrderBlob.isEmpty else { return [] }
        guard let decoded = try? JSONDecoder().decode([String].self, from: chainOrderBlob) else { return [] }
        return decoded.compactMap(UUID.init(uuidString:))
    }

    private func encodeChainOrder(_ ids: [UUID]) -> Data {
        (try? JSONEncoder().encode(ids.map(\.uuidString))) ?? Data()
    }
}

private struct CollapsedPackBubble: View {
    let pack: ChainSelectionView.ChainPack

    var body: some View {
        let style = styleForPackState(pack.state)

        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(pack.title)
                    .font(.headline)
                    .foregroundColor(style.titleColor)
                Spacer()
                statusBadge
            }

            Text("\(pack.completedCount)/\(pack.chains.count) chains completed")
                .font(.footnote)
                .foregroundColor(style.subtitleColor)

            ProgressView(value: pack.progress)
                .tint(style.progressColor)
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(style.backgroundFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 12)
                .stroke(style.borderColor, lineWidth: 1)
        )
        .opacity(style.opacity)
    }

    @ViewBuilder
    private var statusBadge: some View {
        switch pack.state {
        case .completed:
            Label("Completed", systemImage: "checkmark.circle.fill")
                .font(.caption)
                .foregroundColor(BrandPalette.success.opacity(0.9))
        case .locked:
            Label("Locked", systemImage: "lock.fill")
                .font(.caption)
                .foregroundColor(.secondary.opacity(0.9))
        case .unlocked:
            Label("Unlocked", systemImage: "sparkles")
                .font(.caption)
                .foregroundColor(BrandPalette.primary)
        }
    }

    private func styleForPackState(_ state: ChainSelectionView.ChainPack.State) -> (
        backgroundFill: Color,
        borderColor: Color,
        progressColor: Color,
        titleColor: Color,
        subtitleColor: Color,
        opacity: Double
    ) {
        switch state {
        case .unlocked:
            return (
                backgroundFill: Color.white.opacity(0.9),
                borderColor: BrandPalette.primary.opacity(0.32),
                progressColor: BrandPalette.primary,
                titleColor: .primary,
                subtitleColor: .secondary,
                opacity: 1.0
            )
        case .completed:
            return (
                backgroundFill: Color.gray.opacity(0.20),
                borderColor: Color.gray.opacity(0.34),
                progressColor: BrandPalette.success.opacity(0.72),
                titleColor: Color.primary.opacity(0.62),
                subtitleColor: Color.secondary.opacity(0.65),
                opacity: 0.9
            )
        case .locked:
            return (
                backgroundFill: Color.gray.opacity(0.26),
                borderColor: Color.gray.opacity(0.36),
                progressColor: Color.gray.opacity(0.58),
                titleColor: Color.primary.opacity(0.58),
                subtitleColor: Color.secondary.opacity(0.62),
                opacity: 0.86
            )
        }
    }
}

private struct ExpandedUnlockedPackBubble: View {
    let pack: ChainSelectionView.ChainPack
    @AppStorage("com.anagramstack.savedProgressByChain") private var savedProgressBlob: Data = Data()

    private var items: [ChainDisplayItem] {
        _ = savedProgressBlob
        return pack.chains.map(makeDisplayItem(for:))
    }

    private var activeItems: [ChainDisplayItem] {
        items
            .filter { $0.status != .completed }
            .sorted { lhs, rhs in
                let lhsRank = statusRank(lhs.status)
                let rhsRank = statusRank(rhs.status)
                if lhsRank != rhsRank { return lhsRank < rhsRank }
                return lhs.chain.modifiedDate > rhs.chain.modifiedDate
            }
    }

    private var completedItems: [ChainDisplayItem] {
        items
            .filter { $0.status == .completed }
            .sorted { $0.chain.modifiedDate > $1.chain.modifiedDate }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 9) {
            HStack {
                Text(pack.title)
                    .font(.headline)
                Spacer()
                Label("Unlocked", systemImage: "sparkles")
                    .font(.caption)
                    .foregroundColor(BrandPalette.primary)
            }

            Text("\(pack.completedCount)/\(pack.chains.count) chains completed")
                .font(.footnote)
                .foregroundColor(.secondary)

            ProgressView(value: pack.progress)
                .tint(BrandPalette.primary)
                .animation(.easeInOut(duration: 0.3), value: pack.progress)

            Divider()

            VStack(alignment: .leading, spacing: 0) {
                VStack(spacing: 0) {
                    ForEach(Array(activeItems.enumerated()), id: \.element.id) { index, item in
                        NavigationLink(value: item.chain) {
                            ChainRow(item: item, animationDelay: Double(index) * 0.03)
                                .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .buttonStyle(.plain)

                        if index < activeItems.count - 1 || !completedItems.isEmpty {
                            Divider()
                        }
                    }
                }
                .padding(.leading, 12)

                if !completedItems.isEmpty {
                    Text("Completed")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.top, 8)
                        .padding(.bottom, 4)

                    VStack(spacing: 0) {
                        ForEach(Array(completedItems.enumerated()), id: \.element.id) { index, item in
                            NavigationLink(value: item.chain) {
                                ChainRow(
                                    item: item,
                                    animationDelay: Double(activeItems.count + index) * 0.03
                                )
                                .frame(maxWidth: .infinity, alignment: .leading)
                            }
                            .buttonStyle(.plain)
                            .opacity(0.58)

                            if index < completedItems.count - 1 {
                                Divider()
                            }
                        }
                    }
                    .padding(.leading, 12)
                }
            }
        }
        .padding(10)
        .background(
            RoundedRectangle(cornerRadius: 13)
                .fill(Color.white.opacity(0.94))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 13)
                .stroke(BrandPalette.primary.opacity(0.35), lineWidth: 1.2)
        )
        .shadow(color: BrandPalette.primary.opacity(0.09), radius: 7, x: 0, y: 2)
    }
}

private struct CompletedPackDetailView: View {
    let pack: ChainSelectionView.ChainPack

    private var totalTime: Int {
        pack.chains.reduce(0) { partial, chain in
            partial + (SavedProgress.completedElapsedSeconds(for: chain) ?? 0)
        }
    }

    private var totalHints: Int {
        pack.chains.reduce(0) { partial, chain in
            partial + (SavedProgress.completedHintsUsed(for: chain) ?? 0)
        }
    }

    var body: some View {
        List {
            Section("Pack Stats") {
                statRow("Chains Completed", "\(pack.completedCount)/\(pack.chains.count)")
                statRow("Total Time", SavedProgress.formatElapsedTime(totalTime))
                statRow("Hints Used", "\(totalHints)")
            }

            Section("Chains") {
                ForEach(pack.chains.sorted { $0.modifiedDate > $1.modifiedDate }) { chain in
                    VStack(alignment: .leading, spacing: 4) {
                        Text(chain.name)
                            .font(.headline)

                        if let elapsed = SavedProgress.completedElapsedSeconds(for: chain) {
                            if let hints = SavedProgress.completedHintsUsed(for: chain), hints > 0 {
                                let hintWord = hints == 1 ? "hint" : "hints"
                                Text("Completed in \(SavedProgress.formatElapsedTime(elapsed)) • Using \(hints) \(hintWord)")
                                    .font(.caption)
                                    .foregroundColor(BrandPalette.success)
                            } else {
                                Text("Completed in \(SavedProgress.formatElapsedTime(elapsed))")
                                    .font(.caption)
                                    .foregroundColor(BrandPalette.success)
                            }
                        }
                    }
                    .padding(.vertical, 2)
                }
            }
        }
        .navigationTitle(pack.title)
    }

    private func statRow(_ title: String, _ value: String) -> some View {
        HStack {
            Text(title)
            Spacer()
            Text(value)
                .foregroundColor(.secondary)
        }
    }
}

private enum ChainPlayStatus {
    case inProgress
    case unplayed
    case completed
}

private struct ChainDisplayItem: Identifiable {
    let chain: AnagramChain
    let status: ChainPlayStatus
    let completionRatio: Double?
    let completedLabelText: String?

    var id: UUID { chain.id }
}

private func makeDisplayItem(for chain: AnagramChain) -> ChainDisplayItem {
    let completionRatio = SavedProgress.completionRatio(for: chain)
    let isCompleted = SavedProgress.isCompleted(for: chain)
    let status: ChainPlayStatus

    if isCompleted {
        status = .completed
    } else if let completionRatio, completionRatio > 0 {
        status = .inProgress
    } else {
        status = .unplayed
    }

    return ChainDisplayItem(
        chain: chain,
        status: status,
        completionRatio: completionRatio,
        completedLabelText: isCompleted ? completedText(for: chain) : nil
    )
}

private func statusRank(_ status: ChainPlayStatus) -> Int {
    switch status {
    case .inProgress:
        return 0
    case .unplayed:
        return 1
    case .completed:
        return 2
    }
}

private func completedText(for chain: AnagramChain) -> String {
    if let elapsed = SavedProgress.completedElapsedSeconds(for: chain) {
        if let hints = SavedProgress.completedHintsUsed(for: chain), hints > 0 {
            let hintWord = hints == 1 ? "hint" : "hints"
            return "Completed in \(SavedProgress.formatElapsedTime(elapsed)) • Using \(hints) \(hintWord)"
        }
        return "Completed in \(SavedProgress.formatElapsedTime(elapsed))"
    }
    return "Completed"
}

private struct ChainRow: View {
    let item: ChainDisplayItem
    let animationDelay: Double
    @State private var hasAppeared = false

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(item.chain.name)
                .font(.headline)
                .foregroundColor(.primary)

            if !item.chain.description.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                item.chain.description.lowercased() != "anagram chain" {
                Text(item.chain.description)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .lineLimit(1)
            }

            if item.status == .completed {
                Label(item.completedLabelText ?? "Completed", systemImage: "checkmark.circle.fill")
                    .font(.caption)
                    .foregroundColor(BrandPalette.success)
            } else if let completionRatio = item.completionRatio, completionRatio > 0 {
                VStack(alignment: .leading, spacing: 4) {
                    Label(
                        "In Progress (\(Int((completionRatio * 100).rounded()))%)",
                        systemImage: "arrow.right.circle.fill"
                    )
                    .font(.caption)
                    .foregroundColor(BrandPalette.primary)

                    ProgressView(value: completionRatio)
                        .tint(BrandPalette.primary)
                        .animation(.easeInOut(duration: 0.35), value: completionRatio)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 5)
        .opacity((item.status == .completed ? 0.58 : 1.0) * (hasAppeared ? 1.0 : 0.0))
        .offset(y: hasAppeared ? 0 : 6)
        .animation(.easeOut(duration: 0.28).delay(animationDelay), value: hasAppeared)
        .onAppear {
            hasAppeared = true
        }
    }
}

private extension Array {
    func chunked(into size: Int) -> [[Element]] {
        guard size > 0 else { return [self] }
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}

#Preview {
    ChainSelectionView(chains: [
        AnagramChain(
            name: "Chain 1",
            description: "First test chain",
            difficulty: .easy,
            levels: []
        ),
        AnagramChain(
            name: "Chain 2",
            description: "Second test chain",
            difficulty: .medium,
            levels: []
        )
    ])
}
