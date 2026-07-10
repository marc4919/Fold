# Fold

Entorno de desarrollo spec-driven para macOS. Fold orquesta agentes de codificación CLI (Claude Code, Codex, Cursor, OpenCode) sobre proyectos [OpenSpec](https://github.com/Fission-AI/OpenSpec): explora, planifica, implementa en aislamiento, revisa y archiva cambios de software — sin picar código.

**Estado: beta temprana (0.1.0-beta.1).** Local-first, sin telemetría.

## Requisitos

- macOS 26.0 o superior
- Xcode 26.x para compilar
- Al menos una CLI de agente instalada y autenticada:
  - [Claude Code](https://claude.com/claude-code) (`claude`)
  - [Codex](https://openai.com/codex) (`codex`)
  - [Cursor CLI](https://cursor.com) (`cursor-agent`)
  - [OpenCode](https://opencode.ai) (`opencode`)

Sin ninguna CLI, Fold abre proyectos en modo lectura: puedes navegar specs, changes, memoria y archive, pero no ejecutar agentes.

## Compilar

```bash
git clone <repo>
cd Fold
xcodebuild -project Fold.xcodeproj -scheme Fold -configuration Debug build
```

O abre `Fold.xcodeproj` en Xcode y pulsa ⌘R. El scheme `Fold` está compartido y versionado.

## Cómo funciona

1. **Abrir proyecto** — Fold lee `openspec/`, `.workspace/` y los agentes de la máquina. No escribe nada hasta que confirmas.
2. **Explorar** — chat de solo lectura con el agente; el briefing se acumula en `exploration.md`.
3. **Idea → Plan** — el agente sintetiza la intención y genera `proposal.md`, `design.md` y `tasks.md`.
4. **Trabajo** — implementación en un worktree de git aislado (`.workspace/worktrees/<change>`), con pausa e intervención.
5. **Revisión** — diff exacto de lo producido; el mensaje de commit es editable y es el que se usa.
6. **Cierre** — merge, archive en `openspec/changes/archive/` y actualización de la memoria del proyecto.

## Qué ejecuta y qué toca

- Fold lanza procesos de las CLIs detectadas con la autenticación del usuario (la misma que en tu terminal).
- Explorar usa los modos de solo lectura de cada CLI (`--permission-mode plan`, `-s read-only`…).
- Implementar escribe únicamente dentro del worktree del change; el árbol principal no se toca hasta el merge que tú confirmas.
- La memoria vive en `.workspace/memory/` del proyecto; nada sale de tu máquina.

## Documentación

- [SECURITY.md](docs/SECURITY.md) — modelo de amenazas, procesos y aislamiento por CLI
- [RELEASE_NOTES.md](docs/RELEASE_NOTES.md) — notas de la beta y problemas conocidos
- [docs/INSTALL.md](docs/INSTALL.md) — instalación y desinstalación

## Licencia

Pendiente de decisión — todos los derechos reservados por ahora. Ver [ACKNOWLEDGEMENTS.md](ACKNOWLEDGEMENTS.md) para las dependencias de terceros.

## Contribuir

El proyecto está en beta cerrada. Si encuentras un fallo, exporta un diagnóstico desde Ajustes → Diagnóstico y adjúntalo al reporte.
