import Foundation

/// Evento persistido del timeline del change (history.json en el change dir).
nonisolated struct StoredHistoryEvent: Codable, Sendable {
    var stage: String      // explore | idea | plan | work | review
    var actor: String      // human | agent | system
    var date: Date
    var text: String
    var detail: String?
}

/// Persistencia de la historia del change: lectura al abrir, escritura en
/// background (el I/O no bloquea el MainActor con cada evento del stream).
nonisolated final class HistoryStore: @unchecked Sendable {
    private let url: URL?
    private let queue = DispatchQueue(label: "dev.fold.history", qos: .utility)

    init(changeDirURL: URL?) {
        url = changeDirURL?.appendingPathComponent("history.json")
    }

    func load() -> [StoredHistoryEvent] {
        guard let url,
              let data = try? Data(contentsOf: url),
              let events = try? JSONDecoder().decode([StoredHistoryEvent].self, from: data) else { return [] }
        return events
    }

    /// Escribe el log completo en background. La última escritura gana —
    /// suficiente para un log append-only de un solo escritor.
    func persist(_ events: [StoredHistoryEvent]) {
        guard let url else { return }
        queue.async {
            guard let data = try? JSONEncoder().encode(events) else { return }
            try? data.write(to: url)
        }
    }
}
