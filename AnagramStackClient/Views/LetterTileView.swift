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

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 8)
                .fill(backgroundColor)
                .shadow(color: shadowColor, radius: 2, x: 0, y: 2)

            if isSelected {
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color.blue, lineWidth: 3)
            }

            Text(String(tile.letter))
                .font(.system(size: fontSize, weight: .bold, design: .rounded))
                .foregroundColor(textColor)
        }
        .frame(width: size, height: size)
        .scaleEffect(isSelected ? 1.1 : 1.0)
        .animation(.spring(response: 0.3), value: isSelected)
    }

    private var backgroundColor: Color {
        if tile.isLocked {
            return Color.green.opacity(0.3)
        }
        return Color(white: 0.9)
    }

    private var textColor: Color {
        tile.isLocked ? Color.green.opacity(0.8) : Color.primary
    }

    private var shadowColor: Color {
        Color.black.opacity(0.15)
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
