// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'username_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Notifier for managing username availability checking and registration
///
/// Provides debounced availability checking to avoid excessive API calls
/// and handles the full registration flow including reserved name detection.

@ProviderFor(UsernameNotifier)
const usernameProvider = UsernameNotifierProvider._();

/// Notifier for managing username availability checking and registration
///
/// Provides debounced availability checking to avoid excessive API calls
/// and handles the full registration flow including reserved name detection.
final class UsernameNotifierProvider
    extends $NotifierProvider<UsernameNotifier, UsernameState> {
  /// Notifier for managing username availability checking and registration
  ///
  /// Provides debounced availability checking to avoid excessive API calls
  /// and handles the full registration flow including reserved name detection.
  const UsernameNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'usernameProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$usernameNotifierHash();

  @$internal
  @override
  UsernameNotifier create() => UsernameNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(UsernameState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<UsernameState>(value),
    );
  }
}

String _$usernameNotifierHash() => r'9c99f53c4aba6f862896fa21f259666d2c30be7a';

/// Notifier for managing username availability checking and registration
///
/// Provides debounced availability checking to avoid excessive API calls
/// and handles the full registration flow including reserved name detection.

abstract class _$UsernameNotifier extends $Notifier<UsernameState> {
  UsernameState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<UsernameState, UsernameState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<UsernameState, UsernameState>,
              UsernameState,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
