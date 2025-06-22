// ABOUTME: JavaScript interop for NIP-07 browser extension support (Alby, nos2x, etc.)
// ABOUTME: Provides type-safe Dart interface to window.nostr object for web authentication

@JS('window')
library;

import 'package:js/js.dart' if (dart.library.io) 'stubs/js_stub.dart';
import 'package:flutter/foundation.dart';

/// Check if NIP-07 extension is available
@JS('nostr')
external NostrExtension? get _nostr;

/// Public getter that safely checks for extension availability
NostrExtension? get nostr => kIsWeb ? _nostr : null;

/// Check if any NIP-07 extension is available
bool get isNip07Available => kIsWeb && _nostr != null;

/// The main NIP-07 interface that browser extensions implement
@JS()
@anonymous
abstract class NostrExtension {
  /// Get the user's public key (hex format)
  external Future<String> getPublicKey();
  
  /// Sign a Nostr event
  external Future<NostrEvent> signEvent(NostrEvent event);
  
  /// Get the user's relays (optional NIP-07 extension)
  external Future<Map<String, dynamic>>? getRelays();
  
  /// NIP-04 encryption (optional)
  external NIP04? get nip04;
}

/// NIP-04 encryption interface (optional extension feature)
@JS()
@anonymous
abstract class NIP04 {
  external Future<String> encrypt(String pubkey, String plaintext);
  external Future<String> decrypt(String pubkey, String ciphertext);
}

/// Nostr event structure for JavaScript interop
@JS()
@anonymous
class NostrEvent {
  external factory NostrEvent({
    String? id,
    required String pubkey,
    // ignore: non_constant_identifier_names
    required int created_at,
    required int kind,
    required List<List<String>> tags,
    required String content,
    String? sig,
  });

  external String? get id;
  external set id(String? id);
  
  external String get pubkey;
  external set pubkey(String pubkey);
  
  // ignore: non_constant_identifier_names
  external int get created_at;
  // ignore: non_constant_identifier_names
  external set created_at(int created_at);
  
  external int get kind;
  external set kind(int kind);
  
  external List<List<String>> get tags;
  external set tags(List<List<String>> tags);
  
  external String get content;
  external set content(String content);
  
  external String? get sig;
  external set sig(String? sig);
}

/// Convert Dart Map to JavaScript NostrEvent
NostrEvent dartEventToJs(Map<String, dynamic> dartEvent) {
  return NostrEvent(
    id: dartEvent['id'],
    pubkey: dartEvent['pubkey'] ?? '',
    created_at: dartEvent['created_at'] ?? DateTime.now().millisecondsSinceEpoch ~/ 1000,
    kind: dartEvent['kind'] ?? 1,
    tags: (dartEvent['tags'] as List<dynamic>?)?.map((tag) => 
      (tag as List<dynamic>).map((item) => item.toString()).toList()
    ).toList() ?? [],
    content: dartEvent['content'] ?? '',
    sig: dartEvent['sig'],
  );
}

/// Convert JavaScript NostrEvent to Dart Map
Map<String, dynamic> jsEventToDart(NostrEvent jsEvent) {
  return {
    'id': jsEvent.id,
    'pubkey': jsEvent.pubkey,
    'created_at': jsEvent.created_at,
    'kind': jsEvent.kind,
    'tags': jsEvent.tags,
    'content': jsEvent.content,
    'sig': jsEvent.sig,
  };
}

/// Enhanced error handling for NIP-07 operations
class Nip07Exception implements Exception {
  final String message;
  final String? code;
  final dynamic originalError;
  
  const Nip07Exception(this.message, {this.code, this.originalError});
  
  @override
  String toString() => 'NIP-07 Error: $message${code != null ? ' ($code)' : ''}';
}

/// Helper function to safely call NIP-07 methods with error handling
Future<T> safeNip07Call<T>(
  Future<T> Function() operation,
  String operationName,
) async {
  try {
    return await operation();
  } catch (e) {
    // Handle common NIP-07 errors
    if (e.toString().contains('User rejected')) {
      throw Nip07Exception(
        'User rejected $operationName request',
        code: 'USER_REJECTED',
        originalError: e,
      );
    } else if (e.toString().contains('Not implemented')) {
      throw Nip07Exception(
        '$operationName not supported by this extension',
        code: 'NOT_IMPLEMENTED',
        originalError: e,
      );
    } else {
      throw Nip07Exception(
        'Failed to $operationName: ${e.toString()}',
        code: 'UNKNOWN_ERROR',
        originalError: e,
      );
    }
  }
}