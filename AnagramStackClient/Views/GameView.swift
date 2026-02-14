//
//  GameView.swift
//  AnagramStackClient
//
//  Main game screen with tile interaction and animations
//

import SwiftUI

struct GameView: View {
    @StateObject private var viewModel: GameViewModel
    @State private var invalidShake = false
    @State private var visibleTileCount = 0
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase

    init(chain: AnagramChain, dictionary: WordDictionary = .shared) {
        // Check for saved progress
        let savedState = SavedProgress.loadResumableGameState(for: chain)
        _viewModel = StateObject(wrappedValue: GameViewModel(chain: chain, dictionary: dictionary, savedState: savedState))
    }

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                gradient: Gradient(colors: [
                    BrandPalette.backgroundTop,
                    BrandPalette.backgroundBottom
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
            .ignoresSafeArea()

            VStack(spacing: 20) {
                // Header
                header

                Spacer()

                // Game board - fixed position from top
                VStack(alignment: .leading, spacing: 16) {
                    // Completed rows (locked at top)
                    ForEach(Array(viewModel.completedRows.enumerated()), id: \.offset) { index, tiles in
                        RowView(tiles: tiles, isLocked: true)
                    }

                    // Current active row with typewriter effect
                    if !viewModel.isGameComplete {
                        currentRow
                    }

                    // Spacer to prevent content from centering
                    Spacer()
                }
                .padding(.top, 40) // Fixed distance from top
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.leading, 20)
                .offset(x: invalidShake ? -10 : 0)
                .animation(
                    invalidShake ? Animation.linear(duration: 0.1).repeatCount(5, autoreverses: true) : .default,
                    value: invalidShake
                )

                Spacer()

                instructionText

                // Submit button
                submitButton
            }
            .padding()

            // Feedback overlays
            if viewModel.showingValidFeedback {
                FeedbackOverlay(message: viewModel.feedbackMessage, isValid: true)
            }

            if viewModel.showingInvalidFeedback {
                FeedbackOverlay(message: viewModel.feedbackMessage, isValid: false)
            }
        }
        .sheet(isPresented: $viewModel.showingWinScreen) {
            WinScreen(onRestart: {
                viewModel.restartGame()
            }, onChooseAnotherChain: {
                viewModel.showingWinScreen = false
                dismiss()
            })
        }
        .onChange(of: viewModel.showingInvalidFeedback) { oldValue, newValue in
            if newValue {
                invalidShake = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                    invalidShake = false
                }
            }
        }
        .onChange(of: viewModel.showingValidFeedback) { oldValue, newValue in
            if newValue {
                playSuccessAnimation()
            }
        }
        .onChange(of: viewModel.currentTiles.count) { oldValue, newValue in
            // Trigger typewriter when new tiles appear
            if newValue > 0 {
                showTilesTypewriter()
            }
        }
        .onAppear {
            // Show initial tiles on first load
            showTilesTypewriter()
            viewModel.startSolvingTimer()
        }
        .onDisappear {
            viewModel.pauseSolvingTimer()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                viewModel.startSolvingTimer()
            } else {
                viewModel.pauseSolvingTimer()
            }
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(alignment: .top) {
            // Close button
            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .font(.title2)
                    .foregroundColor(.secondary)
            }

            Spacer()

            // Progress indicator
            VStack(spacing: 4) {
                Text("Level \(viewModel.currentLevelNumber)")
                    .font(.headline)
                    .foregroundColor(BrandPalette.textPrimary)

                Text(viewModel.currentLevelInfo)
                    .font(.caption)
                    .foregroundColor(BrandPalette.textSecondary)

                Text(viewModel.formattedElapsedTime)
                    .font(.caption2)
                    .foregroundColor(BrandPalette.textSecondary)

                ProgressView(value: viewModel.progressPercentage)
                    .tint(BrandPalette.primary)
                    .frame(width: 120)
                    .animation(.easeInOut(duration: 0.35), value: viewModel.progressPercentage)
            }

            Spacer()

            Button {
                viewModel.activateHelp()
            } label: {
                Image(systemName: "questionmark.circle.fill")
                    .font(.title)
                    .foregroundColor(viewModel.helpModeEnabled ? BrandPalette.disabled : BrandPalette.control)
            }
            .disabled(viewModel.droppingToNextRow || viewModel.helpModeEnabled)

            // Restart button
            Button {
                viewModel.restartGame()
                visibleTileCount = 0
                showTilesTypewriter()
            } label: {
                Image(systemName: "arrow.counterclockwise.circle.fill")
                    .font(.title)
                    .foregroundColor(BrandPalette.control)
            }
        }
    }

    // MARK: - Current Row

    @Environment(\.horizontalSizeClass) var sizeClass

    private var tileSize: CGFloat {
        // Calculate size to fit 8 letters (maximum) - use this for all rows
        // Use a safe estimate for screen width
        let screenWidth: CGFloat = 400 // Reasonable estimate for most phones
        let padding: CGFloat = 40
        let maxLetters: CGFloat = 8
        let spacing: CGFloat = 8 * (maxLetters - 1)
        let availableWidth = screenWidth - padding - spacing
        let size = availableWidth / maxLetters
        return min(size, 60) // Cap at 60pt
    }

    private var currentRow: some View {
        HStack(spacing: 8) {
            ForEach(Array(viewModel.currentTiles.enumerated()), id: \.element.id) { index, tile in
                if index < visibleTileCount {
                    LetterTileView(
                        tile: tile,
                        isSelected: viewModel.firstTappedTile == tile.id,
                        isDragging: false,
                        size: tileSize
                    )
                    .transition(.scale.combined(with: .opacity))
                    .onTapGesture {
                        // Haptic feedback
                        let impact = UIImpactFeedbackGenerator(style: .light)
                        impact.impactOccurred()

                        viewModel.handleTileTap(tile.id)
                    }
                }
            }
        }
    }

    private func showTilesTypewriter() {
        // Reset and show all tiles
        visibleTileCount = 0

        // Wait a brief moment for tiles to be ready, then animate them in
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            let totalTiles = viewModel.currentTiles.count
            for i in 0..<totalTiles {
                DispatchQueue.main.asyncAfter(deadline: .now() + Double(i) * 0.15) {
                    withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                        visibleTileCount = i + 1
                    }
                }
            }
        }
    }

    // MARK: - Animations

    private func playSuccessAnimation() {
        // Animation is now handled by onChange of currentTiles.count
    }

    // MARK: - Submit Button

    private var instructionText: some View {
        Text("Rearrange the letters to create valid words. If you succeed, you unlock a new letter. How quickly can you get to 8 letters")
            .font(.footnote)
            .foregroundColor(BrandPalette.textSecondary)
            .multilineTextAlignment(.center)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(
                RoundedRectangle(cornerRadius: 10)
                    .fill(.ultraThinMaterial)
            )
    }

    private var submitButton: some View {
        HStack(spacing: 12) {
            // Shuffle button
            Button {
                if viewModel.helpModeEnabled {
                    viewModel.applyShuffleHint()
                } else {
                    viewModel.shuffleTiles()
                }
            } label: {
                HStack {
                    Image(systemName: "shuffle")
                    Text(viewModel.helpModeEnabled ? "Shuffle Hint" : "Shuffle")
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(shuffleButtonColor)
                .cornerRadius(12)
                .shadow(color: shuffleButtonDisabled ? .clear : Color.black.opacity(0.08), radius: 4, x: 0, y: 2)
            }
            .disabled(shuffleButtonDisabled)

            // Submit button
            Button {
                Task {
                    await viewModel.submitWord()
                }
            } label: {
                HStack {
                    Image(systemName: "checkmark.circle.fill")
                    Text("Submit")
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding()
                .background(BrandPalette.primary)
                .cornerRadius(12)
                .shadow(color: viewModel.droppingToNextRow ? .clear : Color.black.opacity(0.1), radius: 5, x: 0, y: 2)
            }
            .disabled(viewModel.droppingToNextRow)
        }
    }

    private var shuffleButtonDisabled: Bool {
        if viewModel.droppingToNextRow { return true }
        if viewModel.helpModeEnabled { return !viewModel.canUseShuffleHint }
        return false
    }

    private var shuffleButtonColor: Color {
        if shuffleButtonDisabled { return BrandPalette.disabled }
        return viewModel.helpModeEnabled ? BrandPalette.hint : BrandPalette.secondary
    }
}

// MARK: - Row View

struct RowView: View {
    let tiles: [LetterTile]
    let isLocked: Bool

    private var tileSize: CGFloat {
        // Use same calculation as current row for uniformity
        let screenWidth: CGFloat = 400
        let padding: CGFloat = 40
        let maxLetters: CGFloat = 8
        let spacing: CGFloat = 8 * (maxLetters - 1)
        let availableWidth = screenWidth - padding - spacing
        let size = availableWidth / maxLetters
        return min(size, 60)
    }

    var body: some View {
        HStack(spacing: 8) {
            ForEach(tiles) { tile in
                LetterTileView(
                    tile: tile,
                    isSelected: false,
                    isDragging: false,
                    size: tileSize
                )
            }
        }
        .opacity(isLocked ? 0.5 : 1.0)
    }
}


#Preview {
    let chain = AnagramChain(
        name: "Test Chain",
        description: "Test",
        difficulty: .easy,
        levels: [
            AnagramLevel(letterCount: 3, letters: "CAT", intendedWord: "CAT"),
            AnagramLevel(letterCount: 4, addedLetter: "R", intendedWord: "CART")
        ]
    )

    GameView(chain: chain)
}
