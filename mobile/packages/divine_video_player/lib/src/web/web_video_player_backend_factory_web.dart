import 'package:divine_video_player/src/web/web_video_player_backend.dart';
import 'package:divine_video_player/src/web/web_video_player_backend_web.dart';

/// Returns the web-backed implementation. Used when the compile target
/// supports `dart:ui_web` / `dart:js_interop` (i.e. real web builds).
WebVideoPlayerBackend createWebVideoPlayerBackend() =>
    HtmlVideoElementBackend();
