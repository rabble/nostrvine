// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'nostr_client_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Core Nostr service via NostrClient for relay communication
/// Uses a Notifier to react to auth state changes and recreate the client
/// when the keyContainer changes (e.g., user signs out and signs in with different keys)

@ProviderFor(NostrService)
const nostrServiceProvider = NostrServiceProvider._();

/// Core Nostr service via NostrClient for relay communication
/// Uses a Notifier to react to auth state changes and recreate the client
/// when the keyContainer changes (e.g., user signs out and signs in with different keys)
final class NostrServiceProvider
    extends $NotifierProvider<NostrService, NostrClient> {
  /// Core Nostr service via NostrClient for relay communication
  /// Uses a Notifier to react to auth state changes and recreate the client
  /// when the keyContainer changes (e.g., user signs out and signs in with different keys)
  const NostrServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'nostrServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$nostrServiceHash();

  @$internal
  @override
  NostrService create() => NostrService();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(NostrClient value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<NostrClient>(value),
    );
  }
}

String _$nostrServiceHash() => r'8e9d99169ae0f31ee3de4bd58aa65e1ec7feb536';

/// Core Nostr service via NostrClient for relay communication
/// Uses a Notifier to react to auth state changes and recreate the client
/// when the keyContainer changes (e.g., user signs out and signs in with different keys)

abstract class _$NostrService extends $Notifier<NostrClient> {
  NostrClient build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<NostrClient, NostrClient>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<NostrClient, NostrClient>,
              NostrClient,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
