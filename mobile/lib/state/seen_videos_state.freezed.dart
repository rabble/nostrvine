// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'seen_videos_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$SeenVideosState {

 Set<String> get seenVideoIds; bool get isInitialized;
/// Create a copy of SeenVideosState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$SeenVideosStateCopyWith<SeenVideosState> get copyWith => _$SeenVideosStateCopyWithImpl<SeenVideosState>(this as SeenVideosState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is SeenVideosState&&const DeepCollectionEquality().equals(other.seenVideoIds, seenVideoIds)&&(identical(other.isInitialized, isInitialized) || other.isInitialized == isInitialized));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(seenVideoIds),isInitialized);

@override
String toString() {
  return 'SeenVideosState(seenVideoIds: $seenVideoIds, isInitialized: $isInitialized)';
}


}

/// @nodoc
abstract mixin class $SeenVideosStateCopyWith<$Res>  {
  factory $SeenVideosStateCopyWith(SeenVideosState value, $Res Function(SeenVideosState) _then) = _$SeenVideosStateCopyWithImpl;
@useResult
$Res call({
 Set<String> seenVideoIds, bool isInitialized
});




}
/// @nodoc
class _$SeenVideosStateCopyWithImpl<$Res>
    implements $SeenVideosStateCopyWith<$Res> {
  _$SeenVideosStateCopyWithImpl(this._self, this._then);

  final SeenVideosState _self;
  final $Res Function(SeenVideosState) _then;

/// Create a copy of SeenVideosState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? seenVideoIds = null,Object? isInitialized = null,}) {
  return _then(_self.copyWith(
seenVideoIds: null == seenVideoIds ? _self.seenVideoIds : seenVideoIds // ignore: cast_nullable_to_non_nullable
as Set<String>,isInitialized: null == isInitialized ? _self.isInitialized : isInitialized // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}

}


/// Adds pattern-matching-related methods to [SeenVideosState].
extension SeenVideosStatePatterns on SeenVideosState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _SeenVideosState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _SeenVideosState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _SeenVideosState value)  $default,){
final _that = this;
switch (_that) {
case _SeenVideosState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _SeenVideosState value)?  $default,){
final _that = this;
switch (_that) {
case _SeenVideosState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( Set<String> seenVideoIds,  bool isInitialized)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _SeenVideosState() when $default != null:
return $default(_that.seenVideoIds,_that.isInitialized);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( Set<String> seenVideoIds,  bool isInitialized)  $default,) {final _that = this;
switch (_that) {
case _SeenVideosState():
return $default(_that.seenVideoIds,_that.isInitialized);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( Set<String> seenVideoIds,  bool isInitialized)?  $default,) {final _that = this;
switch (_that) {
case _SeenVideosState() when $default != null:
return $default(_that.seenVideoIds,_that.isInitialized);case _:
  return null;

}
}

}

/// @nodoc


class _SeenVideosState implements SeenVideosState {
  const _SeenVideosState({final  Set<String> seenVideoIds = const {}, this.isInitialized = false}): _seenVideoIds = seenVideoIds;
  

 final  Set<String> _seenVideoIds;
@override@JsonKey() Set<String> get seenVideoIds {
  if (_seenVideoIds is EqualUnmodifiableSetView) return _seenVideoIds;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableSetView(_seenVideoIds);
}

@override@JsonKey() final  bool isInitialized;

/// Create a copy of SeenVideosState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$SeenVideosStateCopyWith<_SeenVideosState> get copyWith => __$SeenVideosStateCopyWithImpl<_SeenVideosState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _SeenVideosState&&const DeepCollectionEquality().equals(other._seenVideoIds, _seenVideoIds)&&(identical(other.isInitialized, isInitialized) || other.isInitialized == isInitialized));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_seenVideoIds),isInitialized);

@override
String toString() {
  return 'SeenVideosState(seenVideoIds: $seenVideoIds, isInitialized: $isInitialized)';
}


}

/// @nodoc
abstract mixin class _$SeenVideosStateCopyWith<$Res> implements $SeenVideosStateCopyWith<$Res> {
  factory _$SeenVideosStateCopyWith(_SeenVideosState value, $Res Function(_SeenVideosState) _then) = __$SeenVideosStateCopyWithImpl;
@override @useResult
$Res call({
 Set<String> seenVideoIds, bool isInitialized
});




}
/// @nodoc
class __$SeenVideosStateCopyWithImpl<$Res>
    implements _$SeenVideosStateCopyWith<$Res> {
  __$SeenVideosStateCopyWithImpl(this._self, this._then);

  final _SeenVideosState _self;
  final $Res Function(_SeenVideosState) _then;

/// Create a copy of SeenVideosState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? seenVideoIds = null,Object? isInitialized = null,}) {
  return _then(_SeenVideosState(
seenVideoIds: null == seenVideoIds ? _self._seenVideoIds : seenVideoIds // ignore: cast_nullable_to_non_nullable
as Set<String>,isInitialized: null == isInitialized ? _self.isInitialized : isInitialized // ignore: cast_nullable_to_non_nullable
as bool,
  ));
}


}

// dart format on
