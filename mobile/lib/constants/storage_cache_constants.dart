// ABOUTME: Shared video-cache byte-budget constants for the storage feature.
// ABOUTME: Neutral home so both the service layer and the settings UI can read
// ABOUTME: them without the UI importing the service layer (layering ratchet).

/// Smallest selectable video-cache byte budget (0.5 GB).
const int kCacheLimitMinBytes = 512 * 1024 * 1024;

/// Largest selectable video-cache byte budget (10 GB).
const int kCacheLimitMaxBytes = 10 * 1024 * 1024 * 1024;

/// Default video-cache byte budget when the user hasn't chosen one (2 GB).
const int kCacheLimitDefaultBytes = 2 * 1024 * 1024 * 1024;

/// SharedPreferences key holding the user-chosen video-cache byte budget.
const String kCacheLimitPrefKey = 'video_cache_max_bytes';

/// Rough average size of one cached short video, used to translate a byte
/// budget into an approximate video count in the UI.
const int kApproxVideoBytes = 4 * 1024 * 1024;
