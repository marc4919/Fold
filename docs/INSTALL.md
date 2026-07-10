# Instalar y desinstalar Fold (beta)

## Instalación

1. Descarga `Fold-<versión>.zip` de la release.
2. Descomprime y arrastra `Fold.app` a `/Applications`.
3. Primer arranque: botón derecho → Abrir (build notarizado; Gatekeeper lo
   verifica en el primer lanzamiento).
4. Para el flujo completo necesitas al menos una CLI de agente con sesión:
   - `claude` → ejecuta `claude` y usa `/login`
   - `codex` → `codex login`
   - `opencode` → `opencode auth login`
   - `cursor-agent` → `cursor-agent login`

## Qué escribe Fold en tu máquina

- `~/Library/Application Support/Fold/Fold.store` — lista de proyectos recientes.
- Dentro de cada proyecto que abras (solo tras tu confirmación):
  `openspec/` (specs y changes) y `.workspace/` (memoria, skills, worktrees,
  transacciones). Todo son archivos planos versionables.

## Desinstalación

1. Arrastra `Fold.app` a la papelera.
2. Borra `~/Library/Application Support/Fold/` (recientes).
3. Opcional, por proyecto: elimina `openspec/` y `.workspace/` si no quieres
   conservar specs, memoria e historial (son tuyos, en tu repo).

Fold no instala daemons, extensiones ni items de arranque.
