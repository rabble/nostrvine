// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'username_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Notifier for managing username availability checking
///
/// Provides debounced availability checking to avoid excessive API calls
/// while the user types in the username field.

@ProviderFor(UsernameNotifier)
const usernameProvider = UsernameNotifierProvider._();

/// Notifier for managing username availability checking
///
/// Provides debounced availability checking to avoid excessive API calls
/// while the user types in the username field.
final class UsernameNotifierProvider
    extends $NotifierProvider<UsernameNotifier, UsernameState> {
  /// Notifier for managing username availability checking
  ///
  /// Provides debounced availability checking to avoid excessive API calls
  /// while the user types in the username field.
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

String _$usernameNotifierHash() => r'76514b404ff53d88f1e6597414e2d8d7a4aafdd9';

/// Notifier for managing username availability checking
///
/// Provides debounced availability checking to avoid excessive API calls
/// while the user types in the username field.

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
