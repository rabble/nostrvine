// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'seen_videos_notifier.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Notifier for managing seen videos state reactively

@ProviderFor(SeenVideosNotifier)
final seenVideosProvider = SeenVideosNotifierProvider._();

/// Notifier for managing seen videos state reactively
final class SeenVideosNotifierProvider
    extends $NotifierProvider<SeenVideosNotifier, SeenVideosState> {
  /// Notifier for managing seen videos state reactively
  SeenVideosNotifierProvider._()
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
    r'8d3d69b2c8cbc1fb2d71857a1421f38ecdaf1dc8';

/// Notifier for managing seen videos state reactively

abstract class _$SeenVideosNotifier extends $Notifier<SeenVideosState> {
  SeenVideosState build();
  @$mustCallSuper
  @override
  WhenComplete runBuild() {
    final ref = this.ref as $Ref<SeenVideosState, SeenVideosState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<SeenVideosState, SeenVideosState>,
              SeenVideosState,
              Object?,
              Object?
            >;
    return element.handleCreate(ref, build);
  }
}
