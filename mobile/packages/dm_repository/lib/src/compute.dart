// ABOUTME: Pure-Dart port of Flutter's compute(), so this repository package
// ABOUTME: can run background work without a runtime Flutter SDK dependency.

/// A `compute` that needs no Flutter SDK dependency (#3338).
///
/// Drop-in replacement for the `compute` in
/// `package:flutter/foundation.dart`. Both implementations mirror Flutter's
/// own: `Isolate.run` where `dart:isolate` exists, and an inline call after
/// yielding the microtask queue on web, where it does not.
library;

export 'compute_vm.dart' if (dart.library.js_interop) 'compute_web.dart';
