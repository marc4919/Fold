import SwiftUI

/// Punto de estado con color por significado. El estado no se comunica solo
/// por color: cada kind tiene etiqueta para VoiceOver.
struct StatusDot: View {
    enum Kind {
        case explore
        case ready
        case running
        case review
        case archived
        case success

        var color: Color {
            switch self {
            case .explore: .teal
            case .ready: .yellow
            case .running: .foldInfo
            case .review: .foldReview
            case .archived: .gray
            case .success: .foldSuccess
            }
        }

        var accessibilityLabel: String {
            switch self {
            case .explore: String(localized: "explorando")
            case .ready: String(localized: "listo para implementar")
            case .running: String(localized: "implementando")
            case .review: String(localized: "en revisión")
            case .archived: String(localized: "archivado")
            case .success: String(localized: "completado")
            }
        }
    }

    let kind: Kind
    var pulses = false
    var size: CGFloat = 8

    @State private var pulsing = false
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Circle()
            .fill(kind.color)
            .frame(width: size, height: size)
            .overlay {
                if pulses, !reduceMotion {
                    Circle()
                        .stroke(kind.color.opacity(0.6), lineWidth: 1.5)
                        .scaleEffect(pulsing ? 2.4 : 1)
                        .opacity(pulsing ? 0 : 0.8)
                        .animation(.easeOut(duration: 1.4).repeatForever(autoreverses: false), value: pulsing)
                }
            }
            .onAppear { pulsing = pulses && !reduceMotion }
            .accessibilityLabel(kind.accessibilityLabel)
    }
}
