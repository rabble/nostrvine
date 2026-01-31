// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'curation_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$CurationState {

/// Editor's picks videos (classic vines)
 List<VideoEvent> get editorsPicks;/// Trending videos (popular now)
 List<VideoEvent> get trending;/// Whether curation data is loading
 bool get isLoading;/// All available curation sets
 List<CurationSet> get curationSets;/// Last refresh timestamp
 DateTime? get lastRefreshed;/// Error message if any
 String? get error;
/// Create a copy of CurationState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CurationStateCopyWith<CurationState> get copyWith => _$CurationStateCopyWithImpl<CurationState>(this as CurationState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CurationState&&const DeepCollectionEquality().equals(other.editorsPicks, editorsPicks)&&const DeepCollectionEquality().equals(other.trending, trending)&&(identical(other.isLoading, isLoading) || other.isLoading == isLoading)&&const DeepCollectionEquality().equals(other.curationSets, curationSets)&&(identical(other.lastRefreshed, lastRefreshed) || other.lastRefreshed == lastRefreshed)&&(identical(other.error, error) || other.error == error));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(editorsPicks),const DeepCollectionEquality().hash(trending),isLoading,const DeepCollectionEquality().hash(curationSets),lastRefreshed,error);

@override
String toString() {
  return 'CurationState(editorsPicks: $editorsPicks, trending: $trending, isLoading: $isLoading, curationSets: $curationSets, lastRefreshed: $lastRefreshed, error: $error)';
}


}

/// @nodoc
abstract mixin class $CurationStateCopyWith<$Res>  {
  factory $CurationStateCopyWith(CurationState value, $Res Function(CurationState) _then) = _$CurationStateCopyWithImpl;
@useResult
$Res call({
 List<VideoEvent> editorsPicks, List<VideoEvent> trending, bool isLoading, List<CurationSet> curationSets, DateTime? lastRefreshed, String? error
});




}
/// @nodoc
class _$CurationStateCopyWithImpl<$Res>
    implements $CurationStateCopyWith<$Res> {
  _$CurationStateCopyWithImpl(this._self, this._then);

  final CurationState _self;
  final $Res Function(CurationState) _then;

/// Create a copy of CurationState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? editorsPicks = null,Object? trending = null,Object? isLoading = null,Object? curationSets = null,Object? lastRefreshed = freezed,Object? error = freezed,}) {
  return _then(_self.copyWith(
editorsPicks: null == editorsPicks ? _self.editorsPicks : editorsPicks // ignore: cast_nullable_to_non_nullable
as List<VideoEvent>,trending: null == trending ? _self.trending : trending // ignore: cast_nullable_to_non_nullable
as List<VideoEvent>,isLoading: null == isLoading ? _self.isLoading : isLoading // ignore: cast_nullable_to_non_nullable
as bool,curationSets: null == curationSets ? _self.curationSets : curationSets // ignore: cast_nullable_to_non_nullable
as List<CurationSet>,lastRefreshed: freezed == lastRefreshed ? _self.lastRefreshed : lastRefreshed // ignore: cast_nullable_to_non_nullable
as DateTime?,error: freezed == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [CurationState].
extension CurationStatePatterns on CurationState {
/// A variant of `map` that fallback to returning `orElse`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _CurationState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _CurationState() when $default != null:
return $default(_that);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// Callbacks receives the raw object, upcasted.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case final Subclass2 value:
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _CurationState value)  $default,){
final _that = this;
switch (_that) {
case _CurationState():
return $default(_that);}
}
/// A variant of `map` that fallback to returning `null`.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case final Subclass value:
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _CurationState value)?  $default,){
final _that = this;
switch (_that) {
case _CurationState() when $default != null:
return $default(_that);case _:
  return null;

}
}
/// A variant of `when` that fallback to an `orElse` callback.
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return orElse();
/// }
/// ```

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<VideoEvent> editorsPicks,  List<VideoEvent> trending,  bool isLoading,  List<CurationSet> curationSets,  DateTime? lastRefreshed,  String? error)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _CurationState() when $default != null:
return $default(_that.editorsPicks,_that.trending,_that.isLoading,_that.curationSets,_that.lastRefreshed,_that.error);case _:
  return orElse();

}
}
/// A `switch`-like method, using callbacks.
///
/// As opposed to `map`, this offers destructuring.
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case Subclass2(:final field2):
///     return ...;
/// }
/// ```

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<VideoEvent> editorsPicks,  List<VideoEvent> trending,  bool isLoading,  List<CurationSet> curationSets,  DateTime? lastRefreshed,  String? error)  $default,) {final _that = this;
switch (_that) {
case _CurationState():
return $default(_that.editorsPicks,_that.trending,_that.isLoading,_that.curationSets,_that.lastRefreshed,_that.error);}
}
/// A variant of `when` that fallback to returning `null`
///
/// It is equivalent to doing:
/// ```dart
/// switch (sealedClass) {
///   case Subclass(:final field):
///     return ...;
///   case _:
///     return null;
/// }
/// ```

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<VideoEvent> editorsPicks,  List<VideoEvent> trending,  bool isLoading,  List<CurationSet> curationSets,  DateTime? lastRefreshed,  String? error)?  $default,) {final _that = this;
switch (_that) {
case _CurationState() when $default != null:
return $default(_that.editorsPicks,_that.trending,_that.isLoading,_that.curationSets,_that.lastRefreshed,_that.error);case _:
  return null;

}
}

}

/// @nodoc


class _CurationState extends CurationState {
  const _CurationState({required final  List<VideoEvent> editorsPicks, final  List<VideoEvent> trending = const [], required this.isLoading, final  List<CurationSet> curationSets = const [], this.lastRefreshed, this.error}): _editorsPicks = editorsPicks,_trending = trending,_curationSets = curationSets,super._();
  

/// Editor's picks videos (classic vines)
 final  List<VideoEvent> _editorsPicks;
/// Editor's picks videos (classic vines)
@override List<VideoEvent> get editorsPicks {
  if (_editorsPicks is EqualUnmodifiableListView) return _editorsPicks;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_editorsPicks);
}

/// Trending videos (popular now)
 final  List<VideoEvent> _trending;
/// Trending videos (popular now)
@override@JsonKey() List<VideoEvent> get trending {
  if (_trending is EqualUnmodifiableListView) return _trending;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_trending);
}

/// Whether curation data is loading
@override final  bool isLoading;
/// All available curation sets
 final  List<CurationSet> _curationSets;
/// All available curation sets
@override@JsonKey() List<CurationSet> get curationSets {
  if (_curationSets is EqualUnmodifiableListView) return _curationSets;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_curationSets);
}

/// Last refresh timestamp
@override final  DateTime? lastRefreshed;
/// Error message if any
@override final  String? error;

/// Create a copy of CurationState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CurationStateCopyWith<_CurationState> get copyWith => __$CurationStateCopyWithImpl<_CurationState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _CurationState&&const DeepCollectionEquality().equals(other._editorsPicks, _editorsPicks)&&const DeepCollectionEquality().equals(other._trending, _trending)&&(identical(other.isLoading, isLoading) || other.isLoading == isLoading)&&const DeepCollectionEquality().equals(other._curationSets, _curationSets)&&(identical(other.lastRefreshed, lastRefreshed) || other.lastRefreshed == lastRefreshed)&&(identical(other.error, error) || other.error == error));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_editorsPicks),const DeepCollectionEquality().hash(_trending),isLoading,const DeepCollectionEquality().hash(_curationSets),lastRefreshed,error);

@override
String toString() {
  return 'CurationState(editorsPicks: $editorsPicks, trending: $trending, isLoading: $isLoading, curationSets: $curationSets, lastRefreshed: $lastRefreshed, error: $error)';
}


}

/// @nodoc
abstract mixin class _$CurationStateCopyWith<$Res> implements $CurationStateCopyWith<$Res> {
  factory _$CurationStateCopyWith(_CurationState value, $Res Function(_CurationState) _then) = __$CurationStateCopyWithImpl;
@override @useResult
$Res call({
 List<VideoEvent> editorsPicks, List<VideoEvent> trending, bool isLoading, List<CurationSet> curationSets, DateTime? lastRefreshed, String? error
});




}
/// @nodoc
class __$CurationStateCopyWithImpl<$Res>
    implements _$CurationStateCopyWith<$Res> {
  __$CurationStateCopyWithImpl(this._self, this._then);

  final _CurationState _self;
  final $Res Function(_CurationState) _then;

/// Create a copy of CurationState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? editorsPicks = null,Object? trending = null,Object? isLoading = null,Object? curationSets = null,Object? lastRefreshed = freezed,Object? error = freezed,}) {
  return _then(_CurationState(
editorsPicks: null == editorsPicks ? _self._editorsPicks : editorsPicks // ignore: cast_nullable_to_non_nullable
as List<VideoEvent>,trending: null == trending ? _self._trending : trending // ignore: cast_nullable_to_non_nullable
as List<VideoEvent>,isLoading: null == isLoading ? _self.isLoading : isLoading // ignore: cast_nullable_to_non_nullable
as bool,curationSets: null == curationSets ? _self._curationSets : curationSets // ignore: cast_nullable_to_non_nullable
as List<CurationSet>,lastRefreshed: freezed == lastRefreshed ? _self.lastRefreshed : lastRefreshed // ignore: cast_nullable_to_non_nullable
as DateTime?,error: freezed == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
