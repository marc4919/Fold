import SwiftUI

/// Color por significado: cada color carga un significado consistente en toda la app.
extension Color {
    /// Acción principal, change listo para actuar.
    static let foldAction = Color.accentColor
    /// Memoria del proyecto.
    static let foldMemory = Color.purple
    /// Éxito, completado, código.
    static let foldSuccess = Color.green
    /// Info, agente, specs.
    static let foldInfo = Color.blue
    /// Destructivo, descartar.
    static let foldDanger = Color.red
    /// Atención, listo para revisar.
    static let foldReview = Color.orange
}

enum FoldMetrics {
    static let cardRadius: CGFloat = 12
    static let controlRadius: CGFloat = 8
}

extension View {
    /// Superficie de contenido estándar (no glass: el glass es para la capa flotante).
    func foldCard(padding: CGFloat = 16) -> some View {
        self
            .padding(padding)
            .background(.background.secondary, in: .rect(cornerRadius: FoldMetrics.cardRadius))
    }

    /// Borde sutil para superficies que necesitan separarse del fondo.
    func foldCardBorder(_ tint: Color = .primary) -> some View {
        self.overlay(
            RoundedRectangle(cornerRadius: FoldMetrics.cardRadius)
                .strokeBorder(tint.opacity(0.12), lineWidth: 1)
        )
    }
}
