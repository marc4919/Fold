# Arquitectura de Fold (0.1.0 beta 1)

## Capas

```
Views/ (SwiftUI, @MainActor)
   │ observa
App/  AppState (router, proyecto activo) · ChangeSession (coordinador del change)
   │ usa
Services/ (nonisolated, testeables sin UI)
   ├── ProcessSupervisor    procesos: posix_spawn directo, process group,
   │                        buffers acotados, timeout por inactividad,
   │                        un solo evento terminal
   ├── AgentRunner          traducción CLI → AgentEvent canónico + AgentRunHandle
   ├── AgentCapabilities    matriz cerrada por CLI + verificación de auth real
   ├── AgentDetector        detección de binarios + versión + estado de sesión
   ├── GitChangeTransaction registro persistente del cierre: base, worktree,
   │                        manifiesto aprobado, commit por pathspec, merge
   │                        con guard de rama, archive versionado
   ├── GitService           worktrees (setup/recuperación/descarte) y helpers
   ├── OpenSpecService      lectura/escritura de openspec/ (fuente de verdad)
   ├── MemoryService        .workspace/memory/ (entradas + adjuntos)
   ├── PiecesService        Inventario/Forja (.workspace/skills, templates…)
   ├── PathGuard            contención de rutas: normaliza, resuelve symlinks,
   │                        falla cerrado
   ├── ChangeStateMachine   transiciones válidas del change (pura)
   ├── HistoryStore         history.json en background (fuera del MainActor)
   ├── NotificationService  notificaciones locales, permiso en contexto
   ├── ProjectWatcher       FSEvents con debounce
   └── ShellRunner          shell-out puntual para git (zsh -lc, pathspecs
                            literales, timeout)
```

## Decisiones clave

1. **El filesystem es la fuente de verdad.** `openspec/` y `.workspace/` se
   leen del disco; la UI se refresca con FSEvents. Nada vive atrapado en la app.
2. **Los permisos son de la CLI, no del prompt.** Explorar usa el modo de
   solo lectura de cada CLI (plan mode de Claude, sandbox read-only de Codex,
   agente `fold-explore` deny-all inyectado en OpenCode); una CLI cuyo modo
   read-only Fold no ha verificado no puede explorar (fail closed). Solo
   Codex aporta sandbox de SO.
3. **Un evento terminal por ejecución.** ProcessSupervisor garantiza
   succeeded/failed/cancelled/timedOut exactamente una vez; AgentRunner retiene
   el `finished` del parser hasta conocer el estado real del proceso.
4. **Revisión == commit.** El manifiesto que el usuario ve en Revisión se
   persiste en la transacción y el commit usa exactamente esos paths, como
   pathspecs literales. Jamás `git add -A`. Lo pre-staged por el usuario
   nunca entra; el modo directo exige además el árbol limpio para empezar.
5. **Commits explícitos y acotados**: `opsx: plan de <id>` (solo la carpeta
   del change, al empezar Trabajo), commit del trabajo + merge, y
   `opsx: archive <id>` (solo el change archivado y su entrada de memoria).
   La limpieza (worktree, rama, registro) solo ocurre después de confirmar
   el archivo.
6. **El registro de la transacción no es de confianza.** Vive en el repo; solo
   se acepta si su rama y su worktree son los que Fold crea para ese change.
7. **Demo aislada.** `SampleData` solo se alcanza cuando no hay proyecto real
   (`projectURL == nil` / `session.realInfo == nil`); la demo se identifica
   como demo en sus textos.

## Aplazado conscientemente (fuera de la primera beta)

- **Descomposición completa de ChangeSession** en ProjectRepository +
  AgentClient con protocolos e inyección: ChangeSession sigue siendo el
  coordinador (~1400 líneas) con los servicios ya extraídos arriba. El coste
  de re-cablear las vistas no compensaba el riesgo antes de la beta.
- **ACP (Agent Client Protocol)**: no implementado. Hoy los cuatro agentes se
  lanzan en headless (`claude -p`, `codex exec`, `opencode run`,
  `cursor-agent -p`) y su salida se traduce a `AgentEvent`. ACP es la
  dirección prevista para sustituir esa capa, sin fecha.
- **Orquestación multiagente**: retirada por simulada.
- **Recuperación completa tras reinicio**: el estado del change se deduce de
  `tasks.md` del árbol principal; el worktree y la rama se reutilizan al
  relanzar Trabajo, no al abrir la app.
- **Conectores MCP gestionados por Fold**: cada CLI usa los suyos.
- **Contención por SO** para claude/opencode/cursor (codex sí tiene sandbox
  de SO): el límite duro uniforme es el manifiesto del commit.
- **Strict concurrency completo**: el proyecto compila con
  `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` y `SWIFT_APPROACHABLE_CONCURRENCY`;
  los servicios son `nonisolated`. El modo `complete` queda para después de
  la descomposición.

## Modelo de amenazas (resumen — ver SECURITY.md)

El contenido del repo (nombres de archivo, referencias en markdown, registros
de transacción, salida de los agentes) se trata como NO confiable: PathGuard
valida toda ruta destructiva, los adjuntos de memoria se validan como nombre
simple + contención y los pathspecs de git son literales. La configuración
de proyecto de cada CLI (hooks, plugins) sí se aplica: abre solo repos en los
que confíes.
