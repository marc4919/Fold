import SwiftUI
import SwiftData
import UserNotifications

@main
struct FoldApp: App {
    @State private var appState = AppState()

    /// Store propio en Application Support/Fold/ — nunca el default.store
    /// compartido, que otras apps pueden pisar.
    private static let modelContainer: ModelContainer = {
        let supportURL = FileManager.default
            .urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Fold", isDirectory: true)
        try? FileManager.default.createDirectory(at: supportURL, withIntermediateDirectories: true)
        let configuration = ModelConfiguration(url: supportURL.appendingPathComponent("Fold.store"))
        do {
            return try ModelContainer(for: PersistentProject.self, configurations: configuration)
        } catch {
            // Último recurso: store en memoria para no impedir el arranque.
            return try! ModelContainer(
                for: PersistentProject.self,
                configurations: ModelConfiguration(isStoredInMemoryOnly: true)
            )
        }
    }()

    var body: some Scene {
        WindowGroup {
            RootView()
                .environment(appState)
                .frame(minWidth: 1180, minHeight: 740)
                .task {
                    appState.detectedAgents = await AgentDetector.detect()
                    _ = try? await UNUserNotificationCenter.current()
                        .requestAuthorization(options: [.alert, .sound])
                }
        }
        .defaultSize(width: 1280, height: 800)
        .windowResizability(.contentMinSize)
        .modelContainer(Self.modelContainer)

        Settings {
            SettingsView()
                .environment(appState)
                .preferredColorScheme(appState.appearance.colorScheme)
        }
    }
}
