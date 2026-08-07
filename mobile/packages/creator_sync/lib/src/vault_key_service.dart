// ABOUTME: Owns the per-account sync vault key lifecycle.
// ABOUTME: Wraps with NIP-44 to self; never forks when the relay is down.

import 'dart:convert';
import 'dart:math';
import 'dart:typed_data';

import 'package:creator_sync/src/exceptions.dart';
import 'package:creator_sync/src/sync_clock.dart';
import 'package:cryptography/cryptography.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/event_kind.dart';
import 'package:nostr_sdk/filter.dart';
import 'package:nostr_sdk/signer/nostr_signer.dart';

/// The `d` tag identifying the wrapped vault key event.
///
/// Shares the `divine:sync:` prefix with synced items but is NOT an item.
/// Item parsing matches the three item prefixes explicitly so this event
/// can never be reconciled as a phantom entry.
const String vaultKeyDTag = 'divine:sync:vault-key';

/// Device-local persistence for the unwrapped vault key.
///
/// Implemented in the app layer over secure storage; kept as an interface
/// so this package stays free of Flutter dependencies.
abstract interface class VaultKeyCache {
  /// Returns the base64 vault key for [pubkeyHex], or null if absent.
  Future<String?> read(String pubkeyHex);

  /// Persists [base64Key] for [pubkeyHex].
  Future<void> write(String pubkeyHex, String base64Key);
}

/// Obtains the account's sync vault key, creating it only when provably
/// absent.
class VaultKeyService {
  /// Creates a [VaultKeyService].
  VaultKeyService({
    required NostrSigner signer,
    required NostrClient client,
    required VaultKeyCache cache,
    Random? random,
  }) : _signer = signer,
       _client = client,
       _cache = cache,
       _random = random ?? Random.secure();

  final NostrSigner _signer;
  final NostrClient _client;
  final VaultKeyCache _cache;
  final Random _random;

  static const int _keyLengthBytes = 32;

  /// Returns the vault key for the signed-in account.
  ///
  /// Resolution order: device cache, then the remote wrapped-key event,
  /// then generate-and-publish.
  ///
  /// Throws [VaultKeyUnavailableException] when signed out, when the
  /// remote lookup fails, or when the signer cannot unwrap an existing
  /// key. It deliberately does NOT generate a replacement in those cases:
  /// publishing a second vault key would replace the first and render
  /// every previously synced item permanently unreadable.
  Future<SecretKey> obtain() async {
    final pubkey = await _signer.getPublicKey();
    if (pubkey == null || pubkey.isEmpty) {
      throw VaultKeyUnavailableException('no signed-in account');
    }

    final cached = await _cache.read(pubkey);
    if (cached != null) {
      return SecretKey(base64Decode(cached));
    }

    final remote = await _fetchRemote(pubkey);
    if (remote != null) {
      final raw = await _unwrap(pubkey, remote);
      await _cache.write(pubkey, raw);
      return SecretKey(base64Decode(raw));
    }

    return _generateAndPublish(pubkey);
  }

  Future<Event?> _fetchRemote(String pubkey) async {
    try {
      final events = await _client.queryEvents([
        Filter(
          kinds: [EventKind.appSpecificData],
          authors: [pubkey],
          d: [vaultKeyDTag],
          limit: 1,
        ),
      ]);
      if (events.isEmpty) return null;
      events.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      return events.first;
    } catch (e) {
      throw VaultKeyUnavailableException(
        'could not determine whether a vault key exists: $e',
      );
    }
  }

  Future<String> _unwrap(String pubkey, Event event) async {
    final String? raw;
    try {
      raw = await _signer.nip44Decrypt(pubkey, event.content);
    } catch (e) {
      throw VaultKeyUnavailableException('signer refused to unwrap: $e');
    }
    if (raw == null || raw.isEmpty) {
      throw VaultKeyUnavailableException('signer returned an empty key');
    }
    return raw;
  }

  Future<SecretKey> _generateAndPublish(String pubkey) async {
    final bytes = Uint8List.fromList(
      List<int>.generate(_keyLengthBytes, (_) => _random.nextInt(256)),
    );
    final raw = base64Encode(bytes);

    final String? wrapped;
    try {
      wrapped = await _signer.nip44Encrypt(pubkey, raw);
    } catch (e) {
      throw VaultKeyUnavailableException('signer refused to wrap: $e');
    }
    if (wrapped == null || wrapped.isEmpty) {
      throw VaultKeyUnavailableException('signer returned an empty wrap');
    }

    final event = Event(
      pubkey,
      EventKind.appSpecificData,
      const [
        ['d', vaultKeyDTag],
      ],
      wrapped,
      createdAt: SyncClock.nowSeconds(),
    );

    final signed = await _signer.signEvent(event);
    if (signed == null) {
      throw VaultKeyUnavailableException('signer refused to sign key event');
    }

    final result = await _client.publishEvent(signed);
    if (!result.isSuccess) {
      throw VaultKeyUnavailableException(
        'vault key event was not accepted by any relay',
      );
    }

    await _cache.write(pubkey, raw);
    return SecretKey(bytes);
  }
}
