// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'supporter_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The store-backed [EntitlementValidator] for the current platform.
///
/// Returns an [InAppPurchaseValidator] on iOS/Android and a
/// [StubEntitlementValidator] elsewhere so the rest of the app can treat the
/// supporter feature uniformly.

@ProviderFor(entitlementValidator)
final entitlementValidatorProvider = EntitlementValidatorProvider._();

/// The store-backed [EntitlementValidator] for the current platform.
///
/// Returns an [InAppPurchaseValidator] on iOS/Android and a
/// [StubEntitlementValidator] elsewhere so the rest of the app can treat the
/// supporter feature uniformly.

final class EntitlementValidatorProvider
    extends
        $FunctionalProvider<
          EntitlementValidator,
          EntitlementValidator,
          EntitlementValidator
        >
    with $Provider<EntitlementValidator> {
  /// The store-backed [EntitlementValidator] for the current platform.
  ///
  /// Returns an [InAppPurchaseValidator] on iOS/Android and a
  /// [StubEntitlementValidator] elsewhere so the rest of the app can treat the
  /// supporter feature uniformly.
  EntitlementValidatorProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'entitlementValidatorProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$entitlementValidatorHash();

  @$internal
  @override
  $ProviderElement<EntitlementValidator> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  EntitlementValidator create(Ref ref) {
    return entitlementValidator(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(EntitlementValidator value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<EntitlementValidator>(value),
    );
  }
}

String _$entitlementValidatorHash() =>
    r'0e3e4f5e3b811340e2ec5adf8882f66c7fe012cc';

/// The keepAlive [SupporterRepository] that owns the cached entitlement.

@ProviderFor(supporterRepository)
final supporterRepositoryProvider = SupporterRepositoryProvider._();

/// The keepAlive [SupporterRepository] that owns the cached entitlement.

final class SupporterRepositoryProvider
    extends
        $FunctionalProvider<
          SupporterRepository,
          SupporterRepository,
          SupporterRepository
        >
    with $Provider<SupporterRepository> {
  /// The keepAlive [SupporterRepository] that owns the cached entitlement.
  SupporterRepositoryProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'supporterRepositoryProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$supporterRepositoryHash();

  @$internal
  @override
  $ProviderElement<SupporterRepository> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  SupporterRepository create(Ref ref) {
    return supporterRepository(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SupporterRepository value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SupporterRepository>(value),
    );
  }
}

String _$supporterRepositoryHash() =>
    r'20dfa7e54c802d785870a13f3cc92dba83d00de8';
