// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'likes_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$LikesState {

/// Set of event IDs that the user has liked
 Set<String> get likedEventIds;/// Map from target event ID to the reaction event ID
/// Required for publishing Kind 5 deletion events when unliking
 Map<String, String> get eventIdToReactionId;/// Map from event ID to like count (public likes from all users)
 Map<String, int> get likeCounts;/// Whether the state has been initialized from local storage/relays
 bool get isInitialized;/// Whether initial sync is in progress
 bool get isSyncing;/// Set of event IDs with like operations currently in progress
/// Prevents duplicate operations on the same event
 Set<String> get operationsInProgress;/// Last error that occurred, if any
 String? get error;
/// Create a copy of LikesState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$LikesStateCopyWith<LikesState> get copyWith => _$LikesStateCopyWithImpl<LikesState>(this as LikesState, _$identity);

  /// Serializes this LikesState to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is LikesState&&const DeepCollectionEquality().equals(other.likedEventIds, likedEventIds)&&const DeepCollectionEquality().equals(other.eventIdToReactionId, eventIdToReactionId)&&const DeepCollectionEquality().equals(other.likeCounts, likeCounts)&&(identical(other.isInitialized, isInitialized) || other.isInitialized == isInitialized)&&(identical(other.isSyncing, isSyncing) || other.isSyncing == isSyncing)&&const DeepCollectionEquality().equals(other.operationsInProgress, operationsInProgress)&&(identical(other.error, error) || other.error == error));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(likedEventIds),const DeepCollectionEquality().hash(eventIdToReactionId),const DeepCollectionEquality().hash(likeCounts),isInitialized,isSyncing,const DeepCollectionEquality().hash(operationsInProgress),error);

@override
String toString() {
  return 'LikesState(likedEventIds: $likedEventIds, eventIdToReactionId: $eventIdToReactionId, likeCounts: $likeCounts, isInitialized: $isInitialized, isSyncing: $isSyncing, operationsInProgress: $operationsInProgress, error: $error)';
}


}

/// @nodoc
abstract mixin class $LikesStateCopyWith<$Res>  {
  factory $LikesStateCopyWith(LikesState value, $Res Function(LikesState) _then) = _$LikesStateCopyWithImpl;
@useResult
$Res call({
 Set<String> likedEventIds, Map<String, String> eventIdToReactionId, Map<String, int> likeCounts, bool isInitialized, bool isSyncing, Set<String> operationsInProgress, String? error
});




}
/// @nodoc
class _$LikesStateCopyWithImpl<$Res>
    implements $LikesStateCopyWith<$Res> {
  _$LikesStateCopyWithImpl(this._self, this._then);

  final LikesState _self;
  final $Res Function(LikesState) _then;

/// Create a copy of LikesState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? likedEventIds = null,Object? eventIdToReactionId = null,Object? likeCounts = null,Object? isInitialized = null,Object? isSyncing = null,Object? operationsInProgress = null,Object? error = freezed,}) {
  return _then(_self.copyWith(
likedEventIds: null == likedEventIds ? _self.likedEventIds : likedEventIds // ignore: cast_nullable_to_non_nullable
as Set<String>,eventIdToReactionId: null == eventIdToReactionId ? _self.eventIdToReactionId : eventIdToReactionId // ignore: cast_nullable_to_non_nullable
as Map<String, String>,likeCounts: null == likeCounts ? _self.likeCounts : likeCounts // ignore: cast_nullable_to_non_nullable
as Map<String, int>,isInitialized: null == isInitialized ? _self.isInitialized : isInitialized // ignore: cast_nullable_to_non_nullable
as bool,isSyncing: null == isSyncing ? _self.isSyncing : isSyncing // ignore: cast_nullable_to_non_nullable
as bool,operationsInProgress: null == operationsInProgress ? _self.operationsInProgress : operationsInProgress // ignore: cast_nullable_to_non_nullable
as Set<String>,error: freezed == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [LikesState].
extension LikesStatePatterns on LikesState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _LikesState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _LikesState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _LikesState value)  $default,){
final _that = this;
switch (_that) {
case _LikesState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _LikesState value)?  $default,){
final _that = this;
switch (_that) {
case _LikesState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( Set<String> likedEventIds,  Map<String, String> eventIdToReactionId,  Map<String, int> likeCounts,  bool isInitialized,  bool isSyncing,  Set<String> operationsInProgress,  String? error)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _LikesState() when $default != null:
return $default(_that.likedEventIds,_that.eventIdToReactionId,_that.likeCounts,_that.isInitialized,_that.isSyncing,_that.operationsInProgress,_that.error);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( Set<String> likedEventIds,  Map<String, String> eventIdToReactionId,  Map<String, int> likeCounts,  bool isInitialized,  bool isSyncing,  Set<String> operationsInProgress,  String? error)  $default,) {final _that = this;
switch (_that) {
case _LikesState():
return $default(_that.likedEventIds,_that.eventIdToReactionId,_that.likeCounts,_that.isInitialized,_that.isSyncing,_that.operationsInProgress,_that.error);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( Set<String> likedEventIds,  Map<String, String> eventIdToReactionId,  Map<String, int> likeCounts,  bool isInitialized,  bool isSyncing,  Set<String> operationsInProgress,  String? error)?  $default,) {final _that = this;
switch (_that) {
case _LikesState() when $default != null:
return $default(_that.likedEventIds,_that.eventIdToReactionId,_that.likeCounts,_that.isInitialized,_that.isSyncing,_that.operationsInProgress,_that.error);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _LikesState extends LikesState {
  const _LikesState({final  Set<String> likedEventIds = const {}, final  Map<String, String> eventIdToReactionId = const {}, final  Map<String, int> likeCounts = const {}, this.isInitialized = false, this.isSyncing = false, final  Set<String> operationsInProgress = const {}, this.error}): _likedEventIds = likedEventIds,_eventIdToReactionId = eventIdToReactionId,_likeCounts = likeCounts,_operationsInProgress = operationsInProgress,super._();
  factory _LikesState.fromJson(Map<String, dynamic> json) => _$LikesStateFromJson(json);

/// Set of event IDs that the user has liked
 final  Set<String> _likedEventIds;
/// Set of event IDs that the user has liked
@override@JsonKey() Set<String> get likedEventIds {
  if (_likedEventIds is EqualUnmodifiableSetView) return _likedEventIds;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableSetView(_likedEventIds);
}

/// Map from target event ID to the reaction event ID
/// Required for publishing Kind 5 deletion events when unliking
 final  Map<String, String> _eventIdToReactionId;
/// Map from target event ID to the reaction event ID
/// Required for publishing Kind 5 deletion events when unliking
@override@JsonKey() Map<String, String> get eventIdToReactionId {
  if (_eventIdToReactionId is EqualUnmodifiableMapView) return _eventIdToReactionId;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_eventIdToReactionId);
}

/// Map from event ID to like count (public likes from all users)
 final  Map<String, int> _likeCounts;
/// Map from event ID to like count (public likes from all users)
@override@JsonKey() Map<String, int> get likeCounts {
  if (_likeCounts is EqualUnmodifiableMapView) return _likeCounts;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_likeCounts);
}

/// Whether the state has been initialized from local storage/relays
@override@JsonKey() final  bool isInitialized;
/// Whether initial sync is in progress
@override@JsonKey() final  bool isSyncing;
/// Set of event IDs with like operations currently in progress
/// Prevents duplicate operations on the same event
 final  Set<String> _operationsInProgress;
/// Set of event IDs with like operations currently in progress
/// Prevents duplicate operations on the same event
@override@JsonKey() Set<String> get operationsInProgress {
  if (_operationsInProgress is EqualUnmodifiableSetView) return _operationsInProgress;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableSetView(_operationsInProgress);
}

/// Last error that occurred, if any
@override final  String? error;

/// Create a copy of LikesState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$LikesStateCopyWith<_LikesState> get copyWith => __$LikesStateCopyWithImpl<_LikesState>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$LikesStateToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _LikesState&&const DeepCollectionEquality().equals(other._likedEventIds, _likedEventIds)&&const DeepCollectionEquality().equals(other._eventIdToReactionId, _eventIdToReactionId)&&const DeepCollectionEquality().equals(other._likeCounts, _likeCounts)&&(identical(other.isInitialized, isInitialized) || other.isInitialized == isInitialized)&&(identical(other.isSyncing, isSyncing) || other.isSyncing == isSyncing)&&const DeepCollectionEquality().equals(other._operationsInProgress, _operationsInProgress)&&(identical(other.error, error) || other.error == error));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_likedEventIds),const DeepCollectionEquality().hash(_eventIdToReactionId),const DeepCollectionEquality().hash(_likeCounts),isInitialized,isSyncing,const DeepCollectionEquality().hash(_operationsInProgress),error);

@override
String toString() {
  return 'LikesState(likedEventIds: $likedEventIds, eventIdToReactionId: $eventIdToReactionId, likeCounts: $likeCounts, isInitialized: $isInitialized, isSyncing: $isSyncing, operationsInProgress: $operationsInProgress, error: $error)';
}


}

/// @nodoc
abstract mixin class _$LikesStateCopyWith<$Res> implements $LikesStateCopyWith<$Res> {
  factory _$LikesStateCopyWith(_LikesState value, $Res Function(_LikesState) _then) = __$LikesStateCopyWithImpl;
@override @useResult
$Res call({
 Set<String> likedEventIds, Map<String, String> eventIdToReactionId, Map<String, int> likeCounts, bool isInitialized, bool isSyncing, Set<String> operationsInProgress, String? error
});




}
/// @nodoc
class __$LikesStateCopyWithImpl<$Res>
    implements _$LikesStateCopyWith<$Res> {
  __$LikesStateCopyWithImpl(this._self, this._then);

  final _LikesState _self;
  final $Res Function(_LikesState) _then;

/// Create a copy of LikesState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? likedEventIds = null,Object? eventIdToReactionId = null,Object? likeCounts = null,Object? isInitialized = null,Object? isSyncing = null,Object? operationsInProgress = null,Object? error = freezed,}) {
  return _then(_LikesState(
likedEventIds: null == likedEventIds ? _self._likedEventIds : likedEventIds // ignore: cast_nullable_to_non_nullable
as Set<String>,eventIdToReactionId: null == eventIdToReactionId ? _self._eventIdToReactionId : eventIdToReactionId // ignore: cast_nullable_to_non_nullable
as Map<String, String>,likeCounts: null == likeCounts ? _self._likeCounts : likeCounts // ignore: cast_nullable_to_non_nullable
as Map<String, int>,isInitialized: null == isInitialized ? _self.isInitialized : isInitialized // ignore: cast_nullable_to_non_nullable
as bool,isSyncing: null == isSyncing ? _self.isSyncing : isSyncing // ignore: cast_nullable_to_non_nullable
as bool,operationsInProgress: null == operationsInProgress ? _self._operationsInProgress : operationsInProgress // ignore: cast_nullable_to_non_nullable
as Set<String>,error: freezed == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
