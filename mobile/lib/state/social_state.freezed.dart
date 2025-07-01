// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'social_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

SocialState _$SocialStateFromJson(Map<String, dynamic> json) {
  return _SocialState.fromJson(json);
}

/// @nodoc
mixin _$SocialState {
// Like-related state
  Set<String> get likedEventIds => throw _privateConstructorUsedError;
  Map<String, int> get likeCounts => throw _privateConstructorUsedError;
  Map<String, String> get likeEventIdToReactionId =>
      throw _privateConstructorUsedError; // Repost-related state
  Set<String> get repostedEventIds => throw _privateConstructorUsedError;
  Map<String, String> get repostEventIdToRepostId =>
      throw _privateConstructorUsedError; // Follow-related state
  List<String> get followingPubkeys => throw _privateConstructorUsedError;
  Map<String, Map<String, int>> get followerStats =>
      throw _privateConstructorUsedError;
  Event? get currentUserContactListEvent =>
      throw _privateConstructorUsedError; // Loading and error state
  bool get isLoading => throw _privateConstructorUsedError;
  bool get isInitialized => throw _privateConstructorUsedError;
  String? get error =>
      throw _privateConstructorUsedError; // Operation-specific loading states
  Set<String> get likesInProgress => throw _privateConstructorUsedError;
  Set<String> get repostsInProgress => throw _privateConstructorUsedError;
  Set<String> get followsInProgress => throw _privateConstructorUsedError;

  /// Serializes this SocialState to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of SocialState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $SocialStateCopyWith<SocialState> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $SocialStateCopyWith<$Res> {
  factory $SocialStateCopyWith(
          SocialState value, $Res Function(SocialState) then) =
      _$SocialStateCopyWithImpl<$Res, SocialState>;
  @useResult
  $Res call(
      {Set<String> likedEventIds,
      Map<String, int> likeCounts,
      Map<String, String> likeEventIdToReactionId,
      Set<String> repostedEventIds,
      Map<String, String> repostEventIdToRepostId,
      List<String> followingPubkeys,
      Map<String, Map<String, int>> followerStats,
      Event? currentUserContactListEvent,
      bool isLoading,
      bool isInitialized,
      String? error,
      Set<String> likesInProgress,
      Set<String> repostsInProgress,
      Set<String> followsInProgress});
}

/// @nodoc
class _$SocialStateCopyWithImpl<$Res, $Val extends SocialState>
    implements $SocialStateCopyWith<$Res> {
  _$SocialStateCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of SocialState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? likedEventIds = null,
    Object? likeCounts = null,
    Object? likeEventIdToReactionId = null,
    Object? repostedEventIds = null,
    Object? repostEventIdToRepostId = null,
    Object? followingPubkeys = null,
    Object? followerStats = null,
    Object? currentUserContactListEvent = freezed,
    Object? isLoading = null,
    Object? isInitialized = null,
    Object? error = freezed,
    Object? likesInProgress = null,
    Object? repostsInProgress = null,
    Object? followsInProgress = null,
  }) {
    return _then(_value.copyWith(
      likedEventIds: null == likedEventIds
          ? _value.likedEventIds
          : likedEventIds // ignore: cast_nullable_to_non_nullable
              as Set<String>,
      likeCounts: null == likeCounts
          ? _value.likeCounts
          : likeCounts // ignore: cast_nullable_to_non_nullable
              as Map<String, int>,
      likeEventIdToReactionId: null == likeEventIdToReactionId
          ? _value.likeEventIdToReactionId
          : likeEventIdToReactionId // ignore: cast_nullable_to_non_nullable
              as Map<String, String>,
      repostedEventIds: null == repostedEventIds
          ? _value.repostedEventIds
          : repostedEventIds // ignore: cast_nullable_to_non_nullable
              as Set<String>,
      repostEventIdToRepostId: null == repostEventIdToRepostId
          ? _value.repostEventIdToRepostId
          : repostEventIdToRepostId // ignore: cast_nullable_to_non_nullable
              as Map<String, String>,
      followingPubkeys: null == followingPubkeys
          ? _value.followingPubkeys
          : followingPubkeys // ignore: cast_nullable_to_non_nullable
              as List<String>,
      followerStats: null == followerStats
          ? _value.followerStats
          : followerStats // ignore: cast_nullable_to_non_nullable
              as Map<String, Map<String, int>>,
      currentUserContactListEvent: freezed == currentUserContactListEvent
          ? _value.currentUserContactListEvent
          : currentUserContactListEvent // ignore: cast_nullable_to_non_nullable
              as Event?,
      isLoading: null == isLoading
          ? _value.isLoading
          : isLoading // ignore: cast_nullable_to_non_nullable
              as bool,
      isInitialized: null == isInitialized
          ? _value.isInitialized
          : isInitialized // ignore: cast_nullable_to_non_nullable
              as bool,
      error: freezed == error
          ? _value.error
          : error // ignore: cast_nullable_to_non_nullable
              as String?,
      likesInProgress: null == likesInProgress
          ? _value.likesInProgress
          : likesInProgress // ignore: cast_nullable_to_non_nullable
              as Set<String>,
      repostsInProgress: null == repostsInProgress
          ? _value.repostsInProgress
          : repostsInProgress // ignore: cast_nullable_to_non_nullable
              as Set<String>,
      followsInProgress: null == followsInProgress
          ? _value.followsInProgress
          : followsInProgress // ignore: cast_nullable_to_non_nullable
              as Set<String>,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$SocialStateImplCopyWith<$Res>
    implements $SocialStateCopyWith<$Res> {
  factory _$$SocialStateImplCopyWith(
          _$SocialStateImpl value, $Res Function(_$SocialStateImpl) then) =
      __$$SocialStateImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {Set<String> likedEventIds,
      Map<String, int> likeCounts,
      Map<String, String> likeEventIdToReactionId,
      Set<String> repostedEventIds,
      Map<String, String> repostEventIdToRepostId,
      List<String> followingPubkeys,
      Map<String, Map<String, int>> followerStats,
      Event? currentUserContactListEvent,
      bool isLoading,
      bool isInitialized,
      String? error,
      Set<String> likesInProgress,
      Set<String> repostsInProgress,
      Set<String> followsInProgress});
}

/// @nodoc
class __$$SocialStateImplCopyWithImpl<$Res>
    extends _$SocialStateCopyWithImpl<$Res, _$SocialStateImpl>
    implements _$$SocialStateImplCopyWith<$Res> {
  __$$SocialStateImplCopyWithImpl(
      _$SocialStateImpl _value, $Res Function(_$SocialStateImpl) _then)
      : super(_value, _then);

  /// Create a copy of SocialState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? likedEventIds = null,
    Object? likeCounts = null,
    Object? likeEventIdToReactionId = null,
    Object? repostedEventIds = null,
    Object? repostEventIdToRepostId = null,
    Object? followingPubkeys = null,
    Object? followerStats = null,
    Object? currentUserContactListEvent = freezed,
    Object? isLoading = null,
    Object? isInitialized = null,
    Object? error = freezed,
    Object? likesInProgress = null,
    Object? repostsInProgress = null,
    Object? followsInProgress = null,
  }) {
    return _then(_$SocialStateImpl(
      likedEventIds: null == likedEventIds
          ? _value._likedEventIds
          : likedEventIds // ignore: cast_nullable_to_non_nullable
              as Set<String>,
      likeCounts: null == likeCounts
          ? _value._likeCounts
          : likeCounts // ignore: cast_nullable_to_non_nullable
              as Map<String, int>,
      likeEventIdToReactionId: null == likeEventIdToReactionId
          ? _value._likeEventIdToReactionId
          : likeEventIdToReactionId // ignore: cast_nullable_to_non_nullable
              as Map<String, String>,
      repostedEventIds: null == repostedEventIds
          ? _value._repostedEventIds
          : repostedEventIds // ignore: cast_nullable_to_non_nullable
              as Set<String>,
      repostEventIdToRepostId: null == repostEventIdToRepostId
          ? _value._repostEventIdToRepostId
          : repostEventIdToRepostId // ignore: cast_nullable_to_non_nullable
              as Map<String, String>,
      followingPubkeys: null == followingPubkeys
          ? _value._followingPubkeys
          : followingPubkeys // ignore: cast_nullable_to_non_nullable
              as List<String>,
      followerStats: null == followerStats
          ? _value._followerStats
          : followerStats // ignore: cast_nullable_to_non_nullable
              as Map<String, Map<String, int>>,
      currentUserContactListEvent: freezed == currentUserContactListEvent
          ? _value.currentUserContactListEvent
          : currentUserContactListEvent // ignore: cast_nullable_to_non_nullable
              as Event?,
      isLoading: null == isLoading
          ? _value.isLoading
          : isLoading // ignore: cast_nullable_to_non_nullable
              as bool,
      isInitialized: null == isInitialized
          ? _value.isInitialized
          : isInitialized // ignore: cast_nullable_to_non_nullable
              as bool,
      error: freezed == error
          ? _value.error
          : error // ignore: cast_nullable_to_non_nullable
              as String?,
      likesInProgress: null == likesInProgress
          ? _value._likesInProgress
          : likesInProgress // ignore: cast_nullable_to_non_nullable
              as Set<String>,
      repostsInProgress: null == repostsInProgress
          ? _value._repostsInProgress
          : repostsInProgress // ignore: cast_nullable_to_non_nullable
              as Set<String>,
      followsInProgress: null == followsInProgress
          ? _value._followsInProgress
          : followsInProgress // ignore: cast_nullable_to_non_nullable
              as Set<String>,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$SocialStateImpl extends _SocialState {
  const _$SocialStateImpl(
      {final Set<String> likedEventIds = const {},
      final Map<String, int> likeCounts = const {},
      final Map<String, String> likeEventIdToReactionId = const {},
      final Set<String> repostedEventIds = const {},
      final Map<String, String> repostEventIdToRepostId = const {},
      final List<String> followingPubkeys = const [],
      final Map<String, Map<String, int>> followerStats = const {},
      this.currentUserContactListEvent,
      this.isLoading = false,
      this.isInitialized = false,
      this.error,
      final Set<String> likesInProgress = const {},
      final Set<String> repostsInProgress = const {},
      final Set<String> followsInProgress = const {}})
      : _likedEventIds = likedEventIds,
        _likeCounts = likeCounts,
        _likeEventIdToReactionId = likeEventIdToReactionId,
        _repostedEventIds = repostedEventIds,
        _repostEventIdToRepostId = repostEventIdToRepostId,
        _followingPubkeys = followingPubkeys,
        _followerStats = followerStats,
        _likesInProgress = likesInProgress,
        _repostsInProgress = repostsInProgress,
        _followsInProgress = followsInProgress,
        super._();

  factory _$SocialStateImpl.fromJson(Map<String, dynamic> json) =>
      _$$SocialStateImplFromJson(json);

// Like-related state
  final Set<String> _likedEventIds;
// Like-related state
  @override
  @JsonKey()
  Set<String> get likedEventIds {
    if (_likedEventIds is EqualUnmodifiableSetView) return _likedEventIds;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableSetView(_likedEventIds);
  }

  final Map<String, int> _likeCounts;
  @override
  @JsonKey()
  Map<String, int> get likeCounts {
    if (_likeCounts is EqualUnmodifiableMapView) return _likeCounts;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_likeCounts);
  }

  final Map<String, String> _likeEventIdToReactionId;
  @override
  @JsonKey()
  Map<String, String> get likeEventIdToReactionId {
    if (_likeEventIdToReactionId is EqualUnmodifiableMapView)
      return _likeEventIdToReactionId;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_likeEventIdToReactionId);
  }

// Repost-related state
  final Set<String> _repostedEventIds;
// Repost-related state
  @override
  @JsonKey()
  Set<String> get repostedEventIds {
    if (_repostedEventIds is EqualUnmodifiableSetView) return _repostedEventIds;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableSetView(_repostedEventIds);
  }

  final Map<String, String> _repostEventIdToRepostId;
  @override
  @JsonKey()
  Map<String, String> get repostEventIdToRepostId {
    if (_repostEventIdToRepostId is EqualUnmodifiableMapView)
      return _repostEventIdToRepostId;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_repostEventIdToRepostId);
  }

// Follow-related state
  final List<String> _followingPubkeys;
// Follow-related state
  @override
  @JsonKey()
  List<String> get followingPubkeys {
    if (_followingPubkeys is EqualUnmodifiableListView)
      return _followingPubkeys;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_followingPubkeys);
  }

  final Map<String, Map<String, int>> _followerStats;
  @override
  @JsonKey()
  Map<String, Map<String, int>> get followerStats {
    if (_followerStats is EqualUnmodifiableMapView) return _followerStats;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_followerStats);
  }

  @override
  final Event? currentUserContactListEvent;
// Loading and error state
  @override
  @JsonKey()
  final bool isLoading;
  @override
  @JsonKey()
  final bool isInitialized;
  @override
  final String? error;
// Operation-specific loading states
  final Set<String> _likesInProgress;
// Operation-specific loading states
  @override
  @JsonKey()
  Set<String> get likesInProgress {
    if (_likesInProgress is EqualUnmodifiableSetView) return _likesInProgress;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableSetView(_likesInProgress);
  }

  final Set<String> _repostsInProgress;
  @override
  @JsonKey()
  Set<String> get repostsInProgress {
    if (_repostsInProgress is EqualUnmodifiableSetView)
      return _repostsInProgress;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableSetView(_repostsInProgress);
  }

  final Set<String> _followsInProgress;
  @override
  @JsonKey()
  Set<String> get followsInProgress {
    if (_followsInProgress is EqualUnmodifiableSetView)
      return _followsInProgress;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableSetView(_followsInProgress);
  }

  @override
  String toString() {
    return 'SocialState(likedEventIds: $likedEventIds, likeCounts: $likeCounts, likeEventIdToReactionId: $likeEventIdToReactionId, repostedEventIds: $repostedEventIds, repostEventIdToRepostId: $repostEventIdToRepostId, followingPubkeys: $followingPubkeys, followerStats: $followerStats, currentUserContactListEvent: $currentUserContactListEvent, isLoading: $isLoading, isInitialized: $isInitialized, error: $error, likesInProgress: $likesInProgress, repostsInProgress: $repostsInProgress, followsInProgress: $followsInProgress)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$SocialStateImpl &&
            const DeepCollectionEquality()
                .equals(other._likedEventIds, _likedEventIds) &&
            const DeepCollectionEquality()
                .equals(other._likeCounts, _likeCounts) &&
            const DeepCollectionEquality().equals(
                other._likeEventIdToReactionId, _likeEventIdToReactionId) &&
            const DeepCollectionEquality()
                .equals(other._repostedEventIds, _repostedEventIds) &&
            const DeepCollectionEquality().equals(
                other._repostEventIdToRepostId, _repostEventIdToRepostId) &&
            const DeepCollectionEquality()
                .equals(other._followingPubkeys, _followingPubkeys) &&
            const DeepCollectionEquality()
                .equals(other._followerStats, _followerStats) &&
            (identical(other.currentUserContactListEvent,
                    currentUserContactListEvent) ||
                other.currentUserContactListEvent ==
                    currentUserContactListEvent) &&
            (identical(other.isLoading, isLoading) ||
                other.isLoading == isLoading) &&
            (identical(other.isInitialized, isInitialized) ||
                other.isInitialized == isInitialized) &&
            (identical(other.error, error) || other.error == error) &&
            const DeepCollectionEquality()
                .equals(other._likesInProgress, _likesInProgress) &&
            const DeepCollectionEquality()
                .equals(other._repostsInProgress, _repostsInProgress) &&
            const DeepCollectionEquality()
                .equals(other._followsInProgress, _followsInProgress));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      const DeepCollectionEquality().hash(_likedEventIds),
      const DeepCollectionEquality().hash(_likeCounts),
      const DeepCollectionEquality().hash(_likeEventIdToReactionId),
      const DeepCollectionEquality().hash(_repostedEventIds),
      const DeepCollectionEquality().hash(_repostEventIdToRepostId),
      const DeepCollectionEquality().hash(_followingPubkeys),
      const DeepCollectionEquality().hash(_followerStats),
      currentUserContactListEvent,
      isLoading,
      isInitialized,
      error,
      const DeepCollectionEquality().hash(_likesInProgress),
      const DeepCollectionEquality().hash(_repostsInProgress),
      const DeepCollectionEquality().hash(_followsInProgress));

  /// Create a copy of SocialState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$SocialStateImplCopyWith<_$SocialStateImpl> get copyWith =>
      __$$SocialStateImplCopyWithImpl<_$SocialStateImpl>(this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$SocialStateImplToJson(
      this,
    );
  }
}

abstract class _SocialState extends SocialState {
  const factory _SocialState(
      {final Set<String> likedEventIds,
      final Map<String, int> likeCounts,
      final Map<String, String> likeEventIdToReactionId,
      final Set<String> repostedEventIds,
      final Map<String, String> repostEventIdToRepostId,
      final List<String> followingPubkeys,
      final Map<String, Map<String, int>> followerStats,
      final Event? currentUserContactListEvent,
      final bool isLoading,
      final bool isInitialized,
      final String? error,
      final Set<String> likesInProgress,
      final Set<String> repostsInProgress,
      final Set<String> followsInProgress}) = _$SocialStateImpl;
  const _SocialState._() : super._();

  factory _SocialState.fromJson(Map<String, dynamic> json) =
      _$SocialStateImpl.fromJson;

// Like-related state
  @override
  Set<String> get likedEventIds;
  @override
  Map<String, int> get likeCounts;
  @override
  Map<String, String> get likeEventIdToReactionId; // Repost-related state
  @override
  Set<String> get repostedEventIds;
  @override
  Map<String, String> get repostEventIdToRepostId; // Follow-related state
  @override
  List<String> get followingPubkeys;
  @override
  Map<String, Map<String, int>> get followerStats;
  @override
  Event? get currentUserContactListEvent; // Loading and error state
  @override
  bool get isLoading;
  @override
  bool get isInitialized;
  @override
  String? get error; // Operation-specific loading states
  @override
  Set<String> get likesInProgress;
  @override
  Set<String> get repostsInProgress;
  @override
  Set<String> get followsInProgress;

  /// Create a copy of SocialState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$SocialStateImplCopyWith<_$SocialStateImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
