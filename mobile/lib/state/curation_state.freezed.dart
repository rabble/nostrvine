// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'curation_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

/// @nodoc
mixin _$CurationState {
  /// Editor's picks videos (classic vines)
  List<VideoEvent> get editorsPicks => throw _privateConstructorUsedError;

  /// Trending videos (from analytics API)
  List<VideoEvent> get trending => throw _privateConstructorUsedError;

  /// Featured high-quality videos
  List<VideoEvent> get featured => throw _privateConstructorUsedError;

  /// All available curation sets
  List<CurationSet> get curationSets => throw _privateConstructorUsedError;

  /// Whether curation data is loading
  bool get isLoading => throw _privateConstructorUsedError;

  /// Whether trending was fetched from API
  bool get trendingFromApi => throw _privateConstructorUsedError;

  /// Last refresh timestamp
  DateTime? get lastRefreshed => throw _privateConstructorUsedError;

  /// Error message if any
  String? get error => throw _privateConstructorUsedError;

  /// Create a copy of CurationState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $CurationStateCopyWith<CurationState> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $CurationStateCopyWith<$Res> {
  factory $CurationStateCopyWith(
          CurationState value, $Res Function(CurationState) then) =
      _$CurationStateCopyWithImpl<$Res, CurationState>;
  @useResult
  $Res call(
      {List<VideoEvent> editorsPicks,
      List<VideoEvent> trending,
      List<VideoEvent> featured,
      List<CurationSet> curationSets,
      bool isLoading,
      bool trendingFromApi,
      DateTime? lastRefreshed,
      String? error});
}

/// @nodoc
class _$CurationStateCopyWithImpl<$Res, $Val extends CurationState>
    implements $CurationStateCopyWith<$Res> {
  _$CurationStateCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of CurationState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? editorsPicks = null,
    Object? trending = null,
    Object? featured = null,
    Object? curationSets = null,
    Object? isLoading = null,
    Object? trendingFromApi = null,
    Object? lastRefreshed = freezed,
    Object? error = freezed,
  }) {
    return _then(_value.copyWith(
      editorsPicks: null == editorsPicks
          ? _value.editorsPicks
          : editorsPicks // ignore: cast_nullable_to_non_nullable
              as List<VideoEvent>,
      trending: null == trending
          ? _value.trending
          : trending // ignore: cast_nullable_to_non_nullable
              as List<VideoEvent>,
      featured: null == featured
          ? _value.featured
          : featured // ignore: cast_nullable_to_non_nullable
              as List<VideoEvent>,
      curationSets: null == curationSets
          ? _value.curationSets
          : curationSets // ignore: cast_nullable_to_non_nullable
              as List<CurationSet>,
      isLoading: null == isLoading
          ? _value.isLoading
          : isLoading // ignore: cast_nullable_to_non_nullable
              as bool,
      trendingFromApi: null == trendingFromApi
          ? _value.trendingFromApi
          : trendingFromApi // ignore: cast_nullable_to_non_nullable
              as bool,
      lastRefreshed: freezed == lastRefreshed
          ? _value.lastRefreshed
          : lastRefreshed // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      error: freezed == error
          ? _value.error
          : error // ignore: cast_nullable_to_non_nullable
              as String?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$CurationStateImplCopyWith<$Res>
    implements $CurationStateCopyWith<$Res> {
  factory _$$CurationStateImplCopyWith(
          _$CurationStateImpl value, $Res Function(_$CurationStateImpl) then) =
      __$$CurationStateImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {List<VideoEvent> editorsPicks,
      List<VideoEvent> trending,
      List<VideoEvent> featured,
      List<CurationSet> curationSets,
      bool isLoading,
      bool trendingFromApi,
      DateTime? lastRefreshed,
      String? error});
}

/// @nodoc
class __$$CurationStateImplCopyWithImpl<$Res>
    extends _$CurationStateCopyWithImpl<$Res, _$CurationStateImpl>
    implements _$$CurationStateImplCopyWith<$Res> {
  __$$CurationStateImplCopyWithImpl(
      _$CurationStateImpl _value, $Res Function(_$CurationStateImpl) _then)
      : super(_value, _then);

  /// Create a copy of CurationState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? editorsPicks = null,
    Object? trending = null,
    Object? featured = null,
    Object? curationSets = null,
    Object? isLoading = null,
    Object? trendingFromApi = null,
    Object? lastRefreshed = freezed,
    Object? error = freezed,
  }) {
    return _then(_$CurationStateImpl(
      editorsPicks: null == editorsPicks
          ? _value._editorsPicks
          : editorsPicks // ignore: cast_nullable_to_non_nullable
              as List<VideoEvent>,
      trending: null == trending
          ? _value._trending
          : trending // ignore: cast_nullable_to_non_nullable
              as List<VideoEvent>,
      featured: null == featured
          ? _value._featured
          : featured // ignore: cast_nullable_to_non_nullable
              as List<VideoEvent>,
      curationSets: null == curationSets
          ? _value._curationSets
          : curationSets // ignore: cast_nullable_to_non_nullable
              as List<CurationSet>,
      isLoading: null == isLoading
          ? _value.isLoading
          : isLoading // ignore: cast_nullable_to_non_nullable
              as bool,
      trendingFromApi: null == trendingFromApi
          ? _value.trendingFromApi
          : trendingFromApi // ignore: cast_nullable_to_non_nullable
              as bool,
      lastRefreshed: freezed == lastRefreshed
          ? _value.lastRefreshed
          : lastRefreshed // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      error: freezed == error
          ? _value.error
          : error // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc

class _$CurationStateImpl extends _CurationState {
  const _$CurationStateImpl(
      {required final List<VideoEvent> editorsPicks,
      required final List<VideoEvent> trending,
      required final List<VideoEvent> featured,
      final List<CurationSet> curationSets = const [],
      required this.isLoading,
      this.trendingFromApi = false,
      this.lastRefreshed,
      this.error})
      : _editorsPicks = editorsPicks,
        _trending = trending,
        _featured = featured,
        _curationSets = curationSets,
        super._();

  /// Editor's picks videos (classic vines)
  final List<VideoEvent> _editorsPicks;

  /// Editor's picks videos (classic vines)
  @override
  List<VideoEvent> get editorsPicks {
    if (_editorsPicks is EqualUnmodifiableListView) return _editorsPicks;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_editorsPicks);
  }

  /// Trending videos (from analytics API)
  final List<VideoEvent> _trending;

  /// Trending videos (from analytics API)
  @override
  List<VideoEvent> get trending {
    if (_trending is EqualUnmodifiableListView) return _trending;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_trending);
  }

  /// Featured high-quality videos
  final List<VideoEvent> _featured;

  /// Featured high-quality videos
  @override
  List<VideoEvent> get featured {
    if (_featured is EqualUnmodifiableListView) return _featured;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_featured);
  }

  /// All available curation sets
  final List<CurationSet> _curationSets;

  /// All available curation sets
  @override
  @JsonKey()
  List<CurationSet> get curationSets {
    if (_curationSets is EqualUnmodifiableListView) return _curationSets;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableListView(_curationSets);
  }

  /// Whether curation data is loading
  @override
  final bool isLoading;

  /// Whether trending was fetched from API
  @override
  @JsonKey()
  final bool trendingFromApi;

  /// Last refresh timestamp
  @override
  final DateTime? lastRefreshed;

  /// Error message if any
  @override
  final String? error;

  @override
  String toString() {
    return 'CurationState(editorsPicks: $editorsPicks, trending: $trending, featured: $featured, curationSets: $curationSets, isLoading: $isLoading, trendingFromApi: $trendingFromApi, lastRefreshed: $lastRefreshed, error: $error)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$CurationStateImpl &&
            const DeepCollectionEquality()
                .equals(other._editorsPicks, _editorsPicks) &&
            const DeepCollectionEquality().equals(other._trending, _trending) &&
            const DeepCollectionEquality().equals(other._featured, _featured) &&
            const DeepCollectionEquality()
                .equals(other._curationSets, _curationSets) &&
            (identical(other.isLoading, isLoading) ||
                other.isLoading == isLoading) &&
            (identical(other.trendingFromApi, trendingFromApi) ||
                other.trendingFromApi == trendingFromApi) &&
            (identical(other.lastRefreshed, lastRefreshed) ||
                other.lastRefreshed == lastRefreshed) &&
            (identical(other.error, error) || other.error == error));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      const DeepCollectionEquality().hash(_editorsPicks),
      const DeepCollectionEquality().hash(_trending),
      const DeepCollectionEquality().hash(_featured),
      const DeepCollectionEquality().hash(_curationSets),
      isLoading,
      trendingFromApi,
      lastRefreshed,
      error);

  /// Create a copy of CurationState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$CurationStateImplCopyWith<_$CurationStateImpl> get copyWith =>
      __$$CurationStateImplCopyWithImpl<_$CurationStateImpl>(this, _$identity);
}

abstract class _CurationState extends CurationState {
  const factory _CurationState(
      {required final List<VideoEvent> editorsPicks,
      required final List<VideoEvent> trending,
      required final List<VideoEvent> featured,
      final List<CurationSet> curationSets,
      required final bool isLoading,
      final bool trendingFromApi,
      final DateTime? lastRefreshed,
      final String? error}) = _$CurationStateImpl;
  const _CurationState._() : super._();

  /// Editor's picks videos (classic vines)
  @override
  List<VideoEvent> get editorsPicks;

  /// Trending videos (from analytics API)
  @override
  List<VideoEvent> get trending;

  /// Featured high-quality videos
  @override
  List<VideoEvent> get featured;

  /// All available curation sets
  @override
  List<CurationSet> get curationSets;

  /// Whether curation data is loading
  @override
  bool get isLoading;

  /// Whether trending was fetched from API
  @override
  bool get trendingFromApi;

  /// Last refresh timestamp
  @override
  DateTime? get lastRefreshed;

  /// Error message if any
  @override
  String? get error;

  /// Create a copy of CurationState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$CurationStateImplCopyWith<_$CurationStateImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
