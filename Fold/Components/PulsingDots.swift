import SwiftUI

/// Tres puntos con pulso — el "está trabajando" de Fold.
struct PulsingDots: View {
    var tint: Color = .secondary
    var size: CGFloat = 5

    @State private var animating = false

    var body: some View {
        HStack(spacing: size * 0.8) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(tint)
                    .frame(width: size, height: size)
                    .scaleEffect(animating ? 1.0 : 0.55)
                    .opacity(animating ? 1.0 : 0.4)
                    .animation(
                        .easeInOut(duration: 0.5)
                            .repeatForever(autoreverses: true)
                            .delay(Double(index) * 0.16),
                        value: animating
                    )
            }
        }
        .onAppear { animating = true }
    }
}
