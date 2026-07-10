import SwiftUI

/// Punto de estado con color por significado.
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
    }

    let kind: Kind
    var pulses = false
    var size: CGFloat = 8

    @State private var pulsing = false

    var body: some View {
        Circle()
            .fill(kind.color)
            .frame(width: size, height: size)
            .overlay {
                if pulses {
                    Circle()
                        .stroke(kind.color.opacity(0.6), lineWidth: 1.5)
                        .scaleEffect(pulsing ? 2.4 : 1)
                        .opacity(pulsing ? 0 : 0.8)
                        .animation(.easeOut(duration: 1.4).repeatForever(autoreverses: false), value: pulsing)
                }
            }
            .onAppear { pulsing = pulses }
    }
}
