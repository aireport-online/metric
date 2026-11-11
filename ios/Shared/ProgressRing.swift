import SwiftUI

/// Voortgangsring voor het weekdoel. Gedeeld door de iPhone- en de Watch-app.
struct ProgressRing: View {
    let progress: Double
    var lineWidth: CGFloat = 14

    private var clamped: Double {
        min(max(progress, 0), 1)
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.accentColor.opacity(0.2), lineWidth: lineWidth)
            Circle()
                .trim(from: 0, to: clamped)
                .stroke(Color.accentColor, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))
                .animation(.easeOut(duration: 0.6), value: clamped)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Weekdoel")
        .accessibilityValue("\(Int((clamped * 100).rounded())) procent")
    }
}
