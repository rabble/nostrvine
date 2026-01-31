// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'tab_visibility_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(TabVisibility)
const tabVisibilityProvider = TabVisibilityProvider._();

final class TabVisibilityProvider
    extends $NotifierProvider<TabVisibility, int> {
  const TabVisibilityProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'tabVisibilityProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$tabVisibilityHash();

  @$internal
  @override
  TabVisibility create() => TabVisibility();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(int value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<int>(value),
    );
  }
}

String _$tabVisibilityHash() => r'9cf5134d5df8c93996ae5069d971b6198cdcce2d';

abstract class _$TabVisibility extends $Notifier<int> {
  int build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<int, int>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<int, int>,
              int,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}

@ProviderFor(isFeedTabActive)
const isFeedTabActiveProvider = IsFeedTabActiveProvider._();

final class IsFeedTabActiveProvider
    extends $FunctionalProvider<bool, bool, bool>
    with $Provider<bool> {
  const IsFeedTabActiveProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'isFeedTabActiveProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$isFeedTabActiveHash();

  @$internal
  @override
  $ProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  bool create(Ref ref) {
    return isFeedTabActive(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$isFeedTabActiveHash() => r'f2e318a0f603f13a04f40d7db6232115994b4e7f';

@ProviderFor(isExploreTabActive)
const isExploreTabActiveProvider = IsExploreTabActiveProvider._();

final class IsExploreTabActiveProvider
    extends $FunctionalProvider<bool, bool, bool>
    with $Provider<bool> {
  const IsExploreTabActiveProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'isExploreTabActiveProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$isExploreTabActiveHash();

  @$internal
  @override
  $ProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  bool create(Ref ref) {
    return isExploreTabActive(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$isExploreTabActiveHash() =>
    r'd040595e2acc4ef80312d6f174a269eac14f1062';

@ProviderFor(isProfileTabActive)
const isProfileTabActiveProvider = IsProfileTabActiveProvider._();

final class IsProfileTabActiveProvider
    extends $FunctionalProvider<bool, bool, bool>
    with $Provider<bool> {
  const IsProfileTabActiveProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'isProfileTabActiveProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$isProfileTabActiveHash();

  @$internal
  @override
  $ProviderElement<bool> $createElement($ProviderPointer pointer) =>
      $ProviderElement(pointer);

  @override
  bool create(Ref ref) {
    return isProfileTabActive(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$isProfileTabActiveHash() =>
    r'80d0d438ceeeb269ad30725e6929b637ce011165';
