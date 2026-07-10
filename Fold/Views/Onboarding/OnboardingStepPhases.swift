import SwiftUI

/// Paso 3/3: el ciclo de un change en lenguaje humano.
struct OnboardingStepPhases: View {
    private struct Phase: Identifiable {
        let id: Int
        let name: String
        let detail: String
    }

    private let phases: [Phase] = [
        Phase(id: 1, name: String(localized: "Idea"), detail: String(localized: "Qué quieres cambiar, en una frase.")),
        Phase(id: 2, name: String(localized: "Plan"), detail: String(localized: "El agente propone qué tocar. Tú decides.")),
        Phase(id: 3, name: String(localized: "Trabajo"), detail: String(localized: "Aislamiento, paso a paso, en directo.")),
        Phase(id: 4, name: String(localized: "Revisión"), detail: String(localized: "Diff, specs y artefactos contra criterios.")),
        Phase(id: 5, name: String(localized: "Cierre"), detail: String(localized: "Archivo. El aprendizaje persiste.")),
    ]

    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Paso 3 de 3")
                    .font(.caption.monospaced())
                    .foregroundStyle(Color.foldAction)
                    .textCase(.uppercase)
                Text("Cómo trabajamos")
                    .font(.largeTitle.weight(.semibold))
                Text("Cada cambio vive un ciclo. Tú piensas y decides; el agente ejecuta. Sin vocabulario nuevo que aprender.")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }

            HStack(alignment: .top, spacing: 10) {
                ForEach(phases) { phase in
                    VStack(alignment: .leading, spacing: 8) {
                        Text(String(format: "%02d", phase.id))
                            .font(.caption.monospaced())
                            .foregroundStyle(Color.foldAction)
                        Text(phase.name)
                            .font(.headline)
                        Text(phase.detail)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, minHeight: 120, alignment: .topLeading)
                    .background(.background.secondary, in: .rect(cornerRadius: FoldMetrics.cardRadius))
                    .foldCardBorder()
                }
            }
        }
        .padding(.horizontal, 48)
    }
}
