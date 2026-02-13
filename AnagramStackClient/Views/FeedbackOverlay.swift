//
//  FeedbackOverlay.swift
//  AnagramStackClient
//
//  Feedback overlay showing valid/invalid word feedback
//

import SwiftUI

struct FeedbackOverlay: View {
    let message: String
    let isValid: Bool

    var body: some View {
        VStack {
            Spacer()

            HStack(spacing: 12) {
                Image(systemName: isValid ? "checkmark.circle.fill" : "xmark.circle.fill")
                    .font(.system(size: 24))

                Text(message)
                    .font(.headline)
            }
            .foregroundColor(.white)
            .padding(.horizontal, 24)
            .padding(.vertical, 16)
            .background(backgroundColor)
            .cornerRadius(12)
            .shadow(radius: 8)
            .transition(.move(edge: .bottom).combined(with: .opacity))

            Spacer()
                .frame(height: 100)
        }
        .animation(.spring(response: 0.4), value: message)
    }

    private var backgroundColor: Color {
        isValid ? Color.green : Color.red
    }
}

#Preview {
    ZStack {
        Color.gray.opacity(0.2)
            .ignoresSafeArea()

        FeedbackOverlay(message: "Great! CAT is valid!", isValid: true)
    }
}
