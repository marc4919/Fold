import SwiftUI

/// Alterna entre modo claro y oscuro (persistido entre sesiones).
struct AppearanceToggleButton: View {
    @Environment(AppState.self) private var appState
    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Button {
            appState.setAppearance(colorScheme == .dark ? .light : .dark)
        } label: {
            Label("Apariencia", systemImage: "circle.lefthalf.filled")
        }
        .help(String(localized: "Alternar modo claro / oscuro"))
    }
}
