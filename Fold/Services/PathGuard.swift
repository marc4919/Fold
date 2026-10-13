import Foundation

/// Contención de rutas: toda operación de escritura o borrado debe quedar dentro
/// del directorio autorizado. Normaliza, resuelve symlinks y falla cerrado —
/// el contenido del repo (nombres, referencias en markdown) no es de confianza.
enum PathGuard {
    nonisolated struct ContainmentError: LocalizedError {
        let path: String
        let root: String
        var errorDescription: String? {
            String(localized: "Ruta fuera del directorio autorizado: \(path) no está dentro de \(root)")
        }
    }

    /// Devuelve la URL normalizada y con symlinks resueltos si queda dentro de `root`;
    /// lanza si escapa. Funciona también con rutas que aún no existen (resuelve el
    /// ancestro existente más profundo, para validar creaciones).
    nonisolated static func verify(_ url: URL, within root: URL) throws -> URL {
        let resolvedRoot = resolveDeep(root.standardizedFileURL)
        let resolved = resolveDeep(url.standardizedFileURL)
        let rootPath = resolvedRoot.path.hasSuffix("/") ? resolvedRoot.path : resolvedRoot.path + "/"
        guard resolved.path == resolvedRoot.path || resolved.path.hasPrefix(rootPath) else {
            throw ContainmentError(path: url.path, root: root.path)
        }
        return resolved
    }

    /// Para operaciones destructivas: como `verify`, pero la propia raíz NO vale
    /// (borrar "dentro de openspec/changes" nunca puede borrar openspec/changes).
    nonisolated static func verifyStrictlyInside(_ url: URL, within root: URL) throws -> URL {
        let resolved = try verify(url, within: root)
        guard resolved.path != resolveDeep(root.standardizedFileURL).path else {
            throw ContainmentError(path: url.path, root: root.path)
        }
        return resolved
    }

    nonisolated static func isContained(_ url: URL, within root: URL) -> Bool {
        (try? verify(url, within: root)) != nil
    }

    /// Un nombre de archivo simple: sin separadores ni "..". Para componentes
    /// individuales extraídos de contenido no confiable.
    nonisolated static func safeFilename(_ name: String) -> String? {
        let trimmed = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty,
              !trimmed.contains("/"),
              !trimmed.contains("\\"),
              trimmed != ".",
              trimmed != ".." else { return nil }
        return trimmed
    }

    /// Resuelve symlinks del componente existente más profundo y reañade el resto.
    /// Así `dir-symlink/nuevo.md` se valida contra el destino real del symlink.
    nonisolated private static func resolveDeep(_ url: URL) -> URL {
        let fm = FileManager.default
        if fm.fileExists(atPath: url.path) {
            return url.resolvingSymlinksInPath()
        }
        var pending: [String] = []
        var current = url
        // Sube hasta el primer ancestro existente (la raíz "/" siempre existe).
        while !fm.fileExists(atPath: current.path), current.pathComponents.count > 1 {
            pending.append(current.lastPathComponent)
            current = current.deletingLastPathComponent()
        }
        var resolved = current.resolvingSymlinksInPath()
        for component in pending.reversed() {
            resolved.appendPathComponent(component)
        }
        return resolved.standardizedFileURL
    }
}
