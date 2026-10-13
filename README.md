<h1 align="center">Fold</h1>

<p align="center">
  <b>Dirige agentes de código desde la fase que importa: antes de implementar.</b>
</p>

<p align="center">
  <img alt="macOS 26+" src="https://img.shields.io/badge/macOS-26%2B-000?logo=apple&logoColor=white">
  <a href="https://github.com/marc4919/Fold/actions/workflows/ci.yml"><img alt="CI" src="https://github.com/marc4919/Fold/actions/workflows/ci.yml/badge.svg"></a>
  <a href="LICENSE"><img alt="MIT" src="https://img.shields.io/badge/licencia-MIT-blue"></a>
</p>

<!-- TODO hero: grabación de ~15 s del ciclo completo
<p align="center">
  <img src="docs/media/hero.gif" width="760" alt="Fold: de la idea al merge en una sola ventana">
</p>
-->

Los agentes escriben código rápido; lo caro es decidir **qué** construir y
revisar **qué** han producido. Fold es una app nativa de macOS que pone el foco
ahí: explora, propone, diseña y desglosa tareas **antes** de que un agente
implemente nada, y al final solo entra en git lo que tú has revisado.

Funciona con **Claude Code, Codex, OpenCode y Cursor CLI** usando tus propias
sesiones. Sin claves, sin servidor y sin telemetría. Beta 0.1.0.

## Funcionalidades

- **Exploración acumulativa**: el contexto no se pierde entre mensajes; vive en
  `exploration.md`, dentro de tu repo.
- **Plan incremental y editable**: proposal, design y tasks aparecen archivo a
  archivo; puedes editarlos o pedir ajustes al agente.
- **Trabajo aislado en worktree**: tu rama no se toca hasta el merge que tú
  confirmas.
- **Pausa, intervención e iteración**: corrige el rumbo a mitad de sesión o
  lanza otra ronda con feedback.
- **Revisión == commit**: lo que ves en Revisión es exactamente lo que se
  commitea.
- **Memoria del proyecto**: decisiones, adjuntos y aprendizajes en
  `.workspace/memory/`, que alimentan los prompts siguientes.
- **Inventario y Forja**: skills, reglas, plantillas, workflows y perfiles de
  agente como archivos planos del repo.
- **Historia por change**: quién hizo qué y cuándo, persistida junto al change.
- **Cuatro agentes, una interfaz**: cambia de agente desde la toolbar.
- **Nativa de verdad**: SwiftUI con Liquid Glass, VoiceOver, Reduce Motion y
  terminal integrada.

## De la idea al merge

<picture>
  <source media="(prefers-color-scheme: dark)" srcset="docs/media/flow-dark.svg">
  <img src="docs/media/flow-light.svg" width="100%" alt="Explorar, Idea, Plan, Trabajo, Revisión y Cierre, con un bucle de iteración entre Revisión y Trabajo">
</picture>

<!-- TODO capturas: Plan · Revisión · Memoria (claro y oscuro)
<p align="center">
  <img src="docs/media/plan.png" width="32%"> <img src="docs/media/review.png" width="32%"> <img src="docs/media/memory.png" width="32%">
</p>
-->

## Fold y OpenSpec

Fold trabaja sobre la estructura de [OpenSpec](https://github.com/Fission-AI/OpenSpec)
(`openspec/specs`, `openspec/changes`, `archive/`), pero **no invoca el CLI
`openspec`**: lee y escribe esos archivos directamente.

| En OpenSpec | En Fold |
|---|---|
| `/opsx:explore` | Fase Explorar, con su propio prompt |
| `/opsx:propose` | Fase Plan: el agente escribe proposal, design y tasks |
| `/opsx:apply` | Fase Trabajo, en un worktree |
| `openspec archive` | Mueve el change a `archive/<fecha>-<id>`. **No fusiona los deltas en `openspec/specs/`** |

## Qué garantiza y qué no

| Garantiza | No garantiza |
|---|---|
| Solo entra en git lo que revisaste (pathspecs literales) | **El worktree no es un sandbox**: solo Codex impide por SO escribir fuera |
| Explorar en solo lectura con Claude, Codex y OpenCode | Que Cursor CLI pueda explorar (deshabilitado) |
| Cero peticiones de red propias, cero telemetría | Que la config del repo no se aplique: las CLIs cargan sus hooks y plugins, así que **abre solo repos en los que confíes** |
| El merge se detiene si cambiaste de rama; un conflicto no rompe nada | Que una sesión caducada se detecte antes de ejecutar |

Los detalles están en [SECURITY.md](docs/SECURITY.md) y [PRIVACY.md](docs/PRIVACY.md).

## Empezar

Requisitos: macOS 26+, Xcode 26 y al menos una CLI de agente con sesión
iniciada.

```bash
git clone https://github.com/marc4919/Fold.git
cd Fold
open Fold.xcodeproj   # ⌘R en Xcode
```

Tests y CI: `./scripts/ci.sh`. Sin ninguna CLI puedes navegar y editar specs,
changes y memoria, pero no ejecutar agentes.

## Hoja de ruta

- [ ] Usar el CLI de OpenSpec cuando esté instalado para archivar y
      sincronizar las specs maestras
- [ ] [Agent Client Protocol](https://agentclientprotocol.com) en lugar de la
      ejecución headless actual
- [ ] Explorar con Cursor CLI, una vez verificado su modo de solo lectura
- [ ] Release firmada y notarizada
- [ ] Interfaz en inglés y UI tests

## Documentación

[Arquitectura](docs/ARCHITECTURE.md) · [Seguridad](docs/SECURITY.md) ·
[Privacidad](docs/PRIVACY.md) · [Notas de la versión](docs/RELEASE_NOTES.md) ·
[Instalación](docs/INSTALL.md)

## Contribuir

Issues y PRs bienvenidos. Si encuentras un fallo, exporta un diagnóstico desde
Ajustes → Diagnóstico y adjúntalo. Para problemas de seguridad, sigue
[SECURITY.md](docs/SECURITY.md#reportar-un-problema-de-seguridad).

## Licencia

[MIT](LICENSE) © 2026 Marc García Teodoro. Dependencias de terceros en
[ACKNOWLEDGEMENTS.md](ACKNOWLEDGEMENTS.md).
