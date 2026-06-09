// ABOUTME: Filter callback for reposter pubkeys in the repository layer.
// ABOUTME: Allows app to inject blocklist/mute logic without coupling.

/// Filter callback for reposter pubkeys.
///
/// Returns `true` if the user with [pubkey] should be hidden from
/// engagement lists (user is blocked/muted).
///
/// This keeps the repository decoupled from app-level services.
typedef BlockedReposterFilter = bool Function(String pubkey);
