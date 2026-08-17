// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'outage_diagnosis_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// The app-wide [OutageDiagnosisService].
///
/// Kept alive so the verdict cache survives a failure view being disposed and
/// rebuilt — a user tapping "try again" repeatedly during one incident must
/// not turn into one status request per tap.

@ProviderFor(outageDiagnosisService)
final outageDiagnosisServiceProvider = OutageDiagnosisServiceProvider._();

/// The app-wide [OutageDiagnosisService].
///
/// Kept alive so the verdict cache survives a failure view being disposed and
/// rebuilt — a user tapping "try again" repeatedly during one incident must
/// not turn into one status request per tap.

final class OutageDiagnosisServiceProvider
    extends
        $FunctionalProvider<
          OutageDiagnosisService,
          OutageDiagnosisService,
          OutageDiagnosisService
        >
    with $Provider<OutageDiagnosisService> {
  /// The app-wide [OutageDiagnosisService].
  ///
  /// Kept alive so the verdict cache survives a failure view being disposed and
  /// rebuilt — a user tapping "try again" repeatedly during one incident must
  /// not turn into one status request per tap.
  OutageDiagnosisServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'outageDiagnosisServiceProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$outageDiagnosisServiceHash();

  @$internal
  @override
  $ProviderElement<OutageDiagnosisService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  OutageDiagnosisService create(Ref ref) {
    return outageDiagnosisService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(OutageDiagnosisService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<OutageDiagnosisService>(value),
    );
  }
}

String _$outageDiagnosisServiceHash() =>
    r'26a5b41fc25a78f8acbb3fa187b3d99e275bcff6';
