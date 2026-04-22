/// In-memory registry of playback source URLs and the currently active
/// source per video index.
///
/// Tracks which URL each video is currently trying to play and supports
/// failover to the next URL in the list. Pure data — no I/O, no Flutter,
/// no async work.
class PlaybackSourceRegistry {
  final _sources = <int, List<String>>{};
  final _activeIndices = <int, int>{};

  /// Records the resolved [sources] and the [activeIndex] currently in use
  /// for video [index].
  void register(int index, List<String> sources, int activeIndex) {
    _sources[index] = sources;
    _activeIndices[index] = activeIndex;
  }

  /// Returns the active source URL for [index], or `null` if none recorded.
  String? activeSourceFor(int index) {
    final list = _sources[index];
    if (list == null) return null;
    final i = _activeIndices[index] ?? 0;
    return i < list.length ? list[i] : null;
  }

  /// Whether this index has any sources registered.
  bool hasSources(int index) =>
      _sources[index] != null && _sources[index]!.isNotEmpty;

  /// Whether there is at least one more source to try for [index].
  bool canAdvance(int index) {
    final list = _sources[index];
    if (list == null || list.isEmpty) return false;
    final next = (_activeIndices[index] ?? 0) + 1;
    return next < list.length;
  }

  /// Advances [index] to the next source and returns it, or `null` when the
  /// source list is exhausted.
  String? advance(int index) {
    final list = _sources[index];
    if (list == null || list.isEmpty) return null;
    final next = (_activeIndices[index] ?? 0) + 1;
    if (next >= list.length) return null;
    _activeIndices[index] = next;
    return list[next];
  }

  /// The current attempt index for [index] (0-based).
  int attemptFor(int index) => _activeIndices[index] ?? 0;

  /// Forgets all entries for [index].
  void remove(int index) {
    _sources.remove(index);
    _activeIndices.remove(index);
  }

  /// Forgets all entries.
  void clear() {
    _sources.clear();
    _activeIndices.clear();
  }
}
