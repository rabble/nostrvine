// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'user_profile_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

UserProfileState _$UserProfileStateFromJson(Map<String, dynamic> json) {
  return _UserProfileState.fromJson(json);
}

/// @nodoc
mixin _$UserProfileState {
// Profile cache - pubkey -> profile
  Map<String, UserProfile> get profileCache =>
      throw _privateConstructorUsedError; // Pending profile requests
  Set<String> get pendingRequests =>
      throw _privateConstructorUsedError; // Missing profiles to avoid spam
  Set<String> get knownMissingProfiles => throw _privateConstructorUsedError;
  Map<String, DateTime> get missingProfileRetryAfter =>
      throw _privateConstructorUsedError; // Batch fetching state
  Set<String> get pendingBatchPubkeys =>
      throw _privateConstructorUsedError; // Loading and error state
  bool get isLoading => throw _privateConstructorUsedError;
  bool get isInitialized => throw _privateConstructorUsedError;
  String? get error => throw _privateConstructorUsedError; // Stats
  int get totalProfilesCached => throw _privateConstructorUsedError;
  int get totalProfilesRequested => throw _privateConstructorUsedError;

  /// Serializes this UserProfileState to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of UserProfileState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $UserProfileStateCopyWith<UserProfileState> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $UserProfileStateCopyWith<$Res> {
  factory $UserProfileStateCopyWith(
          UserProfileState value, $Res Function(UserProfileState) then) =
      _$UserProfileStateCopyWithImpl<$Res, UserProfileState>;
  @useResult
  $Res call(
      {Map<String, UserProfile> profileCache,
      Set<String> pendingRequests,
      Set<String> knownMissingProfiles,
      Map<String, DateTime> missingProfileRetryAfter,
      Set<String> pendingBatchPubkeys,
      bool isLoading,
      bool isInitialized,
      String? error,
      int totalProfilesCached,
      int totalProfilesRequested});
}

/// @nodoc
class _$UserProfileStateCopyWithImpl<$Res, $Val extends UserProfileState>
    implements $UserProfileStateCopyWith<$Res> {
  _$UserProfileStateCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of UserProfileState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? profileCache = null,
    Object? pendingRequests = null,
    Object? knownMissingProfiles = null,
    Object? missingProfileRetryAfter = null,
    Object? pendingBatchPubkeys = null,
    Object? isLoading = null,
    Object? isInitialized = null,
    Object? error = freezed,
    Object? totalProfilesCached = null,
    Object? totalProfilesRequested = null,
  }) {
    return _then(_value.copyWith(
      profileCache: null == profileCache
          ? _value.profileCache
          : profileCache // ignore: cast_nullable_to_non_nullable
              as Map<String, UserProfile>,
      pendingRequests: null == pendingRequests
          ? _value.pendingRequests
          : pendingRequests // ignore: cast_nullable_to_non_nullable
              as Set<String>,
      knownMissingProfiles: null == knownMissingProfiles
          ? _value.knownMissingProfiles
          : knownMissingProfiles // ignore: cast_nullable_to_non_nullable
              as Set<String>,
      missingProfileRetryAfter: null == missingProfileRetryAfter
          ? _value.missingProfileRetryAfter
          : missingProfileRetryAfter // ignore: cast_nullable_to_non_nullable
              as Map<String, DateTime>,
      pendingBatchPubkeys: null == pendingBatchPubkeys
          ? _value.pendingBatchPubkeys
          : pendingBatchPubkeys // ignore: cast_nullable_to_non_nullable
              as Set<String>,
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
      totalProfilesCached: null == totalProfilesCached
          ? _value.totalProfilesCached
          : totalProfilesCached // ignore: cast_nullable_to_non_nullable
              as int,
      totalProfilesRequested: null == totalProfilesRequested
          ? _value.totalProfilesRequested
          : totalProfilesRequested // ignore: cast_nullable_to_non_nullable
              as int,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$UserProfileStateImplCopyWith<$Res>
    implements $UserProfileStateCopyWith<$Res> {
  factory _$$UserProfileStateImplCopyWith(_$UserProfileStateImpl value,
          $Res Function(_$UserProfileStateImpl) then) =
      __$$UserProfileStateImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {Map<String, UserProfile> profileCache,
      Set<String> pendingRequests,
      Set<String> knownMissingProfiles,
      Map<String, DateTime> missingProfileRetryAfter,
      Set<String> pendingBatchPubkeys,
      bool isLoading,
      bool isInitialized,
      String? error,
      int totalProfilesCached,
      int totalProfilesRequested});
}

/// @nodoc
class __$$UserProfileStateImplCopyWithImpl<$Res>
    extends _$UserProfileStateCopyWithImpl<$Res, _$UserProfileStateImpl>
    implements _$$UserProfileStateImplCopyWith<$Res> {
  __$$UserProfileStateImplCopyWithImpl(_$UserProfileStateImpl _value,
      $Res Function(_$UserProfileStateImpl) _then)
      : super(_value, _then);

  /// Create a copy of UserProfileState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? profileCache = null,
    Object? pendingRequests = null,
    Object? knownMissingProfiles = null,
    Object? missingProfileRetryAfter = null,
    Object? pendingBatchPubkeys = null,
    Object? isLoading = null,
    Object? isInitialized = null,
    Object? error = freezed,
    Object? totalProfilesCached = null,
    Object? totalProfilesRequested = null,
  }) {
    return _then(_$UserProfileStateImpl(
      profileCache: null == profileCache
          ? _value._profileCache
          : profileCache // ignore: cast_nullable_to_non_nullable
              as Map<String, UserProfile>,
      pendingRequests: null == pendingRequests
          ? _value._pendingRequests
          : pendingRequests // ignore: cast_nullable_to_non_nullable
              as Set<String>,
      knownMissingProfiles: null == knownMissingProfiles
          ? _value._knownMissingProfiles
          : knownMissingProfiles // ignore: cast_nullable_to_non_nullable
              as Set<String>,
      missingProfileRetryAfter: null == missingProfileRetryAfter
          ? _value._missingProfileRetryAfter
          : missingProfileRetryAfter // ignore: cast_nullable_to_non_nullable
              as Map<String, DateTime>,
      pendingBatchPubkeys: null == pendingBatchPubkeys
          ? _value._pendingBatchPubkeys
          : pendingBatchPubkeys // ignore: cast_nullable_to_non_nullable
              as Set<String>,
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
      totalProfilesCached: null == totalProfilesCached
          ? _value.totalProfilesCached
          : totalProfilesCached // ignore: cast_nullable_to_non_nullable
              as int,
      totalProfilesRequested: null == totalProfilesRequested
          ? _value.totalProfilesRequested
          : totalProfilesRequested // ignore: cast_nullable_to_non_nullable
              as int,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$UserProfileStateImpl extends _UserProfileState {
  const _$UserProfileStateImpl(
      {final Map<String, UserProfile> profileCache = const {},
      final Set<String> pendingRequests = const {},
      final Set<String> knownMissingProfiles = const {},
      final Map<String, DateTime> missingProfileRetryAfter = const {},
      final Set<String> pendingBatchPubkeys = const {},
      this.isLoading = false,
      this.isInitialized = false,
      this.error,
      this.totalProfilesCached = 0,
      this.totalProfilesRequested = 0})
      : _profileCache = profileCache,
        _pendingRequests = pendingRequests,
        _knownMissingProfiles = knownMissingProfiles,
        _missingProfileRetryAfter = missingProfileRetryAfter,
        _pendingBatchPubkeys = pendingBatchPubkeys,
        super._();

  factory _$UserProfileStateImpl.fromJson(Map<String, dynamic> json) =>
      _$$UserProfileStateImplFromJson(json);

// Profile cache - pubkey -> profile
  final Map<String, UserProfile> _profileCache;
// Profile cache - pubkey -> profile
  @override
  @JsonKey()
  Map<String, UserProfile> get profileCache {
    if (_profileCache is EqualUnmodifiableMapView) return _profileCache;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_profileCache);
  }

// Pending profile requests
  final Set<String> _pendingRequests;
// Pending profile requests
  @override
  @JsonKey()
  Set<String> get pendingRequests {
    if (_pendingRequests is EqualUnmodifiableSetView) return _pendingRequests;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableSetView(_pendingRequests);
  }

// Missing profiles to avoid spam
  final Set<String> _knownMissingProfiles;
// Missing profiles to avoid spam
  @override
  @JsonKey()
  Set<String> get knownMissingProfiles {
    if (_knownMissingProfiles is EqualUnmodifiableSetView)
      return _knownMissingProfiles;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableSetView(_knownMissingProfiles);
  }

  final Map<String, DateTime> _missingProfileRetryAfter;
  @override
  @JsonKey()
  Map<String, DateTime> get missingProfileRetryAfter {
    if (_missingProfileRetryAfter is EqualUnmodifiableMapView)
      return _missingProfileRetryAfter;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_missingProfileRetryAfter);
  }

// Batch fetching state
  final Set<String> _pendingBatchPubkeys;
// Batch fetching state
  @override
  @JsonKey()
  Set<String> get pendingBatchPubkeys {
    if (_pendingBatchPubkeys is EqualUnmodifiableSetView)
      return _pendingBatchPubkeys;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableSetView(_pendingBatchPubkeys);
  }

// Loading and error state
  @override
  @JsonKey()
  final bool isLoading;
  @override
  @JsonKey()
  final bool isInitialized;
  @override
  final String? error;
// Stats
  @override
  @JsonKey()
  final int totalProfilesCached;
  @override
  @JsonKey()
  final int totalProfilesRequested;

  @override
  String toString() {
    return 'UserProfileState(profileCache: $profileCache, pendingRequests: $pendingRequests, knownMissingProfiles: $knownMissingProfiles, missingProfileRetryAfter: $missingProfileRetryAfter, pendingBatchPubkeys: $pendingBatchPubkeys, isLoading: $isLoading, isInitialized: $isInitialized, error: $error, totalProfilesCached: $totalProfilesCached, totalProfilesRequested: $totalProfilesRequested)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$UserProfileStateImpl &&
            const DeepCollectionEquality()
                .equals(other._profileCache, _profileCache) &&
            const DeepCollectionEquality()
                .equals(other._pendingRequests, _pendingRequests) &&
            const DeepCollectionEquality()
                .equals(other._knownMissingProfiles, _knownMissingProfiles) &&
            const DeepCollectionEquality().equals(
                other._missingProfileRetryAfter, _missingProfileRetryAfter) &&
            const DeepCollectionEquality()
                .equals(other._pendingBatchPubkeys, _pendingBatchPubkeys) &&
            (identical(other.isLoading, isLoading) ||
                other.isLoading == isLoading) &&
            (identical(other.isInitialized, isInitialized) ||
                other.isInitialized == isInitialized) &&
            (identical(other.error, error) || other.error == error) &&
            (identical(other.totalProfilesCached, totalProfilesCached) ||
                other.totalProfilesCached == totalProfilesCached) &&
            (identical(other.totalProfilesRequested, totalProfilesRequested) ||
                other.totalProfilesRequested == totalProfilesRequested));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(
      runtimeType,
      const DeepCollectionEquality().hash(_profileCache),
      const DeepCollectionEquality().hash(_pendingRequests),
      const DeepCollectionEquality().hash(_knownMissingProfiles),
      const DeepCollectionEquality().hash(_missingProfileRetryAfter),
      const DeepCollectionEquality().hash(_pendingBatchPubkeys),
      isLoading,
      isInitialized,
      error,
      totalProfilesCached,
      totalProfilesRequested);

  /// Create a copy of UserProfileState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$UserProfileStateImplCopyWith<_$UserProfileStateImpl> get copyWith =>
      __$$UserProfileStateImplCopyWithImpl<_$UserProfileStateImpl>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$UserProfileStateImplToJson(
      this,
    );
  }
}

abstract class _UserProfileState extends UserProfileState {
  const factory _UserProfileState(
      {final Map<String, UserProfile> profileCache,
      final Set<String> pendingRequests,
      final Set<String> knownMissingProfiles,
      final Map<String, DateTime> missingProfileRetryAfter,
      final Set<String> pendingBatchPubkeys,
      final bool isLoading,
      final bool isInitialized,
      final String? error,
      final int totalProfilesCached,
      final int totalProfilesRequested}) = _$UserProfileStateImpl;
  const _UserProfileState._() : super._();

  factory _UserProfileState.fromJson(Map<String, dynamic> json) =
      _$UserProfileStateImpl.fromJson;

// Profile cache - pubkey -> profile
  @override
  Map<String, UserProfile> get profileCache; // Pending profile requests
  @override
  Set<String> get pendingRequests; // Missing profiles to avoid spam
  @override
  Set<String> get knownMissingProfiles;
  @override
  Map<String, DateTime> get missingProfileRetryAfter; // Batch fetching state
  @override
  Set<String> get pendingBatchPubkeys; // Loading and error state
  @override
  bool get isLoading;
  @override
  bool get isInitialized;
  @override
  String? get error; // Stats
  @override
  int get totalProfilesCached;
  @override
  int get totalProfilesRequested;

  /// Create a copy of UserProfileState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$UserProfileStateImplCopyWith<_$UserProfileStateImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
