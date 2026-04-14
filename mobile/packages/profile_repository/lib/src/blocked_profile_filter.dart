// ABOUTME: Filter callback for profile content in the repository layer.
// ABOUTME: Allows app to inject blocklist/mute logic without coupling.

/// Filter callback for profile content.
///
/// Returns `true` if the content from [pubkey] should be hidden
/// (user is blocked/muted).
///
/// This keeps the repository decoupled from app-level services.
typedef BlockedProfileFilter = bool Function(String pubkey);
