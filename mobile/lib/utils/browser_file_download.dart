// ABOUTME: Conditional re-export selecting the browser-download helper impl —
// ABOUTME: native builds get a stub so package:web stays web-only.

export 'browser_file_download_io.dart'
    if (dart.library.js_interop) 'browser_file_download_web.dart';
