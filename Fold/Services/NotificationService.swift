import Foundation
import UserNotifications

/// Notificaciones locales de Fold. El permiso se pide EN CONTEXTO (primera
/// sesión de trabajo larga), nunca en el arranque de la app.
enum NotificationService {
    static func requestPermissionIfNeeded() {
        Task {
            let settings = await UNUserNotificationCenter.current().notificationSettings()
            if settings.authorizationStatus == .notDetermined {
                _ = try? await UNUserNotificationCenter.current()
                    .requestAuthorization(options: [.alert, .sound])
            }
        }
    }

    static func notify(title: String, body: String) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        let request = UNNotificationRequest(
            identifier: UUID().uuidString, content: content, trigger: nil
        )
        UNUserNotificationCenter.current().add(request)
    }
}
