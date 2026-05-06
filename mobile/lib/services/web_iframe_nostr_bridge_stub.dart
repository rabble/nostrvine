// ABOUTME: Native-platform stub of the web iframe bridge — never used at runtime.
// ABOUTME: Conditional import in web_iframe_nostr_bridge.dart selects this on dart:io.
//
// Minimal stub of the dart:html surface this bridge touches. The real
// dart:html types are only available on Flutter web; on native platforms
// the conditional import in `web_iframe_nostr_bridge.dart` resolves to
// this file, but no code path here is exercised at runtime — the bridge
// only constructs on `kIsWeb`.

class Event {}

class MessageEvent extends Event {
  String get origin => '';
  dynamic get data => null;
}

typedef EventListener = void Function(Event event);

class Window {
  void addEventListener(
    String type,
    EventListener? callback, [
    bool? useCapture,
  ]) {
    throw UnsupportedError(
      'web_iframe_nostr_bridge is web-only; do not construct on native',
    );
  }

  void removeEventListener(
    String type,
    EventListener? callback, [
    bool? useCapture,
  ]) {}
}

Window get window => Window();
