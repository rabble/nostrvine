// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'environment_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Provider for the environment service singleton

@ProviderFor(environmentService)
const environmentServiceProvider = EnvironmentServiceProvider._();

/// Provider for the environment service singleton

final class EnvironmentServiceProvider
    extends
        $FunctionalProvider<
          EnvironmentService,
          EnvironmentService,
          EnvironmentService
        >
    with $Provider<EnvironmentService> {
  /// Provider for the environment service singleton
  const EnvironmentServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'environmentServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$environmentServiceHash();

  @$internal
  @override
  $ProviderElement<EnvironmentService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  EnvironmentService create(Ref ref) {
    return environmentService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(EnvironmentService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<EnvironmentService>(value),
    );
  }
}

String _$environmentServiceHash() =>
    r'838df3b92839b030c0bae0c59566ffe7ea45e2da';

/// Provider for current environment config (reactive)

@ProviderFor(currentEnvironment)
const currentEnvironmentProvider = CurrentEnvironmentProvider._();

/// Provider for current environment config (reactive)

final class CurrentEnvironmentProvider
    extends
        $FunctionalProvider<
          EnvironmentConfig,
          EnvironmentConfig,
          EnvironmentConfig
        >
    with $Provider<EnvironmentConfig> {
  /// Provider for current environment config (reactive)
  const CurrentEnvironmentProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'currentEnvironmentProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$currentEnvironmentHash();

  @$internal
  @override
  $ProviderElement<EnvironmentConfig> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  EnvironmentConfig create(Ref ref) {
    return currentEnvironment(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(EnvironmentConfig value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<EnvironmentConfig>(value),
    );
  }
}

String _$currentEnvironmentHash() =>
    r'7e9c79685df1563e6772cd47f6cbf7a06256fb6a';

/// Provider for developer mode enabled state

@ProviderFor(isDeveloperModeEnabled)
const isDeveloperModeEnabledProvider = IsDeveloperModeEnabledProvider._();

/// Provider for developer mode enabled state

final class IsDeveloperModeEnabledProvider
    extends $FunctionalProvider<bool, bool, bool>
    with $Provider<bool> {
  /// Provider for developer mode enabled state
  const IsDeveloperModeEnabledProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'isDeveloperModeEnabledProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$isDeveloperModeEnabledHash();

  @$internal
  @override
  $ProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  bool create(Ref ref) {
    return isDeveloperModeEnabled(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$isDeveloperModeEnabledHash() =>
    r'3f5028fa51095861d0d08202e70435540443fe84';

/// Provider to check if showing environment indicator

@ProviderFor(showEnvironmentIndicator)
const showEnvironmentIndicatorProvider = ShowEnvironmentIndicatorProvider._();

/// Provider to check if showing environment indicator

final class ShowEnvironmentIndicatorProvider
    extends $FunctionalProvider<bool, bool, bool>
    with $Provider<bool> {
  /// Provider to check if showing environment indicator
  const ShowEnvironmentIndicatorProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'showEnvironmentIndicatorProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$showEnvironmentIndicatorHash();

  @$internal
  @override
  $ProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  bool create(Ref ref) {
    return showEnvironmentIndicator(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$showEnvironmentIndicatorHash() =>
    r'69c75f591b9b3b88074e4b405b422892bc4eaa0a';
