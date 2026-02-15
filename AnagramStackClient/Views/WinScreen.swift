//
//  WinScreen.swift
//  AnagramStackClient
//
//  Compact completion overlay card
//

import SwiftUI

struct WinScreen: View {
    let onRestart: () -> Void
    let onChooseAnotherChain: () -> Void

    var body: some View {
        VStack(spacing: 16) {
            Text("Congratulations")
                .font(.title3.weight(.bold))
                .foregroundColor(.primary)

            HStack(spacing: 10) {
                Button {
                    onRestart()
                } label: {
                    Text("Play Again")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(BrandPalette.success)
                        .cornerRadius(10)
                }

                Button {
                    onChooseAnotherChain()
                } label: {
                    Text("New Chain")
                        .font(.subheadline.weight(.semibold))
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(BrandPalette.primary)
                        .cornerRadius(10)
                }
            }
        }
        .padding(16)
        .frame(maxWidth: 320)
        .background(
            RoundedRectangle(cornerRadius: 14)
                .fill(.ultraThinMaterial)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 14)
                .stroke(Color.black.opacity(0.08), lineWidth: 1)
        )
        .shadow(color: Color.black.opacity(0.15), radius: 12, x: 0, y: 4)
        .contentShape(RoundedRectangle(cornerRadius: 14))
        .onTapGesture {
            // Consume taps so only outside area dismisses.
        }
    }
}

#Preview {
    ZStack {
        Color.gray.opacity(0.2).ignoresSafeArea()
        WinScreen(onRestart: {}, onChooseAnotherChain: {})
    }
}
