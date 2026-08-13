// ABOUTME: Inline compute() for web, which has no dart:isolate.
// ABOUTME: Selected by the conditional export in compute.dart.

import 'dart:async';

/// Runs [callback] with [message] on the current isolate.
///
/// Same body as Flutter's `_isolates_web.dart`: web has no isolates, so the
/// callback runs inline. The `await null` yields the microtask queue first so
/// an expensive callback does not block the current frame's remaining work.
Future<R> compute<M, R>(
  FutureOr<R> Function(M message) callback,
  M message,
) async {
  await null;
  return callback(message);
}
