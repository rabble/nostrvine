// ABOUTME: Tracks in-flight native pro_video_editor tasks started by this app
// ABOUTME: Shared registry so teardown cancellation sees every native render

/// Registry of in-flight native `pro_video_editor` tasks started by this app.
///
/// Teardown cancellation (`AppLifecycleState.detached`) can only cancel native
/// work it knows about, so every app-owned native render entry point must run
/// inside [track]. Lives apart from the render services themselves because both
/// the composite render service and the stop-motion assembler register here,
/// and the former already imports the latter.
class NativeRenderTaskRegistry {
  NativeRenderTaskRegistry._();

  static final Map<String, Object> _tokens = <String, Object>{};

  /// Ids of the native tasks currently in flight.
  static Set<String> get activeTaskIds => Set.unmodifiable(_tokens.keys);

  /// Runs [operation], tracking it as active under [id] until it settles.
  ///
  /// A task re-registering the same [id] takes ownership of the entry; the
  /// displaced call's cleanup then leaves the newer registration alone (the
  /// token identity check), so it stays cancellable.
  static Future<T> track<T>(String id, Future<T> Function() operation) async {
    final token = Object();
    _tokens[id] = token;
    try {
      return await operation();
    } finally {
      if (identical(_tokens[id], token)) {
        _tokens.remove(id);
      }
    }
  }

  /// Drops all tracking without cancelling anything.
  ///
  /// Test teardown only — the registry has no production reason to forget a
  /// task that is still running natively.
  static void reset() => _tokens.clear();
}
