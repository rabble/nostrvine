// ABOUTME: Pure-Dart build-mode constants, replacing package:flutter/foundation
// ABOUTME: so this repository package needs no runtime Flutter SDK dependency.

/// Whether the app was compiled in release (AOT product) mode.
///
/// Identical in definition to Flutter's `kReleaseMode`
/// (`foundation/constants.dart`), so it keeps the same const-folding
/// behaviour: a `!kReleaseMode` term in a `const` expression folds to
/// `false` under product mode and the guarded branch is tree-shaken.
const bool kReleaseMode = bool.fromEnvironment('dart.vm.product');
