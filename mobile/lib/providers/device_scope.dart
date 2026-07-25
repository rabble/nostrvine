// ABOUTME: The device-scoped dependencies that must survive an account switch —
// ABOUTME: shared across every ProviderContainer so a swap opens no new DB, etc.

import 'package:db_client/db_client.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/providers/container_swap_host.dart';
import 'package:openvine/providers/database_corruption_provider.dart';
import 'package:openvine/providers/database_provider.dart';
import 'package:openvine/providers/db_cipher_key_provider.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/services/database_corruption_service.dart';
// Override lives in riverpod's misc barrel; flutter_riverpod does not
// re-export the type name even though it accepts List<Override>.
import 'package:riverpod/misc.dart' show Override;
import 'package:shared_preferences/shared_preferences.dart';

/// The [DeviceScope] for the current app, injected into every container so UI
/// anywhere in the tree can trigger an account switch. Overridden at
/// construction; reading it without a [DeviceScope] override throws.
final deviceScopeProvider = Provider<DeviceScope>(
  (_) => throw StateError('deviceScopeProvider must be overridden'),
);

/// Dependencies that belong to the *device*, not to a signed-in account, and
/// must therefore outlive an account switch.
///
/// Account switching (design §8.2, Phase 4) rebuilds the Riverpod
/// `ProviderContainer` for the new account and disposes the old one. Anything
/// created *inside* that container is torn down and rebuilt — which is the
/// point for account-scoped state, but catastrophic for device-scoped
/// singletons. The clearest example is [AppDatabase]: `databaseProvider`
/// opens a native SQLite connection per container and closes it on dispose, so
/// two live containers would mean two connections to the same encrypted file
/// (lock contention / corruption). Hoisting the connection here and handing it
/// to every container as an override keeps exactly one open across swaps.
///
/// Construct this once in `main()` and pass [overrides] into every container —
/// the initial one and each swapped-in one. Because the providers are
/// overridden *with values*, their factories (and their `onDispose(db.close)`)
/// never run, so disposing a container does not tear down the shared instance.
class DeviceScope {
  const DeviceScope({
    required this.database,
    required this.sharedPreferences,
    required this.switchController,
    this.dbCipherKey,
    this.databaseCorruptionService,
  });

  /// The single open database connection, shared across every container.
  ///
  /// This is the one dependency that genuinely cannot be rebuilt per container:
  /// it holds an open SQLite connection to the encrypted file, so two would
  /// mean lock contention / corruption. `FlutterSecureStorage` is deliberately
  /// *not* here — it is a stateless facade over the platform keychain, so a
  /// per-container instance is harmless.
  final AppDatabase database;

  final SharedPreferences sharedPreferences;

  /// The app-lifetime handle the UI calls to switch accounts. Device-scoped so
  /// it outlives — and drives — every container swap.
  final AccountSwitchController switchController;

  /// At-rest encryption key resolved by the startup bootstrap, or null on web /
  /// tests / a deferred migration.
  final String? dbCipherKey;

  /// Runtime corruption reporter, or null when the connection is
  /// uninstrumented (no cipher key).
  final DatabaseCorruptionService? databaseCorruptionService;

  /// The provider overrides that pin every container to these shared
  /// instances. Spread into `ProviderContainer(overrides: [...])`.
  List<Override> get overrides => [
    databaseProvider.overrideWithValue(database),
    sharedPreferencesProvider.overrideWithValue(sharedPreferences),
    dbCipherKeyProvider.overrideWithValue(dbCipherKey),
    databaseCorruptionServiceProvider.overrideWithValue(
      databaseCorruptionService,
    ),
    deviceScopeProvider.overrideWithValue(this),
  ];
}

/// Builds a fresh account-scoped [ProviderContainer] pinned to [deviceScope]'s
/// shared instances.
///
/// [accountOverrides] seed the account this container signs in as (Phase 4
/// wires the switch here). The returned container owns only account-scoped
/// providers; the device singletons are shared, so disposing it after a swap
/// tears down the leaving account's runtime without touching the database or
/// secure storage.
ProviderContainer buildAccountContainer(
  DeviceScope deviceScope, {
  List<Override> accountOverrides = const [],
}) {
  return ProviderContainer(
    overrides: [...deviceScope.overrides, ...accountOverrides],
  );
}
