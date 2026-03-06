// ABOUTME: Shared constants for search UX and performance behavior.

/// Debounce duration applied to search query updates.
const searchDebounceDuration = Duration(milliseconds: 300);

/// Minimum query length before expensive search work should start.
///
/// Single-character queries tend to explode result sets and force broad local
/// scans plus remote searches on every keystroke.
const minSearchQueryLength = 2;
