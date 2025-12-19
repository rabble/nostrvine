// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'readiness_gate_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Provider that combines all readiness gates to determine if app is ready for subscriptions

@ProviderFor(appReady)
const appReadyProvider = AppReadyProvider._();

/// Provider that combines all readiness gates to determine if app is ready for subscriptions

final class AppReadyProvider extends $FunctionalProvider<bool, bool, bool>
    with $Provider<bool> {
  /// Provider that combines all readiness gates to determine if app is ready for subscriptions
  const AppReadyProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'appReadyProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$appReadyHash();

  @$internal
  @override
  $ProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  bool create(Ref ref) {
    return appReady(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$appReadyHash() => r'e5ade29720db0ff896154f0423b80168cdce97c8';

/// Provider that checks if the discovery/explore tab is currently active

@ProviderFor(isDiscoveryTabActive)
const isDiscoveryTabActiveProvider = IsDiscoveryTabActiveProvider._();

/// Provider that checks if the discovery/explore tab is currently active

final class IsDiscoveryTabActiveProvider
    extends $FunctionalProvider<bool, bool, bool>
    with $Provider<bool> {
  /// Provider that checks if the discovery/explore tab is currently active
  const IsDiscoveryTabActiveProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'isDiscoveryTabActiveProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$isDiscoveryTabActiveHash();

  @$internal
  @override
  $ProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  bool create(Ref ref) {
    return isDiscoveryTabActive(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$isDiscoveryTabActiveHash() =>
    r'daecf924ea41f6790fce17118342534ced074413';
