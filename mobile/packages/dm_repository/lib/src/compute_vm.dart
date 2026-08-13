// ABOUTME: Isolate-backed compute() for every target that has dart:isolate.
// ABOUTME: Web swaps this out for compute_web.dart via compute.dart.

import 'dart:async';
import 'dart:isolate';

import 'package:dm_repository/src/build_mode.dart';

/// Runs [callback] with [message] in a background isolate.
///
/// Same body as Flutter's `_isolates_io.dart`: `Isolate.run` with a debug name
/// that stays a constant under release so the callback's `toString()` is not
/// retained in a product build.
Future<R> compute<M, R>(FutureOr<R> Function(M message) callback, M message) =>
    Isolate.run<R>(
      () => callback(message),
      debugName: kReleaseMode ? 'compute' : callback.toString(),
    );
