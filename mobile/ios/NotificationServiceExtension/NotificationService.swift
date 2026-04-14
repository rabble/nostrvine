import UserNotifications

class NotificationService: UNNotificationServiceExtension {
    var contentHandler: ((UNNotificationContent) -> Void)?
    var bestAttemptContent: UNMutableNotificationContent?

    override func didReceive(
        _ request: UNNotificationRequest,
        withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void
    ) {
        self.contentHandler = contentHandler
        bestAttemptContent = (request.content.mutableCopy() as? UNMutableNotificationContent)

        guard let bestAttemptContent = bestAttemptContent else {
            contentHandler(request.content)
            return
        }

        // Parse data-only FCM payload from divine-push-service
        let userInfo = request.content.userInfo

        // FCM wraps data in different keys depending on payload structure
        let data: [String: Any]
        if let fcmData = userInfo["data"] as? [String: Any] {
            data = fcmData
        } else {
            data = userInfo as? [String: Any] ?? [:]
        }

        if let title = data["title"] as? String {
            bestAttemptContent.title = title
        }
        if let body = data["body"] as? String {
            bestAttemptContent.body = body
        }

        if let referencedEventId = data["referencedEventId"] as? String {
            bestAttemptContent.userInfo["referencedEventId"] = referencedEventId
        }

        if let type = data["type"] as? String {
            bestAttemptContent.categoryIdentifier = "divine_\(type.lowercased())"
        }

        bestAttemptContent.threadIdentifier = "divine_notifications"

        contentHandler(bestAttemptContent)
    }

    override func serviceExtensionTimeWillExpire() {
        if let contentHandler = contentHandler,
           let bestAttemptContent = bestAttemptContent {
            contentHandler(bestAttemptContent)
        }
    }
}
