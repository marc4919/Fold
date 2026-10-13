# Fold

Entorno de desarrollo spec-driven para macOS. Fold orquesta agentes de
codificación CLI (Claude Code, Codex, OpenCode, Cursor CLI) sobre proyectos
[OpenSpec](https://github.com/Fission-AI/OpenSpec): explora, planifica,
implementa en un worktree, revisa y archiva cambios de software.

**Estado: beta temprana (0.1.0 beta 1).** Local-first, sin telemetría. Licencia MIT.

## Por qué

Con agentes de código, el cuello de botella no es teclear: es decidir qué
construir y revisar lo que sale. Fold pone en el centro la fase previa a la
implementación — explorar, proponer, diseñar y desglosar tareas — y deja que
el agente implemente solo cuando el plan está aceptado. Al final, revisas el
diff exacto y solo eso entra en git.

## Cómo funciona

1. **Abrir proyecto** — Fold lee `openspec/`, `.workspace/` y los agentes
   instalados. No escribe nada hasta que confirmas.
2. **Explorar** — chat en solo lectura con el agente; el briefing se acumula
   en `exploration.md`.
3. **Idea → Plan** — el agente sintetiza la intención y genera `proposal.md`,
   `design.md` y `tasks.md`.
4. **Trabajo** — implementación en un git worktree (`.workspace/worktrees/<change>`,
   rama `fold/<change>`), con pausa e intervención.
5. **Revisión** — diff exacto de lo producido; el mensaje de commit es editable
   y es el que se usa.
6. **Cierre** — merge, archivo en `openspec/changes/archive/` y actualización de
   la memoria del proyecto.

## Requisitos

- macOS 26.0 o superior
- Xcode 26.x para compilar
- Al menos una CLI de agente instalada y con sesión iniciada:
  - [Claude Code](https://claude.com/claude-code) (`claude`)
  - [Codex](https://openai.com/codex) (`codex`)
  - [OpenCode](https://opencode.ai) (`opencode`)
  - [Cursor CLI](https://cursor.com) (`cursor-agent`) — solo implementación

Sin ninguna CLI puedes navegar y editar specs, changes y memoria, pero no
ejecutar agentes.

## Compilar

```bash
git clone https://github.com/marc4919/Fold.git
cd Fold
xcodebuild -project Fold.xcodeproj -scheme Fold -configuration Debug build
```

O abre `Fold.xcodeproj` en Xcode y pulsa ⌘R. Tests y CI: `./scripts/ci.sh`.

## Qué garantiza y qué no

- **Entra en git solo lo revisado.** El commit usa exactamente los paths que
  viste en Revisión (pathspecs literales); el archivo commitea solo el change
  y su entrada de memoria. El plan se commitea al empezar Trabajo, acotado a
  `openspec/changes/<id>/`.
- **Explorar es de solo lectura** con Claude Code (plan mode), Codex (sandbox
  de SO) y OpenCode (agente deny-all que inyecta Fold). Con Cursor está
  deshabilitado.
- **El worktree no es un sandbox.** Solo Codex impide por SO escribir fuera
  de él; con el resto, la contención en disco depende de los permisos de
  cada CLI.
- **Abre solo repos en los que confíes**: las CLIs aplican la configuración
  del proyecto (hooks, plugins) también en headless.
- Fold no hace peticiones de red propias. Tus prompts, tu perfil y la memoria
  del proyecto llegan al proveedor de tu agente a través de su CLI.

Detalle completo en [SECURITY.md](docs/SECURITY.md) y [PRIVACY.md](docs/PRIVACY.md).

## Documentación

- [ARCHITECTURE.md](docs/ARCHITECTURE.md) — capas, decisiones y lo aplazado
- [SECURITY.md](docs/SECURITY.md) — modelo de amenazas, procesos y contención por CLI
- [PRIVACY.md](docs/PRIVACY.md) — qué sale de tu máquina y qué se guarda
- [RELEASE_NOTES.md](docs/RELEASE_NOTES.md) — matriz de agentes y problemas conocidos
- [INSTALL.md](docs/INSTALL.md) — instalación y desinstalación

## Hoja de ruta (sin fechas)

- Integración con [Agent Client Protocol](https://agentclientprotocol.com) en
  lugar de la ejecución headless actual
- Explorar con Cursor CLI una vez verificado su modo de solo lectura
- UI tests y localización en inglés

## Contribuir

Issues y PRs bienvenidos. Si encuentras un fallo, exporta un diagnóstico desde
Ajustes → Diagnóstico y adjúntalo. Para problemas de seguridad, ver
[SECURITY.md](docs/SECURITY.md#reportar-un-problema-de-seguridad).

## Licencia

[MIT](LICENSE). Dependencias de terceros en [ACKNOWLEDGEMENTS.md](ACKNOWLEDGEMENTS.md).
