// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'user_profile_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;

/// @nodoc
mixin _$UserProfileState {

// Pending profile requests
 Set<String> get pendingRequests;// Missing profiles to avoid spam
 Set<String> get knownMissingProfiles; Map<String, DateTime> get missingProfileRetryAfter;// Batch fetching state
 Set<String> get pendingBatchPubkeys;// Loading and error state
 bool get isLoading; bool get isInitialized; String? get error;// Stats
 int get totalProfilesRequested;
/// Create a copy of UserProfileState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$UserProfileStateCopyWith<UserProfileState> get copyWith => _$UserProfileStateCopyWithImpl<UserProfileState>(this as UserProfileState, _$identity);

  /// Serializes this UserProfileState to a JSON map.
  Map<String, dynamic> toJson();


@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is UserProfileState&&const DeepCollectionEquality().equals(other.pendingRequests, pendingRequests)&&const DeepCollectionEquality().equals(other.knownMissingProfiles, knownMissingProfiles)&&const DeepCollectionEquality().equals(other.missingProfileRetryAfter, missingProfileRetryAfter)&&const DeepCollectionEquality().equals(other.pendingBatchPubkeys, pendingBatchPubkeys)&&(identical(other.isLoading, isLoading) || other.isLoading == isLoading)&&(identical(other.isInitialized, isInitialized) || other.isInitialized == isInitialized)&&(identical(other.error, error) || other.error == error)&&(identical(other.totalProfilesRequested, totalProfilesRequested) || other.totalProfilesRequested == totalProfilesRequested));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(pendingRequests),const DeepCollectionEquality().hash(knownMissingProfiles),const DeepCollectionEquality().hash(missingProfileRetryAfter),const DeepCollectionEquality().hash(pendingBatchPubkeys),isLoading,isInitialized,error,totalProfilesRequested);

@override
String toString() {
  return 'UserProfileState(pendingRequests: $pendingRequests, knownMissingProfiles: $knownMissingProfiles, missingProfileRetryAfter: $missingProfileRetryAfter, pendingBatchPubkeys: $pendingBatchPubkeys, isLoading: $isLoading, isInitialized: $isInitialized, error: $error, totalProfilesRequested: $totalProfilesRequested)';
}


}

/// @nodoc
abstract mixin class $UserProfileStateCopyWith<$Res>  {
  factory $UserProfileStateCopyWith(UserProfileState value, $Res Function(UserProfileState) _then) = _$UserProfileStateCopyWithImpl;
@useResult
$Res call({
 Set<String> pendingRequests, Set<String> knownMissingProfiles, Map<String, DateTime> missingProfileRetryAfter, Set<String> pendingBatchPubkeys, bool isLoading, bool isInitialized, String? error, int totalProfilesRequested
});




}
/// @nodoc
class _$UserProfileStateCopyWithImpl<$Res>
    implements $UserProfileStateCopyWith<$Res> {
  _$UserProfileStateCopyWithImpl(this._self, this._then);

  final UserProfileState _self;
  final $Res Function(UserProfileState) _then;

/// Create a copy of UserProfileState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? pendingRequests = null,Object? knownMissingProfiles = null,Object? missingProfileRetryAfter = null,Object? pendingBatchPubkeys = null,Object? isLoading = null,Object? isInitialized = null,Object? error = freezed,Object? totalProfilesRequested = null,}) {
  return _then(_self.copyWith(
pendingRequests: null == pendingRequests ? _self.pendingRequests : pendingRequests // ignore: cast_nullable_to_non_nullable
as Set<String>,knownMissingProfiles: null == knownMissingProfiles ? _self.knownMissingProfiles : knownMissingProfiles // ignore: cast_nullable_to_non_nullable
as Set<String>,missingProfileRetryAfter: null == missingProfileRetryAfter ? _self.missingProfileRetryAfter : missingProfileRetryAfter // ignore: cast_nullable_to_non_nullable
as Map<String, DateTime>,pendingBatchPubkeys: null == pendingBatchPubkeys ? _self.pendingBatchPubkeys : pendingBatchPubkeys // ignore: cast_nullable_to_non_nullable
as Set<String>,isLoading: null == isLoading ? _self.isLoading : isLoading // ignore: cast_nullable_to_non_nullable
as bool,isInitialized: null == isInitialized ? _self.isInitialized : isInitialized // ignore: cast_nullable_to_non_nullable
as bool,error: freezed == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as String?,totalProfilesRequested: null == totalProfilesRequested ? _self.totalProfilesRequested : totalProfilesRequested // ignore: cast_nullable_to_non_nullable
as int,
  ));
}

}


/// Adds pattern-matching-related methods to [UserProfileState].
extension UserProfileStatePatterns on UserProfileState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _UserProfileState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _UserProfileState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _UserProfileState value)  $default,){
final _that = this;
switch (_that) {
case _UserProfileState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _UserProfileState value)?  $default,){
final _that = this;
switch (_that) {
case _UserProfileState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( Set<String> pendingRequests,  Set<String> knownMissingProfiles,  Map<String, DateTime> missingProfileRetryAfter,  Set<String> pendingBatchPubkeys,  bool isLoading,  bool isInitialized,  String? error,  int totalProfilesRequested)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _UserProfileState() when $default != null:
return $default(_that.pendingRequests,_that.knownMissingProfiles,_that.missingProfileRetryAfter,_that.pendingBatchPubkeys,_that.isLoading,_that.isInitialized,_that.error,_that.totalProfilesRequested);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( Set<String> pendingRequests,  Set<String> knownMissingProfiles,  Map<String, DateTime> missingProfileRetryAfter,  Set<String> pendingBatchPubkeys,  bool isLoading,  bool isInitialized,  String? error,  int totalProfilesRequested)  $default,) {final _that = this;
switch (_that) {
case _UserProfileState():
return $default(_that.pendingRequests,_that.knownMissingProfiles,_that.missingProfileRetryAfter,_that.pendingBatchPubkeys,_that.isLoading,_that.isInitialized,_that.error,_that.totalProfilesRequested);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( Set<String> pendingRequests,  Set<String> knownMissingProfiles,  Map<String, DateTime> missingProfileRetryAfter,  Set<String> pendingBatchPubkeys,  bool isLoading,  bool isInitialized,  String? error,  int totalProfilesRequested)?  $default,) {final _that = this;
switch (_that) {
case _UserProfileState() when $default != null:
return $default(_that.pendingRequests,_that.knownMissingProfiles,_that.missingProfileRetryAfter,_that.pendingBatchPubkeys,_that.isLoading,_that.isInitialized,_that.error,_that.totalProfilesRequested);case _:
  return null;

}
}

}

/// @nodoc
@JsonSerializable()

class _UserProfileState extends UserProfileState {
  const _UserProfileState({final  Set<String> pendingRequests = const {}, final  Set<String> knownMissingProfiles = const {}, final  Map<String, DateTime> missingProfileRetryAfter = const {}, final  Set<String> pendingBatchPubkeys = const {}, this.isLoading = false, this.isInitialized = false, this.error, this.totalProfilesRequested = 0}): _pendingRequests = pendingRequests,_knownMissingProfiles = knownMissingProfiles,_missingProfileRetryAfter = missingProfileRetryAfter,_pendingBatchPubkeys = pendingBatchPubkeys,super._();
  factory _UserProfileState.fromJson(Map<String, dynamic> json) => _$UserProfileStateFromJson(json);

// Pending profile requests
 final  Set<String> _pendingRequests;
// Pending profile requests
@override@JsonKey() Set<String> get pendingRequests {
  if (_pendingRequests is EqualUnmodifiableSetView) return _pendingRequests;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableSetView(_pendingRequests);
}

// Missing profiles to avoid spam
 final  Set<String> _knownMissingProfiles;
// Missing profiles to avoid spam
@override@JsonKey() Set<String> get knownMissingProfiles {
  if (_knownMissingProfiles is EqualUnmodifiableSetView) return _knownMissingProfiles;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableSetView(_knownMissingProfiles);
}

 final  Map<String, DateTime> _missingProfileRetryAfter;
@override@JsonKey() Map<String, DateTime> get missingProfileRetryAfter {
  if (_missingProfileRetryAfter is EqualUnmodifiableMapView) return _missingProfileRetryAfter;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_missingProfileRetryAfter);
}

// Batch fetching state
 final  Set<String> _pendingBatchPubkeys;
// Batch fetching state
@override@JsonKey() Set<String> get pendingBatchPubkeys {
  if (_pendingBatchPubkeys is EqualUnmodifiableSetView) return _pendingBatchPubkeys;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableSetView(_pendingBatchPubkeys);
}

// Loading and error state
@override@JsonKey() final  bool isLoading;
@override@JsonKey() final  bool isInitialized;
@override final  String? error;
// Stats
@override@JsonKey() final  int totalProfilesRequested;

/// Create a copy of UserProfileState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$UserProfileStateCopyWith<_UserProfileState> get copyWith => __$UserProfileStateCopyWithImpl<_UserProfileState>(this, _$identity);

@override
Map<String, dynamic> toJson() {
  return _$UserProfileStateToJson(this, );
}

@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _UserProfileState&&const DeepCollectionEquality().equals(other._pendingRequests, _pendingRequests)&&const DeepCollectionEquality().equals(other._knownMissingProfiles, _knownMissingProfiles)&&const DeepCollectionEquality().equals(other._missingProfileRetryAfter, _missingProfileRetryAfter)&&const DeepCollectionEquality().equals(other._pendingBatchPubkeys, _pendingBatchPubkeys)&&(identical(other.isLoading, isLoading) || other.isLoading == isLoading)&&(identical(other.isInitialized, isInitialized) || other.isInitialized == isInitialized)&&(identical(other.error, error) || other.error == error)&&(identical(other.totalProfilesRequested, totalProfilesRequested) || other.totalProfilesRequested == totalProfilesRequested));
}

@JsonKey(includeFromJson: false, includeToJson: false)
@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_pendingRequests),const DeepCollectionEquality().hash(_knownMissingProfiles),const DeepCollectionEquality().hash(_missingProfileRetryAfter),const DeepCollectionEquality().hash(_pendingBatchPubkeys),isLoading,isInitialized,error,totalProfilesRequested);

@override
String toString() {
  return 'UserProfileState(pendingRequests: $pendingRequests, knownMissingProfiles: $knownMissingProfiles, missingProfileRetryAfter: $missingProfileRetryAfter, pendingBatchPubkeys: $pendingBatchPubkeys, isLoading: $isLoading, isInitialized: $isInitialized, error: $error, totalProfilesRequested: $totalProfilesRequested)';
}


}

/// @nodoc
abstract mixin class _$UserProfileStateCopyWith<$Res> implements $UserProfileStateCopyWith<$Res> {
  factory _$UserProfileStateCopyWith(_UserProfileState value, $Res Function(_UserProfileState) _then) = __$UserProfileStateCopyWithImpl;
@override @useResult
$Res call({
 Set<String> pendingRequests, Set<String> knownMissingProfiles, Map<String, DateTime> missingProfileRetryAfter, Set<String> pendingBatchPubkeys, bool isLoading, bool isInitialized, String? error, int totalProfilesRequested
});




}
/// @nodoc
class __$UserProfileStateCopyWithImpl<$Res>
    implements _$UserProfileStateCopyWith<$Res> {
  __$UserProfileStateCopyWithImpl(this._self, this._then);

  final _UserProfileState _self;
  final $Res Function(_UserProfileState) _then;

/// Create a copy of UserProfileState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? pendingRequests = null,Object? knownMissingProfiles = null,Object? missingProfileRetryAfter = null,Object? pendingBatchPubkeys = null,Object? isLoading = null,Object? isInitialized = null,Object? error = freezed,Object? totalProfilesRequested = null,}) {
  return _then(_UserProfileState(
pendingRequests: null == pendingRequests ? _self._pendingRequests : pendingRequests // ignore: cast_nullable_to_non_nullable
as Set<String>,knownMissingProfiles: null == knownMissingProfiles ? _self._knownMissingProfiles : knownMissingProfiles // ignore: cast_nullable_to_non_nullable
as Set<String>,missingProfileRetryAfter: null == missingProfileRetryAfter ? _self._missingProfileRetryAfter : missingProfileRetryAfter // ignore: cast_nullable_to_non_nullable
as Map<String, DateTime>,pendingBatchPubkeys: null == pendingBatchPubkeys ? _self._pendingBatchPubkeys : pendingBatchPubkeys // ignore: cast_nullable_to_non_nullable
as Set<String>,isLoading: null == isLoading ? _self.isLoading : isLoading // ignore: cast_nullable_to_non_nullable
as bool,isInitialized: null == isInitialized ? _self.isInitialized : isInitialized // ignore: cast_nullable_to_non_nullable
as bool,error: freezed == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as String?,totalProfilesRequested: null == totalProfilesRequested ? _self.totalProfilesRequested : totalProfilesRequested // ignore: cast_nullable_to_non_nullable
as int,
  ));
}


}

// dart format on
