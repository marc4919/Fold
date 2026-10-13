# Fold 0.1.0 beta 1 — Notas de la versión

Primera beta pública de Fold: entorno spec-driven para macOS que orquesta
agentes CLI sobre proyectos OpenSpec.

## Qué funciona de extremo a extremo

- Abrir/crear proyecto → comprobación del entorno (agentes + OpenSpec + memoria)
- Crear change → explorar (chat de solo lectura con briefing acumulativo) →
  aterrizar idea → generar plan (proposal/design/tasks incrementales) →
  implementar en worktree → pausar/intervenir → revisar el diff exacto →
  editar el mensaje de commit → merge → archivar → memoria actualizada
- Memoria del proyecto: entradas, adjuntos, renombrar/eliminar; lo archivado
  alimenta la memoria y la memoria condiciona los prompts siguientes
- Inventario/Forja: skills, reglas, plantillas, workflows y perfiles de agente
  como archivos planos del repo
- Historia por change persistida con actores y tiempos reales

## Agentes compatibles (matriz real)

| CLI | Explorar (solo lectura) | Implementar | Continuar conversación | Sesión detectada |
|---|---|---|---|---|
| Claude Code | ✓ `--permission-mode plan` | ✓ `acceptEdits` | ✓ | ✓ (llavero) |
| Codex | ✓ sandbox de SO read-only | ✓ `workspace-write` (sandbox de SO) | ✓ | ✓ (`login status`) |
| OpenCode | ✓ agente `fold-explore` (deny-all + lectura) | ✓ agente `build` | ✗ | ✓ (credenciales) |
| Cursor CLI | ✗ deshabilitado (read-only no verificado) | ✓ `-f`, sin sandbox | ✗ | ✓ (`status`) |

"Sesión detectada" comprueba que existe, no que siga siendo válida.

## Problemas conocidos

- **El worktree no es un sandbox.** Solo Codex impide por SO escribir fuera de
  él. Claude, OpenCode y Cursor (este con `-f`) pueden tocar archivos fuera
  del worktree; lo que Fold garantiza es que solo lo revisado entra en git.
- **La configuración del proyecto de cada CLI se aplica sin diálogo de
  confianza** (hooks de `.claude/settings.json`, plugins de `opencode.json`…),
  también al explorar. Abre solo repos en los que confíes.
- **El plan se commitea automáticamente** (`opsx: plan de <id>`) en la rama
  base al pasar a Trabajo, sin revisión de ese commit. Solo incluye
  `openspec/changes/<id>/`.
- **La generación del plan** se ejecuta con permisos de escritura del CLI en
  todo el repo; el prompt la restringe al change.
- **Modo directo** (Ajustes → aislamiento): el agente trabaja en el árbol
  principal. Para no mezclar tus cambios con los suyos, solo arranca con el
  árbol limpio fuera del change.
- **App Sandbox desactivado** (necesario para ejecutar las CLIs).
- **Entorno heredado**: solo se eliminan `ANTHROPIC_*` y `CLAUDE*`; Claude
  Code con API key/Bedrock/Vertex por variables de entorno no funciona.
- **Recuperación tras reinicio parcial**: el worktree y la rama se reutilizan
  al relanzar Trabajo, no al abrir la app.
- **Continuar conversación** no funciona con OpenCode ni Cursor: cada paso
  usa el transcript como contexto.
- La lista de editores externos ("Abrir en editor") es fija y no detecta si
  el editor está instalado (`open -a` falla limpiamente si no lo está).
- Sin UI tests automatizados todavía (la suite cubre servicios y git).
- La localización es solo español.
- El watcher FSEvents puede tardar ~1 s en reflejar cambios externos.
- Sin release firmada todavía: se compila desde el código.
- No hay integración ACP: los agentes se lanzan en headless por CLI.
- **Las specs maestras no se sincronizan al archivar.** Fold mueve el change
  a `archive/`, pero no fusiona sus deltas en `openspec/specs/` como hace
  `openspec archive`. Fold no invoca el CLI de OpenSpec.

## Requisitos

macOS 26.0+ · Xcode 26 para compilar · al menos una CLI de agente con sesión
para el flujo completo. Sin ninguna CLI se puede navegar y editar specs,
changes y memoria, pero no ejecutar agentes.
