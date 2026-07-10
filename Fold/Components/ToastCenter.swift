import SwiftUI
import Observation

/// Cola global de toasts efímeros.
@MainActor
@Observable
final class ToastCenter {
    struct Toast: Identifiable, Equatable {
        let id = UUID()
        let message: String
    }

    private(set) var items: [Toast] = []

    func show(_ message: String) {
        let toast = Toast(message: message)
        withAnimation(.spring(duration: 0.35)) {
            items.append(toast)
        }
        Task {
            try? await Task.sleep(for: .seconds(1.9))
            withAnimation(.easeOut(duration: 0.25)) {
                items.removeAll { $0.id == toast.id }
            }
        }
    }
}

/// Overlay inferior que muestra los toasts como cápsulas glass flotantes.
struct ToastOverlay: View {
    let center: ToastCenter

    var body: some View {
        GlassEffectContainer {
            VStack(spacing: 8) {
                ForEach(center.items) { toast in
                    Text(toast.message)
                        .font(.callout)
                        .padding(.horizontal, 18)
                        .padding(.vertical, 10)
                        .glassEffect(.regular, in: .capsule)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
        }
        .padding(.bottom, 28)
        .allowsHitTesting(false)
    }
}
