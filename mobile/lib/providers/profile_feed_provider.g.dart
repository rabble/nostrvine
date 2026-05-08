// GENERATED CODE - DO NOT MODIFY BY HAND

part of 'profile_feed_provider.dart';

// **************************************************************************
// RiverpodGenerator
// **************************************************************************

// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint, type=warning
/// Profile feed provider - shows videos for a specific user with pagination
///
/// This is a family provider, so each userId gets its own provider instance
/// with independent pagination tracking.
///
/// Strategy: Try Funnelcake REST API first for better performance,
/// fall back to Nostr subscription if unavailable.
///
/// **Engagement merge policy (#3384):** Lists merge relay snapshots with
/// Funnelcake REST rows for the same `(pubkey, stableId)`. For counts that
/// drive the same UX as the home feed ([VideoEvent.totalLoops] and related
/// engagement fields), **prefer Funnelcake and bulk-stat hydration** over
/// conflicting static Nostr tag values: relay copies may carry `loops` / zero
/// or stale figures while the API reflects current aggregates. When only Nostr
/// data exists (no REST row, no cache backfill), relay values remain the sole
/// source. [_mergeVideo], [mergeTwoProfileVideos], [mergeProfileEngagementCount],
/// [mergeRawTagsForVideoMerge], and shared `video_event_merge_utils` (used from
/// Nostr enrichment) must stay aligned with this policy whenever merge logic
/// changes.
///
/// Usage:
/// ```dart
/// final feed = ref.watch(profileFeedProvider(userId));
/// await ref.read(profileFeedProvider(userId).notifier).loadMore();
/// ```

@ProviderFor(ProfileFeed)
const profileFeedProvider = ProfileFeedFamily._();

/// Profile feed provider - shows videos for a specific user with pagination
///
/// This is a family provider, so each userId gets its own provider instance
/// with independent pagination tracking.
///
/// Strategy: Try Funnelcake REST API first for better performance,
/// fall back to Nostr subscription if unavailable.
///
/// **Engagement merge policy (#3384):** Lists merge relay snapshots with
/// Funnelcake REST rows for the same `(pubkey, stableId)`. For counts that
/// drive the same UX as the home feed ([VideoEvent.totalLoops] and related
/// engagement fields), **prefer Funnelcake and bulk-stat hydration** over
/// conflicting static Nostr tag values: relay copies may carry `loops` / zero
/// or stale figures while the API reflects current aggregates. When only Nostr
/// data exists (no REST row, no cache backfill), relay values remain the sole
/// source. [_mergeVideo], [mergeTwoProfileVideos], [mergeProfileEngagementCount],
/// [mergeRawTagsForVideoMerge], and shared `video_event_merge_utils` (used from
/// Nostr enrichment) must stay aligned with this policy whenever merge logic
/// changes.
///
/// Usage:
/// ```dart
/// final feed = ref.watch(profileFeedProvider(userId));
/// await ref.read(profileFeedProvider(userId).notifier).loadMore();
/// ```
final class ProfileFeedProvider
    extends $AsyncNotifierProvider<ProfileFeed, VideoFeedState> {
  /// Profile feed provider - shows videos for a specific user with pagination
  ///
  /// This is a family provider, so each userId gets its own provider instance
  /// with independent pagination tracking.
  ///
  /// Strategy: Try Funnelcake REST API first for better performance,
  /// fall back to Nostr subscription if unavailable.
  ///
  /// **Engagement merge policy (#3384):** Lists merge relay snapshots with
  /// Funnelcake REST rows for the same `(pubkey, stableId)`. For counts that
  /// drive the same UX as the home feed ([VideoEvent.totalLoops] and related
  /// engagement fields), **prefer Funnelcake and bulk-stat hydration** over
  /// conflicting static Nostr tag values: relay copies may carry `loops` / zero
  /// or stale figures while the API reflects current aggregates. When only Nostr
  /// data exists (no REST row, no cache backfill), relay values remain the sole
  /// source. [_mergeVideo], [mergeTwoProfileVideos], [mergeProfileEngagementCount],
  /// [mergeRawTagsForVideoMerge], and shared `video_event_merge_utils` (used from
  /// Nostr enrichment) must stay aligned with this policy whenever merge logic
  /// changes.
  ///
  /// Usage:
  /// ```dart
  /// final feed = ref.watch(profileFeedProvider(userId));
  /// await ref.read(profileFeedProvider(userId).notifier).loadMore();
  /// ```
  const ProfileFeedProvider._({
    required ProfileFeedFamily super.from,
    required String super.argument,
  }) : super(
         retry: null,
         name: r'profileFeedProvider',
         isAutoDispose: false,
         dependencies: null,
         $allTransitiveDependencies: null,
       );

  @override
  String debugGetCreateSourceHash() => _$profileFeedHash();

  @override
  String toString() {
    return r'profileFeedProvider'
        ''
        '($argument)';
  }

  @$internal
  @override
  ProfileFeed create() => ProfileFeed();

  @override
  bool operator ==(Object other) {
    return other is ProfileFeedProvider && other.argument == argument;
  }

  @override
  int get hashCode {
    return argument.hashCode;
  }
}

String _$profileFeedHash() => r'bfa1e8e2540ce5e41e1a61484f769a2cf5291322';

/// Profile feed provider - shows videos for a specific user with pagination
///
/// This is a family provider, so each userId gets its own provider instance
/// with independent pagination tracking.
///
/// Strategy: Try Funnelcake REST API first for better performance,
/// fall back to Nostr subscription if unavailable.
///
/// **Engagement merge policy (#3384):** Lists merge relay snapshots with
/// Funnelcake REST rows for the same `(pubkey, stableId)`. For counts that
/// drive the same UX as the home feed ([VideoEvent.totalLoops] and related
/// engagement fields), **prefer Funnelcake and bulk-stat hydration** over
/// conflicting static Nostr tag values: relay copies may carry `loops` / zero
/// or stale figures while the API reflects current aggregates. When only Nostr
/// data exists (no REST row, no cache backfill), relay values remain the sole
/// source. [_mergeVideo], [mergeTwoProfileVideos], [mergeProfileEngagementCount],
/// [mergeRawTagsForVideoMerge], and shared `video_event_merge_utils` (used from
/// Nostr enrichment) must stay aligned with this policy whenever merge logic
/// changes.
///
/// Usage:
/// ```dart
/// final feed = ref.watch(profileFeedProvider(userId));
/// await ref.read(profileFeedProvider(userId).notifier).loadMore();
/// ```

final class ProfileFeedFamily extends $Family
    with
        $ClassFamilyOverride<
          ProfileFeed,
          AsyncValue<VideoFeedState>,
          VideoFeedState,
          FutureOr<VideoFeedState>,
          String
        > {
  const ProfileFeedFamily._()
    : super(
        retry: null,
        name: r'profileFeedProvider',
        dependencies: null,
        $allTransitiveDependencies: null,
        isAutoDispose: false,
      );

  /// Profile feed provider - shows videos for a specific user with pagination
  ///
  /// This is a family provider, so each userId gets its own provider instance
  /// with independent pagination tracking.
  ///
  /// Strategy: Try Funnelcake REST API first for better performance,
  /// fall back to Nostr subscription if unavailable.
  ///
  /// **Engagement merge policy (#3384):** Lists merge relay snapshots with
  /// Funnelcake REST rows for the same `(pubkey, stableId)`. For counts that
  /// drive the same UX as the home feed ([VideoEvent.totalLoops] and related
  /// engagement fields), **prefer Funnelcake and bulk-stat hydration** over
  /// conflicting static Nostr tag values: relay copies may carry `loops` / zero
  /// or stale figures while the API reflects current aggregates. When only Nostr
  /// data exists (no REST row, no cache backfill), relay values remain the sole
  /// source. [_mergeVideo], [mergeTwoProfileVideos], [mergeProfileEngagementCount],
  /// [mergeRawTagsForVideoMerge], and shared `video_event_merge_utils` (used from
  /// Nostr enrichment) must stay aligned with this policy whenever merge logic
  /// changes.
  ///
  /// Usage:
  /// ```dart
  /// final feed = ref.watch(profileFeedProvider(userId));
  /// await ref.read(profileFeedProvider(userId).notifier).loadMore();
  /// ```

  ProfileFeedProvider call(String userId) =>
      ProfileFeedProvider._(argument: userId, from: this);

  @override
  String toString() => r'profileFeedProvider';
}

/// Profile feed provider - shows videos for a specific user with pagination
///
/// This is a family provider, so each userId gets its own provider instance
/// with independent pagination tracking.
///
/// Strategy: Try Funnelcake REST API first for better performance,
/// fall back to Nostr subscription if unavailable.
///
/// **Engagement merge policy (#3384):** Lists merge relay snapshots with
/// Funnelcake REST rows for the same `(pubkey, stableId)`. For counts that
/// drive the same UX as the home feed ([VideoEvent.totalLoops] and related
/// engagement fields), **prefer Funnelcake and bulk-stat hydration** over
/// conflicting static Nostr tag values: relay copies may carry `loops` / zero
/// or stale figures while the API reflects current aggregates. When only Nostr
/// data exists (no REST row, no cache backfill), relay values remain the sole
/// source. [_mergeVideo], [mergeTwoProfileVideos], [mergeProfileEngagementCount],
/// [mergeRawTagsForVideoMerge], and shared `video_event_merge_utils` (used from
/// Nostr enrichment) must stay aligned with this policy whenever merge logic
/// changes.
///
/// Usage:
/// ```dart
/// final feed = ref.watch(profileFeedProvider(userId));
/// await ref.read(profileFeedProvider(userId).notifier).loadMore();
/// ```

abstract class _$ProfileFeed extends $AsyncNotifier<VideoFeedState> {
  late final _$args = ref.$arg as String;
  String get userId => _$args;

  FutureOr<VideoFeedState> build(String userId);
  @$mustCallSuper
  @override
  void runBuild() {
    final created = build(_$args);
    final ref = this.ref as $Ref<AsyncValue<VideoFeedState>, VideoFeedState>;
    final element =
        ref.element
            as $ClassProviderElement<
              AnyNotifier<AsyncValue<VideoFeedState>, VideoFeedState>,
              AsyncValue<VideoFeedState>,
              Object?,
              Object?
            >;
    element.handleValue(ref, created);
  }
}
