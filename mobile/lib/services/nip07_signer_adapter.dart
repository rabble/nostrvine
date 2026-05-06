// ABOUTME: Adapter that exposes Nip07Service as a NostrSigner so it can back
// ABOUTME: a Nip07NostrIdentity in the same shape as Bunker/Amber signers.

import 'package:nostr_sdk/nostr_sdk.dart';
import 'package:openvine/services/nip07_service.dart';

/// Adapts [Nip07Service] to the [NostrSigner] surface that
/// [Nip07NostrIdentity] expects.
///
/// All methods delegate to the underlying service. Encryption returns null
/// when the extension does not implement nip04 / nip44, signalling the
/// caller to surface a meaningful error rather than silently degrade.
class Nip07SignerAdapter implements NostrSigner {
  Nip07SignerAdapter(this._service);

  final Nip07Service _service;

  @override
  Future<String?> getPublicKey() async => _service.publicKey;

  @override
  Future<Event?> signEvent(Event event) async {
    final result = await _service.signEvent(_eventToMap(event));
    if (!result.success || result.signedEvent == null) {
      return null;
    }
    return _mapToEvent(result.signedEvent!);
  }

  @override
  Future<Map?> getRelays() async => _service.userRelays;

  @override
  Future<String?> encrypt(String pubkey, String plaintext) =>
      _service.encryptMessage(pubkey, plaintext);

  @override
  Future<String?> decrypt(String pubkey, String ciphertext) =>
      _service.decryptMessage(pubkey, ciphertext);

  @override
  Future<String?> nip44Encrypt(String pubkey, String plaintext) =>
      _service.nip44EncryptMessage(pubkey, plaintext);

  @override
  Future<String?> nip44Decrypt(String pubkey, String ciphertext) =>
      _service.nip44DecryptMessage(pubkey, ciphertext);

  @override
  void close() {
    // Service lifecycle is owned by AuthService.
  }

  Map<String, dynamic> _eventToMap(Event event) => {
    'pubkey': event.pubkey,
    'created_at': event.createdAt,
    'kind': event.kind,
    'tags': event.tags,
    'content': event.content,
    if (event.id.isNotEmpty) 'id': event.id,
    if (event.sig.isNotEmpty) 'sig': event.sig,
  };

  Event _mapToEvent(Map<String, dynamic> map) {
    final tags = (map['tags'] as List<dynamic>? ?? const <dynamic>[])
        .map(
          (tag) =>
              (tag as List<dynamic>).map((item) => item.toString()).toList(),
        )
        .toList();
    return Event.fromJson({
      'id': map['id'] as String? ?? '',
      'pubkey': map['pubkey'] as String? ?? '',
      'created_at':
          map['created_at'] as int? ??
          (DateTime.now().millisecondsSinceEpoch ~/ 1000),
      'kind': map['kind'] as int? ?? 1,
      'tags': tags,
      'content': map['content'] as String? ?? '',
      'sig': map['sig'] as String? ?? '',
    });
  }
}
