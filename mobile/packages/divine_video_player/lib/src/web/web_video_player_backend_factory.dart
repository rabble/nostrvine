import 'package:divine_video_player/src/web/web_video_player_backend.dart';
import 'package:divine_video_player/src/web/web_video_player_backend_factory_stub.dart'
    if (dart.library.js_interop) 'package:divine_video_player/src/web/web_video_player_backend_factory_web.dart';

/// Returns the default web backend implementation.
///
/// On real web builds this is the `HtmlVideoElementBackend` that drives an
/// `HTMLVideoElement` via `dart:ui_web` and `package:web`. On every other
/// target it is a stub that throws on use — the controller never reaches
/// it because `kIsWeb` is false there.
WebVideoPlayerBackend createDefaultWebVideoPlayerBackend() =>
    createWebVideoPlayerBackend();
