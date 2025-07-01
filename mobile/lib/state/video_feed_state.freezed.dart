// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'video_feed_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

/// @nodoc
mixin _$VideoFeedState {
  /// List of videos in the feed
  List<VideoEvent> get videos => throw _privateConstructorUsedError;

  /// Current feed mode
  FeedMode get feedMode => throw _privateConstructorUsedError;

  /// Whether this is a following-based feed
  bool get isFollowingFeed => throw _privateConstructorUsedError;

  /// Whether more content can be loaded
  bool get hasMoreContent => throw _privateConstructorUsedError;

  /// Number of videos from primary source (following/curated)
  int get primaryVideoCount => throw _privateConstructorUsedError;

  /// Loading state for pagination
  bool get isLoadingMore => throw _privateConstructorUsedError;

  /// Refreshing state for pull-to-refresh
  bool get isRefreshing => throw _privateConstructorUsedError;

  /// Current context value (hashtag or pubkey)
  String? get feedContext => throw _privateConstructorUsedError;

  /// Error message if any
  String? get error => throw _privateConstructorUsedError;

  /// Timestamp of last update
  DateTime? get lastUpdated => throw _privateConstructorUsedError;

  /// Create a copy of VideoFeedState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $VideoFeedStateCopyWith<VideoFeedState> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $VideoFeedStateCopyWith<$Res> {
  factory $VideoFeedStateCopyWith(
          VideoFeedState value, $Res Function(VideoFeedState) then) =
      _$VideoFeedStateCopyWithImpl<$Res, VideoFeedState>;
  @useResult
  $Res call(
      {List<VideoEvent> videos,
      FeedMode feedMode,
      bool isFollowingFeed,
      bool hasMoreContent,
      int primaryVideoCount,
      bool isLoadingMore,
      bool isRefreshing,
      String? feedContext,
      String? error,
      DateTime? lastUpdated});
}

/// @nodoc
class _$VideoFeedStateCopyWithImpl<$Res, $Val extends VideoFeedState>
    implements $VideoFeedStateCopyWith<$Res> {
  _$VideoFeedStateCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of VideoFeedState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? videos = null,
    Object? feedMode = null,
    Object? isFollowingFeed = null,
    Object? hasMoreContent = null,
    Object? primaryVideoCount = null,
    Object? isLoadingMore = null,
    Object? isRefreshing = null,
    Object? feedContext = freezed,
    Object? error = freezed,
    Object? lastUpdated = freezed,
  }) {
    return _then(_value.copyWith(
      videos: null == videos
          ? _value.videos
          : videos // ignore: cast_nullable_to_non_nullable
              as List<VideoEvent>,
      feedMode: null == feedMode
          ? _value.feedMode
          : feedMode // ignore: cast_nullable_to_non_nullable
              as FeedMode,
      isFollowingFeed: null == isFollowingFeed
          ? _value.isFollowingFeed
          : isFollowingFeed // ignore: cast_nullable_to_non_nullable
              as bool,
      hasMoreContent: null == hasMoreContent
          ? _value.hasMoreContent
          : hasMoreContent // ignore: cast_nullable_to_non_nullable
              as bool,
      primaryVideoCount: null == primaryVideoCount
          ? _value.primaryVideoCount
          : primaryVideoCount // ignore: cast_nullable_to_non_nullable
              as int,
      isLoadingMore: null == isLoadingMore
          ? _value.isLoadingMore
          : isLoadingMore // ignore: cast_nullable_to_non_nullable
              as bool,
      isRefreshing: null == isRefreshing
          ? _value.isRefreshing
          : isRefreshing // ignore: cast_nullable_to_non_nullable
              as bool,
      feedContext: freezed == feedContext
          ? _value.feedContext
          : feedContext // ignore: cast_nullable_to_non_nullable
              as String?,
      error: freezed == error
          ? _value.error
          : error // ignore: cast_nullable_to_non_nullable
              as String?,
      lastUpdated: freezed == lastUpdated
          ? _value.lastUpdated
          : lastUpdated // ignore: cast_nullable_to_non_nullable
              as DateTime?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$VideoFeedStateImplCopyWith<$Res>
    implements $VideoFeedStateCopyWith<$Res> {
  factory _$$VideoFeedStateImplCopyWith(_$VideoFeedStateImpl value,
          $Res Function(_$VideoFeedStateImpl) then) =
      __$$VideoFeedStateImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {List<VideoEvent> videos,
      FeedMode feedMode,
      bool isFollowingFeed,
      bool hasMoreContent,
      int primaryVideoCount,
      bool isLoadingMore,
      bool isRefreshing,
      String? feedContext,
      String? error,
      DateTime? lastUpdated});
}

/// @nodoc
class __$$VideoFeedStateImplCopyWithImpl<$Res>
    extends _$VideoFeedStateCopyWithImpl<$Res, _$VideoFeedStateImpl>
    implements _$$VideoFeedStateImplCopyWith<$Res> {
  __$$VideoFeedStateImplCopyWithImpl(
      _$VideoFeedStateImpl _value, $Res Function(_$VideoFeedStateImpl) _then)
      : super(_value, _then);

  /// Create a copy of VideoFeedState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? videos = null,
    Object? feedMode = null,
    Object? isFollowingFeed = null,
    Object? hasMoreContent = null,
    Object? primaryVideoCount = null,
    Object? isLoadingMore = null,
    Object? isRefreshing = null,
    Object? feedContext = freezed,
    Object? error = freezed,
    Object? lastUpdated = freezed,
  }) {
    return _then(_$VideoFeedStateImpl(
      videos: null == videos
          ? _value._videos
          : videos // ignore: cast_nullable_to_non_nullable
              as List<VideoEvent>,
      feedMode: null == feedMode
          ? _value.feedMode
          : feedMode // ignore: cast_nullable_to_non_nullable
              as FeedMode,
      isFollowingFeed: null == isFollowingFeed
          ? _value.isFollowingFeed
          : isFollowingFeed // ignore: cast_nullable_to_non_nullable
              as bool,
      hasMoreContent: null == hasMoreContent
          ? _value.hasMoreContent
          : hasMoreContent // ignore: cast_nullable_to_non_nullable
              as bool,
      primaryVideoCount: null == primaryVideoCount
          ? _value.primaryVideoCount
          : primaryVideoCount // ignore: cast_nullable_to_non_nullable
              as int,
      isLoadingMore: null == isLoadingMore
          ? _value.isLoadingMore
          : isLoadingMore // ignore: cast_nullable_to_non_nullable
              as bool,
      isRefreshing: null == isRefreshing
          ? _value.isRefreshing
          : isRefreshing // ignore: cast_nullable_to_non_nullable
              as bool,
      feedContext: freezed == feedContext
          ? _value.feedContext
          : feedContext // ignore: cast_nullable_to_non_nullable
              as String?,
      error: freezed == error
          ? _value.error
          : error // ignore: cast_nullable_to_non_nullable
              as String?,
      lastUpdated: freezed == lastUpdated
          ? _value.lastUpdated
          : lastUpdated // ignore: cast_nullable_to_non_nullable
              as DateTime?,
    ));
  }
}

/// @nodoc

class _$VideoFeedStateImpl extends _VideoFeedState {
  const _$VideoFeedStateImpl(
      {required final List<VideoEvent> videos,
      required this.feedMode,
      required this.isFollowingFeed,
      required this.hasMoreContent,
      required this.primaryVideoCount,
      this.isLoadingMore = false,
      this.isRefreshing = false,
      this.feedContext,
      this.error,
      this.lastUpdated})
      : _videos = videos,
        super._();

  /// List of videos in the feed
  final List<VideoEvent> _videos;

  /// List of videos in the feed
  @override
  List<VideoEvent> get videos {
    if (_videos is EqualUnmodifiableListView) return _videos;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_videos);
  }

  /// Current feed mode
  @override
  final FeedMode feedMode;

  /// Whether this is a following-based feed
  @override
  final bool isFollowingFeed;

  /// Whether more content can be loaded
  @override
  final bool hasMoreContent;

  /// Number of videos from primary source (following/curated)
  @override
  final int primaryVideoCount;

  /// Loading state for pagination
  @override
  @JsonKey()
  final bool isLoadingMore;

  /// Refreshing state for pull-to-refresh
  @override
  @JsonKey()
  final bool isRefreshing;

  /// Current context value (hashtag or pubkey)
  @override
  final String? feedContext;

  /// Error message if any
  @override
  final String? error;

  /// Timestamp of last update
  @override
  final DateTime? lastUpdated;

  @override
  String toString() {
    return 'VideoFeedState(videos: $videos, feedMode: $feedMode, isFollowingFeed: $isFollowingFeed, hasMoreContent: $hasMoreContent, primaryVideoCount: $primaryVideoCount, isLoadingMore: $isLoadingMore, isRefreshing: $isRefreshing, feedContext: $feedContext, error: $error, lastUpdated: $lastUpdated)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$VideoFeedStateImpl &&
            const DeepCollectionEquality().equals(other._videos, _videos) &&
            (identical(other.feedMode, feedMode) ||
                other.feedMode == feedMode) &&
            (identical(other.isFollowingFeed, isFollowingFeed) ||
                other.isFollowingFeed == isFollowingFeed) &&
            (identical(other.hasMoreContent, hasMoreContent) ||
                other.hasMoreContent == hasMoreContent) &&
            (identical(other.primaryVideoCount, primaryVideoCount) ||
                other.primaryVideoCount == primaryVideoCount) &&
            (identical(other.isLoadingMore, isLoadingMore) ||
                other.isLoadingMore == isLoadingMore) &&
            (identical(other.isRefreshing, isRefreshing) ||
                other.isRefreshing == isRefreshing) &&
            (identical(other.feedContext, feedContext) ||
                other.feedContext == feedContext) &&
            (identical(other.error, error) || other.error == error) &&
            (identical(other.lastUpdated, lastUpdated) ||
                other.lastUpdated == lastUpdated));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      const DeepCollectionEquality().hash(_videos),
      feedMode,
      isFollowingFeed,
      hasMoreContent,
      primaryVideoCount,
      isLoadingMore,
      isRefreshing,
      feedContext,
      error,
      lastUpdated);

  /// Create a copy of VideoFeedState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$VideoFeedStateImplCopyWith<_$VideoFeedStateImpl> get copyWith =>
      __$$VideoFeedStateImplCopyWithImpl<_$VideoFeedStateImpl>(
          this, _$identity);
}

abstract class _VideoFeedState extends VideoFeedState {
  const factory _VideoFeedState(
      {required final List<VideoEvent> videos,
      required final FeedMode feedMode,
      required final bool isFollowingFeed,
      required final bool hasMoreContent,
      required final int primaryVideoCount,
      final bool isLoadingMore,
      final bool isRefreshing,
      final String? feedContext,
      final String? error,
      final DateTime? lastUpdated}) = _$VideoFeedStateImpl;
  const _VideoFeedState._() : super._();

  /// List of videos in the feed
  @override
  List<VideoEvent> get videos;

  /// Current feed mode
  @override
  FeedMode get feedMode;

  /// Whether this is a following-based feed
  @override
  bool get isFollowingFeed;

  /// Whether more content can be loaded
  @override
  bool get hasMoreContent;

  /// Number of videos from primary source (following/curated)
  @override
  int get primaryVideoCount;

  /// Loading state for pagination
  @override
  bool get isLoadingMore;

  /// Refreshing state for pull-to-refresh
  @override
  bool get isRefreshing;

  /// Current context value (hashtag or pubkey)
  @override
  String? get feedContext;

  /// Error message if any
  @override
  String? get error;

  /// Timestamp of last update
  @override
  DateTime? get lastUpdated;

  /// Create a copy of VideoFeedState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$VideoFeedStateImplCopyWith<_$VideoFeedStateImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
