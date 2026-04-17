import 'package:hls_auth_web_player/src/hls_auth_web_runtime.dart';
import 'package:hls_auth_web_player/src/runtime_factory_stub.dart'
    if (dart.library.js_interop) 'package:hls_auth_web_player/src/runtime_factory_web.dart';

/// Returns the platform-appropriate runtime. On web this drives hls.js;
/// elsewhere it returns an unsupported stub so widgets can fail closed.
HlsAuthWebRuntime createDefaultHlsAuthWebRuntime() => createDefaultRuntime();
