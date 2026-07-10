import Foundation

/// Tipo de pieza forjable en la Forja.
enum ForgePieceKind: String, CaseIterable, Identifiable {
    case skill
    case agent
    case workflow
    case rule
    case template
    case schema

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .skill: "chevron.left.forwardslash.chevron.right"
        case .agent: "atom"
        case .workflow: "arrow.trianglehead.swap"
        case .rule: "text.justify.left"
        case .template: "square.grid.3x1.below.line.grid.1x2"
        case .schema: "diamond"
        }
    }

    var title: String {
        switch self {
        case .skill: String(localized: "Skill")
        case .agent: String(localized: "Agente")
        case .workflow: String(localized: "Workflow")
        case .rule: String(localized: "Regla")
        case .template: String(localized: "Plantilla de cambio")
        case .schema: String(localized: "Esquema")
        }
    }

    var summary: String {
        switch self {
        case .skill: String(localized: "Capacidad reutilizable empaquetada, como «tests Vapor» o «migración Postgres».")
        case .agent: String(localized: "Qué CLI y modelo usa, su rol, qué puede tocar y su nivel de aislamiento.")
        case .workflow: String(localized: "Flujo de fases propio. Parte del estándar o crea uno nuevo.")
        case .rule: String(localized: "Restricción que los agentes respetan siempre: convenciones, límites, naming.")
        case .template: String(localized: "Andamiaje pre-rellenado para cambios recurrentes.")
        case .schema: String(localized: "Cambia la forma misma de specs y deltas de OpenSpec. Avanzado.")
        }
    }

    var location: String {
        switch self {
        case .skill: ".workspace/skills/"
        case .agent: "config"
        case .workflow: "workflow"
        case .rule: "CLAUDE.md"
        case .template: "templates"
        case .schema: "schema"
        }
    }

    var isAdvanced: Bool { self == .schema }

    /// Ejemplo que se muestra en el estado preview de la Forja.
    var previewExample: String {
        switch self {
        case .skill:
            """
            Nombre: nombre-de-skill
            Ruta: .workspace/skills/nueva-skill/SKILL.md

            Cuándo se usa: cuando una task implique escribir tests de integración.
            Qué hace:
            · Levanta una BD efímera con testcontainers
            · Genera el caso feliz y dos de error
            · Verifica el contrato contra la spec
            """
        case .agent:
            """
            Nombre: Nuevo agente

            CLI: Claude Code
            Modelo: claude-opus-4.7
            Rol: implementador
            Puede tocar: internal/, api/
            Aislamiento: worktree · sandbox L3
            """
        case .workflow:
            """
            Nombre: mi-flujo
            Ruta: openspec/profiles/custom.yaml

            Fases: Explorar → Idea → Plan → Trabajo → Revisión
            Comandos opsx: explore · propose · apply · verify · archive
            """
        case .rule:
            """
            Nombre: nueva-regla
            Vive en: CLAUDE.md

            Ejemplo: «toda autenticación pasa por SessionManager».
            Los agentes la respetan en cada sesión, sin excepciones.
            """
        case .template:
            """
            Nombre: plantilla-endpoint
            Vive en: templates/

            Pre-rellena proposal, tasks y deltas para cambios
            recurrentes como añadir un endpoint REST.
            """
        case .schema:
            """
            Nombre: esquema-custom
            Vive en: schema/

            Redefine la estructura de specs y deltas.
            Solo si sabes lo que haces.
            """
        }
    }
}

/// Pieza existente en el Inventario.
struct InventoryPiece: Identifiable {
    let id = UUID()
    let name: String
    let detail: String
    let badges: [String]
    let previewText: String
}

/// Grupo del Inventario (Skills, Agentes, Workflows, Reglas).
struct InventoryGroup: Identifiable {
    let id = UUID()
    let title: String
    let pieces: [InventoryPiece]
}
