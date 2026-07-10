import SwiftUI

/// Entrada de la memoria del proyecto.
struct MemoryEntry: Identifiable {
    enum Kind: String, CaseIterable, Identifiable {
        case spec
        case convention
        case decision
        case lesson

        var id: String { rawValue }

        var label: String {
            switch self {
            case .spec: String(localized: "Spec")
            case .convention: String(localized: "Convención")
            case .decision: String(localized: "Decisión")
            case .lesson: String(localized: "Lección")
            }
        }

        var tint: Color {
            switch self {
            case .spec: .foldInfo
            case .convention: .foldAction
            case .decision: .foldMemory
            case .lesson: .foldReview
            }
        }
    }

    let id = UUID()
    let title: String
    let kind: Kind
    let body: String
    let source: String
    let dateLabel: String
    let linkLabel: String
}
