// ABOUTME: SharedPreferences implementation of RelayStorage for persistence.
// ABOUTME: Stores configured relay URLs as a string list.

import 'package:nostr_client/src/models/relay_manager_config.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// {@template shared_preferences_relay_storage}
/// SharedPreferences implementation of [RelayStorage].
///
/// Persists relay URLs to device storage using SharedPreferences.
/// This is the recommended storage implementation for production use.
///
/// Example:
/// ```dart
/// final storage = SharedPreferencesRelayStorage();
/// final relayManager = RelayManager(
///   config: RelayManagerConfig(
///     defaultRelayUrl: 'wss://relay.example.com',
///     storage: storage,
///   ),
/// );
/// ```
/// {@endtemplate}
class SharedPreferencesRelayStorage implements RelayStorage {
  /// {@macro shared_preferences_relay_storage}
  ///
  /// [key] is the SharedPreferences key to use for configured relay storage.
  /// Defaults to 'configured_relays'.
  ///
  /// [removedRelaysKey] stores relays the user explicitly removed so
  /// automatic discovery and fallback paths do not re-add them.
  SharedPreferencesRelayStorage({String? key, String? removedRelaysKey})
    : _key = key ?? defaultKey,
      _removedRelaysKey = removedRelaysKey ?? defaultRemovedRelaysKey;

  /// Default SharedPreferences key for configured relays.
  static const String defaultKey = 'configured_relays';

  /// Default SharedPreferences key for relays explicitly removed by the user.
  static const String defaultRemovedRelaysKey = 'user_removed_relays';

  final String _key;
  final String _removedRelaysKey;

  @override
  Future<List<String>> loadRelays() async {
    final prefs = await SharedPreferences.getInstance();
    final relays = prefs.getStringList(_key);
    return relays != null ? List<String>.from(relays) : <String>[];
  }

  @override
  Future<void> saveRelays(List<String> relayUrls) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_key, relayUrls);
  }

  @override
  Future<List<String>> loadRemovedRelays() async {
    final prefs = await SharedPreferences.getInstance();
    final relays = prefs.getStringList(_removedRelaysKey);
    return relays != null ? List<String>.from(relays) : <String>[];
  }

  @override
  Future<void> saveRemovedRelays(List<String> relayUrls) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(_removedRelaysKey, relayUrls);
  }
}
