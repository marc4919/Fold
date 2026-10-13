import SwiftUI
import Observation

/// Apariencia de la app: sistema, claro u oscuro.
enum AppearanceMode: String {
    case system
    case light
    case dark

    var colorScheme: ColorScheme? {
        switch self {
        case .system: nil
        case .light: .light
        case .dark: .dark
        }
    }
}

/// Estado global de la app: router, overlays, proyecto activo y modo transversal.
@MainActor
@Observable
final class AppState {
    var route: AppRoute = .onboarding
    var sidebarSelection: SidebarSelection = .home

    var activeProject: Project?
    var session: ChangeSession?
    /// Último change abierto (para recrear la sesión al cambiar de change en la sidebar).
    var openedChangeID: String?

    /// Carpeta elegida pendiente de pasar por Setup. `nil` = flujo demo.
    var pendingProjectURL: URL?
    /// Proyecto real activo (la demo no lo usa).
    var projectURL: URL?
    /// Estado OpenSpec leído del disco del proyecto real.
    var openSpecState: OpenSpecState?
    /// Memoria real leída de .workspace/memory/.
    var realMemory: [MemoryEntry] = []
    /// CLIs detectadas en la máquina (detección real al arrancar).
    var detectedAgents: [AgentCLI] = [] {
        didSet { applyStoredDefaultAgent() }
    }
    @ObservationIgnored private var defaultAgentApplied = false

    /// Modo "Ahorro de tokens": sin artefactos visuales en toda la app.
    var frugalMode = false

    var activeSheet: AppSheet?
    var inspector: InspectorContent?

    let toasts = ToastCenter()
    var profile = UserProfile()
    var appearance: AppearanceMode = .system
    /// Modo de aislamiento de las sesiones: "worktree" o "direct".
    var isolationMode = "worktree"

    @ObservationIgnored private var watcher: ProjectWatcher?

    var isRealProject: Bool { projectURL != nil }

    init() {
        // El onboarding solo aparece la primera vez; el primer uso real es el verdadero onboarding.
        if UserDefaults.standard.bool(forKey: "onboardingCompleted") {
            route = .selector
        }
        if let raw = UserDefaults.standard.string(forKey: "appearance"),
           let mode = AppearanceMode(rawValue: raw) {
            appearance = mode
        }
        if let isolation = UserDefaults.standard.string(forKey: "isolationMode") {
            isolationMode = isolation
        }
        loadProfile()
    }

    func setIsolation(_ mode: String) {
        isolationMode = mode
        UserDefaults.standard.set(mode, forKey: "isolationMode")
    }

    /// El agente por defecto elegido por el usuario persiste entre arranques.
    func saveDefaultAgent() {
        if let id = detectedAgents.first(where: \.isDefault)?.id {
            UserDefaults.standard.set(id, forKey: "defaultAgentID")
        }
    }

    private func applyStoredDefaultAgent() {
        guard !defaultAgentApplied, !detectedAgents.isEmpty,
              let storedID = UserDefaults.standard.string(forKey: "defaultAgentID"),
              let index = detectedAgents.firstIndex(where: { $0.id == storedID && $0.isDetected }) else { return }
        defaultAgentApplied = true
        for i in detectedAgents.indices {
            detectedAgents[i].isDefault = i == index
        }
        detectedAgents[index].isSelected = true
    }

    func completeOnboarding() {
        UserDefaults.standard.set(true, forKey: "onboardingCompleted")
        saveProfile()
        navigate(to: .selector)
    }

    func setAppearance(_ mode: AppearanceMode) {
        appearance = mode
        UserDefaults.standard.set(mode.rawValue, forKey: "appearance")
    }

    /// Cierra el proyecto activo y vuelve al selector.
    /// Todo lo que la sesión tuviera en marcha (chat, plan, trabajo) se
    /// cancela y se espera a que muera: sin procesos huérfanos.
    func closeProject() {
        watcher = nil
        if let closing = session {
            Task.detached { await closing.shutdown() }
        }
        session = nil
        openedChangeID = nil
        projectURL = nil
        openSpecState = nil
        realMemory = []
        activeProject = nil
        inspector = nil
        sidebarSelection = .home
        navigate(to: .selector)
    }

    // MARK: - Perfil de usuario

    private struct StoredProfile: Codable {
        var name: String
        var roles: [String]
        var preferences: String
    }

    private func loadProfile() {
        guard let data = UserDefaults.standard.data(forKey: "userProfile"),
              let stored = try? JSONDecoder().decode(StoredProfile.self, from: data) else { return }
        profile.name = stored.name
        profile.roles = Set(stored.roles)
        profile.preferences = stored.preferences
    }

    func saveProfile() {
        let stored = StoredProfile(
            name: profile.name,
            roles: Array(profile.roles),
            preferences: profile.preferences
        )
        if let data = try? JSONEncoder().encode(stored) {
            UserDefaults.standard.set(data, forKey: "userProfile")
        }
    }

    /// Contexto del usuario que se inyecta en los prompts del agente.
    var userContext: String? {
        var parts: [String] = []
        if !profile.name.isEmpty { parts.append(String(localized: "Usuario: \(profile.name).")) }
        if !profile.roles.isEmpty { parts.append(String(localized: "Perfil: \(profile.roles.sorted().joined(separator: ", ")).")) }
        if !profile.preferences.isEmpty { parts.append(String(localized: "Preferencias: \(profile.preferences)")) }
        return parts.isEmpty ? nil : parts.joined(separator: " ")
    }

    /// Memoria del proyecto condensada para los prompts: la app aprende de lo archivado.
    /// Acotada (~1200 caracteres) para no engordar cada llamada al agente.
    var memoryContext: String? {
        guard isRealProject, !realMemory.isEmpty else { return nil }
        var lines: [String] = []
        var budget = 1200
        for entry in realMemory {
            let body = entry.body
                .replacingOccurrences(of: "\n", with: " ")
                .trimmingCharacters(in: .whitespaces)
            let line = "- [\(entry.kind.label)] \(entry.title): \(String(body.prefix(180)))"
            guard budget - line.count > 0 else { break }
            budget -= line.count
            lines.append(line)
        }
        return lines.isEmpty ? nil : lines.joined(separator: "\n")
    }

    /// Solo agentes con autenticación no-fallida: un agente sin sesión no se
    /// selecciona en silencio (fail closed; la UI explica cómo hacer login).
    var defaultAgentBinary: String? {
        let usable = detectedAgents.filter { $0.isDetected && $0.isAuthenticated != false }
        return usable.first(where: \.isDefault)?.binaryPath ?? usable.first?.binaryPath
    }

    var memoryEntries: [MemoryEntry] {
        isRealProject ? realMemory : SampleMemory.entries
    }

    func navigate(to route: AppRoute) {
        withAnimation(.smooth(duration: 0.3)) {
            self.route = route
        }
    }

    // MARK: - Proyecto real

    /// Activa un proyecto real: lee OpenSpec y memoria del disco y construye la vista.
    func activateRealProject(url: URL) {
        let state = OpenSpecService.read(at: url)
        openSpecState = state
        realMemory = MemoryService.read(at: url)
        projectURL = url
        pendingProjectURL = nil
        activeProject = buildProject(url: url, state: state)
        sidebarSelection = .home
        session = nil

        // El filesystem es la fuente de verdad: la UI se refresca sola al cambiar.
        watcher = ProjectWatcher(paths: [
            url.appendingPathComponent("openspec"),
            url.appendingPathComponent(".workspace"),
        ]) { [weak self] in
            self?.refreshRealProject()
        }
    }

    @ObservationIgnored private var isRefreshing = false

    /// Relee el estado del proyecto real desde disco (el filesystem es la fuente de verdad).
    func refreshRealProject() {
        guard let url = projectURL, !isRefreshing else { return }
        isRefreshing = true
        defer { isRefreshing = false }
        let state = OpenSpecService.read(at: url)
        openSpecState = state
        realMemory = MemoryService.read(at: url)
        activeProject = buildProject(url: url, state: state)
    }

    private func buildProject(url: URL, state: OpenSpecState) -> Project {
        let refs = state.changes.map { info in
            ChangeRef(id: info.id, title: info.title, dot: changeDot(info))
        }
        return Project(
            id: url.path,
            name: url.lastPathComponent,
            path: displayPath(url),
            relativeTimeLabel: String(localized: "ahora"),
            statusSummary: refs.isEmpty
                ? String(localized: "sin changes activos")
                : String(localized: "\(refs.count) changes activos"),
            activeChanges: refs,
            archivedCount: state.archivedCount,
            memoryEntryCount: realMemory.count,
            inventoryPieceCount: PiecesService.pieceCount(at: url)
        )
    }

    private func changeDot(_ info: OpenSpecChangeInfo) -> StatusDot.Kind {
        let done = info.tasks.filter(\.done).count
        if info.tasks.isEmpty { return .explore }
        if done == info.tasks.count { return .review }
        if done > 0 { return .running }
        return .ready
    }

    func displayPath(_ url: URL) -> String {
        let home = NSHomeDirectory()
        return url.path.hasPrefix(home)
            ? "~" + url.path.dropFirst(home.count)
            : url.path
    }

    // MARK: - Changes

    /// Abre el dashboard de un change, creando su sesión.
    /// En proyecto real lee el change del disco; en demo usa el change de ejemplo.
    func openChange(id: String, initialState: ChangeState? = nil, seed: String? = nil) {
        // La sesión anterior se apaga del todo antes de crear la nueva:
        // sin procesos huérfanos ni respuestas intercaladas entre changes.
        if let previous = session, openedChangeID != id {
            Task.detached { await previous.shutdown() }
        }
        if isRealProject, let info = openSpecState?.changes.first(where: { $0.id == id }) {
            let agentName = defaultAgentBinary.map { ($0 as NSString).lastPathComponent } ?? "agente"
            let change = OpenSpecService.makeChange(from: info, agentLabel: agentName)
            session = ChangeSession(
                change: change,
                initialState: initialState,
                projectURL: projectURL,
                agentBinary: defaultAgentBinary,
                realInfo: info,
                userContext: userContext,
                memoryContext: memoryContext,
                isolationMode: isolationMode,
                seedPrompt: seed,
                toasts: toasts,
                isFrugal: frugalMode
            )
        } else {
            let state: ChangeState = initialState ?? {
                switch id {
                case "migrate-openapi-31": .review
                case "add-rate-limiting": .planned
                default: .exploring
                }
            }()
            session = ChangeSession(change: SampleData.addAppleLogin, initialState: state)
        }
        openedChangeID = id
        withAnimation(.smooth(duration: 0.25)) {
            sidebarSelection = .change(id)
        }
    }

    /// Crea un change real en openspec/changes/ y lo abre.
    func createRealChange(title: String, initialState: ChangeState) {
        guard let url = projectURL else { return }
        do {
            let info = try OpenSpecService.createChange(at: url, title: title)
            refreshRealProject()
            openChange(id: info.id, initialState: initialState, seed: title)
        } catch {
            toasts.show(String(localized: "No se pudo crear el change: \(error.localizedDescription)"))
        }
    }

    /// Descarta el change activo DE VERDAD: proceso, worktree, rama y directorio.
    func discardActiveChange() {
        guard let session else {
            sidebarSelection = .home
            return
        }
        let info = session.realInfo
        Task {
            await session.discardCleanup()
            if let info {
                do {
                    // Borrado destructivo: solo dentro de openspec/changes/ del proyecto.
                    guard let root = self.projectURL else { throw CocoaError(.fileNoSuchFile) }
                    let changes = root.appendingPathComponent("openspec/changes")
                    let target = try PathGuard.verifyStrictlyInside(info.dirURL, within: changes)
                    try FileManager.default.removeItem(at: target)
                } catch {
                    self.toasts.show(String(localized: "No se pudo borrar el change: \(error.localizedDescription)"))
                }
                self.refreshRealProject()
            }
            self.session = nil
            self.openedChangeID = nil
            self.sidebarSelection = .home
            self.toasts.show(String(localized: "Change descartado — worktree, rama y artefactos eliminados"))
        }
    }

    /// Archiva el change (mueve el directorio al archive), alimenta la memoria
    /// y deja todo VERSIONADO vía la transacción. Devuelve si el cierre completo
    /// fue bien: el estado "Archivado" solo debe mostrarse con true.
    func archiveActiveChange() async -> (ok: Bool, detail: String?) {
        guard isRealProject, let url = projectURL, let session, let info = session.realInfo else {
            return (false, String(localized: "No hay change activo que archivar"))
        }
        let archivedURL: URL
        do {
            archivedURL = try OpenSpecService.archive(info)
        } catch {
            toasts.show(String(localized: "No se pudo archivar: \(error.localizedDescription)"))
            return (false, error.localizedDescription)
        }

        let summary = OpenSpecService.proposalSummary(
            from: session.fileContents[.proposal]?.content ?? info.proposal
        )
        let body = summary.isEmpty
            ? String(localized: "Change «\(session.change.title)» mergeado y archivado.")
            : summary
        let memoryURL = try? MemoryService.add(
            title: session.change.title,
            body: body + "\n\n" + String(localized: "Archivado en openspec/changes/archive/ — el registro completo (exploración, plan, historia) vive allí."),
            kind: .decision,
            at: url
        )

        // Cierre coherente: archive + memoria quedan en su commit y solo
        // entonces se limpian worktree, rama y registro de la transacción.
        // El commit lleva SOLO las rutas de este cierre.
        var closurePaths = [
            "openspec/changes/\(info.id)",
            "openspec/changes/archive/\(archivedURL.lastPathComponent)",
        ]
        if let memoryURL { closurePaths.append(".workspace/memory/\(memoryURL.lastPathComponent)") }

        var finalizeDetail: String?
        if let record = GitChangeTransaction.load(root: url, changeID: info.id) {
            let result = await GitChangeTransaction.finalizeArchive(root: url, record: record, paths: closurePaths)
            if !result.ok {
                toasts.show(String(localized: "El archivo no quedó versionado: \(result.detail)"))
                refreshRealProject()
                return (false, result.detail)
            }
            finalizeDetail = result.detail.isEmpty ? nil : result.detail
        }

        refreshRealProject()
        if let finalizeDetail {
            toasts.show(finalizeDetail)
        }
        return (true, finalizeDetail)
    }

    func toggleInspector(_ content: InspectorContent) {
        withAnimation(.smooth(duration: 0.25)) {
            inspector = inspector == content ? nil : content
        }
    }
}
