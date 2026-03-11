import 'package:media_kit/media_kit.dart';

/// No-op on web, where native media_kit logging APIs are unavailable.
Future<void> suppressNativePlayerWarnings(Player player) async {}
