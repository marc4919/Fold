import SwiftUI

/// Lectura del terreno. Con carpeta real hace los checks de verdad
/// (agentes, OpenSpec, memoria); en demo los simula.
struct ProjectSetupView: View {
    @Environment(AppState.self) private var appState

    @State private var checks = SampleData.setupChecks
    @State private var showConfirmCard = false
    @State private var isReady = false
    @State private var statusText = String(localized: "leyendo el repo…")

    private var isReal: Bool { appState.pendingProjectURL != nil }

    private var headerPath: String {
        if let url = appState.pendingProjectURL {
            appState.displayPath(url)
        } else {
            "~/code/acme/api"
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 28) {
            header

            VStack(spacing: 10) {
                ForEach(checks) { check in
                    SetupCheckRow(check: check)
                }
            }

            if showConfirmCard {
                confirmCard
                    .transition(.move(edge: .top).combined(with: .opacity))
            }

            Spacer()

            footer
        }
        .padding(48)
        .frame(maxWidth: 680)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .task {
            if isReal {
                await runRealSetup()
            } else {
                await runDemoSetup()
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(headerPath)
                .font(.caption.monospaced())
                .foregroundStyle(Color.foldAction)
            Text("Leyendo el terreno")
                .font(.largeTitle.weight(.semibold))
            Text("No configuras nada: Fold lee el repo y se adapta. Agentes, OpenSpec y memoria, detectados solos.")
                .font(.body)
                .foregroundStyle(.secondary)
        }
    }

    private var confirmCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Voy a tocar tu repo")
                .font(.headline)
            Text("OpenSpec no está inicializado. Para trabajar necesito crear estos archivos — todos planos, versionados con git, tuyos:")
                .font(.callout)
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 6) {
                ForEach(SampleData.setupFilesToCreate, id: \.path) { file in
                    HStack(spacing: 10) {
                        Image(systemName: "plus")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(Color.foldSuccess)
                        Text(file.path)
                            .font(.callout.monospaced())
                        Text(file.note)
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                        Spacer()
                    }
                }
            }
            .padding(12)
            .background(.background, in: .rect(cornerRadius: 8))

            HStack(spacing: 10) {
                Button("Crear archivos y continuar") { confirmWrites() }
                    .buttonStyle(.glassProminent)
                Button("Cancelar") { appState.navigate(to: .selector) }
                    .buttonStyle(.glass)
            }
        }
        .foldCard()
        .foldCardBorder(.foldAction)
    }

    private var footer: some View {
        HStack(spacing: 12) {
            StatusDot(kind: isReady ? .success : .running, pulses: !isReady)
            Text(statusText)
                .font(.caption.monospaced())
                .foregroundStyle(.secondary)
            Spacer()
            Button("Abrir proyecto") {
                if let url = appState.pendingProjectURL {
                    appState.activateRealProject(url: url)
                } else {
                    appState.activeProject = SampleData.acmeAPI
                    appState.projectURL = nil
                    appState.sidebarSelection = .home
                }
                appState.navigate(to: .workspace)
            }
            .buttonStyle(.glassProminent)
            .disabled(!isReady)
        }
    }

    // MARK: - Setup real

    private func runRealSetup() async {
        guard let url = appState.pendingProjectURL,
              checks.allSatisfy({ $0.state == .pending }) else { return }
        try? await Task.sleep(for: .seconds(0.4))

        // 1 · Agentes
        setState(0, .running)
        if appState.detectedAgents.isEmpty {
            appState.detectedAgents = await AgentDetector.detect()
        }
        let detected = appState.detectedAgents.filter(\.isDetected)
        setDone(0, detail: detected.isEmpty
            ? String(localized: "ninguna CLI detectada — Fold funcionará en modo lectura")
            : detected.map(\.versionLabel).joined(separator: " · ") + " disponibles")

        // 2 · OpenSpec
        setState(1, .running)
        try? await Task.sleep(for: .seconds(0.5))
        let state = OpenSpecService.read(at: url)
        if !state.isInitialized {
            withAnimation(.snappy) {
                checks[1].state = .waitingConfirmation
                showConfirmCard = true
                statusText = String(localized: "esperando tu confirmación")
            }
            return
        }
        setDone(1, detail: String(localized: "openspec/ inicializado · \(state.specPaths.count) specs · \(state.changes.count) changes activos · \(state.archivedCount) archivados"))

        await runRealMemoryCheck(url: url)
    }

    private func runRealMemoryCheck(url: URL) async {
        setState(2, .running)
        try? await Task.sleep(for: .seconds(0.5))
        let memoryDir = url.appendingPathComponent(".workspace/memory")
        try? FileManager.default.createDirectory(at: memoryDir, withIntermediateDirectories: true)
        let entries = MemoryService.read(at: url)
        setDone(2, detail: String(localized: ".workspace/memory/ listo · \(entries.count) entradas indexadas"))
        finishSetup()
    }

    // MARK: - Setup demo

    private func runDemoSetup() async {
        guard checks.allSatisfy({ $0.state == .pending }) else { return }
        try? await Task.sleep(for: .seconds(0.6))

        for index in checks.indices {
            guard !Task.isCancelled else { return }
            setState(index, .running)
            try? await Task.sleep(for: .seconds(1.1))

            if checks[index].id == 2 {
                withAnimation(.snappy) {
                    checks[index].state = .waitingConfirmation
                    showConfirmCard = true
                    statusText = String(localized: "esperando tu confirmación")
                }
                return
            }
            withAnimation(.snappy) { checks[index].state = .done }
        }
        finishSetup()
    }

    // MARK: - Confirmación

    private func confirmWrites() {
        withAnimation(.snappy) {
            showConfirmCard = false
            statusText = String(localized: "preparando el workspace…")
        }
        Task {
            setState(1, .running)
            if let url = appState.pendingProjectURL {
                do {
                    try OpenSpecService.initializeStructure(at: url, projectName: url.lastPathComponent)
                } catch {
                    appState.toasts.show(String(localized: "Error creando la estructura: \(error.localizedDescription)"))
                }
                try? await Task.sleep(for: .seconds(0.5))
                let state = OpenSpecService.read(at: url)
                setDone(1, detail: String(localized: "openspec/ creado · \(state.specPaths.count) specs · listo para el primer change"))
                await runRealMemoryCheck(url: url)
            } else {
                try? await Task.sleep(for: .seconds(0.9))
                withAnimation(.snappy) { checks[1].state = .done }
                setState(2, .running)
                try? await Task.sleep(for: .seconds(1.1))
                withAnimation(.snappy) { checks[2].state = .done }
                finishSetup()
            }
        }
    }

    // MARK: - Helpers

    private func setState(_ index: Int, _ state: SetupCheck.State) {
        withAnimation(.snappy) { checks[index].state = state }
    }

    private func setDone(_ index: Int, detail: String) {
        withAnimation(.snappy) {
            checks[index] = SetupCheck(
                id: checks[index].id,
                name: checks[index].name,
                pendingDetail: checks[index].pendingDetail,
                runningDetail: checks[index].runningDetail,
                doneDetail: detail,
                state: .done
            )
        }
    }

    private func finishSetup() {
        withAnimation(.snappy) {
            isReady = true
            statusText = String(localized: "terreno leído · todo listo")
        }
    }
}

private struct SetupCheckRow: View {
    let check: SetupCheck

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                switch check.state {
                case .pending:
                    Text("\(check.id)")
                        .font(.callout.weight(.semibold).monospaced())
                        .foregroundStyle(.tertiary)
                case .running, .waitingConfirmation:
                    ProgressView()
                        .controlSize(.small)
                case .done:
                    Image(systemName: "checkmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(Color.foldSuccess)
                }
            }
            .frame(width: 32, height: 32)
            .background(.background, in: .circle)

            VStack(alignment: .leading, spacing: 2) {
                Text(check.name)
                    .font(.body.weight(.medium))
                Text(check.detail)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .contentTransition(.opacity)
            }

            Spacer()

            Text(check.actionLabel)
                .font(.caption.monospaced())
                .foregroundStyle(check.state == .done ? AnyShapeStyle(Color.foldSuccess) : AnyShapeStyle(.tertiary))
        }
        .padding(14)
        .background(.background.secondary, in: .rect(cornerRadius: FoldMetrics.cardRadius))
        .opacity(check.state == .pending ? 0.6 : 1)
    }
}

#Preview {
    ProjectSetupView()
        .environment(AppState())
        .frame(width: 1280, height: 800)
}
