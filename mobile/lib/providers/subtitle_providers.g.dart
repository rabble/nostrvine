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
/// 2. If [sha256] is present, fetch VTT from the Blossom server at
///    `https://media.divine.video/{sha256}/vtt`. Returns empty list on 404
///    (VTT not yet generated). Non-blocking.
/// 3. If [textTrackRef] is present (addressable coordinates like
///    `39307:<pubkey>:subtitles:<d-tag>`), query the relay for the subtitle
///    event and parse its content.
/// 4. Otherwise returns an empty list (no subtitles available).

@ProviderFor(subtitleCues)
const subtitleCuesProvider = SubtitleCuesFamily._();

/// Fetches subtitle cues for a video, using the fastest available path.
///
/// 1. If [textTrackContent] is present (REST API embedded the VTT), parse it
///    directly — zero network cost.
/// 2. If [sha256] is present, fetch VTT from the Blossom server at
///    `https://media.divine.video/{sha256}/vtt`. Returns empty list on 404
///    (VTT not yet generated). Non-blocking.
/// 3. If [textTrackRef] is present (addressable coordinates like
///    `39307:<pubkey>:subtitles:<d-tag>`), query the relay for the subtitle
///    event and parse its content.
/// 4. Otherwise returns an empty list (no subtitles available).

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
  /// 2. If [sha256] is present, fetch VTT from the Blossom server at
  ///    `https://media.divine.video/{sha256}/vtt`. Returns empty list on 404
  ///    (VTT not yet generated). Non-blocking.
  /// 3. If [textTrackRef] is present (addressable coordinates like
  ///    `39307:<pubkey>:subtitles:<d-tag>`), query the relay for the subtitle
  ///    event and parse its content.
  /// 4. Otherwise returns an empty list (no subtitles available).
  const SubtitleCuesProvider._({
    required SubtitleCuesFamily super.from,
    required ({
      String videoId,
      String? textTrackRef,
      String? textTrackContent,
      String? sha256,
    })
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
              String? sha256,
            });
    return subtitleCues(
      ref,
      videoId: argument.videoId,
      textTrackRef: argument.textTrackRef,
      textTrackContent: argument.textTrackContent,
      sha256: argument.sha256,
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

String _$subtitleCuesHash() => r'21d2c1f6d3f9506e1a72d7d7ddbca0a0a27df797';

/// Fetches subtitle cues for a video, using the fastest available path.
///
/// 1. If [textTrackContent] is present (REST API embedded the VTT), parse it
///    directly — zero network cost.
/// 2. If [sha256] is present, fetch VTT from the Blossom server at
///    `https://media.divine.video/{sha256}/vtt`. Returns empty list on 404
///    (VTT not yet generated). Non-blocking.
/// 3. If [textTrackRef] is present (addressable coordinates like
///    `39307:<pubkey>:subtitles:<d-tag>`), query the relay for the subtitle
///    event and parse its content.
/// 4. Otherwise returns an empty list (no subtitles available).

final class SubtitleCuesFamily extends $Family
    with
        $FunctionalFamilyOverride<
          FutureOr<List<SubtitleCue>>,
          ({
            String videoId,
            String? textTrackRef,
            String? textTrackContent,
            String? sha256,
          })
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
  /// 2. If [sha256] is present, fetch VTT from the Blossom server at
  ///    `https://media.divine.video/{sha256}/vtt`. Returns empty list on 404
  ///    (VTT not yet generated). Non-blocking.
  /// 3. If [textTrackRef] is present (addressable coordinates like
  ///    `39307:<pubkey>:subtitles:<d-tag>`), query the relay for the subtitle
  ///    event and parse its content.
  /// 4. Otherwise returns an empty list (no subtitles available).

  SubtitleCuesProvider call({
    required String videoId,
    String? textTrackRef,
    String? textTrackContent,
    String? sha256,
  }) => SubtitleCuesProvider._(
    argument: (
      videoId: videoId,
      textTrackRef: textTrackRef,
      textTrackContent: textTrackContent,
      sha256: sha256,
    ),
    from: this,
  );

  @override
  String toString() => r'subtitleCuesProvider';
}

/// Tracks global subtitle visibility (CC on/off).
///
/// When enabled, subtitles are shown on all videos that have them.
/// This acts as an app-wide preference - toggling on one video
/// applies to all videos.

@ProviderFor(SubtitleVisibility)
const subtitleVisibilityProvider = SubtitleVisibilityProvider._();

/// Tracks global subtitle visibility (CC on/off).
///
/// When enabled, subtitles are shown on all videos that have them.
/// This acts as an app-wide preference - toggling on one video
/// applies to all videos.
final class SubtitleVisibilityProvider
    extends $NotifierProvider<SubtitleVisibility, bool> {
  /// Tracks global subtitle visibility (CC on/off).
  ///
  /// When enabled, subtitles are shown on all videos that have them.
  /// This acts as an app-wide preference - toggling on one video
  /// applies to all videos.
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
  Override overrideWithValue(bool value) {
    return $ProviderOverride(
      origin: this,
      providerOverride: $SyncValueProvider<bool>(value),
    );
  }
}

String _$subtitleVisibilityHash() =>
    r'01e50dcdb7681118380f1e6ce2e216dafcb0e35b';

/// Tracks global subtitle visibility (CC on/off).
///
/// When enabled, subtitles are shown on all videos that have them.
/// This acts as an app-wide preference - toggling on one video
/// applies to all videos.

abstract class _$SubtitleVisibility extends $Notifier<bool> {
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
