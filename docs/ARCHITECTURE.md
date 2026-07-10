# Arquitectura de Fold (beta 0.1)

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
   └── ShellRunner          shell-out puntual para git (zsh -lc, saneado)
```

## Decisiones clave

1. **El filesystem es la fuente de verdad.** `openspec/` y `.workspace/` se
   leen del disco; la UI se refresca con FSEvents. Nada vive atrapado en la app.
2. **Los permisos son del sistema, no del prompt.** Explorar usa los modos de
   solo lectura de cada CLI (plan mode / sandbox read-only / agente plan);
   una CLI sin modo read-only garantizado no puede explorar (fail closed).
3. **Un evento terminal por ejecución.** ProcessSupervisor garantiza
   succeeded/failed/cancelled/timedOut exactamente una vez; AgentRunner retiene
   el `finished` del parser hasta conocer el estado real del proceso.
4. **Revisión == commit.** El manifiesto que el usuario ve en Revisión se
   persiste en la transacción y el commit usa exactamente ese pathspec.
   Jamás `git add -A`. Lo pre-staged por el usuario nunca entra.
5. **Cierre en dos commits explícitos**: merge del trabajo + `opsx: archive`
   (artefactos + memoria). La limpieza (worktree, rama, registro) solo ocurre
   después de confirmar ambos.
6. **Demo aislada.** `SampleData` solo se alcanza cuando no hay proyecto real
   (`projectURL == nil` / `session.realInfo == nil`); la demo se identifica
   como demo en sus textos.

## Aplazado conscientemente (fuera de la primera beta)

- **Descomposición completa de ChangeSession** en ProjectRepository +
  AgentClient con protocolos e inyección: ChangeSession sigue siendo el
  coordinador (~1400 líneas) con los servicios ya extraídos arriba. El coste
  de re-cablear las vistas no compensaba el riesgo antes de la beta.
- **Orquestación multiagente**: retirada por simulada. Se rediseñará sobre ACP.
- **Conectores MCP gestionados por Fold**: cada CLI usa los suyos.
- **Contención por SO del modo plan** para claude/opencode (codex sí tiene
  sandbox de SO): el límite duro uniforme es el manifiesto del commit.
- **Strict concurrency completo**: el proyecto compila con
  `SWIFT_DEFAULT_ACTOR_ISOLATION = MainActor` y `SWIFT_APPROACHABLE_CONCURRENCY`;
  los servicios son `nonisolated`. El modo `complete` queda para después de
  la descomposición.

## Modelo de amenazas (resumen — ver SECURITY.md)

El contenido del repo (nombres de archivo, referencias en markdown, salida de
los agentes) se trata como NO confiable: PathGuard valida toda ruta destructiva,
los adjuntos de memoria se validan como nombre simple + contención, y los
procesos corren con el entorno saneado (sin ANTHROPIC_*/CLAUDE*).
