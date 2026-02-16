// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'subtitle_providers.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Fetches subtitle cues for a video, using the fastest available path.
///
/// 1. If [textTrackContent] is present (REST API embedded the VTT), parse it
///    directly — zero network cost.
/// 2. If [textTrackRef] is present (addressable coordinates like
///    `39307:<pubkey>:subtitles:<d-tag>`), query the relay for the subtitle
///    event and parse its content.
/// 3. Otherwise returns an empty list (no subtitles available).

@ProviderFor(subtitleCues)
const subtitleCuesProvider = SubtitleCuesFamily._();

/// Fetches subtitle cues for a video, using the fastest available path.
///
/// 1. If [textTrackContent] is present (REST API embedded the VTT), parse it
///    directly — zero network cost.
/// 2. If [textTrackRef] is present (addressable coordinates like
///    `39307:<pubkey>:subtitles:<d-tag>`), query the relay for the subtitle
///    event and parse its content.
/// 3. Otherwise returns an empty list (no subtitles available).

final class SubtitleCuesProvider
    extends
        $FunctionalProvider<
          AsyncValue<List<SubtitleCue>>,
          List<SubtitleCue>,
          FutureOr<List<SubtitleCue>>
        >
    with
        $FutureModifier<List<SubtitleCue>>,
        $FutureProvider<List<SubtitleCue>> {
  /// Fetches subtitle cues for a video, using the fastest available path.
  ///
  /// 1. If [textTrackContent] is present (REST API embedded the VTT), parse it
  ///    directly — zero network cost.
  /// 2. If [textTrackRef] is present (addressable coordinates like
  ///    `39307:<pubkey>:subtitles:<d-tag>`), query the relay for the subtitle
  ///    event and parse its content.
  /// 3. Otherwise returns an empty list (no subtitles available).
  const SubtitleCuesProvider._({
    required SubtitleCuesFamily super.from,
    required ({String videoId, String? textTrackRef, String? textTrackContent})
    super.argument,
  }) : super(
         retry: null,
         name: r'subtitleCuesProvider',
         isAutoDispose: true,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$subtitleCuesHash();

  @override
  String toString() {
    return r'subtitleCuesProvider'
        ''
        '$argument';
  }

  @$internal
  @override
  $FutureProviderElement<List<SubtitleCue>> $createElement(
    $ProviderPointer pointer,
  ) => $FutureProviderElement(pointer);

  @override
  FutureOr<List<SubtitleCue>> create(Ref ref) {
    final argument =
        this.argument
            as ({
              String videoId,
              String? textTrackRef,
              String? textTrackContent,
            });
    return subtitleCues(
      ref,
      videoId: argument.videoId,
      textTrackRef: argument.textTrackRef,
      textTrackContent: argument.textTrackContent,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is SubtitleCuesProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$subtitleCuesHash() => r'27292d674d89d6614ef4cb45c83be7e78fd44c32';

/// Fetches subtitle cues for a video, using the fastest available path.
///
/// 1. If [textTrackContent] is present (REST API embedded the VTT), parse it
///    directly — zero network cost.
/// 2. If [textTrackRef] is present (addressable coordinates like
///    `39307:<pubkey>:subtitles:<d-tag>`), query the relay for the subtitle
///    event and parse its content.
/// 3. Otherwise returns an empty list (no subtitles available).

final class SubtitleCuesFamily extends $Family
    with
        $FunctionalFamilyOverride<
          FutureOr<List<SubtitleCue>>,
          ({String videoId, String? textTrackRef, String? textTrackContent})
        > {
  const SubtitleCuesFamily._()
    : super(
        retry: null,
        name: r'subtitleCuesProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: true,
      );

  /// Fetches subtitle cues for a video, using the fastest available path.
  ///
  /// 1. If [textTrackContent] is present (REST API embedded the VTT), parse it
  ///    directly — zero network cost.
  /// 2. If [textTrackRef] is present (addressable coordinates like
  ///    `39307:<pubkey>:subtitles:<d-tag>`), query the relay for the subtitle
  ///    event and parse its content.
  /// 3. Otherwise returns an empty list (no subtitles available).

  SubtitleCuesProvider call({
    required String videoId,
    String? textTrackRef,
    String? textTrackContent,
  }) => SubtitleCuesProvider._(
    argument: (
      videoId: videoId,
      textTrackRef: textTrackRef,
      textTrackContent: textTrackContent,
    ),
    from: this,
  );

  @override
  String toString() => r'subtitleCuesProvider';
}

/// Tracks per-video subtitle visibility (CC on/off).
///
/// State is a map of video IDs to visibility booleans.
/// Videos not in the map default to subtitles hidden.

@ProviderFor(SubtitleVisibility)
const subtitleVisibilityProvider = SubtitleVisibilityProvider._();

/// Tracks per-video subtitle visibility (CC on/off).
///
/// State is a map of video IDs to visibility booleans.
/// Videos not in the map default to subtitles hidden.
final class SubtitleVisibilityProvider
    extends $NotifierProvider<SubtitleVisibility, Map<String, bool>> {
  /// Tracks per-video subtitle visibility (CC on/off).
  ///
  /// State is a map of video IDs to visibility booleans.
  /// Videos not in the map default to subtitles hidden.
  const SubtitleVisibilityProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'subtitleVisibilityProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$subtitleVisibilityHash();

  @$internal
  @override
  SubtitleVisibility create() => SubtitleVisibility();

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(Map<String, bool> value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<Map<String, bool>>(value),
    );
  }
}

String _$subtitleVisibilityHash() =>
    r'55bfd16d789f7c321fda6be432b6a5b33a05e3a3';

/// Tracks per-video subtitle visibility (CC on/off).
///
/// State is a map of video IDs to visibility booleans.
/// Videos not in the map default to subtitles hidden.

abstract class _$SubtitleVisibility extends $Notifier<Map<String, bool>> {
  Map<String, bool> build();
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build();
    final ref = this.ref as $Ref<Map<String, bool>, Map<String, bool>>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<Map<String, bool>, Map<String, bool>>,
              Map<String, bool>,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}

/// Provider for the SubtitleGenerationService.
/// Requires authentication.

@ProviderFor(subtitleGenerationService)
const subtitleGenerationServiceProvider = SubtitleGenerationServiceProvider._();

/// Provider for the SubtitleGenerationService.
/// Requires authentication.

final class SubtitleGenerationServiceProvider
    extends
        $FunctionalProvider<
          SubtitleGenerationService,
          SubtitleGenerationService,
          SubtitleGenerationService
        >
    with $Provider<SubtitleGenerationService> {
  /// Provider for the SubtitleGenerationService.
  /// Requires authentication.
  const SubtitleGenerationServiceProvider._()
    : super(
        from: null,
        argument: null,
        retry: null,
        name: r'subtitleGenerationServiceProvider',
        isAutoDispose: true,
        dependencies: null,
        $allTransitiveDependencies: null,
      );

  @override
  String debugGetCreateSourceHash() => _$subtitleGenerationServiceHash();

  @$internal
  @override
  $ProviderElement<SubtitleGenerationService> $createElement(
    $ProviderPointer pointer,
  ) => $ProviderElement(pointer);

  @override
  SubtitleGenerationService create(Ref ref) {
    return subtitleGenerationService(ref);
  }

  /// {@macro riverpod.override_with_value}
  Override overrideWithValue(SubtitleGenerationService value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<SubtitleGenerationService>(value),
    );
  }
}

String _$subtitleGenerationServiceHash() =>
    r'f133950715654a1c1b0ba05708698f20392b6624';
