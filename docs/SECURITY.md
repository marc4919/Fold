# Seguridad y modelo de amenazas — Fold beta

## Qué procesos ejecuta Fold

- **CLIs de agente** (claude, codex, cursor-agent, opencode): binario +
  argumentos directos vía `posix_spawn` (sin shell), en un grupo de procesos
  propio, con entorno saneado (se eliminan `ANTHROPIC_*` y `CLAUDE*`) y el
  PATH de login del usuario. Buffers acotados, timeout por inactividad y
  cancelación que alcanza a los descendientes (`killpg`).
- **git**: shell-out puntual para status/worktree/commit/merge, siempre con
  argumentos entrecomillados y sobre el proyecto abierto.
- **Terminal embebida** (SwiftTerm): una `zsh -il` que se TERMINA al cerrar
  el sheet (SIGHUP al grupo + SIGKILL de gracia).
- Fold es local-first: no abre conexiones de red propias ni envía telemetría.
  La red la usan las CLIs de agente con sus propias cuentas.

## Qué autenticación se hereda

Fold NUNCA gestiona API keys. Cada CLI usa la sesión que el usuario inició en
su terminal (llavero de Claude Code, `codex login`, `opencode auth login`,
`cursor-agent login`). La detección comprueba la sesión real (llavero /
archivo de credenciales / comando de estado); un agente sin sesión verificada
no se selecciona.

## Qué archivos puede modificar cada fase

| Fase | Escritura permitida | Mecanismo |
|---|---|---|
| Explorar | ninguna | claude `--permission-mode plan` · codex sandbox `read-only` (SO) · opencode `--agent plan` · cursor: deshabilitado (sin modo read-only garantizado) |
| Plan | `openspec/changes/<id>/` | por prompt + revisión posterior (ver límites) |
| Trabajo | worktree `.workspace/worktrees/<id>` | git worktree aislado; el árbol principal no se toca |
| Cierre | rama base | commit por pathspec del manifiesto REVISADO + merge confirmado por el usuario |

## Límites conocidos (honestidad ante todo)

- **El sandbox de SO solo lo aporta Codex.** Con Claude/OpenCode, el modo de
  solo lectura es un mecanismo del propio CLI (permisos/agente restringido),
  no un sandbox del sistema. El límite duro uniforme es el cierre: SOLO se
  commitea el manifiesto que el usuario revisó; nada más entra en git.
- **App Sandbox de macOS está desactivado**: Fold necesita ejecutar las CLIs
  del usuario y leer repos arbitrarios. Distribución prevista: Developer ID
  con Hardened Runtime y notarización (no App Store).
- El contenido del repo (nombres, referencias en markdown, salida del agente)
  se trata como NO confiable: `PathGuard` normaliza, resuelve symlinks y
  valida contención antes de cualquier borrado/escritura fuera del flujo git;
  los adjuntos de memoria referenciados en markdown se validan como nombre
  simple y contención en `attachments/`.

## Qué registra Fold

- `history.json` por change (eventos del timeline con resúmenes de 90 chars).
- Sin logging de prompts completos, tokens ni variables de entorno.
- El export de diagnóstico (Ajustes) incluye versiones y estados, nunca
  credenciales ni contenido del repo.

## Reportar un problema de seguridad

Abre un issue privado o escribe al autor antes de publicar detalles.
