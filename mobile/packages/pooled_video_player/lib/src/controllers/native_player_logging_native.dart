import 'package:media_kit/media_kit.dart';

/// Suppresses noisy native media_kit stderr output when the platform supports
/// MPV property configuration.
Future<void> suppressNativePlayerWarnings(Player player) async {
  try {
    final nativePlayer = player.platform;
    if (nativePlayer is NativePlayer) {
      await nativePlayer.setProperty('msg-level', 'all=error');
    }
  } on Exception {
    // Ignore - non-native platforms or implementations may not expose this.
  }
}
