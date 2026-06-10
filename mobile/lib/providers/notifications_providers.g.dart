// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'notifications_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Bridges Nostr session readiness to push notification registration.
///
/// Registers FCM token only after the signer-backed Nostr client is ready.
/// Deregisters the last ready client through AuthService's pre-teardown hook so
/// outgoing-session cleanup runs before signers and callbacks are cleared.

@ProviderFor(pushNotificationSync)
const pushNotificationSyncProvider = PushNotificationSyncProvider._();

/// Bridges Nostr session readiness to push notification registration.
///
/// Registers FCM token only after the signer-backed Nostr client is ready.
/// Deregisters the last ready client through AuthService's pre-teardown hook so
/// outgoing-session cleanup runs before signers and callbacks are cleared.

final class PushNotificationSyncProvider
    extends $FunctionalProvider<void, void, void>
    with $Provider<void> {
  /// Bridges Nostr session readiness to push notification registration.
  ///
  /// Registers FCM token only after the signer-backed Nostr client is ready.
  /// Deregisters the last ready client through AuthService's pre-teardown hook so
  /// outgoing-session cleanup runs before signers and callbacks are cleared.
  const PushNotificationSyncProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'pushNotificationSyncProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$pushNotificationSyncHash();

  @$internal
  @override
  $ProviderElement<void> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  void create(Ref ref) {
    return pushNotificationSync(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(void value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<void>(value),
    );
  }
}

String _$pushNotificationSyncHash() =>
    r'bd7c6af23335a355541b7086d8afedf15743369b';
