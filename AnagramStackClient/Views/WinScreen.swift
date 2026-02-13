//
//  WinScreen.swift
//  AnagramStackClient
//
//  Victory screen displayed when player completes all 6 levels
//

import SwiftUI

struct WinScreen: View {
    let onRestart: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ZStack {
            // Background gradient
            LinearGradient(
                gradient: Gradient(colors: [
                    Color.green.opacity(0.3),
                    Color.blue.opacity(0.3)
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
                    .foregroundColor(.yellow)
                    .shadow(radius: 10)
                    .scaleEffect(animationPhase ? 1.1 : 1.0)
                    .animation(
                        Animation.easeInOut(duration: 0.8).repeatForever(autoreverses: true),
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
                            .background(Color.green)
                            .cornerRadius(12)
                    }

                    Button {
                        dismiss()
                    } label: {
                        Text("Choose Another Chain")
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.blue)
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
    WinScreen(onRestart: {})
}
