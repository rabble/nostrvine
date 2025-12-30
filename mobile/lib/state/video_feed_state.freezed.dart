// GENERATED CODE - DO NOT MODIFY BY HAND
// coverage:ignore-file
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'video_feed_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

// dart format off
T _$identity<T>(T value) => value;
/// @nodoc
mixin _$VideoFeedState {

/// List of videos in the feed
 List<VideoEvent> get videos;/// Whether more content can be loaded
 bool get hasMoreContent;/// Loading state for pagination
 bool get isLoadingMore;/// Refreshing state for pull-to-refresh
 bool get isRefreshing;/// Whether this is the initial load (videos may still be arriving)
/// When true and videos is empty, show loading indicator instead of empty state
 bool get isInitialLoad;/// Error message if any
 String? get error;/// Timestamp of last update
 DateTime? get lastUpdated;
/// Create a copy of VideoFeedState
/// with the given fields replaced by the non-null parameter values.
@JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
$VideoFeedStateCopyWith<VideoFeedState> get copyWith => _$VideoFeedStateCopyWithImpl<VideoFeedState>(this as VideoFeedState, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is VideoFeedState&&const DeepCollectionEquality().equals(other.videos, videos)&&(identical(other.hasMoreContent, hasMoreContent) || other.hasMoreContent == hasMoreContent)&&(identical(other.isLoadingMore, isLoadingMore) || other.isLoadingMore == isLoadingMore)&&(identical(other.isRefreshing, isRefreshing) || other.isRefreshing == isRefreshing)&&(identical(other.isInitialLoad, isInitialLoad) || other.isInitialLoad == isInitialLoad)&&(identical(other.error, error) || other.error == error)&&(identical(other.lastUpdated, lastUpdated) || other.lastUpdated == lastUpdated));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(videos),hasMoreContent,isLoadingMore,isRefreshing,isInitialLoad,error,lastUpdated);

@override
String toString() {
  return 'VideoFeedState(videos: $videos, hasMoreContent: $hasMoreContent, isLoadingMore: $isLoadingMore, isRefreshing: $isRefreshing, isInitialLoad: $isInitialLoad, error: $error, lastUpdated: $lastUpdated)';
}


}

/// @nodoc
abstract mixin class $VideoFeedStateCopyWith<$Res>  {
  factory $VideoFeedStateCopyWith(VideoFeedState value, $Res Function(VideoFeedState) _then) = _$VideoFeedStateCopyWithImpl;
@useResult
$Res call({
 List<VideoEvent> videos, bool hasMoreContent, bool isLoadingMore, bool isRefreshing, bool isInitialLoad, String? error, DateTime? lastUpdated
});




}
/// @nodoc
class _$VideoFeedStateCopyWithImpl<$Res>
    implements $VideoFeedStateCopyWith<$Res> {
  _$VideoFeedStateCopyWithImpl(this._self, this._then);

  final VideoFeedState _self;
  final $Res Function(VideoFeedState) _then;

/// Create a copy of VideoFeedState
/// with the given fields replaced by the non-null parameter values.
@pragma('vm:prefer-inline') @override $Res call({Object? videos = null,Object? hasMoreContent = null,Object? isLoadingMore = null,Object? isRefreshing = null,Object? isInitialLoad = null,Object? error = freezed,Object? lastUpdated = freezed,}) {
  return _then(_self.copyWith(
videos: null == videos ? _self.videos : videos // ignore: cast_nullable_to_non_nullable
as List<VideoEvent>,hasMoreContent: null == hasMoreContent ? _self.hasMoreContent : hasMoreContent // ignore: cast_nullable_to_non_nullable
as bool,isLoadingMore: null == isLoadingMore ? _self.isLoadingMore : isLoadingMore // ignore: cast_nullable_to_non_nullable
as bool,isRefreshing: null == isRefreshing ? _self.isRefreshing : isRefreshing // ignore: cast_nullable_to_non_nullable
as bool,isInitialLoad: null == isInitialLoad ? _self.isInitialLoad : isInitialLoad // ignore: cast_nullable_to_non_nullable
as bool,error: freezed == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as String?,lastUpdated: freezed == lastUpdated ? _self.lastUpdated : lastUpdated // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}

}


/// Adds pattern-matching-related methods to [VideoFeedState].
extension VideoFeedStatePatterns on VideoFeedState {
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

@optionalTypeArgs TResult maybeMap<TResult extends Object?>(TResult Function( _VideoFeedState value)?  $default,{required TResult orElse(),}){
final _that = this;
switch (_that) {
case _VideoFeedState() when $default != null:
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

@optionalTypeArgs TResult map<TResult extends Object?>(TResult Function( _VideoFeedState value)  $default,){
final _that = this;
switch (_that) {
case _VideoFeedState():
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

@optionalTypeArgs TResult? mapOrNull<TResult extends Object?>(TResult? Function( _VideoFeedState value)?  $default,){
final _that = this;
switch (_that) {
case _VideoFeedState() when $default != null:
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

@optionalTypeArgs TResult maybeWhen<TResult extends Object?>(TResult Function( List<VideoEvent> videos,  bool hasMoreContent,  bool isLoadingMore,  bool isRefreshing,  bool isInitialLoad,  String? error,  DateTime? lastUpdated)?  $default,{required TResult orElse(),}) {final _that = this;
switch (_that) {
case _VideoFeedState() when $default != null:
return $default(_that.videos,_that.hasMoreContent,_that.isLoadingMore,_that.isRefreshing,_that.isInitialLoad,_that.error,_that.lastUpdated);case _:
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

@optionalTypeArgs TResult when<TResult extends Object?>(TResult Function( List<VideoEvent> videos,  bool hasMoreContent,  bool isLoadingMore,  bool isRefreshing,  bool isInitialLoad,  String? error,  DateTime? lastUpdated)  $default,) {final _that = this;
switch (_that) {
case _VideoFeedState():
return $default(_that.videos,_that.hasMoreContent,_that.isLoadingMore,_that.isRefreshing,_that.isInitialLoad,_that.error,_that.lastUpdated);}
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

@optionalTypeArgs TResult? whenOrNull<TResult extends Object?>(TResult? Function( List<VideoEvent> videos,  bool hasMoreContent,  bool isLoadingMore,  bool isRefreshing,  bool isInitialLoad,  String? error,  DateTime? lastUpdated)?  $default,) {final _that = this;
switch (_that) {
case _VideoFeedState() when $default != null:
return $default(_that.videos,_that.hasMoreContent,_that.isLoadingMore,_that.isRefreshing,_that.isInitialLoad,_that.error,_that.lastUpdated);case _:
  return null;

}
}

}

/// @nodoc


class _VideoFeedState extends VideoFeedState {
  const _VideoFeedState({required final  List<VideoEvent> videos, required this.hasMoreContent, this.isLoadingMore = false, this.isRefreshing = false, this.isInitialLoad = false, this.error, this.lastUpdated}): _videos = videos,super._();
  

/// List of videos in the feed
 final  List<VideoEvent> _videos;
/// List of videos in the feed
@override List<VideoEvent> get videos {
  if (_videos is EqualUnmodifiableListView) return _videos;
  // ignore: implicit_dynamic_type
  return EqualUnmodifiableListView(_videos);
}

/// Whether more content can be loaded
@override final  bool hasMoreContent;
/// Loading state for pagination
@override@JsonKey() final  bool isLoadingMore;
/// Refreshing state for pull-to-refresh
@override@JsonKey() final  bool isRefreshing;
/// Whether this is the initial load (videos may still be arriving)
/// When true and videos is empty, show loading indicator instead of empty state
@override@JsonKey() final  bool isInitialLoad;
/// Error message if any
@override final  String? error;
/// Timestamp of last update
@override final  DateTime? lastUpdated;

/// Create a copy of VideoFeedState
/// with the given fields replaced by the non-null parameter values.
@override @JsonKey(includeFromJson: false, includeToJson: false)
@pragma('vm:prefer-inline')
_$VideoFeedStateCopyWith<_VideoFeedState> get copyWith => __$VideoFeedStateCopyWithImpl<_VideoFeedState>(this, _$identity);



@override
bool operator ==(Object other) {
  return identical(this, other) || (other.runtimeType == runtimeType&&other is _VideoFeedState&&const DeepCollectionEquality().equals(other._videos, _videos)&&(identical(other.hasMoreContent, hasMoreContent) || other.hasMoreContent == hasMoreContent)&&(identical(other.isLoadingMore, isLoadingMore) || other.isLoadingMore == isLoadingMore)&&(identical(other.isRefreshing, isRefreshing) || other.isRefreshing == isRefreshing)&&(identical(other.isInitialLoad, isInitialLoad) || other.isInitialLoad == isInitialLoad)&&(identical(other.error, error) || other.error == error)&&(identical(other.lastUpdated, lastUpdated) || other.lastUpdated == lastUpdated));
}


@override
int get hashCode => Object.hash(runtimeType,const DeepCollectionEquality().hash(_videos),hasMoreContent,isLoadingMore,isRefreshing,isInitialLoad,error,lastUpdated);

@override
String toString() {
  return 'VideoFeedState(videos: $videos, hasMoreContent: $hasMoreContent, isLoadingMore: $isLoadingMore, isRefreshing: $isRefreshing, isInitialLoad: $isInitialLoad, error: $error, lastUpdated: $lastUpdated)';
}


}

/// @nodoc
abstract mixin class _$VideoFeedStateCopyWith<$Res> implements $VideoFeedStateCopyWith<$Res> {
  factory _$VideoFeedStateCopyWith(_VideoFeedState value, $Res Function(_VideoFeedState) _then) = __$VideoFeedStateCopyWithImpl;
@override @useResult
$Res call({
 List<VideoEvent> videos, bool hasMoreContent, bool isLoadingMore, bool isRefreshing, bool isInitialLoad, String? error, DateTime? lastUpdated
});




}
/// @nodoc
class __$VideoFeedStateCopyWithImpl<$Res>
    implements _$VideoFeedStateCopyWith<$Res> {
  __$VideoFeedStateCopyWithImpl(this._self, this._then);

  final _VideoFeedState _self;
  final $Res Function(_VideoFeedState) _then;

/// Create a copy of VideoFeedState
/// with the given fields replaced by the non-null parameter values.
@override @pragma('vm:prefer-inline') $Res call({Object? videos = null,Object? hasMoreContent = null,Object? isLoadingMore = null,Object? isRefreshing = null,Object? isInitialLoad = null,Object? error = freezed,Object? lastUpdated = freezed,}) {
  return _then(_VideoFeedState(
videos: null == videos ? _self._videos : videos // ignore: cast_nullable_to_non_nullable
as List<VideoEvent>,hasMoreContent: null == hasMoreContent ? _self.hasMoreContent : hasMoreContent // ignore: cast_nullable_to_non_nullable
as bool,isLoadingMore: null == isLoadingMore ? _self.isLoadingMore : isLoadingMore // ignore: cast_nullable_to_non_nullable
as bool,isRefreshing: null == isRefreshing ? _self.isRefreshing : isRefreshing // ignore: cast_nullable_to_non_nullable
as bool,isInitialLoad: null == isInitialLoad ? _self.isInitialLoad : isInitialLoad // ignore: cast_nullable_to_non_nullable
as bool,error: freezed == error ? _self.error : error // ignore: cast_nullable_to_non_nullable
as String?,lastUpdated: freezed == lastUpdated ? _self.lastUpdated : lastUpdated // ignore: cast_nullable_to_non_nullable
as DateTime?,
  ));
}


}

// dart format on
