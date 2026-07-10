import SwiftUI

/// Bienvenida suave en tres pasos: Tú · Agentes · Cómo trabajamos.
struct OnboardingView: View {
    @Environment(AppState.self) private var appState

    @State private var step = 0
    @State private var name = ""
    @State private var roles: Set<String> = []
    @State private var clis = SampleData.clis
    @State private var realCLIsLoaded = false

    private let stepTitles = [
        String(localized: "Tú"),
        String(localized: "Agentes"),
        String(localized: "Cómo trabajamos"),
    ]

    var body: some View {
        VStack(spacing: 0) {
            stepper
                .padding(.top, 52)

            Spacer(minLength: 24)

            ZStack {
                switch step {
                case 0:
                    OnboardingStepWho(name: $name, roles: $roles)
                        .transition(stepTransition)
                case 1:
                    OnboardingStepCLIs(clis: $clis)
                        .transition(stepTransition)
                default:
                    OnboardingStepPhases()
                        .transition(stepTransition)
                }
            }
            .frame(maxWidth: 720)
            .animation(.smooth(duration: 0.35), value: step)

            Spacer(minLength: 24)

            footer
                .padding(.horizontal, 48)
                .padding(.bottom, 32)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .onChange(of: appState.detectedAgents.isEmpty) {
            loadRealCLIsIfNeeded()
        }
        .onAppear {
            loadRealCLIsIfNeeded()
        }
    }

    /// Sustituye los datos de ejemplo por la detección real (solo antes de que el usuario toque nada).
    private func loadRealCLIsIfNeeded() {
        guard !realCLIsLoaded, step == 0, !appState.detectedAgents.isEmpty else { return }
        realCLIsLoaded = true
        clis = appState.detectedAgents
    }

    private var stepTransition: AnyTransition {
        .asymmetric(
            insertion: .move(edge: .trailing).combined(with: .opacity),
            removal: .move(edge: .leading).combined(with: .opacity)
        )
    }

    private var stepper: some View {
        HStack(spacing: 10) {
            ForEach(0..<3, id: \.self) { index in
                HStack(spacing: 10) {
                    HStack(spacing: 7) {
                        Circle()
                            .fill(index <= step ? Color.foldAction : Color.gray.opacity(0.35))
                            .frame(width: 7, height: 7)
                        Text(stepTitles[index])
                            .font(.caption.weight(index == step ? .semibold : .regular))
                            .foregroundStyle(index == step ? .primary : .secondary)
                    }
                    if index < 2 {
                        Rectangle()
                            .fill(.quaternary)
                            .frame(width: 36, height: 1)
                    }
                }
            }
        }
    }

    private var footer: some View {
        HStack {
            Button("Configurar luego") { finish(skipped: true) }
                .buttonStyle(.plain)
                .font(.callout)
                .foregroundStyle(.tertiary)

            Spacer()

            Text(String(format: "%02d / 03", step + 1))
                .font(.caption.monospaced())
                .foregroundStyle(.tertiary)

            Spacer()

            HStack(spacing: 10) {
                Button("Volver") {
                    withAnimation(.smooth(duration: 0.35)) { step -= 1 }
                }
                .buttonStyle(.glass)
                .disabled(step == 0)

                Button(step == 2 ? String(localized: "Empezar") : String(localized: "Continuar")) {
                    if step == 2 {
                        finish(skipped: false)
                    } else {
                        withAnimation(.smooth(duration: 0.35)) { step += 1 }
                    }
                }
                .buttonStyle(.glassProminent)
            }
        }
    }

    private func finish(skipped: Bool) {
        if !skipped {
            appState.profile.name = name
            appState.profile.roles = roles
            appState.profile.clis = clis
        }
        appState.completeOnboarding()
    }
}

#Preview {
    OnboardingView()
        .environment(AppState())
        .frame(width: 1280, height: 800)
}
