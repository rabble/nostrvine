// ABOUTME: Web implementation of NIP-07 interop using dart:js_interop.
// ABOUTME: Binds window.nostr (Alby, nos2x, Nostore, ...) to NostrExtension.

import 'dart:js_interop';

import 'package:openvine/services/nip07_types.dart';

@JS('window.nostr')
external _JsNostr? get _jsNostr;

extension type _JsNostr._(JSObject _) implements JSObject {
  external JSPromise<JSString> getPublicKey();

  external JSPromise<JSObject> signEvent(JSObject event);

  external JSPromise<JSObject>? getRelays();

  external _JsNip04? get nip04;

  external _JsNip44? get nip44;
}

extension type _JsNip04._(JSObject _) implements JSObject {
  external JSPromise<JSString> encrypt(JSString pubkey, JSString plaintext);
  external JSPromise<JSString> decrypt(JSString pubkey, JSString ciphertext);
}

extension type _JsNip44._(JSObject _) implements JSObject {
  external JSPromise<JSString> encrypt(JSString pubkey, JSString plaintext);
  external JSPromise<JSString> decrypt(JSString pubkey, JSString ciphertext);
}

bool get isNip07Available => _jsNostr != null;

NostrExtension? get nostr {
  final js = _jsNostr;
  if (js == null) return null;
  return _WebNostrExtension(js);
}

class _WebNostrExtension implements NostrExtension {
  _WebNostrExtension(this._js);
  final _JsNostr _js;

  @override
  Future<String> getPublicKey() async {
    final result = await _js.getPublicKey().toDart;
    return result.toDart;
  }

  @override
  Future<Map<String, dynamic>> signEvent(Map<String, dynamic> event) async {
    final jsObj = event.jsify();
    if (jsObj == null) {
      throw const Nip07Exception(
        'Could not serialise event to JS',
        code: 'SERIALISATION_ERROR',
      );
    }
    final jsResult = await _js.signEvent(jsObj as JSObject).toDart;
    final dartified = jsResult.dartify();
    if (dartified is! Map) {
      throw const Nip07Exception(
        'Unexpected signEvent response shape from extension',
        code: 'INVALID_RESPONSE',
      );
    }
    return Map<String, dynamic>.from(dartified);
  }

  @override
  Future<Map<String, dynamic>>? getRelays() {
    final promise = _js.getRelays();
    if (promise == null) return null;
    return _getRelaysAsync(promise);
  }

  Future<Map<String, dynamic>> _getRelaysAsync(
    JSPromise<JSObject> promise,
  ) async {
    final jsResult = await promise.toDart;
    final dartified = jsResult.dartify();
    if (dartified is! Map) {
      throw const Nip07Exception(
        'Unexpected getRelays response shape from extension',
        code: 'INVALID_RESPONSE',
      );
    }
    return Map<String, dynamic>.from(dartified);
  }

  @override
  NIP04? get nip04 {
    final js = _js.nip04;
    if (js == null) return null;
    return _WebNip04(js);
  }

  @override
  NIP44? get nip44 {
    final js = _js.nip44;
    if (js == null) return null;
    return _WebNip44(js);
  }
}

class _WebNip04 implements NIP04 {
  _WebNip04(this._js);
  final _JsNip04 _js;

  @override
  Future<String> encrypt(String pubkey, String plaintext) async {
    final result = await _js.encrypt(pubkey.toJS, plaintext.toJS).toDart;
    return result.toDart;
  }

  @override
  Future<String> decrypt(String pubkey, String ciphertext) async {
    final result = await _js.decrypt(pubkey.toJS, ciphertext.toJS).toDart;
    return result.toDart;
  }
}

class _WebNip44 implements NIP44 {
  _WebNip44(this._js);
  final _JsNip44 _js;

  @override
  Future<String> encrypt(String pubkey, String plaintext) async {
    final result = await _js.encrypt(pubkey.toJS, plaintext.toJS).toDart;
    return result.toDart;
  }

  @override
  Future<String> decrypt(String pubkey, String ciphertext) async {
    final result = await _js.decrypt(pubkey.toJS, ciphertext.toJS).toDart;
    return result.toDart;
  }
}
