// ABOUTME: Conditional re-export selecting the web iframe screen impl —
// ABOUTME: native VM gets a stub so dart:html / dart:ui_web stay web-only.

export 'web_iframe_sandbox_screen_io.dart'
    if (dart.library.js_interop) 'web_iframe_sandbox_screen_web.dart';
