// Web-only JS bindings for hls.js and the minimal DOM surface the player
// needs. Intentionally narrow — the public surface is `WebHlsAuthRuntime`
// (`hls_auth_web_runtime_web.dart`), and nothing outside this subtree should
// import these externs directly.

@JS()
library;

import 'dart:js_interop';

/// Top-level `Hls` constructor. Null when hls.js has not been loaded.
@JS('Hls')
external JSFunction? get hlsConstructor;

/// hls.js static `isSupported()` method.
@JS('Hls.isSupported')
external JSBoolean hlsIsSupportedJs();

/// Registers the video element created by the Dart runtime so the JS shim
/// can manage its lifecycle (`attachMedia`, `src` assignment, blob URL
/// revocation).
@JS('window.__divineRegisterVideo')
external JSFunction? get divineRegisterVideo;

/// Tells the JS side to fetch the MP4 at `url` (with an optional
/// `Authorization` header), convert it to a blob, and attach it to the
/// element for `viewType`. Resolves to an object shaped
/// `{status: 'ok'|'requiresAuth'|'failure', code?: number}`.
@JS('window.__divineFetchMp4')
external JSFunction? get divineFetchMp4;

/// Tells the JS side to instantiate hls.js with the auth loader and attach
/// it to the registered video element. Resolves with the same shape as
/// [divineFetchMp4].
@JS('window.__divineLoadHls')
external JSFunction? get divineLoadHls;

/// Tells the JS side to dispose an active hls.js instance and release any
/// blob URL held for the given `viewType`.
@JS('window.__divineDisposeView')
external JSFunction? get divineDisposeView;
