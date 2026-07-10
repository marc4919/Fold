import SwiftUI
import Observation
import UserNotifications

enum WorkMode {
    case stream
    case agents
}

enum ExecVerdict {
    case parallel
    case serial
}

/// Evento persistido del timeline del change (history.json en el change dir).
nonisolated struct StoredHistoryEvent: Codable, Sendable {
    var stage: String      // explore | idea | plan | work | review
    var actor: String      // human | agent | system
    var date: Date
    var text: String
    var detail: String?
}

/// Estado vivo del change activo: state machine, tabs progresivas,
/// y la sesión del agente (real en proyectos abiertos, simulada en la demo).
@MainActor
@Observable
final class ChangeSession {
    var change: Change
    private(set) var state: ChangeState
    var activeTab: DashboardTab

    /// Proyecto real al que pertenece el change (nil = demo).
    let projectURL: URL?
    /// Binario del agente de la sesión (cambiable desde el selector de la toolbar).
    private(set) var agentBinary: String?
    /// Change real en disco — siempre apunta al árbol principal (para archivar).
    var realInfo: OpenSpecChangeInfo?
    /// Contexto del usuario (perfil + preferencias) que acompaña a cada prompt.
    let userContext: String?
    /// Memoria del proyecto condensada: decisiones y reglas que los prompts deben respetar.
    let memoryContext: String?
    /// Modo de aislamiento del proyecto: "worktree" o "direct".
    let isolationMode: String
    /// Frase inicial del change: arranca la exploración sola.
    let seedPrompt: String?
    /// Canal de avisos al usuario (errores de escritura, git…).
    private let toasts: ToastCenter?
    /// Modo ahorro de tokens: los prompts piden concisión.
    var isFrugal = false

    /// Continuidad: id de sesión del CLI (claude/codex la emiten; el resto usa transcripción).
    private(set) var agentSessionID: String?
    /// Transcripción reciente para agentes sin resume.
    @ObservationIgnored private var transcript: [(question: String, answer: String)] = []

    var isReal: Bool { realInfo != nil }
    var canRunAgent: Bool { isReal && agentBinary != nil }

    var chatMessages: [ExploreMessage]
    var isAgentThinking = false
    var fileContents: [ChangeFileKey: ChangeFileContent]

    /// Artefacto vivo de la exploración: crece con cada intercambio.
    var explorationLog = ""

    // Estados de progreso del flujo
    var isLandingIdea = false
    var isGeneratingPlan = false
    var planProgressText: String?
    var isPreparingReview = false
    var isMerging = false
    var regeneratingVoice: ClosingVoice.Kind?

    // Plan
    var execVerdict: ExecVerdict = .parallel

    // Trabajo
    var workMode: WorkMode = .stream
    var streamEvents: [StreamEvent] = []
    var terminalLines: [String] = []
    var sessionMinutes = 0
    var sessionTokens = "0"
    var runNumber = 1
    /// Estimación en vivo (chars/4) hasta que el CLI reporta el uso real.
    @ObservationIgnored private var approxOutputChars = 0
    @ObservationIgnored private var receivedRealUsage = false
    /// Fin real de la sesión de trabajo (para la duración del Cierre).
    private(set) var sessionEnd: Date?
    var isPaused = false
    var orchNodes: [OrchNode] = SampleData.orchNodes
    var orchStep = 0
    private(set) var sessionStart: Date?
    /// Donde trabaja el agente: worktree aislado o el árbol principal.
    private(set) var workingDirURL: URL?
    /// Feedback pendiente para la siguiente sesión (Iterar / Intervenir).
    private var pendingInstruction: String?

    // Revisión
    var loadedReviewLanes: [ReviewLane]?
    var reviewVerdict: String?

    // Historia persistida — observable para que el drawer se actualice en vivo.
    private var historyLog: [StoredHistoryEvent] = []

    @ObservationIgnored private var streamTask: Task<Void, Never>?
    @ObservationIgnored private var chatTask: Task<Void, Never>?
    @ObservationIgnored private var planTask: Task<Void, Never>?
    @ObservationIgnored private var seedStarted = false

    init(
        change: Change,
        initialState: ChangeState? = nil,
        projectURL: URL? = nil,
        agentBinary: String? = nil,
        realInfo: OpenSpecChangeInfo? = nil,
        userContext: String? = nil,
        memoryContext: String? = nil,
        isolationMode: String = "worktree",
        seedPrompt: String? = nil,
        toasts: ToastCenter? = nil,
        isFrugal: Bool = false
    ) {
        var change = change
        let state = initialState ?? change.state
        change.state = state
        self.change = change
        self.state = state
        self.activeTab = state.defaultTab
        self.projectURL = projectURL
        self.agentBinary = agentBinary
        self.realInfo = realInfo
        self.userContext = userContext
        self.memoryContext = memoryContext
        self.isolationMode = isolationMode
        self.seedPrompt = seedPrompt
        self.toasts = toasts
        self.isFrugal = isFrugal
        self.chatMessages = change.exploreChat
        self.terminalLines = [String(localized: "⏺ sesión sin iniciar")]

        if let realInfo {
            self.fileContents = Self.makeRealFileContents(realInfo)
            if let log = try? String(
                contentsOf: realInfo.dirURL.appendingPathComponent("exploration.md"),
                encoding: .utf8
            ) {
                explorationLog = log
            }
            if let idea = try? String(
                contentsOf: realInfo.dirURL.appendingPathComponent("idea.md"),
                encoding: .utf8
            ) {
                self.change.ideaText = idea
            }
            loadHistory()
        } else {
            self.fileContents = SampleData.changeFiles
            self.terminalLines = ["⏺ sesión iniciada · worktree aislado"]
        }

        if realInfo == nil, state >= .implementing {
            // Demo: si se entra directamente en un estado avanzado, el stream ya “ocurrió”.
            streamEvents = SampleData.workScript
            terminalLines += SampleData.workScript.compactMap(\.terminalLine)
            markDemoTasksDone(upTo: SampleData.workScript.count)
            sessionMinutes = 19
            sessionTokens = "~14k"
        }
        if realInfo == nil, state == .implementing {
            startWork(resume: true)
        }
    }

    private static func makeRealFileContents(_ info: OpenSpecChangeInfo) -> [ChangeFileKey: ChangeFileContent] {
        [
            .proposal: ChangeFileContent(
                name: "proposal.md",
                title: String(localized: "Qué y por qué"),
                content: info.proposal ?? "# \(info.title)\n\n## ¿Qué?\n"
            ),
            .design: ChangeFileContent(
                name: "design.md",
                title: String(localized: "Decisiones técnicas"),
                content: info.design ?? "# Diseño · \(info.title)\n"
            ),
            .tasks: ChangeFileContent(
                name: "tasks.md",
                title: String(localized: "Tareas del change"),
                content: info.tasksText ?? "# Tareas\n\n## 1. Implementación\n"
            ),
            .deltas: ChangeFileContent(
                name: "deltas",
                title: String(localized: "Deltas de specs"),
                content: String(localized: "# Deltas\n\nLos delta specs de este change viven junto a las specs afectadas.")
            ),
        ]
    }

    var visibleTabs: [DashboardTab] {
        DashboardTab.allCases.filter { state >= $0.minState }
    }

    func isCompleted(_ tab: DashboardTab) -> Bool {
        state > tab.minState && !(tab == .review && state < .archived)
    }

    var completedTaskCount: Int {
        change.tasks.filter(\.done).count
    }

    /// Cambiar el agente de la sesión resetea la continuidad (cada CLI tiene la suya).
    func setAgent(binaryPath: String?) {
        guard binaryPath != agentBinary else { return }
        agentBinary = binaryPath
        agentSessionID = nil
    }

    /// Lanes de revisión: cargadas de git en real; del mock en demo; derivadas del stream si no.
    var effectiveReviewLanes: [ReviewLane] {
        if let loadedReviewLanes { return loadedReviewLanes }
        if !change.reviewLanes.isEmpty { return change.reviewLanes }

        let files = streamEvents.compactMap(\.fileRow)
        return [
            ReviewLane(
                iconLetter: "C",
                title: String(localized: "Código · ficheros tocados"),
                countLabel: files.isEmpty ? String(localized: "ninguno") : "\(files.count)",
                content: .files(files.map {
                    ReviewFile(kind: $0.removed == 0 ? .new : .mod, path: $0.path, added: $0.added, removed: $0.removed)
                }),
                note: files.isEmpty ? String(localized: "La sesión no tocó archivos.") : nil
            ),
        ]
    }

    // MARK: - Escrituras con errores visibles

    /// Toda escritura al repo pasa por aquí: si falla, el usuario se entera.
    @discardableResult
    private func persist(_ name: String, _ write: () throws -> Void) -> Bool {
        do {
            try write()
            return true
        } catch {
            toasts?.show(String(localized: "No se pudo guardar \(name): \(error.localizedDescription)"))
            return false
        }
    }

    // MARK: - Historia persistida

    private var historyURL: URL? {
        realInfo?.dirURL.appendingPathComponent("history.json")
    }

    private func loadHistory() {
        guard let historyURL,
              let data = try? Data(contentsOf: historyURL),
              let events = try? JSONDecoder().decode([StoredHistoryEvent].self, from: data) else { return }
        historyLog = events
    }

    func logEvent(stage: String, actor: HistoryEvent.Actor, text: String, detail: String? = nil) {
        guard isReal else { return }
        let actorKey = switch actor {
        case .human: "human"
        case .agent: "agent"
        case .system: "system"
        }
        historyLog.append(StoredHistoryEvent(
            stage: stage, actor: actorKey, date: .now, text: text, detail: detail
        ))
        if let historyURL, let data = try? JSONEncoder().encode(historyLog) {
            try? data.write(to: historyURL)
        }
    }

    /// Timeline real agrupado por etapas, para el drawer de Historia.
    var realHistoryStages: [HistoryStage] {
        let order = ["explore", "idea", "plan", "work", "review"]
        let names: [String: String] = [
            "explore": String(localized: "Explorar"),
            "idea": String(localized: "Idea"),
            "plan": String(localized: "Plan"),
            "work": String(localized: "Trabajo"),
            "review": String(localized: "Revisión"),
        ]
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"

        return order.compactMap { stage in
            let events = historyLog.filter { $0.stage == stage }
            guard !events.isEmpty else { return nil }
            let duration: String
            if let first = events.first?.date, let last = events.last?.date, last > first {
                duration = String(localized: "\(events.count) eventos · \(max(1, Int(last.timeIntervalSince(first) / 60))) min")
            } else {
                duration = String(localized: "\(events.count) eventos")
            }
            return HistoryStage(
                name: names[stage] ?? stage,
                durationLabel: duration,
                events: events.map { stored in
                    HistoryEvent(
                        actor: stored.actor == "human" ? .human : (stored.actor == "agent" ? .agent : .system),
                        timeLabel: formatter.string(from: stored.date),
                        text: stored.text,
                        detail: stored.detail
                    )
                }
            )
        }
    }

    // MARK: - Transiciones

    func advance(to newState: ChangeState) {
        guard newState != state else { return }
        withAnimation(.smooth(duration: 0.35)) {
            state = newState
            change.state = newState
            activeTab = newState.defaultTab
        }
        if newState == .implementing {
            startWork()
        } else if newState != .review || streamTask == nil {
            stopWork()
        }
        if newState == .review, isReal {
            Task {
                await prepareReview()
            }
        }
        if newState == .archived, !isReal {
            for index in change.tasks.indices {
                change.tasks[index].done = true
            }
        }
    }

    func select(tab: DashboardTab) {
        guard state >= tab.minState else { return }
        withAnimation(.smooth(duration: 0.25)) {
            activeTab = tab
        }
    }

    // MARK: - Exploración

    /// La frase del alta del change lanza la primera exploración sola.
    func startSeededExplorationIfNeeded() {
        guard isReal, canRunAgent, !seedStarted,
              let seed = seedPrompt,
              state == .exploring,
              !chatMessages.contains(where: { $0.author == .user }) else { return }
        seedStarted = true
        logEvent(stage: "explore", actor: .human, text: String(localized: "Iniciaste la exploración"), detail: seed)
        sendChatMessage(seed)
    }

    func sendChatMessage(_ text: String) {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return }
        withAnimation(.smooth(duration: 0.25)) {
            chatMessages.append(ExploreMessage(author: .user, text: trimmed))
        }

        guard canRunAgent, let binary = agentBinary else {
            Task {
                try? await Task.sleep(for: .seconds(0.9))
                withAnimation(.smooth(duration: 0.25)) {
                    self.chatMessages.append(ExploreMessage(
                        author: .agent,
                        text: String(localized: "Anotado. Lo incorporo a la exploración — cuando quieras, aterriza la idea y seguimos.")
                    ))
                }
            }
            return
        }

        isAgentThinking = true
        let prompt = explorePrompt(question: trimmed)
        let cwd = projectURL
        let resume = agentSessionID

        // Mensaje vivo que se va rellenando por bloques.
        let liveMessage = ExploreMessage(author: .agent, text: "", isStreaming: true)
        let liveID = liveMessage.id
        withAnimation(.smooth(duration: 0.2)) {
            chatMessages.append(liveMessage)
        }

        chatTask = Task {
            var reply = ""
            for await event in AgentRunner.stream(
                prompt: prompt, binary: binary, cwd: cwd, mode: .explore, resumeID: resume, timeout: 300
            ) {
                if Task.isCancelled { break }
                switch event {
                case .started(let sessionID):
                    self.agentSessionID = sessionID
                case .message(let block), .raw(let block):
                    reply += (reply.isEmpty ? "" : "\n\n") + block
                    self.updateChatMessage(id: liveID, text: reply, streaming: true)
                case .finished(let success, let result):
                    if !success, reply.isEmpty {
                        reply = result ?? String(localized: "El agente no respondió. Comprueba que su CLI funciona en tu terminal.")
                    }
                default:
                    break
                }
            }

            if Task.isCancelled {
                self.isAgentThinking = false
                self.updateChatMessage(
                    id: liveID,
                    text: reply.isEmpty ? String(localized: "(cancelado)") : reply + "\n\n" + String(localized: "(cancelado)"),
                    streaming: false
                )
                self.chatTask = nil
                return
            }

            let cliName = ((binary as NSString).lastPathComponent)
            if reply.isEmpty {
                reply = String(localized: "No obtuve respuesta del agente. Comprueba que su CLI funciona en tu terminal.")
                self.updateChatMessage(id: liveID, text: reply, streaming: false)
            } else if reply.contains("401")
                        || reply.localizedCaseInsensitiveContains("authenticat")
                        || reply.localizedCaseInsensitiveContains("please run") {
                reply += "\n\n" + Self.loginHint(for: cliName)
                self.updateChatMessage(id: liveID, text: reply, streaming: false)
            } else {
                self.transcript.append((question: trimmed, answer: reply))
                self.appendToExplorationLog(question: trimmed, answer: reply)
                self.logEvent(stage: "explore", actor: .agent, text: String(localized: "Respondió a «\(String(trimmed.prefix(60)))»"))
                // El contenido largo vive en el artefacto: el chat se queda
                // con el resumen y el enlace, sin duplicar las dos columnas.
                if reply.count > 350 {
                    let summary = Self.firstMeaningfulSentence(of: reply)
                    self.updateChatMessage(
                        id: liveID,
                        text: summary + "\n\n" + String(localized: "He actualizado el briefing de exploración con el detalle completo →"),
                        streaming: false,
                        artifactLink: "exploration.md"
                    )
                } else {
                    self.updateChatMessage(id: liveID, text: reply, streaming: false)
                }
            }
            self.isAgentThinking = false
            self.chatTask = nil
        }
    }

    /// Detiene la pregunta en curso del chat.
    func cancelChat() {
        chatTask?.cancel()
        chatTask = nil
        isAgentThinking = false
    }

    private func updateChatMessage(id: UUID, text: String, streaming: Bool, artifactLink: String? = nil) {
        guard let index = chatMessages.firstIndex(where: { $0.id == id }) else { return }
        withAnimation(.smooth(duration: 0.15)) {
            chatMessages[index].text = text
            chatMessages[index].isStreaming = streaming
            if let artifactLink {
                chatMessages[index].artifactLink = artifactLink
            }
        }
    }

    /// Primera frase con contenido (para el resumen del chat).
    nonisolated static func firstMeaningfulSentence(of text: String) -> String {
        let cleaned = text.components(separatedBy: "\n")
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty && !$0.hasPrefix("#") && !$0.hasPrefix("|") && !$0.hasPrefix("-") }
            .joined(separator: " ")
        let prefix = String(cleaned.prefix(240))
        if let dot = prefix.range(of: ". ", range: prefix.index(prefix.startIndex, offsetBy: min(80, prefix.count))..<prefix.endIndex) {
            return String(prefix[..<dot.lowerBound]) + "."
        }
        return prefix + (cleaned.count > 240 ? "…" : "")
    }

    /// El artefacto de exploración crece con cada intercambio y vive en el repo.
    private func appendToExplorationLog(question: String, answer: String) {
        if explorationLog.isEmpty {
            explorationLog = "# Exploración · \(change.title)\n\n"
        }
        explorationLog += "## \(question)\n\n\(answer)\n\n"
        if let info = realInfo {
            persist("exploration.md") {
                try OpenSpecService.saveFile(named: "exploration.md", content: explorationLog, in: info)
            }
            if !change.artifacts.contains(where: { $0.name == "exploration.md" }) {
                change.artifacts.append(ChangeArtifact(
                    name: "exploration.md", phase: "explore", timeLabel: String(localized: "en vivo")
                ))
            }
        }
    }

    private func explorePrompt(question: String) -> String {
        var prompt = """
        Eres el modo explorar de un flujo spec-driven (OpenSpec). Estamos explorando el change \
        «\(change.title)» (openspec/changes/\(change.id)/). NO implementes nada ni toques archivos: \
        investiga, compara approaches y responde en español, conciso y concreto. \
        No anuncies lo que vas a hacer ni narres tus pasos: responde directamente con el contenido útil.
        """
        if isFrugal {
            prompt += "\nModo ahorro de tokens activo: responde de forma ultra concisa, sin tablas ni adornos."
        }
        if let userContext {
            prompt += "\n\n\(userContext)"
        }
        if let memoryContext {
            prompt += "\n\nMemoria del proyecto (decisiones y reglas ya tomadas — respétalas):\n\(memoryContext)"
        }
        if agentSessionID == nil, !transcript.isEmpty {
            let history = transcript.suffix(4)
                .map { "Tú preguntaste: \($0.question)\nRespondiste: \(String($0.answer.prefix(700)))" }
                .joined(separator: "\n---\n")
            prompt += "\n\nConversación previa (para contexto):\n\(history)"
        }
        prompt += "\n\nPregunta del usuario: \(question)"
        return prompt
    }

    /// Pregunta con resiliencia: si la reanudación de sesión falla (error de CLI),
    /// reintenta una vez con sesión fresca.
    private func askAgent(_ prompt: String, mode: AgentMode, timeout: TimeInterval = 300) async -> String {
        guard let binary = agentBinary else { return "" }
        let cwd = workingDirURL ?? projectURL
        var reply = await AgentRunner.ask(
            prompt: prompt, binary: binary, cwd: cwd, mode: mode, resumeID: agentSessionID, timeout: timeout
        )
        if Self.looksLikeCLIError(reply), agentSessionID != nil {
            agentSessionID = nil
            reply = await AgentRunner.ask(
                prompt: prompt, binary: binary, cwd: cwd, mode: mode, resumeID: nil, timeout: timeout
            )
        }
        return reply
    }

    nonisolated static func looksLikeCLIError(_ reply: String) -> Bool {
        reply.hasPrefix("error:")
            || reply.contains("unexpected argument")
            || reply.contains("Usage: ")
    }

    // MARK: - Aterrizar idea (síntesis real)

    func landIdea() {
        guard canRunAgent, !explorationOrChatEmpty else {
            advance(to: .idea)
            return
        }
        isLandingIdea = true
        let prompt = """
        Sintetiza nuestra exploración del change «\(change.title)» en este formato EXACTO:

        # Idea
        (2-3 frases con la intención del cambio, en las palabras del usuario)

        ## Contexto
        - (3-5 bullets con lo aprendido: estado actual, approach elegido, riesgos)
        """
        Task {
            let reply = await self.askAgent(prompt, mode: .explore)
            if !reply.isEmpty, !reply.contains("401") {
                self.applyIdeaSynthesis(reply)
                self.logEvent(stage: "idea", actor: .agent, text: String(localized: "Sintetizó la intención y el contexto"))
            }
            self.logEvent(stage: "idea", actor: .human, text: String(localized: "Aterrizaste la idea"))
            self.isLandingIdea = false
            self.advance(to: .idea)
        }
    }

    private var explorationOrChatEmpty: Bool {
        transcript.isEmpty && explorationLog.isEmpty
    }

    private func applyIdeaSynthesis(_ markdown: String) {
        guard markdown.contains("# Idea"), !Self.looksLikeCLIError(markdown) else { return }
        var ideaLines: [String] = []
        var contextBullets: [String] = []
        var section = ""
        for line in markdown.components(separatedBy: "\n") {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            if trimmed.hasPrefix("# Idea") { section = "idea"; continue }
            if trimmed.hasPrefix("## Contexto") { section = "context"; continue }
            if trimmed.hasPrefix("#") { section = ""; continue }
            if section == "idea", !trimmed.isEmpty {
                ideaLines.append(trimmed)
            }
            if section == "context", trimmed.hasPrefix("- ") {
                contextBullets.append(String(trimmed.dropFirst(2)))
            }
        }
        if !ideaLines.isEmpty {
            change.ideaText = ideaLines.joined(separator: " ")
        }
        if !contextBullets.isEmpty {
            change.ideaContext = contextBullets
        }
        if let info = realInfo {
            persist("idea.md") {
                try OpenSpecService.saveFile(named: "idea.md", content: markdown, in: info)
            }
        }
    }

    /// Autosave real de la intención a idea.md.
    func saveIdeaText() {
        guard let info = realInfo else { return }
        persist("idea.md") {
            try OpenSpecService.saveFile(named: "idea.md", content: change.ideaText, in: info)
        }
    }

    // MARK: - Plan real

    func generatePlan() {
        guard canRunAgent, let binary = agentBinary else {
            advance(to: .planned)
            return
        }
        isGeneratingPlan = true
        planProgressText = String(localized: "El agente está redactando el plan…")

        // Salta ya a la tab Plan: el usuario ve proposal, design y tasks
        // aparecer incrementalmente mientras el agente los escribe.
        if state < .planned {
            advance(to: .planned)
        } else {
            select(tab: .plan)
        }

        var prompt = """
        Genera los artefactos de planning del change «\(change.title)» escribiendo estos archivos \
        DENTRO de openspec/changes/\(change.id)/ (y solo ahí):

        1. proposal.md — formato: "# \(change.title)", secciones "## ¿Qué?", "## ¿Por qué?", "## Alcance", "## Fuera de alcance".
        2. design.md — las decisiones técnicas clave, numeradas.
        3. tasks.md — formato: "# Tareas", grupos "## 1. Nombre" y tareas como "- [ ] 1.1 Título" (ids N.N).

        IMPORTANTE: escribe cada archivo en cuanto lo tengas terminado, en este orden \
        (proposal.md → design.md → tasks.md), en escrituras separadas — no lo dejes todo para el final.

        La intención del usuario: \(change.ideaText)
        """
        if !change.ideaContext.isEmpty {
            prompt += "\nContexto de la exploración:\n" + change.ideaContext.map { "- \($0)" }.joined(separator: "\n")
        }
        if let userContext {
            prompt += "\n\n\(userContext)"
        }
        if let memoryContext {
            prompt += "\n\nMemoria del proyecto (decisiones y reglas ya tomadas — el plan debe respetarlas):\n\(memoryContext)"
        }
        prompt += "\nAnaliza el código del repo para que el plan sea concreto. Responde brevemente al terminar."

        // Progreso visible aunque el agente escriba sin emitir eventos de archivo:
        // mientras se genera, el plan se relee del disco cada 2 s.
        let poller = Task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(2))
                if Task.isCancelled { break }
                self.reloadFromDisk()
            }
        }

        planTask = Task {
            defer { poller.cancel() }
            await self.runPlanGeneration(prompt: prompt, binary: binary, resumeID: self.agentSessionID)
            var planReady = !self.change.tasks.isEmpty || (self.fileContents[.proposal]?.content.count ?? 0) > 60

            // Si la reanudación falló (CLI viejo, sesión perdida), reintento fresco.
            if !planReady, !Task.isCancelled, self.agentSessionID != nil {
                self.agentSessionID = nil
                await self.runPlanGeneration(prompt: prompt, binary: binary, resumeID: nil)
                planReady = !self.change.tasks.isEmpty || (self.fileContents[.proposal]?.content.count ?? 0) > 60
            }

            self.isGeneratingPlan = false
            self.planProgressText = nil
            self.planTask = nil
            if planReady, !Task.isCancelled {
                self.logEvent(
                    stage: "plan", actor: .agent,
                    text: String(localized: "Generó proposal, design y tasks"),
                    detail: String(localized: "\(self.change.tasks.count) tasks")
                )
            }
        }
    }

    /// Cancela la generación/ajuste del plan en curso.
    func cancelPlanGeneration() {
        planTask?.cancel()
        planTask = nil
        isGeneratingPlan = false
        planProgressText = nil
    }

    private func runPlanGeneration(prompt: String, binary: String, resumeID: String?) async {
        for await event in AgentRunner.stream(
            prompt: prompt, binary: binary, cwd: projectURL, mode: .work, resumeID: resumeID, timeout: 600
        ) {
            if Task.isCancelled { break }
            switch event {
            case .started(let id): agentSessionID = id
            case .fileChanged(let path, _):
                let name = (path as NSString).lastPathComponent
                planProgressText = String(localized: "Escribiendo \(name)…")
                // Generación incremental: cada archivo escrito aparece al momento.
                reloadFromDisk()
            case .toolUse(let name, _):
                planProgressText = String(localized: "Analizando el repo (\(name))…")
            default: break
            }
        }
        reloadFromDisk()
    }

    /// El prompt efímero del plan: el agente modifica los artefactos de verdad.
    func refinePlan(instruction: String) {
        guard canRunAgent else { return }
        isGeneratingPlan = true
        planProgressText = String(localized: "Ajustando el plan…")
        let prompt = """
        Ajusta los artefactos del change openspec/changes/\(change.id)/ (proposal.md, design.md, tasks.md) \
        según esta petición del usuario, conservando el formato de checkboxes "- [ ] N.N":

        \(instruction)
        """
        planTask = Task {
            _ = await self.askAgent(prompt, mode: .work, timeout: 600)
            self.reloadFromDisk()
            self.isGeneratingPlan = false
            self.planProgressText = nil
            self.planTask = nil
            self.logEvent(stage: "plan", actor: .human, text: String(localized: "Pediste ajustar el plan"), detail: instruction)
        }
    }

    /// Marca/desmarca una task con write-back a tasks.md.
    func toggleTask(id: String) {
        guard let index = change.tasks.firstIndex(where: { $0.id == id }) else { return }
        change.tasks[index].done.toggle()
        if let info = liveChangeInfo {
            persist("tasks.md") {
                try OpenSpecService.toggleTask(id: id, done: change.tasks[index].done, in: info)
            }
        }
    }

    /// El change “vivo”: en el worktree durante el trabajo, en el árbol principal si no.
    private var liveChangeInfo: OpenSpecChangeInfo? {
        guard let realInfo else { return nil }
        if let workingDirURL, workingDirURL != projectURL {
            let liveDir = workingDirURL.appendingPathComponent("openspec/changes/\(change.id)")
            if FileManager.default.fileExists(atPath: liveDir.path) {
                return OpenSpecService.readChange(at: liveDir)
            }
        }
        return realInfo
    }

    /// Relee los artefactos del change desde disco y actualiza la sesión.
    func reloadFromDisk() {
        guard let info = liveChangeInfo else { return }
        let fresh = OpenSpecService.readChange(at: info.dirURL)
        withAnimation(.smooth(duration: 0.3)) {
            change.tasks = fresh.tasks
            change.deltas = OpenSpecService.deltas(for: fresh)
            fileContents = Self.makeRealFileContents(fresh)
        }
        if workingDirURL == nil || workingDirURL == projectURL {
            realInfo = fresh
        }
    }

    // MARK: - Sesión de trabajo

    func startWork(resume: Bool = false) {
        guard streamTask == nil else { return }
        isPaused = false

        if canRunAgent, let binary = agentBinary {
            startRealWork(binary: binary)
            return
        }
        startSimulatedWork(resume: resume)
    }

    func stopWork() {
        streamTask?.cancel()
        streamTask = nil
    }

    /// Pausa real: termina el proceso del agente y espera tu indicación.
    func pauseWork() {
        guard streamTask != nil else { return }
        stopWork()
        isPaused = true
        terminalLines.append(String(localized: "⏺ sesión pausada por ti"))
        logEvent(stage: "work", actor: .human, text: String(localized: "Pausaste la sesión"))
    }

    /// Reanuda tras una pausa, con una indicación opcional para el agente.
    func resumeWork(instruction: String?) {
        if let instruction, !instruction.trimmingCharacters(in: .whitespaces).isEmpty {
            pendingInstruction = instruction
            logEvent(stage: "work", actor: .human, text: String(localized: "Intervención"), detail: instruction)
        }
        isPaused = false
        startWork()
    }

    /// Iterar tras la revisión: nueva sesión (run +1) con tu feedback.
    func iterateWork(feedback: String) {
        pendingInstruction = feedback
        runNumber += 1
        logEvent(stage: "review", actor: .human, text: String(localized: "Pediste iterar (run #\(runNumber))"), detail: feedback)
        loadedReviewLanes = nil
        reviewVerdict = nil
        advance(to: .implementing)
    }

    // MARK: Real

    private func startRealWork(binary: String) {
        streamEvents = []
        terminalLines = ["⏺ sesión iniciada · \(change.id) · run #\(runNumber)"]
        sessionMinutes = 0
        sessionTokens = "0"
        approxOutputChars = 0
        receivedRealUsage = false
        sessionStart = .now
        sessionEnd = nil

        streamTask = Task { [weak self] in
            guard let self, let root = self.projectURL else { return }

            // Aislamiento real: worktree dedicado si el repo lo permite.
            var cwd = root
            if self.isolationMode == "worktree" {
                if let existing = self.workingDirURL, existing != root,
                   FileManager.default.fileExists(atPath: existing.path) {
                    cwd = existing
                } else if let worktree = await GitService.setupWorktree(root: root, changeID: self.change.id) {
                    cwd = worktree
                    self.terminalLines.append("⏺ worktree aislado · .workspace/worktrees/\(self.change.id)")
                } else {
                    self.terminalLines.append(String(localized: "⏺ sin worktree (repo sin commits) · trabajando en el árbol principal"))
                }
            }
            self.workingDirURL = cwd
            self.logEvent(
                stage: "work", actor: .system,
                text: String(localized: "Sesión iniciada · run #\(self.runNumber)"),
                detail: cwd == root ? String(localized: "árbol principal") : String(localized: "worktree aislado")
            )

            let prompt = self.workPrompt()
            self.pendingInstruction = nil

            // Tasks y artefactos al día aunque el agente no emita eventos de archivo.
            let poller = Task {
                while !Task.isCancelled {
                    try? await Task.sleep(for: .seconds(3))
                    if Task.isCancelled { break }
                    self.reloadFromDisk()
                }
            }
            defer { poller.cancel() }

            for await event in AgentRunner.stream(
                prompt: prompt, binary: binary, cwd: cwd, mode: .work, resumeID: self.agentSessionID, timeout: 900
            ) {
                guard !Task.isCancelled else { return }
                self.apply(event)
            }
            guard !Task.isCancelled else { return }
            self.streamTask = nil
            self.reloadFromDisk()
            let files = self.streamEvents.filter { $0.fileRow != nil }.count
            self.logEvent(
                stage: "work", actor: .system,
                text: String(localized: "Sesión terminada"),
                detail: String(localized: "\(self.streamEvents.count) eventos · \(files) archivos")
            )
            if self.state == .implementing {
                self.advance(to: .review)
            }
        }
    }

    private func workPrompt() -> String {
        let pending = change.tasks.filter { !$0.done }
            .map { "- [ ] \($0.id) \($0.title)" }
            .joined(separator: "\n")
        var prompt = """
        Implementa el change «\(change.title)» (openspec/changes/\(change.id)/) de este repo OpenSpec. \
        Lee proposal.md y tasks.md del change. Tareas pendientes:
        \(pending.isEmpty ? "(define las tareas a partir del proposal y escríbelas en tasks.md)" : pending)

        Implementa las tareas, marca en tasks.md las que completes (- [x]) y explica cada paso brevemente en español.
        """
        if let pendingInstruction {
            prompt += "\n\nIndicación del usuario para esta sesión (prioritaria):\n\(pendingInstruction)"
        }
        if isFrugal {
            prompt += "\nModo ahorro de tokens: sé breve en las explicaciones."
        }
        if let userContext {
            prompt += "\n\n\(userContext)"
        }
        if let memoryContext {
            prompt += "\n\nMemoria del proyecto (decisiones y reglas ya tomadas — respétalas al implementar):\n\(memoryContext)"
        }
        return prompt
    }

    private func apply(_ event: AgentEvent) {
        let formatter = DateFormatter()
        formatter.dateFormat = "HH:mm"
        let time = formatter.string(from: .now)
        if let start = sessionStart {
            sessionMinutes = max(0, Int(Date.now.timeIntervalSince(start) / 60))
        }

        withAnimation(.smooth(duration: 0.3)) {
            switch event {
            case .started(let sessionID):
                agentSessionID = sessionID
                terminalLines.append("⏺ sesión \(String(sessionID.prefix(8))) · auth heredada")
            case .thought(let text):
                streamEvents.append(StreamEvent(kind: .thought, text: text, timeLabel: time))
                accumulateApproxTokens(text)
            case .message(let text):
                streamEvents.append(StreamEvent(kind: .message, text: text, timeLabel: time))
                terminalLines.append("⏺ mensaje del agente")
                accumulateApproxTokens(text)
                logEvent(
                    stage: "work", actor: .agent,
                    text: String(Self.firstMeaningfulSentence(of: text).prefix(90))
                )
            case .toolUse(let name, let detail):
                // Solo la primera línea del comando: los scripts enteros no aportan en el stream.
                let firstLine = detail.components(separatedBy: "\n").first ?? detail
                let compact = firstLine.count > 140 ? String(firstLine.prefix(140)) + "…" : firstLine
                streamEvents.append(StreamEvent(kind: .tool(name: name), text: compact.isEmpty ? name : compact, timeLabel: time))
                terminalLines.append("⏺ tool \(name)")
            case .fileChanged(let path, let created):
                let base = workingDirURL ?? projectURL
                let relative = base.map { path.replacingOccurrences(of: $0.path + "/", with: "") } ?? path
                streamEvents.append(StreamEvent(
                    kind: created ? .fileCreated : .fileModified,
                    text: created ? String(localized: "Archivo creado por el agente.") : String(localized: "Archivo modificado por el agente."),
                    timeLabel: time,
                    fileRow: .init(path: relative, added: 0, removed: 0)
                ))
                terminalLines.append("⏺ \(created ? "write" : "edit") \(relative)")
                logEvent(
                    stage: "work", actor: .agent,
                    text: created ? String(localized: "Creó \((relative as NSString).lastPathComponent)") : String(localized: "Modificó \((relative as NSString).lastPathComponent)"),
                    detail: relative
                )
                // Las tasks marcadas por el agente se reflejan al momento.
                if relative.hasSuffix("tasks.md") {
                    reloadFromDisk()
                }
            case .raw(let line):
                streamEvents.append(StreamEvent(kind: .message, text: line, timeLabel: time))
                accumulateApproxTokens(line)
            case .usage(let outputTokens):
                receivedRealUsage = true
                sessionTokens = outputTokens > 999 ? "~\(outputTokens / 1000)k" : "\(outputTokens)"
            case .finished(let success, let result):
                if let result, !result.isEmpty,
                   !streamEvents.contains(where: { $0.text == result }) {
                    streamEvents.append(StreamEvent(kind: .message, text: result, timeLabel: time))
                }
                sessionEnd = .now
                terminalLines.append(success ? "⏺ sesión terminada ✓" : "⏺ sesión terminada con errores")
                notifySessionFinished(success: success)
            }
        }
    }

    /// Tokens estimados en vivo (≈4 chars/token) hasta que llega el uso real.
    private func accumulateApproxTokens(_ text: String) {
        guard !receivedRealUsage else { return }
        approxOutputChars += text.count
        let approx = approxOutputChars / 4
        sessionTokens = approx > 999 ? "~\(approx / 1000)k" : "~\(approx)"
    }

    private func notifySessionFinished(success: Bool) {
        let content = UNMutableNotificationContent()
        content.title = change.title
        content.body = success
            ? String(localized: "Sesión del agente terminada · lista para revisar")
            : String(localized: "La sesión del agente terminó con errores")
        let request = UNNotificationRequest(
            identifier: UUID().uuidString, content: content, trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }

    // MARK: - Revisión real

    /// Diff real + veredicto por tasks + voces redactadas por el agente.
    private func prepareReview() async {
        isPreparingReview = true
        defer { isPreparingReview = false }

        let dir = workingDirURL ?? projectURL
        if let dir {
            let allFiles = await GitService.pendingChanges(at: dir)
            // Solo lo que pertenece a ESTE change: fuera los artefactos de otros
            // changes y el ruido del workspace (worktrees, historia…).
            let files = allFiles.filter { file in
                if file.path.hasPrefix("openspec/changes/") {
                    return file.path.hasPrefix("openspec/changes/\(change.id)/")
                }
                if file.path.hasPrefix(".workspace/") {
                    return file.path.hasPrefix(".workspace/memory/")
                }
                return true
            }
            let specs = files.filter { $0.path.hasPrefix("openspec/") || $0.path.hasPrefix(".workspace/") }
            let code = files.filter { !$0.path.hasPrefix("openspec/") && !$0.path.hasPrefix(".workspace/") }

            var lanes: [ReviewLane] = []
            lanes.append(ReviewLane(
                iconLetter: "C",
                title: String(localized: "Código · ficheros tocados"),
                countLabel: code.isEmpty
                    ? String(localized: "ninguno")
                    : "\(code.count) · +\(code.map(\.added).reduce(0, +)) −\(code.map(\.removed).reduce(0, +))",
                content: .files(code),
                note: code.isEmpty ? String(localized: "La sesión no tocó código fuera de los artefactos.") : nil
            ))
            lanes.append(ReviewLane(
                iconLetter: "S",
                title: String(localized: "Specs · conocimiento"),
                countLabel: "\(specs.count)",
                content: .files(specs),
                note: String(localized: "Artefactos del change y memoria del proyecto.")
            ))
            withAnimation(.smooth(duration: 0.3)) {
                loadedReviewLanes = lanes
            }
        }

        let done = completedTaskCount
        let total = change.tasks.count
        let filesCount = (loadedReviewLanes?.compactMap { lane -> Int? in
            if case .files(let files) = lane.content { return files.count } else { return nil }
        }.reduce(0, +)) ?? 0
        reviewVerdict = total > 0
            ? String(localized: "\(done)/\(total) tasks completadas · \(filesCount) archivos tocados")
            : String(localized: "\(filesCount) archivos tocados en la sesión")
        logEvent(stage: "review", actor: .system, text: String(localized: "Revisión preparada"), detail: reviewVerdict)

        await generateVoices()
    }

    /// Las tres voces las redacta el agente que vivió la sesión.
    private func generateVoices() async {
        guard canRunAgent else { return }
        let reply = await askAgent(voicesPrompt(), mode: .explore)
        guard !reply.isEmpty, !reply.contains("401"), !Self.looksLikeCLIError(reply) else { return }
        applyVoices(from: reply)
        logEvent(stage: "review", actor: .agent, text: String(localized: "Redactó las tres voces del cierre"))
    }

    /// Regenera una sola voz llamando de nuevo al agente.
    func regenerateVoice(_ kind: ClosingVoice.Kind) {
        guard canRunAgent else {
            toasts?.show(String(localized: "En la demo las voces son fijas"))
            return
        }
        regeneratingVoice = kind
        Task {
            let reply = await self.askAgent(self.voicesPrompt(), mode: .explore)
            if !reply.isEmpty, !Self.looksLikeCLIError(reply) {
                self.applyVoices(from: reply, only: kind)
            }
            self.regeneratingVoice = nil
        }
    }

    private func voicesPrompt() -> String {
        var prompt = """
        Acabas de implementar el change «\(change.title)». Redacta los tres textos de cierre \
        en este formato EXACTO (sin nada más):

        ## Commit
        (mensaje de commit estilo conventional commits: una línea tipo feat/fix(scope): …, línea en blanco, 2-4 líneas de cuerpo)

        ## Ticket
        (nota breve para el ticket de negocio, empieza con "✅ Resuelto —")

        ## Equipo
        (resumen de 2-3 líneas para el canal del equipo, empieza con "🚀 Mergeado:")
        """
        if isFrugal {
            prompt += "\nModo ahorro: textos mínimos."
        }
        return prompt
    }

    private func applyVoices(from reply: String, only kind: ClosingVoice.Kind? = nil) {
        let sections = parseSections(reply, headers: ["## Commit", "## Ticket", "## Equipo"])
        withAnimation(.smooth(duration: 0.3)) {
            for index in change.closingVoices.indices {
                let voiceKind = change.closingVoices[index].kind
                if let kind, voiceKind != kind { continue }
                switch voiceKind {
                case .commit: if let text = sections["## Commit"] { change.closingVoices[index].content = text }
                case .ticket: if let text = sections["## Ticket"] { change.closingVoices[index].content = text }
                case .team: if let text = sections["## Equipo"] { change.closingVoices[index].content = text }
                }
            }
        }
    }

    private func parseSections(_ text: String, headers: [String]) -> [String: String] {
        var result: [String: String] = [:]
        var current: String?
        var buffer: [String] = []
        func flush() {
            if let current, !buffer.isEmpty {
                result[current] = buffer.joined(separator: "\n").trimmingCharacters(in: .whitespacesAndNewlines)
            }
            buffer = []
        }
        for line in text.components(separatedBy: "\n") {
            if let header = headers.first(where: { line.trimmingCharacters(in: .whitespaces).hasPrefix($0) }) {
                flush()
                current = header
            } else if current != nil {
                buffer.append(line)
            }
        }
        flush()
        return result
    }

    // MARK: - Merge real

    /// Commit + merge del worktree (o commit directo) antes de archivar.
    func mergeChange(commitMessage: String) async -> (ok: Bool, detail: String?) {
        guard isReal, let root = projectURL else { return (true, nil) }
        isMerging = true
        defer { isMerging = false }

        let message = commitMessage.components(separatedBy: "\n").first.flatMap {
            $0.isEmpty ? nil : $0
        } ?? "feat: \(change.title)"

        var ok = true
        var detail: String?
        if let worktree = workingDirURL, worktree != root {
            let result = await GitService.mergeWorktree(
                root: root, changeID: change.id, worktree: worktree, message: message
            )
            ok = result.ok
            detail = result.detail
            if ok { workingDirURL = nil }
        } else if await GitService.hasHead(at: root) {
            let committed = await GitService.commitAll(at: root, message: message)
            if !committed {
                let pending = await ShellRunner.run("git status --porcelain 2>/dev/null", cwd: root)
                if !pending.trimmedOutput.isEmpty {
                    ok = false
                    detail = String(localized: "el commit directo falló con cambios pendientes")
                }
            }
        }

        if ok {
            let formatter = DateFormatter()
            formatter.dateFormat = "HH:mm"
            let stats = change.closureStats
            let sha = await GitService.headSHA(at: root) ?? "—"

            // Duración de TODO el change (desde el primer evento registrado),
            // con la implementación desglosada en el detalle.
            let duration: String
            var durationDetail = String(localized: "\(runNumber) sesión(es)")
            let changeStart = historyLog.first?.date ?? sessionStart
            if let changeStart {
                let total = max(1, Int(Date.now.timeIntervalSince(changeStart) / 60))
                duration = "\(total) min"
                if let start = sessionStart {
                    let end = sessionEnd ?? .now
                    let impl = max(1, Int(end.timeIntervalSince(start) / 60))
                    durationDetail = String(localized: "implementación \(impl) min · \(runNumber) sesión(es)")
                }
            } else {
                duration = stats.durationValue
            }

            // Archivos reales: el diff de la revisión; si no, los eventos del stream.
            let reviewFiles = loadedReviewLanes?.compactMap { lane -> [ReviewFile]? in
                if case .files(let files) = lane.content { return files } else { return nil }
            }.flatMap { $0 } ?? []
            let filesCount = reviewFiles.isEmpty
                ? streamEvents.filter { $0.fileRow != nil }.count
                : reviewFiles.count
            let codeCount = reviewFiles.filter { !$0.path.hasPrefix("openspec/") && !$0.path.hasPrefix(".workspace/") }.count

            change.closureStats = ClosureStats(
                archivedAtLabel: formatter.string(from: .now),
                durationValue: duration,
                durationDetail: durationDetail,
                tokensValue: sessionTokens,
                tokensDetail: String(localized: "salida del agente"),
                filesValue: "\(filesCount)",
                filesDetail: String(localized: "\(codeCount) código · \(max(0, filesCount - codeCount)) specs"),
                committedItems: [String(localized: "Cambios de la sesión mergeados a tu rama")],
                commitSHA: sha,
                commitMessage: message,
                learnedItems: [
                    String(localized: "exploration.md, idea.md y history.json forman parte del archivo"),
                    String(localized: "El change queda archivado en el repo"),
                ],
                archivePath: stats.archivePath
            )
            logEvent(stage: "review", actor: .system, text: String(localized: "Merge y archivo"), detail: sha)
        }
        return (ok, detail)
    }

    /// Limpieza al descartar el change: proceso, worktree y rama.
    func discardCleanup() async {
        stopWork()
        cancelChat()
        cancelPlanGeneration()
        guard let root = projectURL, isReal else { return }
        await GitService.discardWorktree(root: root, changeID: change.id)
    }

    static func loginHint(for cliName: String) -> String {
        switch cliName {
        case "claude":
            String(localized: "La sesión de Claude Code ha caducado: abre `claude` en tu terminal y ejecuta `/login`. Fold hereda exactamente esa sesión. Mientras tanto puedes cambiar el agente por defecto en Configuración.")
        case "cursor-agent":
            String(localized: "Cursor CLI necesita sesión: ejecuta `cursor-agent login` en tu terminal. Fold hereda exactamente esa sesión. Mientras tanto puedes cambiar el agente por defecto en Configuración.")
        case "codex":
            String(localized: "Codex necesita sesión: abre la app Codex (o ejecuta `codex login`) e inicia sesión. Mientras tanto puedes cambiar el agente por defecto en Configuración.")
        case "opencode":
            String(localized: "OpenCode necesita sesión: ejecuta `opencode auth login` en tu terminal. Mientras tanto puedes cambiar el agente por defecto en Configuración.")
        default:
            String(localized: "Renueva la sesión del CLI en tu terminal — Fold hereda exactamente esa auth.")
        }
    }

    // MARK: Demo

    private func startSimulatedWork(resume: Bool) {
        if !resume {
            streamEvents = []
            terminalLines = ["⏺ sesión iniciada · worktree aislado"]
            sessionMinutes = 0
            sessionTokens = "~2k"
            for index in change.tasks.indices {
                change.tasks[index].done = false
            }
        }
        streamTask = Task { [weak self] in
            guard let self else { return }
            let script = SampleData.workScript
            let startIndex = resume ? script.count : 0
            for index in startIndex..<script.count {
                try? await Task.sleep(for: .seconds(Double.random(in: 1.2...2.0)))
                guard !Task.isCancelled else { return }
                let event = script[index]
                withAnimation(.smooth(duration: 0.3)) {
                    self.streamEvents.append(event)
                    if let line = event.terminalLine {
                        self.terminalLines.append(line)
                    }
                    self.markDemoTasksDone(upTo: index + 1)
                    self.sessionMinutes = min(19, 2 + index * 2)
                    self.sessionTokens = "~\(2 + index)k"
                }
            }
        }
    }

    private func markDemoTasksDone(upTo eventCount: Int) {
        let milestones: [(eventIndex: Int, taskID: String)] = [
            (3, "1.1"), (8, "1.2"), (10, "1.3"), (10, "2.1"), (11, "2.2"),
        ]
        for milestone in milestones where eventCount >= milestone.eventIndex {
            if let index = change.tasks.firstIndex(where: { $0.id == milestone.taskID }) {
                change.tasks[index].done = true
            }
        }
    }

    // MARK: - Orquestación (visualización demo)

    /// Avanza la simulación del diagrama: cierra 2.1 → cierra 1.3 + merge listo → reinicia.
    func orchAdvance() {
        withAnimation(.spring(duration: 0.5)) {
            switch orchStep {
            case 0:
                setOrchStatus("2.1", .done)
                orchStep = 1
            case 1:
                setOrchStatus("1.3", .done)
                setOrchStatus("merge", .done)
                orchStep = 2
            default:
                orchNodes = SampleData.orchNodes
                orchStep = 0
            }
        }
    }

    var orchClosedCount: Int {
        orchNodes.filter { $0.column == .fan && $0.status == .done }.count
    }

    private func setOrchStatus(_ id: String, _ status: OrchNode.Status) {
        if let index = orchNodes.firstIndex(where: { $0.id == id }) {
            orchNodes[index].status = status
        }
    }
}
