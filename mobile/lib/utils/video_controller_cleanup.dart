// ABOUTME: Helper utilities for video controller lifecycle management
// ABOUTME: Provides functions to dispose video controllers when entering camera or other screens

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/providers/individual_video_providers.dart';
import 'package:openvine/utils/unified_logger.dart';

/// Tracks the last invalidation time to prevent duplicate invalidations.
/// Riverpod throws assertions when the same provider is invalidated multiple
/// times in the same frame, so we debounce by skipping repeated calls within
/// the frame time window (16ms at 60fps).
///
/// Thread-safety: This global state is safe because Flutter UI code runs on
/// a single isolate. All calls to disposeAllVideoControllers happen on the
/// main UI thread.
DateTime? _lastInvalidationTime;

/// Minimum time between invalidations (one frame at 60fps)
const _debounceThreshold = Duration(milliseconds: 16);

/// Dispose all video controllers by invalidating the provider family
///
/// This forces all video controllers to dispose, even those kept alive by cache.
/// Use this when entering camera screen or other contexts that need to fully
/// reset video playback state.
///
/// Includes a debounce guard to prevent multiple invalidations in the same
/// frame, which would cause Riverpod assertion errors.
///
/// Works with both WidgetRef and ProviderContainer
void disposeAllVideoControllers(Object ref) {
  final now = DateTime.now();

  // Skip if we invalidated too recently (within same frame)
  if (_lastInvalidationTime != null) {
    final elapsed = now.difference(_lastInvalidationTime!);
    // Handle clock adjustments: negative duration means clock went backwards,
    // so allow the invalidation (treat as if enough time has passed)
    if (elapsed >= Duration.zero && elapsed < _debounceThreshold) {
      Log.debug(
        '🛡️ Skipping duplicate invalidation (${elapsed.inMilliseconds}ms since last)',
        name: 'VideoControllerCleanup',
        category: LogCategory.video,
      );
      return;
    }
  }
  _lastInvalidationTime = now;

  Log.debug(
    '🧹 Invalidating all video controllers',
    name: 'VideoControllerCleanup',
    category: LogCategory.video,
  );

  if (ref is WidgetRef) {
    ref.invalidate(individualVideoControllerProvider);
  } else if (ref is ProviderContainer) {
    ref.invalidate(individualVideoControllerProvider);
  } else {
    throw ArgumentError(
      'Expected WidgetRef or ProviderContainer, got ${ref.runtimeType}',
    );
  }
}
