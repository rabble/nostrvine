import 'package:flutter_web_plugins/flutter_web_plugins.dart';

/// Registers the Web implementation for the Flutter plugin toolchain.
///
/// The actual playback logic lives in Dart and is dispatched by
/// `DivineVideoPlayerController` when `kIsWeb` is true, so registration
/// is a no-op.
base class DivineVideoPlayerWebPlugin {
  /// Registers the Web plugin implementation.
  static void registerWith(Registrar registrar) {}
}
