# Privacidad — Fold

Fold es **local-first** y no tiene servidor propio.

## Lo que Fold no hace

- No envía telemetría, analíticas ni informes de fallos.
- No abre conexiones de red propias (no usa URLSession, WebKit ni Network).

## Lo que sí sale de tu máquina (a través de tus CLIs)

- **Prompts al proveedor de tu agente** (Anthropic, OpenAI, el que use
  OpenCode, Cursor…), con tu cuenta y sus condiciones. Además del texto que
  escribes, Fold incluye en los prompts: tu perfil (nombre, rol y
  preferencias de Ajustes), la memoria del proyecto y los artefactos del
  change. Lo que el agente lea del repo también llega al proveedor.
- **Comprobaciones de sesión al arrancar**: `codex login status` y
  `cursor-agent status` pueden contactar con su servidor.

## Lo que Fold guarda en tu Mac

| Dónde | Qué |
|---|---|
| `~/Library/Application Support/Fold/Fold.store` | proyectos recientes |
| UserDefaults (`dev.marcgarciateodoro.fold`) | perfil de usuario, agente y editor por defecto, modo de aislamiento, apariencia, onboarding |
| `~/Library/Logs/Fold/fold.log` | eventos de ejecución redactados (sin prompts; ver SECURITY.md) |
| Dentro de cada proyecto | `openspec/` y `.workspace/` (memoria, worktrees, transacciones, historia), y las ramas `fold/<id>` y commits `opsx:`/`merge:` que crea el flujo |

## Diagnóstico

El export de diagnóstico es opcional, se genera bajo demanda y contiene
versiones y estados de la app — nunca credenciales ni contenido del repo.

Si algún día se plantea telemetría, será opt-in explícito y documentado.
