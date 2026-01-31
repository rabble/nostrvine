// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'seen_videos_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Notifier for managing seen videos state reactively

@ProviderFor(SeenVideosNotifier)
const seenVideosProvider = SeenVideosNotifierProvider._();

/// Notifier for managing seen videos state reactively
final class SeenVideosNotifierProvider
    extends $NotifierProvider<SeenVideosNotifier, SeenVideosState> {
  /// Notifier for managing seen videos state reactively
  const SeenVideosNotifierProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'seenVideosProvider',
        isAutoDispose: false,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$seenVideosNotifierHash();

  @$internal
  @override
  SeenVideosNotifier create() => SeenVideosNotifier();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SeenVideosState value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SeenVideosState>(value),
    );
  }
}

String _$seenVideosNotifierHash() =>
    r'4abc2beebe5767ef986a0c84e12ffae9685c63a1';

/// Notifier for managing seen videos state reactively

abstract class _$SeenVideosNotifier extends $Notifier<SeenVideosState> {
  SeenVideosState build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<SeenVideosState, SeenVideosState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<SeenVideosState, SeenVideosState>,
              SeenVideosState,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
