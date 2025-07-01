// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'analytics_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

AnalyticsState _$AnalyticsStateFromJson(Map<String, dynamic> json) {
  return _AnalyticsState.fromJson(json);
}

/// @nodoc
mixin _$AnalyticsState {
  bool get analyticsEnabled => throw _privateConstructorUsedError;
  bool get isInitialized => throw _privateConstructorUsedError;
  bool get isLoading => throw _privateConstructorUsedError;
  String? get lastEvent => throw _privateConstructorUsedError;
  String? get error => throw _privateConstructorUsedError;

  /// Serializes this AnalyticsState to a JSON map.
  Map<String, dynamic> toJson() => throw _privateConstructorUsedError;

  /// Create a copy of AnalyticsState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $AnalyticsStateCopyWith<AnalyticsState> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $AnalyticsStateCopyWith<$Res> {
  factory $AnalyticsStateCopyWith(
          AnalyticsState value, $Res Function(AnalyticsState) then) =
      _$AnalyticsStateCopyWithImpl<$Res, AnalyticsState>;
  @useResult
  $Res call(
      {bool analyticsEnabled,
      bool isInitialized,
      bool isLoading,
      String? lastEvent,
      String? error});
}

/// @nodoc
class _$AnalyticsStateCopyWithImpl<$Res, $Val extends AnalyticsState>
    implements $AnalyticsStateCopyWith<$Res> {
  _$AnalyticsStateCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of AnalyticsState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? analyticsEnabled = null,
    Object? isInitialized = null,
    Object? isLoading = null,
    Object? lastEvent = freezed,
    Object? error = freezed,
  }) {
    return _then(_value.copyWith(
      analyticsEnabled: null == analyticsEnabled
          ? _value.analyticsEnabled
          : analyticsEnabled // ignore: cast_nullable_to_non_nullable
              as bool,
      isInitialized: null == isInitialized
          ? _value.isInitialized
          : isInitialized // ignore: cast_nullable_to_non_nullable
              as bool,
      isLoading: null == isLoading
          ? _value.isLoading
          : isLoading // ignore: cast_nullable_to_non_nullable
              as bool,
      lastEvent: freezed == lastEvent
          ? _value.lastEvent
          : lastEvent // ignore: cast_nullable_to_non_nullable
              as String?,
      error: freezed == error
          ? _value.error
          : error // ignore: cast_nullable_to_non_nullable
              as String?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$AnalyticsStateImplCopyWith<$Res>
    implements $AnalyticsStateCopyWith<$Res> {
  factory _$$AnalyticsStateImplCopyWith(_$AnalyticsStateImpl value,
          $Res Function(_$AnalyticsStateImpl) then) =
      __$$AnalyticsStateImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {bool analyticsEnabled,
      bool isInitialized,
      bool isLoading,
      String? lastEvent,
      String? error});
}

/// @nodoc
class __$$AnalyticsStateImplCopyWithImpl<$Res>
    extends _$AnalyticsStateCopyWithImpl<$Res, _$AnalyticsStateImpl>
    implements _$$AnalyticsStateImplCopyWith<$Res> {
  __$$AnalyticsStateImplCopyWithImpl(
      _$AnalyticsStateImpl _value, $Res Function(_$AnalyticsStateImpl) _then)
      : super(_value, _then);

  /// Create a copy of AnalyticsState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? analyticsEnabled = null,
    Object? isInitialized = null,
    Object? isLoading = null,
    Object? lastEvent = freezed,
    Object? error = freezed,
  }) {
    return _then(_$AnalyticsStateImpl(
      analyticsEnabled: null == analyticsEnabled
          ? _value.analyticsEnabled
          : analyticsEnabled // ignore: cast_nullable_to_non_nullable
              as bool,
      isInitialized: null == isInitialized
          ? _value.isInitialized
          : isInitialized // ignore: cast_nullable_to_non_nullable
              as bool,
      isLoading: null == isLoading
          ? _value.isLoading
          : isLoading // ignore: cast_nullable_to_non_nullable
              as bool,
      lastEvent: freezed == lastEvent
          ? _value.lastEvent
          : lastEvent // ignore: cast_nullable_to_non_nullable
              as String?,
      error: freezed == error
          ? _value.error
          : error // ignore: cast_nullable_to_non_nullable
              as String?,
    ));
  }
}

/// @nodoc
@JsonSerializable()
class _$AnalyticsStateImpl extends _AnalyticsState {
  const _$AnalyticsStateImpl(
      {this.analyticsEnabled = true,
      this.isInitialized = false,
      this.isLoading = false,
      this.lastEvent,
      this.error})
      : super._();

  factory _$AnalyticsStateImpl.fromJson(Map<String, dynamic> json) =>
      _$$AnalyticsStateImplFromJson(json);

  @override
  @JsonKey()
  final bool analyticsEnabled;
  @override
  @JsonKey()
  final bool isInitialized;
  @override
  @JsonKey()
  final bool isLoading;
  @override
  final String? lastEvent;
  @override
  final String? error;

  @override
  String toString() {
    return 'AnalyticsState(analyticsEnabled: $analyticsEnabled, isInitialized: $isInitialized, isLoading: $isLoading, lastEvent: $lastEvent, error: $error)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$AnalyticsStateImpl &&
            (identical(other.analyticsEnabled, analyticsEnabled) ||
                other.analyticsEnabled == analyticsEnabled) &&
            (identical(other.isInitialized, isInitialized) ||
                other.isInitialized == isInitialized) &&
            (identical(other.isLoading, isLoading) ||
                other.isLoading == isLoading) &&
            (identical(other.lastEvent, lastEvent) ||
                other.lastEvent == lastEvent) &&
            (identical(other.error, error) || other.error == error));
  }

  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  int get hashCode => Object.hash(runtimeType, analyticsEnabled, isInitialized,
      isLoading, lastEvent, error);

  /// Create a copy of AnalyticsState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$AnalyticsStateImplCopyWith<_$AnalyticsStateImpl> get copyWith =>
      __$$AnalyticsStateImplCopyWithImpl<_$AnalyticsStateImpl>(
          this, _$identity);

  @override
  Map<String, dynamic> toJson() {
    return _$$AnalyticsStateImplToJson(
      this,
    );
  }
}

abstract class _AnalyticsState extends AnalyticsState {
  const factory _AnalyticsState(
      {final bool analyticsEnabled,
      final bool isInitialized,
      final bool isLoading,
      final String? lastEvent,
      final String? error}) = _$AnalyticsStateImpl;
  const _AnalyticsState._() : super._();

  factory _AnalyticsState.fromJson(Map<String, dynamic> json) =
      _$AnalyticsStateImpl.fromJson;

  @override
  bool get analyticsEnabled;
  @override
  bool get isInitialized;
  @override
  bool get isLoading;
  @override
  String? get lastEvent;
  @override
  String? get error;

  /// Create a copy of AnalyticsState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$AnalyticsStateImplCopyWith<_$AnalyticsStateImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
