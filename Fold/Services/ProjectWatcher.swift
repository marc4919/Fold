import Foundation
import CoreServices

/// Observa directorios del proyecto con FSEvents y notifica con debounce.
/// El filesystem es la fuente de verdad: la app nunca duplica su estado.
final class ProjectWatcher: @unchecked Sendable {
    private var stream: FSEventStreamRef?
    private let onChange: @MainActor () -> Void
    private var debounce: DispatchWorkItem?
    private let queue = DispatchQueue(label: "fold.project-watcher")

    init?(paths: [URL], onChange: @escaping @MainActor () -> Void) {
        self.onChange = onChange

        let existing = paths.filter { FileManager.default.fileExists(atPath: $0.path) }
        guard !existing.isEmpty else { return nil }

        var context = FSEventStreamContext(
            version: 0,
            info: Unmanaged.passUnretained(self).toOpaque(),
            retain: nil,
            release: nil,
            copyDescription: nil
        )

        let callback: FSEventStreamCallback = { _, info, _, _, _, _ in
            guard let info else { return }
            let watcher = Unmanaged<ProjectWatcher>.fromOpaque(info).takeUnretainedValue()
            watcher.scheduleNotification()
        }

        guard let stream = FSEventStreamCreate(
            kCFAllocatorDefault,
            callback,
            &context,
            existing.map(\.path) as CFArray,
            FSEventStreamEventId(kFSEventStreamEventIdSinceNow),
            0.5,
            FSEventStreamCreateFlags(kFSEventStreamCreateFlagFileEvents | kFSEventStreamCreateFlagIgnoreSelf)
        ) else { return nil }

        self.stream = stream
        FSEventStreamSetDispatchQueue(stream, queue)
        FSEventStreamStart(stream)
    }

    private func scheduleNotification() {
        debounce?.cancel()
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            Task { @MainActor in
                self.onChange()
            }
        }
        debounce = work
        queue.asyncAfter(deadline: .now() + 0.6, execute: work)
    }

    deinit {
        if let stream {
            FSEventStreamStop(stream)
            FSEventStreamInvalidate(stream)
            FSEventStreamRelease(stream)
        }
    }
}
