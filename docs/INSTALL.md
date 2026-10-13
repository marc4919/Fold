# Instalar y desinstalar Fold (beta)

## Desde el código (hoy)

Todavía no hay release firmada. Para probar Fold:

```bash
git clone https://github.com/marc4919/Fold.git
cd Fold
xcodebuild -project Fold.xcodeproj -scheme Fold -configuration Release build
```

O abre `Fold.xcodeproj` en Xcode 26 y pulsa ⌘R.

## Desde una release (cuando exista)

1. Descarga `Fold-<versión>-beta.<build>.zip` de la release.
2. Descomprime y arrastra `Fold.app` a `/Applications`.
3. Ábrela con doble clic: el build estará firmado con Developer ID y
   notarizado, así que Gatekeeper lo verifica sin pasos extra.

## Agentes

Para el flujo completo necesitas al menos una CLI de agente con sesión:

- `claude` → ejecuta `claude` y usa `/login`
- `codex` → `codex login`
- `opencode` → `opencode auth login`
- `cursor-agent` → `cursor-agent login`

## Qué escribe Fold en tu máquina

Ver la tabla de [PRIVACY.md](PRIVACY.md#lo-que-fold-guarda-en-tu-mac).

## Desinstalación

1. Arrastra `Fold.app` a la papelera.
2. Borra los datos de la app:

   ```bash
   rm -rf ~/Library/Application\ Support/Fold ~/Library/Logs/Fold
   defaults delete dev.marcgarciateodoro.fold
   ```

3. Opcional, por proyecto: elimina `openspec/` y `.workspace/`, y las ramas
   `fold/*` que queden (`git branch --list 'fold/*'`). Son tuyos, en tu repo.

Fold no instala daemons, extensiones ni items de arranque.
