import Foundation
import SwiftData

/// Proyecto abierto, persistido entre sesiones.
/// El estado OpenSpec NUNCA se duplica aquí: el filesystem es la fuente de verdad.
@Model
final class PersistentProject {
    @Attribute(.unique) var path: String
    var name: String
    var lastOpenedAt: Date

    init(path: String, name: String, lastOpenedAt: Date = .now) {
        self.path = path
        self.name = name
        self.lastOpenedAt = lastOpenedAt
    }

    var url: URL {
        URL(fileURLWithPath: path)
    }

    var displayPath: String {
        let home = NSHomeDirectory()
        return path.hasPrefix(home)
            ? "~" + path.dropFirst(home.count)
            : path
    }
}
