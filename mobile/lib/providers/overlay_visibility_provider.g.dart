// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'overlay_visibility_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Notifier for managing overlay visibility state

@ProviderFor(OverlayVisibility)
const overlayVisibilityProvider = OverlayVisibilityProvider._();

/// Notifier for managing overlay visibility state
final class OverlayVisibilityProvider
    extends $NotifierProvider<OverlayVisibility, OverlayVisibilityState> {
  /// Notifier for managing overlay visibility state
  const OverlayVisibilityProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'overlayVisibilityProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$overlayVisibilityHash();

  @$internal
  @override
  OverlayVisibility create() => OverlayVisibility();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(OverlayVisibilityState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<OverlayVisibilityState>(value),
    );
  }
}

String _$overlayVisibilityHash() => r'462066019856a0ed648ed17174d22f350e9bf62d';

/// Notifier for managing overlay visibility state

abstract class _$OverlayVisibility extends $Notifier<OverlayVisibilityState> {
  OverlayVisibilityState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref =
        this.ref as $Ref<OverlayVisibilityState, OverlayVisibilityState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<OverlayVisibilityState, OverlayVisibilityState>,
              OverlayVisibilityState,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
