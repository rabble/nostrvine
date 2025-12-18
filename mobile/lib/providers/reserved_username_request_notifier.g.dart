// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'reserved_username_request_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Notifier for managing reserved username request form and submission
///
/// Provides methods for updating form fields and submitting the request
/// to the backend. Handles validation and error states.

@ProviderFor(ReservedUsernameRequestNotifier)
const reservedUsernameRequestProvider =
    ReservedUsernameRequestNotifierProvider._();

/// Notifier for managing reserved username request form and submission
///
/// Provides methods for updating form fields and submitting the request
/// to the backend. Handles validation and error states.
final class ReservedUsernameRequestNotifierProvider
    extends
        $NotifierProvider<
          ReservedUsernameRequestNotifier,
          ReservedUsernameRequestState
        > {
  /// Notifier for managing reserved username request form and submission
  ///
  /// Provides methods for updating form fields and submitting the request
  /// to the backend. Handles validation and error states.
  const ReservedUsernameRequestNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'reservedUsernameRequestProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$reservedUsernameRequestNotifierHash();

  @$internal
  @override
  ReservedUsernameRequestNotifier create() => ReservedUsernameRequestNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(ReservedUsernameRequestState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<ReservedUsernameRequestState>(value),
    );
  }
}

String _$reservedUsernameRequestNotifierHash() =>
    r'e35a245114cac47b1c0b738d01438b3e6f5b493f';

/// Notifier for managing reserved username request form and submission
///
/// Provides methods for updating form fields and submitting the request
/// to the backend. Handles validation and error states.

abstract class _$ReservedUsernameRequestNotifier
    extends $Notifier<ReservedUsernameRequestState> {
  ReservedUsernameRequestState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref =
        this.ref
            as $Ref<ReservedUsernameRequestState, ReservedUsernameRequestState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<
                ReservedUsernameRequestState,
                ReservedUsernameRequestState
              >,
              ReservedUsernameRequestState,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
