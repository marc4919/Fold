# Seguridad y modelo de amenazas — Fold beta

Este documento describe lo que Fold hace **hoy**, incluidos sus límites. Si
algo de aquí no coincide con el código, es un bug: repórtalo.

## Qué procesos ejecuta Fold

- **CLIs de agente** (`claude`, `codex`, `opencode`, `cursor-agent`): binario +
  argumentos directos vía `posix_spawn` (sin shell), en un grupo de procesos
  propio, con buffers acotados, timeout por inactividad y tope duro, y
  cancelación que alcanza al grupo (`killpg`). Un descendiente que cree su
  propio grupo de procesos (p. ej. algunos servidores MCP) puede no recibir la
  señal.
- **Comandos propios de Fold** vía `zsh -lc` (se carga tu perfil de login para
  heredar el PATH): `git` (status, worktree, add, commit, merge, branch),
  `wc`, `command -v` y `--version` para detectar CLIs, `open -a` para abrir el
  editor y `/usr/bin/security find-generic-password` para comprobar la sesión
  de Claude Code. Los argumentos van siempre entrecomillados; git corre con
  `GIT_LITERAL_PATHSPECS=1` y `GIT_TERMINAL_PROMPT=0`, y cada comando tiene
  timeout (120 s por defecto).
- **Comprobación de sesión al arrancar**: `codex login status` y
  `cursor-agent status`. Estos comandos pueden contactar con el servidor de
  su proveedor.
- **Terminal embebida** (SwiftTerm): una `zsh -il` que se termina al cerrar el
  sheet (SIGHUP al grupo + SIGKILL de gracia).

## Entorno de los procesos

Se eliminan **solo** las variables `ANTHROPIC_*` y `CLAUDE*` (para que un
agente lanzado desde otro agente no herede su sesión). El resto del entorno se
hereda tal cual, incluidas variables como `OPENAI_API_KEY`, `GITHUB_TOKEN` o
`AWS_*` si las tienes exportadas. Consecuencia: Claude Code configurado con
API key, Bedrock o Vertex por variables de entorno no funciona desde Fold.

## Qué autenticación se hereda

Fold nunca gestiona credenciales. Cada CLI usa la sesión que iniciaste en tu
terminal. La detección comprueba **presencia**, no validez:

| CLI | Comprobación |
|---|---|
| Claude Code | existe el ítem `Claude Code-credentials` en el llavero |
| Codex | `codex login status` sale con 0 |
| OpenCode | existe `~/.local/share/opencode/auth.json` con contenido |
| Cursor CLI | `cursor-agent status` dice "Logged in" (y no "Not logged in") |

Un token caducado pasa la comprobación; el fallo aparecerá al ejecutar.

## Qué puede tocar cada fase

| Fase | Directorio de trabajo | Mecanismo de contención |
|---|---|---|
| Explorar | proyecto | claude `--permission-mode plan` · codex `-s read-only` (sandbox de SO) · opencode: agente `fold-explore` inyectado por Fold (deny-all + solo read/glob/grep/list) · cursor: **deshabilitado** |
| Plan | proyecto | el agente escribe `proposal.md`/`design.md`/`tasks.md` con permisos de escritura del CLI; el prompt lo restringe a `openspec/changes/<id>/` |
| Trabajo (aislado, por defecto) | worktree `.workspace/worktrees/<id>` en rama `fold/<id>` | ver abajo |
| Trabajo (modo directo, opcional) | árbol principal | solo arranca con el árbol limpio fuera del change |
| Cierre | rama base | commit por pathspec literal del manifiesto revisado + merge confirmado por ti |

### El worktree NO es un sandbox

El worktree es el directorio de trabajo del agente, no una jaula:

- **Codex** (`-s workspace-write`) es el único con sandbox de SO que impide
  escribir fuera.
- **Claude Code** (`--permission-mode acceptEdits`) acepta ediciones
  automáticamente; los comandos de shell siguen sus reglas de permisos.
- **OpenCode** usa su agente `build` por defecto, que permite herramientas de
  escritura y bash.
- **Cursor CLI** se lanza con `-f` (autoriza comandos sin preguntar) y sin
  sandbox.

Con Claude, OpenCode y Cursor, un agente puede técnicamente escribir fuera
del worktree. Lo que Fold garantiza es qué entra en git, no qué toca el
agente en disco.

### Lo que entra en git

1. **Commit del plan** (automático, al pasar a Trabajo): `opsx: plan de <id>`
   en la rama base, con pathspec `openspec/changes/<id>` y nada más. No hay
   revisión previa de este commit: incluye lo que el agente escribió en esa
   carpeta durante el Plan.
2. **Commit del trabajo**: exactamente los paths del manifiesto que viste en
   Revisión (pathspecs literales: un archivo llamado `*` no amplía el commit).
   En modo directo, lo que tenías staged antes de empezar se excluye.
3. **Merge** `--no-ff` de `fold/<id>` a la rama base, que debe seguir siendo la
   rama actual; un conflicto aborta el merge y conserva worktree y rama.
4. **Commit del archivo** `opsx: archive <id>`: solo el directorio original
   del change, su destino en `openspec/changes/archive/` y la entrada de
   memoria creada. Otros changes y memorias no entran.

## El repo es contenido no confiable

- `PathGuard` normaliza, resuelve symlinks y valida contención antes de
  cualquier borrado o escritura fuera del flujo git; las operaciones
  destructivas rechazan además la propia raíz.
- Los adjuntos de memoria referenciados en markdown se validan como nombre
  simple y contención en `attachments/`.
- Los registros de transacción (`.workspace/transactions/<id>.json`) solo se
  aceptan si su rama es `fold/<id>` y su worktree `.workspace/worktrees/<id>`;
  si no, se ignoran.

**Límite importante:** las CLIs aplican la configuración del proyecto que
abras (`.claude/settings.json` con hooks, `opencode.json` con plugins,
`.cursor/`, `AGENTS.md`…) y en headless se salta el diálogo de confianza del
workspace. **Abre en Fold solo repos en los que confíes**, igual que harías
al ejecutar `claude -p` o `codex exec` en ellos.

## App Sandbox

El App Sandbox de macOS está **desactivado**: Fold necesita ejecutar tus CLIs
y leer repos arbitrarios. La app usa Hardened Runtime; la distribución
prevista es Developer ID notarizado (no App Store).

## Qué registra Fold

- `history.json` por change: eventos del timeline con detalle acotado a 280
  caracteres (puede contener parte de tus instrucciones o de un error). Se
  versiona con el archivo del change.
- `~/Library/Logs/Fold/fold.log`: inicio y fin de cada ejecución de agente
  (binario, modo, nº de argumentos, nombre de la carpeta, código de salida y
  hasta 200 caracteres de stderr). Nunca el prompt.
- El export de diagnóstico (Ajustes → Diagnóstico) incluye versión de la app
  y del SO, agentes con versión y estado de sesión, modo de aislamiento y
  recuentos. Nunca credenciales ni contenido del repo.

## Reportar un problema de seguridad

Usa **Private vulnerability reporting** del repositorio en GitHub
(pestaña Security → Report a vulnerability) o escribe a
marcgt.dev@icloud.com. No publiques detalles en un issue abierto antes de
que haya un arreglo.
