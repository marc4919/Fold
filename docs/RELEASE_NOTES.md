# Fold 0.1.0-beta.1 — Notas de la versión

Primera beta pública de Fold: entorno spec-driven para macOS que orquesta
agentes CLI sobre proyectos OpenSpec.

## Qué funciona de extremo a extremo

- Abrir/crear proyecto → comprobación del entorno (agentes + OpenSpec + memoria)
- Crear change → explorar (chat de solo lectura con briefing acumulativo) →
  aterrizar idea → generar plan (proposal/design/tasks incrementales) →
  implementar en worktree aislado → pausar/intervenir → revisar el diff exacto →
  editar el mensaje de commit → merge → archivar → memoria actualizada
- Recuperación tras reinicio: worktrees y transacciones registradas se retoman
- Memoria del proyecto: entradas, adjuntos, renombrar/eliminar; lo archivado
  alimenta la memoria y la memoria condiciona los prompts siguientes
- Inventario/Forja: skills, reglas, plantillas, workflows y perfiles de agente
  como archivos planos del repo
- Historia por change persistida con actores y tiempos reales

## Agentes compatibles (matriz real)

| CLI | Explorar (read-only) | Implementar | Resume | Auth verificable |
|---|---|---|---|---|
| Claude Code | ✓ (permission-mode plan) | ✓ | ✓ | ✓ (llavero) |
| Codex | ✓ (sandbox SO read-only) | ✓ (workspace-write) | ✓ | ✓ (login status) |
| OpenCode | ✓ (agente plan) | ✓ | ✓ | ✓ (credenciales) |
| Cursor CLI | ✗ deshabilitado (sin read-only garantizado) | ✓ | ✓ | ✓ (status) |

## Problemas conocidos

- La generación del plan escribe con permisos de escritura del CLI en todo el
  repo (el prompt la restringe al change; el cierre solo commitea lo revisado).
- La lista de editores externos ("Abrir en editor") es fija y no detecta si
  el editor está instalado (`open -a` falla limpiamente si no lo está).
- Sin UI tests automatizados todavía (la suite cubre servicios y git).
- La localización es solo español; `en` no se declara.
- El watcher FSEvents puede tardar ~1 s en reflejar cambios externos.

## Requisitos

macOS 26.0+ · al menos una CLI de agente autenticada para el flujo completo
(sin CLI, los proyectos se abren en modo lectura).
