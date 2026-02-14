//
//  WinScreen.swift
//  AnagramStackClient
//
//  Victory screen displayed when player completes all 6 levels
//

import SwiftUI

struct WinScreen: View {
    let onRestart: () -> Void
    let onChooseAnotherChain: () -> Void
    @Environment(\.dismiss) private var dismiss

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

            VStack(spacing: 32) {
                Spacer()

                // Trophy icon with animation
                Image(systemName: "trophy.fill")
                    .font(.system(size: 80))
                    .foregroundColor(BrandPalette.trophy)
                    .shadow(radius: 10)
                    .scaleEffect(animationPhase ? 1.05 : 1.0)
                    .animation(
                        Animation.easeInOut(duration: 1.6).repeatForever(autoreverses: true),
                        value: animationPhase
                    )

                // Congratulations text
                VStack(spacing: 12) {
                    Text("Congratulations!")
                        .font(.system(size: 40, weight: .bold))
                        .foregroundColor(.primary)

                    Text("You completed the anagram chain!")
                        .font(.title3)
                        .foregroundColor(.secondary)
                }

                Spacer()

                // Actions
                VStack(spacing: 16) {
                    Button {
                        onRestart()
                        dismiss()
                    } label: {
                        Text("Play Again")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(BrandPalette.success)
                            .cornerRadius(12)
                    }

                    Button {
                        onChooseAnotherChain()
                    } label: {
                        Text("Choose Another Chain")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(BrandPalette.primary)
                            .cornerRadius(12)
                    }
                }
                .padding(.horizontal, 40)

                Spacer()
                    .frame(height: 60)
            }
        }
        .onAppear {
            animationPhase = true
        }
    }

    @State private var animationPhase = false
}


#Preview {
    WinScreen(onRestart: {}, onChooseAnotherChain: {})
}
