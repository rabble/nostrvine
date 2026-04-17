import 'package:hls_auth_web_player/src/hls_auth_web_runtime.dart';
import 'package:hls_auth_web_player/src/hls_auth_web_runtime_web.dart';

/// Returns the web-backed runtime. Used when the compile target supports
/// `dart:ui_web` / `dart:js_interop` (i.e. real web builds).
HlsAuthWebRuntime createDefaultRuntime() => WebHlsAuthRuntime();
