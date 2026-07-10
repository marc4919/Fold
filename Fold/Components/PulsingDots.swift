import SwiftUI

/// Tres puntos con pulso — el "está trabajando" de Fold.
/// Con Reduce Motion activo los puntos quedan estáticos.
struct PulsingDots: View {
    var tint: Color = .secondary
    var size: CGFloat = 5

    @State private var animating = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        HStack(spacing: size * 0.8) {
            ForEach(0..<3, id: \.self) { index in
                Circle()
                    .fill(tint)
                    .frame(width: size, height: size)
                    .scaleEffect(animating ? 1.0 : 0.55)
                    .opacity(animating ? 1.0 : 0.4)
                    .animation(
                        reduceMotion ? nil : .easeInOut(duration: 0.5)
                            .repeatForever(autoreverses: true)
                            .delay(Double(index) * 0.16),
                        value: animating
                    )
            }
        }
        .onAppear { animating = !reduceMotion }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(String(localized: "El agente está trabajando"))
    }
}
