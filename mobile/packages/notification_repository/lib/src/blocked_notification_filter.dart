// ABOUTME: Filter callback for notification content in the repository layer.
// ABOUTME: Allows app to inject blocklist/mute logic without coupling.

/// Filter callback for notification content.
///
/// Returns `true` if the content from [pubkey] should be hidden
/// (user is blocked/muted).
///
/// This keeps the repository decoupled from app-level services.
typedef BlockedNotificationFilter = bool Function(String pubkey);
