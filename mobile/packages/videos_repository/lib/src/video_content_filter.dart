// ABOUTME: Filter callback for video content in the repository layer.
// ABOUTME: Allows app to inject blocklist/mute logic without coupling.

/// Filter callback for video content.
///
/// Returns `true` if the content from [pubkey] should be hidden
/// (user is blocked/muted).
///
/// Implementations can check blocklists, mute lists, age verification, etc.
/// This keeps the repository decoupled from app-level services.
typedef VideoContentFilter = bool Function(String pubkey);
