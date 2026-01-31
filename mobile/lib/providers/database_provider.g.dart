// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'database_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(database)
const databaseProvider = DatabaseProvider._();

final class DatabaseProvider
    extends $FunctionalProvider<AppDatabase, AppDatabase, AppDatabase>
    with $Provider<AppDatabase> {
  const DatabaseProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'databaseProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$databaseHash();

  @$internal
  @override
  $ProviderElement<AppDatabase> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  AppDatabase create(Ref ref) {
    return database(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AppDatabase value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AppDatabase>(value),
    );
  }
}

String _$databaseHash() => r'd66464688f3f3beae31aa517238455b4413086f1';

/// AppDbClient wrapping the database for NostrClient integration.
/// Enables optimistic caching of Nostr events in the local database.

@ProviderFor(appDbClient)
const appDbClientProvider = AppDbClientProvider._();

/// AppDbClient wrapping the database for NostrClient integration.
/// Enables optimistic caching of Nostr events in the local database.

final class AppDbClientProvider
    extends $FunctionalProvider<AppDbClient, AppDbClient, AppDbClient>
    with $Provider<AppDbClient> {
  /// AppDbClient wrapping the database for NostrClient integration.
  /// Enables optimistic caching of Nostr events in the local database.
  const AppDbClientProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'appDbClientProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$appDbClientHash();

  @$internal
  @override
  $ProviderElement<AppDbClient> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  AppDbClient create(Ref ref) {
    return appDbClient(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(AppDbClient value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<AppDbClient>(value),
    );
  }
}

String _$appDbClientHash() => r'c4d2017985665ff5d6c72afa546321042a5f16ca';
