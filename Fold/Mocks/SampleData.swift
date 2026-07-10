import Foundation

/// Editor externo seleccionable en el dashboard.
struct EditorOption: Identifiable {
    let id: String
    let name: String
    let abbreviation: String
    /// Nombre de la app para `open -a`.
    var appName: String
    var isAvailable = true
}

/// Todos los datos de ejemplo del prototipo v15.
enum SampleData {
    // MARK: - Selector

    static let globalStats = GlobalStats(openProjects: 3, detectedAgents: 4, totalArchives: 57)

    static let acmeAPI = Project(
        id: "acme-api",
        name: "acme-api",
        path: "~/code/acme/api",
        relativeTimeLabel: "hace 4 min",
        statusSummary: "1 implementando · 1 revisar · 1 listo",
        activeChanges: [
            ChangeRef(id: "add-apple-login", title: "Login con Apple", dot: .running),
            ChangeRef(id: "migrate-openapi-31", title: "Migrar OpenAPI 3.1", dot: .review),
            ChangeRef(id: "add-rate-limiting", title: "Rate limiting", dot: .ready),
        ],
        archivedCount: 14,
        memoryEntryCount: 12,
        inventoryPieceCount: 7
    )

    static let recentProjects: [Project] = [
        acmeAPI,
        Project(
            id: "fold-website",
            name: "fold-website",
            path: "~/code/fold/web",
            relativeTimeLabel: "ayer",
            statusSummary: "1 explorando",
            activeChanges: [
                ChangeRef(id: "landing-v2", title: "Landing v2", dot: .explore),
            ],
            archivedCount: 21,
            memoryEntryCount: 8,
            inventoryPieceCount: 4
        ),
        Project(
            id: "stepkit-server",
            name: "stepkit-server",
            path: "~/code/stepkit/server",
            relativeTimeLabel: "hace 3 días",
            statusSummary: "sin changes activos",
            activeChanges: [],
            archivedCount: 22,
            memoryEntryCount: 15,
            inventoryPieceCount: 6
        ),
    ]

    // MARK: - Agentes

    static let clis: [AgentCLI] = [
        AgentCLI(id: "claude-code", name: "Claude Code", abbreviation: "CC", version: "v2.1.4",
                 isDetected: true, isSelected: true, isDefault: true),
        AgentCLI(id: "codex", name: "Codex CLI", abbreviation: "CX", version: "v0.18",
                 isDetected: true, isSelected: true),
        AgentCLI(id: "cursor", name: "Cursor CLI", abbreviation: "CR", version: "v1.6",
                 isDetected: true),
        AgentCLI(id: "opencode", name: "OpenCode", abbreviation: "OC", version: nil,
                 isDetected: false),
    ]

    static let editors: [EditorOption] = [
        EditorOption(id: "cursor", name: "Cursor", abbreviation: "CR", appName: "Cursor"),
        EditorOption(id: "vscode", name: "VS Code", abbreviation: "VS", appName: "Visual Studio Code"),
        EditorOption(id: "zed", name: "Zed", abbreviation: "Z", appName: "Zed"),
        EditorOption(id: "xcode", name: "Xcode", abbreviation: "Xc", appName: "Xcode"),
        EditorOption(id: "sublime", name: "Sublime Text", abbreviation: "ST", appName: "Sublime Text", isAvailable: false),
    ]

    // MARK: - Setup

    static let setupChecks: [SetupCheck] = [
        SetupCheck(
            id: 1,
            name: String(localized: "Agentes detectados"),
            pendingDetail: String(localized: "Qué CLIs hay disponibles y autenticadas en la máquina."),
            runningDetail: String(localized: "Buscando CLIs activadas en tu onboarding…"),
            doneDetail: "Claude Code v2.1.4 · Codex CLI v0.18 disponibles"
        ),
        SetupCheck(
            id: 2,
            name: String(localized: "OpenSpec en el repo"),
            pendingDetail: String(localized: "Estado del cliente OPSX, profile activo, specs y changes existentes."),
            runningDetail: String(localized: "Leyendo openspec/ y el profile activo…"),
            doneDetail: "openspec/ inicializado · profile estándar · 5 specs · 3 changes activos"
        ),
        SetupCheck(
            id: 3,
            name: String(localized: "Memoria y skills preparadas"),
            pendingDetail: String(localized: "Indexación de .workspace/memory/, CLAUDE.md y specs/."),
            runningDetail: String(localized: "Indexando memoria y skills del workspace…"),
            doneDetail: ".workspace/memory/ listo · 3 skills auto-detectadas (Swift/Vapor, Postgres, Testing)"
        ),
    ]

    static let setupFilesToCreate: [(path: String, note: String)] = [
        ("openspec/AGENTS.md", String(localized: "instrucciones para agentes")),
        ("openspec/project.md", String(localized: "contexto del proyecto")),
        ("openspec/specs/", String(localized: "specs vivas")),
        ("openspec/changes/", String(localized: "changes y archive")),
        (".workspace/memory/", String(localized: "memoria del proyecto")),
    ]

    // MARK: - El change de ejemplo

    static let appleLoginTasks: [WorkTask] = [
        WorkTask(id: "1.1", title: "Configurar `apple-services` en config y env", group: "Backend", lane: .trunk),
        WorkTask(id: "1.2", title: "Endpoint `POST /auth/apple` con validación JWKS", group: "Backend", lane: .trunk),
        WorkTask(id: "1.3", title: "Mapear `sub` a usuario existente o crear nuevo", group: "Backend", lane: .fan),
        WorkTask(id: "2.1", title: "Tests de integración con tokens válidos e inválidos", group: "Calidad", lane: .fan),
        WorkTask(id: "2.2", title: "Actualizar OpenAPI spec con el nuevo endpoint", group: "Calidad", lane: .fan),
    ]

    static let appleLoginDeltas: [Delta] = [
        Delta(kind: .md, path: "proposal.md", summary: "qué y por qué · 142 palabras", fileKey: .proposal),
        Delta(kind: .md, path: "design.md", summary: "decisiones técnicas · 3 decisiones", fileKey: .design),
        Delta(kind: .md, path: "tasks.md", summary: "5 tareas · 2 grupos", fileKey: .tasks),
        Delta(kind: .mod, path: "specs/auth/spec.md", summary: "+1 método de login", fileKey: .deltas),
        Delta(kind: .new, path: "specs/auth/apple.md", summary: "capacidad nueva", fileKey: .deltas),
    ]

    static let appleLoginChat: [ExploreMessage] = [
        ExploreMessage(author: .user, text: "Quiero añadir login con Apple a la app iOS. Tenemos JWT con SessionManager y no quiero tocar el modelo de sesión."),
        ExploreMessage(author: .agent, text: "He revisado internal/auth/ — 12 archivos. El modelo de sesión aguanta sin cambios. Te he comparado tres approaches:", artifactLink: "briefing.html"),
        ExploreMessage(author: .user, text: "Vale, leído. Me convence validar contra JWKS en local."),
        ExploreMessage(author: .agent, text: "Un punto que no está en el briefing: el sub de Apple es estable por app, no por Team ID. Si mañana hay otra app con otro client_id, habrá que mapear cuentas."),
        ExploreMessage(author: .agent, text: "Decisión: implementar SIWA validando el identity token contra el JWKS público de Apple, cacheado con TTL 1 h. El modelo de sesión no cambia.", isDecision: true),
    ]

    static let appleLoginHistory: [HistoryStage] = [
        HistoryStage(name: String(localized: "Explorar"), durationLabel: "5 eventos · 14 min", events: [
            HistoryEvent(actor: .human, timeLabel: "13:45", text: "Iniciaste exploración con la idea «login con Apple sin tocar la sesión»"),
            HistoryEvent(actor: .agent, timeLabel: "13:46", text: "Agente revisó internal/auth/", detail: "12 archivos leídos"),
            HistoryEvent(actor: .agent, timeLabel: "13:51", text: "Generó briefing.html con tres approaches"),
            HistoryEvent(actor: .human, timeLabel: "13:57", text: "Decidiste approach 2 (JWKS local)"),
            HistoryEvent(actor: .system, timeLabel: "13:59", text: "Cierre de exploración"),
        ]),
        HistoryStage(name: String(localized: "Idea"), durationLabel: "3 eventos · 4 min", events: [
            HistoryEvent(actor: .human, timeLabel: "14:00", text: "Aterrizaste la idea"),
            HistoryEvent(actor: .human, timeLabel: "14:02", text: "Editaste el resumen", detail: "2 cambios"),
            HistoryEvent(actor: .human, timeLabel: "14:04", text: "Pediste generar plan"),
        ]),
        HistoryStage(name: String(localized: "Plan"), durationLabel: "3 eventos · 4 min", events: [
            HistoryEvent(actor: .agent, timeLabel: "14:04", text: "Generó proposal + design + tasks + deltas", detail: "/opsx:propose"),
            HistoryEvent(actor: .agent, timeLabel: "14:06", text: "Veredicto de paralelización: 3 agentes", detail: "tronco 1.1–1.2 · abanico 1.3, 2.1, 2.2"),
            HistoryEvent(actor: .human, timeLabel: "14:08", text: "Aceptaste el plan e implementación"),
        ]),
        HistoryStage(name: String(localized: "Trabajo"), durationLabel: "6 eventos · 20 min", events: [
            HistoryEvent(actor: .system, timeLabel: "14:08", text: "Sesión iniciada en worktree aislado", detail: "run #1"),
            HistoryEvent(actor: .agent, timeLabel: "14:11", text: "Task 1.1 completada"),
            HistoryEvent(actor: .agent, timeLabel: "14:17", text: "Task 1.2 completada", detail: "apple_handler.go +92"),
            HistoryEvent(actor: .agent, timeLabel: "14:23", text: "Tasks 1.3, 2.1, 2.2 en paralelo", detail: "3 agentes"),
            HistoryEvent(actor: .agent, timeLabel: "14:27", text: "Tests pasando en local", detail: "12/12"),
            HistoryEvent(actor: .system, timeLabel: "14:28", text: "Sesión terminada · lista para revisar"),
        ]),
        HistoryStage(name: String(localized: "Revisión"), durationLabel: "3 eventos · 4 min", events: [
            HistoryEvent(actor: .agent, timeLabel: "14:28", text: "Veredicto de conformance: 4/5 criterios con evidencia"),
            HistoryEvent(actor: .human, timeLabel: "14:31", text: "Revisaste el diff y firmaste las tres voces"),
            HistoryEvent(actor: .system, timeLabel: "14:32", text: "Merge + archivo del change", detail: "a3f7c91"),
        ]),
    ]

    static let appleLoginVoices: [ClosingVoice] = [
        ClosingVoice(
            kind: .commit,
            icon: "G",
            title: String(localized: "Mensaje de commit"),
            audience: String(localized: "para git · técnico"),
            ruleBadge: "regla: conventional-commits",
            content: """
            feat(auth): add Sign in with Apple via JWKS validation

            Validar el identity token de Apple contra su JWKS antes de emitir el
            JWT de sesión. Mapear `sub` a un nuevo campo `apple_sub`. El modelo de
            sesión no cambia (SessionManager). JWKS cacheado en memoria, TTL 1h.

            Refs: PROJ-241
            """,
            primaryActionLabel: String(localized: "Copiar"),
            footnote: String(localized: "el merge usará este mensaje"),
            needsConfirmation: false
        ),
        ClosingVoice(
            kind: .ticket,
            icon: "J",
            title: String(localized: "Nota para el ticket"),
            audience: String(localized: "para PROJ-241 · negocio"),
            content: """
            ✅ Resuelto — Login con Apple ya disponible en la app iOS.

            Los usuarios pueden iniciar sesión con su Apple ID. La validación se
            hace en nuestro backend contra las claves públicas de Apple, sin
            cambios en el modelo de sesión existente.
            """,
            primaryActionLabel: String(localized: "Adjuntar a PROJ-241 →"),
            footnote: String(localized: "cierra contra la intención de origen"),
            needsConfirmation: true
        ),
        ClosingVoice(
            kind: .team,
            icon: "#",
            title: String(localized: "Resumen para el equipo"),
            audience: String(localized: "para #eng · humano, breve"),
            content: """
            🚀 Mergeado: Login con Apple. SIWA validado contra JWKS en local
            (cache 1h), sub mapeado a apple_sub. SessionManager intacto.
            5 archivos, tests verdes.
            """,
            primaryActionLabel: String(localized: "Enviar a #eng →"),
            footnote: String(localized: "tu firma, no la del agente"),
            needsConfirmation: true
        ),
    ]

    static let appleLoginClosure = ClosureStats(
        archivedAtLabel: "14:32",
        durationValue: "38 min",
        durationDetail: "14:08 → 14:32 · 1 sesión",
        tokensValue: "~22k",
        tokensDetail: "explore: 6k · apply: 16k",
        filesValue: "7",
        filesDetail: "5 código · 2 specs",
        committedItems: [
            "5 archivos de código (+113 / −1)",
            "Tests pasando localmente",
            "POST /auth/apple en OpenAPI",
        ],
        commitSHA: "a3f7c91",
        commitMessage: "feat(auth): add Sign in with Apple via JWKS validation",
        learnedItems: [
            "Nueva spec specs/auth/apple.md",
            "Spec maestra specs/auth/spec.md actualizada",
            "1 artefacto archivado · 1 lección en memoria",
        ],
        archivePath: "openspec/changes/archive/2026-05-09-add-apple-login/"
    )

    static let appleLoginReviewLanes: [ReviewLane] = [
        ReviewLane(
            iconLetter: "S",
            title: String(localized: "Specs · conocimiento"),
            countLabel: "2 archivos",
            content: .files([
                ReviewFile(kind: .new, path: "specs/auth/apple.md", added: 24, removed: 0),
                ReviewFile(kind: .mod, path: "specs/auth/spec.md", added: 5, removed: 1),
            ]),
            note: String(localized: "Las specs maestras se actualizarán al mergear vía /opsx:sync.")
        ),
        ReviewLane(
            iconLetter: "C",
            title: String(localized: "Código · ficheros tocados"),
            countLabel: "5 · +113 −1",
            content: .files([
                ReviewFile(kind: .new, path: "internal/auth/apple_handler.go", added: 92, removed: 0),
                ReviewFile(kind: .new, path: "config/apple_services.yaml", added: 18, removed: 0),
                ReviewFile(kind: .mod, path: "config/auth.yaml", added: 3, removed: 1),
                ReviewFile(kind: .mod, path: "internal/auth/routes.go", added: 2, removed: 0),
                ReviewFile(kind: .new, path: "internal/auth/apple_handler_test.go", added: 48, removed: 0),
            ])
        ),
        ReviewLane(
            iconLetter: "A",
            title: String(localized: "Artefactos · briefings y notas"),
            countLabel: "2 generados",
            content: .artifacts([
                ChangeArtifact(name: "briefing.html", phase: "explore", timeLabel: "hace 12 min"),
                ChangeArtifact(name: "implementation_notes.html", phase: "apply", timeLabel: "hace 1 min"),
            ])
        ),
    ]

    static let addAppleLogin = Change(
        id: "add-apple-login",
        title: "Login con Apple",
        state: .exploring,
        createdLabel: "creado hace 3 min",
        origin: "/opsx:explore",
        agentLabel: "claude-code",
        tasks: appleLoginTasks,
        deltas: appleLoginDeltas,
        artifacts: [
            ChangeArtifact(name: "briefing.html", phase: "explore", timeLabel: "hace 12 min"),
            ChangeArtifact(name: "implementation_notes.html", phase: "apply", timeLabel: "hace 1 min"),
        ],
        exploreChat: appleLoginChat,
        ideaText: SampleMarkdown.idea,
        ideaContext: [
            "Sistema de auth actual: JWT + email/contraseña vía SessionManager.",
            "Approach elegido: validar el identity token contra JWKS (cacheado, TTL 1 h).",
            "Riesgo conocido: el sub es estable por app, no por Team ID.",
            "Artefacto: briefing.html con los 3 approaches comparados.",
        ],
        historyStages: appleLoginHistory,
        closingVoices: appleLoginVoices,
        closureStats: appleLoginClosure,
        reviewLanes: appleLoginReviewLanes
    )

    static let changeFiles: [ChangeFileKey: ChangeFileContent] = [
        .proposal: ChangeFileContent(name: "proposal.md", title: String(localized: "Qué y por qué"), content: SampleMarkdown.proposal),
        .design: ChangeFileContent(name: "design.md", title: String(localized: "Decisiones técnicas"), content: SampleMarkdown.design),
        .tasks: ChangeFileContent(name: "tasks.md", title: String(localized: "Tareas del change"), content: SampleMarkdown.tasks),
        .deltas: ChangeFileContent(name: "deltas", title: String(localized: "Deltas de specs"), content: SampleMarkdown.deltas),
    ]

    // MARK: - Hub

    static let queueDecisions: [QueueDecision] = [
        QueueDecision(
            id: "conflict",
            kindLabel: String(localized: "Conflicto entre ramas"),
            scopeLabel: "add-apple-login ✕ add-rate-limiting",
            authorityLabel: String(localized: "decisión humana"),
            title: "Dos cambios reescriben `SessionManager` a la vez",
            body: String(localized: "Apple login añade un método de emisión de sesión; rate limiting envuelve el mismo flujo con contadores por tier. Si mergean en cualquier orden sin decidir, el segundo pisa al primero."),
            consequenceTitle: String(localized: "Si fusionas Apple primero"),
            consequences: [
                String(localized: "Rate limiting rebasa sobre el método nuevo — sin conflicto de merge."),
                String(localized: "El contador por tier cubre también los logins con Apple."),
                String(localized: "Coste: la rama de rate limiting necesita un rebase corto."),
            ],
            actions: [
                .init(label: String(localized: "Apple primero, luego rate limit"), role: .primary, toastMessage: String(localized: "Orden decidido: Apple → rate limit")),
                .init(label: String(localized: "Rate limit primero"), role: .secondary, toastMessage: String(localized: "Orden decidido: rate limit → Apple")),
                .init(label: String(localized: "Ver el choque"), role: .ghost, toastMessage: String(localized: "Abriendo comparación del conflicto…")),
                .init(label: String(localized: "aplazar"), role: .postpone, toastMessage: String(localized: "Decisión aplazada")),
            ]
        ),
        QueueDecision(
            id: "plan",
            kindLabel: String(localized: "Plan listo · necesita tu OK"),
            scopeLabel: "add-apple-login",
            authorityLabel: String(localized: "propuesto por claude-opus-4.7"),
            title: String(localized: "Plan de 5 tasks para Sign in with Apple"),
            body: String(localized: "Proposal, design y tasks generados. El veredicto de paralelización recomienda 3 agentes: tronco secuencial 1.1–1.2 y abanico 1.3, 2.1, 2.2."),
            consequenceTitle: String(localized: "Asunciones del plan a revisar"),
            consequences: [
                String(localized: "El campo apple_sub se añade a la tabla users sin migración disruptiva."),
                String(localized: "El JWKS se cachea en memoria — sin Redis."),
                String(localized: "Los tests usan tokens firmados con clave de prueba propia."),
            ],
            actions: [
                .init(label: String(localized: "Aprobar e implementar"), role: .primary, toastMessage: String(localized: "Plan aprobado · implementando")),
                .init(label: String(localized: "Revisar y ajustar"), role: .secondary, toastMessage: String(localized: "Abriendo el plan…")),
                .init(label: String(localized: "Descartar"), role: .destructive, toastMessage: String(localized: "Plan descartado")),
                .init(label: String(localized: "aplazar"), role: .postpone, toastMessage: String(localized: "Decisión aplazada")),
            ]
        ),
        QueueDecision(
            id: "jira",
            kindLabel: String(localized: "Intent desde Jira"),
            scopeLabel: "PROJ-263",
            authorityLabel: String(localized: "importado · sin aterrizar"),
            title: String(localized: "«Los usuarios free ven el botón de exportar»"),
            body: String(localized: "El ticket describe un bug de permisos en la exportación. Puede aterrizarse como change directo (propose) o explorarse primero si el alcance no está claro."),
            consequenceTitle: String(localized: "Lo que sabemos del ticket"),
            consequences: [
                String(localized: "Reportado por soporte · 14 usuarios afectados."),
                String(localized: "La spec specs/billing/spec.md define exportar como premium."),
            ],
            actions: [
                .init(label: String(localized: "Proponer change"), role: .primary, toastMessage: String(localized: "Creando change desde PROJ-263…")),
                .init(label: String(localized: "Explorar primero"), role: .secondary, toastMessage: String(localized: "Abriendo exploración…")),
                .init(label: String(localized: "aplazar"), role: .postpone, toastMessage: String(localized: "Decisión aplazada")),
            ]
        ),
    ]

    static let workLanes: [WorkLane] = [
        WorkLane(status: .conflict, name: "add-apple-login", taskInfo: "task 1.3 en curso · 2/5 hechas", agentInfo: "claude-code · run #1", actions: [String(localized: "Ver conflicto"), String(localized: "Abrir change")]),
        WorkLane(status: .needsRevision, name: "migrate-openapi-31", taskInfo: "sesión terminada · 7/7 tasks", agentInfo: "codex · run #2", actions: [String(localized: "Revisar ahora"), String(localized: "Abrir change")]),
        WorkLane(status: .readyToMerge, name: "add-rate-limiting", taskInfo: "aprobado 5/5 criterios", agentInfo: "claude-code · run #1", actions: [String(localized: "Mergear y archivar"), String(localized: "Abrir change")]),
        WorkLane(status: .needsRevision, name: "fix-export-permissions", taskInfo: "1 criterio sin evidencia", agentInfo: "codex · run #1", actions: [String(localized: "Juzgar evidencia"), String(localized: "Abrir change")]),
    ]

    // MARK: - Trabajo: guion del stream

    static let workScript: [StreamEvent] = [
        StreamEvent(kind: .thought, text: "Necesito validar el identity token contra el JWKS de Apple antes de emitir sesión. Empiezo por la configuración.", timeLabel: "14:09", terminalLine: "⏺ leyendo config/auth.yaml"),
        StreamEvent(kind: .fileCreated, text: "Configuración de apple-services con claves de entorno.", timeLabel: "14:10", fileRow: .init(path: "config/apple_services.yaml", added: 18, removed: 0), terminalLine: "⏺ write config/apple_services.yaml"),
        StreamEvent(kind: .message, text: "Task 1.1 completada. Paso a la 1.2.", timeLabel: "14:11", terminalLine: "⏺ task 1.1 done"),
        StreamEvent(kind: .tool(name: "web_search"), text: "Buscando especificación del endpoint JWKS de Apple", timeLabel: "14:12", terminalLine: "⏺ tool web_search «apple jwks endpoint»"),
        StreamEvent(kind: .fileCreated, text: "Handler del endpoint POST /auth/apple con validación JWKS y cache TTL 1h.", timeLabel: "14:15", fileRow: .init(path: "internal/auth/apple_handler.go", added: 92, removed: 0), terminalLine: "⏺ write internal/auth/apple_handler.go"),
        StreamEvent(kind: .fileModified, text: "Registro de la ruta nueva en el router de auth.", timeLabel: "14:16", fileRow: .init(path: "internal/auth/routes.go", added: 2, removed: 0), terminalLine: "⏺ edit internal/auth/routes.go"),
        StreamEvent(kind: .fileModified, text: "auth.yaml: Apple como método de login soportado.", timeLabel: "14:16", fileRow: .init(path: "config/auth.yaml", added: 3, removed: 1), terminalLine: "⏺ edit config/auth.yaml"),
        StreamEvent(kind: .message, text: "Task 1.2 completada. El tronco está cerrado; reparto 1.3, 2.1 y 2.2 entre los agentes del abanico.", timeLabel: "14:17", terminalLine: "⏺ task 1.2 done · fan-out ×3"),
        StreamEvent(kind: .thought, text: "Los tests necesitan tokens firmados con una clave de prueba propia para no depender de Apple.", timeLabel: "14:19", terminalLine: "⏺ generando fixtures de test"),
        StreamEvent(kind: .fileCreated, text: "Tests de integración: token válido, expirado y con firma inválida.", timeLabel: "14:23", fileRow: .init(path: "internal/auth/apple_handler_test.go", added: 48, removed: 0), terminalLine: "⏺ write apple_handler_test.go"),
        StreamEvent(kind: .message, text: "Tests pasando 12/12. OpenAPI actualizada. Listo para revisión.", timeLabel: "14:27", terminalLine: "⏺ tests 12/12 ok"),
    ]

    // MARK: - Orquestación

    static let orchNodes: [OrchNode] = [
        OrchNode(id: "1.1", agentLabel: "tronco", taskLabel: "1.1 config", column: .trunk, status: .done, position: CGPoint(x: 110, y: 90)),
        OrchNode(id: "1.2", agentLabel: "tronco", taskLabel: "1.2 endpoint", column: .trunk, status: .done, position: CGPoint(x: 110, y: 240)),
        OrchNode(id: "1.3", agentLabel: "agente-A", taskLabel: "1.3 mapear sub", column: .fan, status: .running, position: CGPoint(x: 410, y: 60)),
        OrchNode(id: "2.1", agentLabel: "agente-B", taskLabel: "2.1 tests", column: .fan, status: .running, position: CGPoint(x: 410, y: 165)),
        OrchNode(id: "2.2", agentLabel: "agente-C", taskLabel: "2.2 openapi", column: .fan, status: .done, position: CGPoint(x: 410, y: 270)),
        OrchNode(id: "merge", agentLabel: "convergencia", taskLabel: "conclusión", column: .merge, status: .pending, position: CGPoint(x: 700, y: 165)),
    ]

    // MARK: - Inventario

    static let inventoryGroups: [InventoryGroup] = [
        InventoryGroup(title: String(localized: "Skills"), pieces: [
            InventoryPiece(name: "test-vapor", detail: String(localized: "tests de integración Vapor"), badges: ["activo"], previewText: "Levanta una BD efímera con testcontainers, genera el caso feliz y dos de error, verifica el contrato contra la spec."),
            InventoryPiece(name: "postgres-migration", detail: String(localized: "migraciones Postgres seguras y reversibles"), badges: ["activo"], previewText: "Toda migración lleva prepare() y revert(). Se prueba el ciclo completo antes de mergear."),
            InventoryPiece(name: "swift-networking", detail: String(localized: "inyección de dependencias en handlers"), badges: ["activo"], previewText: "Los handlers reciben sus dependencias por inyección; nada de singletons de red."),
        ]),
        InventoryGroup(title: String(localized: "Agentes"), pieces: [
            InventoryPiece(name: "Builder", detail: "claude-opus · implementa tasks en worktrees aislados", badges: ["activo", "default"], previewText: "CLI: Claude Code · Modelo: claude-opus-4.7 · Rol: implementador · Puede tocar: internal/, api/ · Aislamiento: worktree · sandbox L3"),
            InventoryPiece(name: "Reviewer", detail: "codex · audita contra specs y reglas", badges: ["activo"], previewText: "CLI: Codex · Rol: revisor · Solo lectura del diff · Verifica criterios de aceptación contra archivos."),
            InventoryPiece(name: "agente-refactor", detail: "claude-code · refactors acotados", badges: [], previewText: "Refactors mecánicos con tests verdes como invariante."),
            InventoryPiece(name: "agente-documentador", detail: "opencode · mantiene specs y docs", badges: [], previewText: "Actualiza specs vivas y documentación tras cada archive."),
        ]),
        InventoryGroup(title: String(localized: "Workflows"), pieces: [
            InventoryPiece(name: "estándar-opsx", detail: "Explorar → Idea → Plan → Trabajo → Revisión", badges: ["core"], previewText: "Fases: Explorar → Idea → Plan → Trabajo → Revisión · Comandos opsx: explore · propose · apply · verify · archive"),
        ]),
        InventoryGroup(title: String(localized: "Reglas"), pieces: [
            InventoryPiece(name: "auth-por-SessionManager", detail: String(localized: "toda auth pasa por SessionManager"), badges: ["bloqueante"], previewText: "Ninguna ruta emite sesión fuera de SessionManager. El agente rechaza diffs que lo violen."),
            InventoryPiece(name: "no-singletons", detail: String(localized: "inyección de dependencias siempre"), badges: ["bloqueante"], previewText: "Nada de var Instance a nivel de paquete excepto config inmutable."),
            InventoryPiece(name: "async-await-preferido", detail: String(localized: "callbacks solo en bordes legacy"), badges: ["activo"], previewText: "Concurrencia con async/await; los callbacks solo al integrar APIs legacy."),
        ]),
    ]
}
