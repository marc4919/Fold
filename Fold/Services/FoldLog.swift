import Foundation

/// Logging local, estructurado y acotado (~/Library/Logs/Fold/fold.log).
/// REDACTADO por diseño: nunca prompts completos, tokens ni credenciales.
enum FoldLog {
    nonisolated private static let queue = DispatchQueue(label: "dev.fold.log", qos: .utility)
    nonisolated private static let maxBytes = 1_048_576

    nonisolated static var url: URL {
        FileManager.default.urls(for: .libraryDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Logs/Fold/fold.log")
    }

    nonisolated static func log(_ message: String) {
        let line = "\(ISO8601DateFormatter().string(from: .now)) \(message)\n"
        queue.async {
            let url = Self.url
            try? FileManager.default.createDirectory(
                at: url.deletingLastPathComponent(), withIntermediateDirectories: true
            )
            // Rotación simple: si supera el tope, se conserva la mitad final.
            if let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize, size > maxBytes,
               let data = try? Data(contentsOf: url) {
                try? data.suffix(maxBytes / 2).write(to: url)
            }
            if let handle = try? FileHandle(forWritingTo: url) {
                handle.seekToEndOfFile()
                handle.write(Data(line.utf8))
                try? handle.close()
            } else {
                try? Data(line.utf8).write(to: url)
            }
        }
    }
}
