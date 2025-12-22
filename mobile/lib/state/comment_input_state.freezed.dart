// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'comment_input_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$CommentInputState {

/// Text content of the main comment input
 String get mainInputText;/// Map of comment ID -> reply text for each active reply
 Map<String, String> get replyInputTexts;/// ID of the comment currently being replied to (shows reply input)
 String? get activeReplyCommentId;/// Whether the main comment is currently being posted
 bool get isMainPosting;/// Set of comment IDs with replies currently being posted
 Set<String> get postingReplyIds;/// Last error that occurred, cleared on next action
 String? get error;
/// Create a copy of CommentInputState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$CommentInputStateCopyWith<CommentInputState> get copyWith => _$CommentInputStateCopyWithImpl<CommentInputState>(this as CommentInputState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is CommentInputState&&(identical(other.mainInputText, mainInputText) || other.mainInputText == mainInputText)&&const DeepCollectionEquality().equals(other.replyInputTexts, replyInputTexts)&&(identical(other.activeReplyCommentId, activeReplyCommentId) || other.activeReplyCommentId == activeReplyCommentId)&&(identical(other.isMainPosting, isMainPosting) || other.isMainPosting == isMainPosting)&&const DeepCollectionEquality().equals(other.postingReplyIds, postingReplyIds)&&(identical(other.error, error) || other.error == error));
}


@override
int get hashCode => Object.hash(runtimeType,mainInputText,const DeepCollectionEquality().hash(replyInputTexts),activeReplyCommentId,isMainPosting,const DeepCollectionEquality().hash(postingReplyIds),error);

@override
String toString() {
  return 'CommentInputState(mainInputText: $mainInputText, replyInputTexts: $replyInputTexts, activeReplyCommentId: $activeReplyCommentId, isMainPosting: $isMainPosting, postingReplyIds: $postingReplyIds, error: $error)';
}


}

/// @nodoc
abstract mixin class $CommentInputStateCopyWith<$Res>  {
  factory $CommentInputStateCopyWith(CommentInputState value, $Res Function(CommentInputState) _then) = _$CommentInputStateCopyWithImpl;
@useResult
$Res call({
 String mainInputText, Map<String, String> replyInputTexts, String? activeReplyCommentId, bool isMainPosting, Set<String> postingReplyIds, String? error
});




}
/// @nodoc
class _$CommentInputStateCopyWithImpl<$Res>
    implements $CommentInputStateCopyWith<$Res> {
  _$CommentInputStateCopyWithImpl(this._self, this._then);

  final CommentInputState _self;
  final $Res Function(CommentInputState) _then;

/// Create a copy of CommentInputState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? mainInputText = null,Object? replyInputTexts = null,Object? activeReplyCommentId = freezed,Object? isMainPosting = null,Object? postingReplyIds = null,Object? error = freezed,}) {
  return _then(_self.copyWith(
mainInputText: null == mainInputText ? _self.mainInputText : mainInputText // ignore: cast_nullable_to_non_nullable
as String,replyInputTexts: null == replyInputTexts ? _self.replyInputTexts : replyInputTexts // ignore: cast_nullable_to_non_nullable
as Map<String, String>,activeReplyCommentId: freezed == activeReplyCommentId ? _self.activeReplyCommentId : activeReplyCommentId // ignore: cast_nullable_to_non_nullable
as String?,isMainPosting: null == isMainPosting ? _self.isMainPosting : isMainPosting // ignore: cast_nullable_to_non_nullable
as bool,postingReplyIds: null == postingReplyIds ? _self.postingReplyIds : postingReplyIds // ignore: cast_nullable_to_non_nullable
as Set<String>,error: freezed == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}

}


/// Adds pattern-matching-related methods to [CommentInputState].
extension CommentInputStatePatterns on CommentInputState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _CommentInputState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _CommentInputState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _CommentInputState value)  $default,){
final _that = this;
switch (_that) {
case _CommentInputState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _CommentInputState value)?  $default,){
final _that = this;
switch (_that) {
case _CommentInputState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( String mainInputText,  Map<String, String> replyInputTexts,  String? activeReplyCommentId,  bool isMainPosting,  Set<String> postingReplyIds,  String? error)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _CommentInputState() when $default != null:
return $default(_that.mainInputText,_that.replyInputTexts,_that.activeReplyCommentId,_that.isMainPosting,_that.postingReplyIds,_that.error);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( String mainInputText,  Map<String, String> replyInputTexts,  String? activeReplyCommentId,  bool isMainPosting,  Set<String> postingReplyIds,  String? error)  $default,) {final _that = this;
switch (_that) {
case _CommentInputState():
return $default(_that.mainInputText,_that.replyInputTexts,_that.activeReplyCommentId,_that.isMainPosting,_that.postingReplyIds,_that.error);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( String mainInputText,  Map<String, String> replyInputTexts,  String? activeReplyCommentId,  bool isMainPosting,  Set<String> postingReplyIds,  String? error)?  $default,) {final _that = this;
switch (_that) {
case _CommentInputState() when $default != null:
return $default(_that.mainInputText,_that.replyInputTexts,_that.activeReplyCommentId,_that.isMainPosting,_that.postingReplyIds,_that.error);case _:
  return null;

}
}

}

/// @nodoc


class _CommentInputState extends CommentInputState {
  const _CommentInputState({this.mainInputText = '', final  Map<String, String> replyInputTexts = const {}, this.activeReplyCommentId, this.isMainPosting = false, final  Set<String> postingReplyIds = const {}, this.error}): _replyInputTexts = replyInputTexts,_postingReplyIds = postingReplyIds,super._();
  

/// Text content of the main comment input
@override@JsonKey() final  String mainInputText;
/// Map of comment ID -> reply text for each active reply
 final  Map<String, String> _replyInputTexts;
/// Map of comment ID -> reply text for each active reply
@override@JsonKey() Map<String, String> get replyInputTexts {
  if (_replyInputTexts is EqualUnmodifiableMapView) return _replyInputTexts;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableMapView(_replyInputTexts);
}

/// ID of the comment currently being replied to (shows reply input)
@override final  String? activeReplyCommentId;
/// Whether the main comment is currently being posted
@override@JsonKey() final  bool isMainPosting;
/// Set of comment IDs with replies currently being posted
 final  Set<String> _postingReplyIds;
/// Set of comment IDs with replies currently being posted
@override@JsonKey() Set<String> get postingReplyIds {
  if (_postingReplyIds is EqualUnmodifiableSetView) return _postingReplyIds;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableSetView(_postingReplyIds);
}

/// Last error that occurred, cleared on next action
@override final  String? error;

/// Create a copy of CommentInputState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$CommentInputStateCopyWith<_CommentInputState> get copyWith => __$CommentInputStateCopyWithImpl<_CommentInputState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _CommentInputState&&(identical(other.mainInputText, mainInputText) || other.mainInputText == mainInputText)&&const DeepCollectionEquality().equals(other._replyInputTexts, _replyInputTexts)&&(identical(other.activeReplyCommentId, activeReplyCommentId) || other.activeReplyCommentId == activeReplyCommentId)&&(identical(other.isMainPosting, isMainPosting) || other.isMainPosting == isMainPosting)&&const DeepCollectionEquality().equals(other._postingReplyIds, _postingReplyIds)&&(identical(other.error, error) || other.error == error));
}


@override
int get hashCode => Object.hash(runtimeType,mainInputText,const DeepCollectionEquality().hash(_replyInputTexts),activeReplyCommentId,isMainPosting,const DeepCollectionEquality().hash(_postingReplyIds),error);

@override
String toString() {
  return 'CommentInputState(mainInputText: $mainInputText, replyInputTexts: $replyInputTexts, activeReplyCommentId: $activeReplyCommentId, isMainPosting: $isMainPosting, postingReplyIds: $postingReplyIds, error: $error)';
}


}

/// @nodoc
abstract mixin class _$CommentInputStateCopyWith<$Res> implements $CommentInputStateCopyWith<$Res> {
  factory _$CommentInputStateCopyWith(_CommentInputState value, $Res Function(_CommentInputState) _then) = __$CommentInputStateCopyWithImpl;
@override @useResult
$Res call({
 String mainInputText, Map<String, String> replyInputTexts, String? activeReplyCommentId, bool isMainPosting, Set<String> postingReplyIds, String? error
});




}
/// @nodoc
class __$CommentInputStateCopyWithImpl<$Res>
    implements _$CommentInputStateCopyWith<$Res> {
  __$CommentInputStateCopyWithImpl(this._self, this._then);

  final _CommentInputState _self;
  final $Res Function(_CommentInputState) _then;

/// Create a copy of CommentInputState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? mainInputText = null,Object? replyInputTexts = null,Object? activeReplyCommentId = freezed,Object? isMainPosting = null,Object? postingReplyIds = null,Object? error = freezed,}) {
  return _then(_CommentInputState(
mainInputText: null == mainInputText ? _self.mainInputText : mainInputText // ignore: cast_nullable_to_non_nullable
as String,replyInputTexts: null == replyInputTexts ? _self._replyInputTexts : replyInputTexts // ignore: cast_nullable_to_non_nullable
as Map<String, String>,activeReplyCommentId: freezed == activeReplyCommentId ? _self.activeReplyCommentId : activeReplyCommentId // ignore: cast_nullable_to_non_nullable
as String?,isMainPosting: null == isMainPosting ? _self.isMainPosting : isMainPosting // ignore: cast_nullable_to_non_nullable
as bool,postingReplyIds: null == postingReplyIds ? _self._postingReplyIds : postingReplyIds // ignore: cast_nullable_to_non_nullable
as Set<String>,error: freezed == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as String?,
  ));
}


}

// dart format on
