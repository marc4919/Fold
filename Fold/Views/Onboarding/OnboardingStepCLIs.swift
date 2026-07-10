import SwiftUI

/// Paso 2/3: grid de cards CLI con selección múltiple y un único default.
struct OnboardingStepCLIs: View {
    @Binding var clis: [AgentCLI]

    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            VStack(alignment: .leading, spacing: 6) {
                Text("Paso 2 de 3")
                    .font(.caption.monospaced())
                    .foregroundStyle(Color.foldAction)
                    .textCase(.uppercase)
                Text("¿Qué CLIs usas?")
                    .font(.largeTitle.weight(.semibold))
                Text("Marca los agentes que tienes instalados. Fold usará los que ya estén autenticados en tu terminal — sin configurar nada.")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }

            LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                ForEach($clis) { $cli in
                    CLICard(cli: $cli) {
                        toggle(cli.id)
                    } makeDefault: {
                        makeDefault(cli.id)
                    }
                }
            }
        }
        .padding(.horizontal, 48)
    }

    private func toggle(_ id: String) {
        guard let index = clis.firstIndex(where: { $0.id == id }), clis[index].isDetected else { return }
        clis[index].isSelected.toggle()

        if !clis[index].isSelected, clis[index].isDefault {
            clis[index].isDefault = false
            if let first = clis.firstIndex(where: { $0.isSelected }) {
                clis[first].isDefault = true
            }
        } else if clis[index].isSelected, !clis.contains(where: { $0.isDefault }) {
            clis[index].isDefault = true
        }
    }

    private func makeDefault(_ id: String) {
        for index in clis.indices {
            clis[index].isDefault = clis[index].id == id
        }
    }
}

private struct CLICard: View {
    @Binding var cli: AgentCLI
    let toggle: () -> Void
    let makeDefault: () -> Void

    var body: some View {
        Button(action: toggle) {
            HStack(spacing: 12) {
                Text(cli.abbreviation)
                    .font(.subheadline.weight(.bold).monospaced())
                    .frame(width: 38, height: 38)
                    .background(
                        cli.isSelected ? Color.foldAction.opacity(0.2) : Color.gray.opacity(0.12),
                        in: .rect(cornerRadius: 9)
                    )
                    .foregroundStyle(cli.isSelected ? Color.foldAction : .secondary)

                VStack(alignment: .leading, spacing: 2) {
                    Text(cli.name)
                        .font(.body.weight(.medium))
                    Text(cli.isDetected
                         ? (cli.version ?? "")
                         : String(localized: "no instalado"))
                        .font(.caption.monospaced())
                        .foregroundStyle(.secondary)
                }

                Spacer()

                if cli.isSelected {
                    if cli.isDefault {
                        Text("por defecto")
                            .font(.caption2.weight(.semibold))
                            .padding(.horizontal, 8)
                            .padding(.vertical, 3)
                            .background(Color.foldAction.opacity(0.18), in: .capsule)
                            .foregroundStyle(Color.foldAction)
                    } else {
                        Button("hacer default") { makeDefault() }
                            .buttonStyle(.plain)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.foldAction)
                }
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.background.secondary, in: .rect(cornerRadius: FoldMetrics.cardRadius))
            .overlay(
                RoundedRectangle(cornerRadius: FoldMetrics.cardRadius)
                    .strokeBorder(
                        cli.isSelected ? Color.foldAction.opacity(0.5) : Color.primary.opacity(0.08),
                        lineWidth: 1
                    )
            )
            .opacity(cli.isDetected ? 1 : 0.45)
            .contentShape(.rect)
        }
        .buttonStyle(.plain)
        .disabled(!cli.isDetected)
        .animation(.smooth(duration: 0.2), value: cli.isSelected)
        .animation(.smooth(duration: 0.2), value: cli.isDefault)
    }
}
