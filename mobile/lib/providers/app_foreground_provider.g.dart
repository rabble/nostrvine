// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'app_foreground_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// State notifier for tracking app foreground/background state

@ProviderFor(AppForeground)
const appForegroundProvider = AppForegroundProvider._();

/// State notifier for tracking app foreground/background state
final class AppForegroundProvider
    extends $NotifierProvider<AppForeground, bool> {
  /// State notifier for tracking app foreground/background state
  const AppForegroundProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'appForegroundProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$appForegroundHash();

  @$internal
  @override
  AppForeground create() => AppForeground();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$appForegroundHash() => r'6945d7181cac24a15d4a8aaa7e4fd73b2e08cbd2';

/// State notifier for tracking app foreground/background state

abstract class _$AppForeground extends $Notifier<bool> {
  bool build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<bool, bool>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<bool, bool>,
              bool,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
