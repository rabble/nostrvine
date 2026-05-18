// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'permissions_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Geo-blocking service for regional compliance

@ProviderFor(geoBlockingService)
const geoBlockingServiceProvider = GeoBlockingServiceProvider._();

/// Geo-blocking service for regional compliance

final class GeoBlockingServiceProvider
    extends
        $FunctionalProvider<
          GeoBlockingService,
          GeoBlockingService,
          GeoBlockingService
        >
    with $Provider<GeoBlockingService> {
  /// Geo-blocking service for regional compliance
  const GeoBlockingServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'geoBlockingServiceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$geoBlockingServiceHash();

  @$internal
  @override
  $ProviderElement<GeoBlockingService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  GeoBlockingService create(Ref ref) {
    return geoBlockingService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(GeoBlockingService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<GeoBlockingService>(value),
    );
  }
}

String _$geoBlockingServiceHash() =>
    r'0475466204746fb8b4c6dd614847e3853d360d12';

/// Permissions service for checking and requesting OS permissions

@ProviderFor(permissionsService)
const permissionsServiceProvider = PermissionsServiceProvider._();

/// Permissions service for checking and requesting OS permissions

final class PermissionsServiceProvider
    extends
        $FunctionalProvider<
          PermissionsService,
          PermissionsService,
          PermissionsService
        >
    with $Provider<PermissionsService> {
  /// Permissions service for checking and requesting OS permissions
  const PermissionsServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'permissionsServiceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$permissionsServiceHash();

  @$internal
  @override
  $ProviderElement<PermissionsService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  PermissionsService create(Ref ref) {
    return permissionsService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(PermissionsService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<PermissionsService>(value),
    );
  }
}

String _$permissionsServiceHash() =>
    r'7212219b8e720fe0fcd19ae7e9313e2c5c5be1d5';

/// Gallery save service for saving videos to device camera roll

@ProviderFor(gallerySaveService)
const gallerySaveServiceProvider = GallerySaveServiceProvider._();

/// Gallery save service for saving videos to device camera roll

final class GallerySaveServiceProvider
    extends
        $FunctionalProvider<
          GallerySaveService,
          GallerySaveService,
          GallerySaveService
        >
    with $Provider<GallerySaveService> {
  /// Gallery save service for saving videos to device camera roll
  const GallerySaveServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'gallerySaveServiceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$gallerySaveServiceHash();

  @$internal
  @override
  $ProviderElement<GallerySaveService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  GallerySaveService create(Ref ref) {
    return gallerySaveService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(GallerySaveService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<GallerySaveService>(value),
    );
  }
}

String _$gallerySaveServiceHash() =>
    r'8d7d0ea856c9bbd1923895e6878e351ea8f9524d';
