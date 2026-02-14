//
//  LetterTileView.swift
//  AnagramStackClient
//
//  Wordle-style letter tile component
//

import SwiftUI

struct LetterTileView: View {
    let tile: LetterTile
    let isSelected: Bool
    let isDragging: Bool
    var size: CGFloat = 60
    @State private var hintPulse = false

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(backgroundColor)
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(borderColor, lineWidth: tile.isHintLocked ? 1.5 : 1)
                )
                .shadow(color: shadowColor, radius: 2, x: 0, y: 1)

            if isSelected {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(BrandPalette.primary, lineWidth: 3)
            }

            Text(String(tile.letter))
                .font(.system(size: fontSize, weight: .bold, design: .rounded))
                .foregroundColor(textColor)
        }
        .frame(width: size, height: size)
        .scaleEffect(hintPulse ? 1.06 : (isSelected ? 1.08 : 1.0))
        .animation(.spring(response: 0.26, dampingFraction: 0.72), value: isSelected)
        .onChange(of: tile.isHintLocked) { isHintLocked in
            guard isHintLocked else { return }
            hintPulse = true
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.22) {
                hintPulse = false
            }
        }
    }

    private var backgroundColor: Color {
        if tile.isLocked {
            return BrandPalette.success.opacity(0.25)
        }
        if tile.isHintLocked {
            return BrandPalette.hint.opacity(0.28)
        }
        return Color.white.opacity(0.92)
    }

    private var textColor: Color {
        if tile.isLocked {
            return BrandPalette.success
        }
        if tile.isHintLocked {
            return BrandPalette.hint
        }
        return Color.primary
    }

    private var borderColor: Color {
        if tile.isLocked {
            return BrandPalette.success.opacity(0.45)
        }
        if tile.isHintLocked {
            return BrandPalette.hint.opacity(0.4)
        }
        return Color.black.opacity(0.08)
    }

    private var shadowColor: Color {
        Color.black.opacity(0.12)
    }

    private var fontSize: CGFloat {
        // Scale font size based on tile size
        return size * 0.5 // Font is 50% of tile size
    }
}

#Preview {
    HStack(spacing: 12) {
        LetterTileView(
            tile: LetterTile(letter: "A", position: 0),
            isSelected: false,
            isDragging: false
        )

        LetterTileView(
            tile: LetterTile(letter: "B", position: 1),
            isSelected: true,
            isDragging: false
        )

        LetterTileView(
            tile: LetterTile(letter: "C", position: 2, isLocked: true),
            isSelected: false,
            isDragging: false
        )
    }
    .padding()
}
