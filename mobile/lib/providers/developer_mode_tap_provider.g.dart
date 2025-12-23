// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'developer_mode_tap_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning

@ProviderFor(DeveloperModeTapCounter)
const developerModeTapCounterProvider = DeveloperModeTapCounterProvider._();

final class DeveloperModeTapCounterProvider
    extends $NotifierProvider<DeveloperModeTapCounter, int> {
  const DeveloperModeTapCounterProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'developerModeTapCounterProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$developerModeTapCounterHash();

  @$internal
  @override
  DeveloperModeTapCounter create() => DeveloperModeTapCounter();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(int value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<int>(value),
    );
  }
}

String _$developerModeTapCounterHash() =>
    r'e1ec2bae8ee07c4cae51ff611316063cd2cda3ec';

abstract class _$DeveloperModeTapCounter extends $Notifier<int> {
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
