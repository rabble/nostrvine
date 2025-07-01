// coverage:ignore-file
// GENERATED CODE - DO NOT MODIFY BY HAND
// ignore_for_file: type=lint
// ignore_for_file: unused_element, deprecated_member_use, deprecated_member_use_from_same_package, use_function_type_syntax_for_parameters, unnecessary_const, avoid_init_to_null, invalid_override_different_default_values_named, prefer_expression_function_bodies, annotate_overrides, invalid_annotation_target, unnecessary_question_mark

part of 'video_manager_state.dart';

// **************************************************************************
// FreezedGenerator
// **************************************************************************

T _$identity<T>(T value) => value;

final _privateConstructorUsedError = UnsupportedError(
    'It seems like you constructed your class using `MyClass._()`. This constructor is only meant to be used by freezed and you are not supposed to need it nor use it.\nPlease check the documentation here for more information: https://github.com/rrousselGit/freezed#adding-getters-and-methods-to-our-models');

/// @nodoc
mixin _$VideoControllerState {
  String get videoId => throw _privateConstructorUsedError;
  VideoPlayerController get controller => throw _privateConstructorUsedError;
  VideoState get state => throw _privateConstructorUsedError;
  DateTime get createdAt => throw _privateConstructorUsedError;
  PreloadPriority get priority => throw _privateConstructorUsedError;
  int get retryCount => throw _privateConstructorUsedError;
  DateTime? get lastAccessedAt => throw _privateConstructorUsedError;

  /// Create a copy of VideoControllerState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $VideoControllerStateCopyWith<VideoControllerState> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $VideoControllerStateCopyWith<$Res> {
  factory $VideoControllerStateCopyWith(VideoControllerState value,
          $Res Function(VideoControllerState) then) =
      _$VideoControllerStateCopyWithImpl<$Res, VideoControllerState>;
  @useResult
  $Res call(
      {String videoId,
      VideoPlayerController controller,
      VideoState state,
      DateTime createdAt,
      PreloadPriority priority,
      int retryCount,
      DateTime? lastAccessedAt});
}

/// @nodoc
class _$VideoControllerStateCopyWithImpl<$Res,
        $Val extends VideoControllerState>
    implements $VideoControllerStateCopyWith<$Res> {
  _$VideoControllerStateCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of VideoControllerState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? videoId = null,
    Object? controller = null,
    Object? state = null,
    Object? createdAt = null,
    Object? priority = null,
    Object? retryCount = null,
    Object? lastAccessedAt = freezed,
  }) {
    return _then(_value.copyWith(
      videoId: null == videoId
          ? _value.videoId
          : videoId // ignore: cast_nullable_to_non_nullable
              as String,
      controller: null == controller
          ? _value.controller
          : controller // ignore: cast_nullable_to_non_nullable
              as VideoPlayerController,
      state: null == state
          ? _value.state
          : state // ignore: cast_nullable_to_non_nullable
              as VideoState,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      priority: null == priority
          ? _value.priority
          : priority // ignore: cast_nullable_to_non_nullable
              as PreloadPriority,
      retryCount: null == retryCount
          ? _value.retryCount
          : retryCount // ignore: cast_nullable_to_non_nullable
              as int,
      lastAccessedAt: freezed == lastAccessedAt
          ? _value.lastAccessedAt
          : lastAccessedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$VideoControllerStateImplCopyWith<$Res>
    implements $VideoControllerStateCopyWith<$Res> {
  factory _$$VideoControllerStateImplCopyWith(_$VideoControllerStateImpl value,
          $Res Function(_$VideoControllerStateImpl) then) =
      __$$VideoControllerStateImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {String videoId,
      VideoPlayerController controller,
      VideoState state,
      DateTime createdAt,
      PreloadPriority priority,
      int retryCount,
      DateTime? lastAccessedAt});
}

/// @nodoc
class __$$VideoControllerStateImplCopyWithImpl<$Res>
    extends _$VideoControllerStateCopyWithImpl<$Res, _$VideoControllerStateImpl>
    implements _$$VideoControllerStateImplCopyWith<$Res> {
  __$$VideoControllerStateImplCopyWithImpl(_$VideoControllerStateImpl _value,
      $Res Function(_$VideoControllerStateImpl) _then)
      : super(_value, _then);

  /// Create a copy of VideoControllerState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? videoId = null,
    Object? controller = null,
    Object? state = null,
    Object? createdAt = null,
    Object? priority = null,
    Object? retryCount = null,
    Object? lastAccessedAt = freezed,
  }) {
    return _then(_$VideoControllerStateImpl(
      videoId: null == videoId
          ? _value.videoId
          : videoId // ignore: cast_nullable_to_non_nullable
              as String,
      controller: null == controller
          ? _value.controller
          : controller // ignore: cast_nullable_to_non_nullable
              as VideoPlayerController,
      state: null == state
          ? _value.state
          : state // ignore: cast_nullable_to_non_nullable
              as VideoState,
      createdAt: null == createdAt
          ? _value.createdAt
          : createdAt // ignore: cast_nullable_to_non_nullable
              as DateTime,
      priority: null == priority
          ? _value.priority
          : priority // ignore: cast_nullable_to_non_nullable
              as PreloadPriority,
      retryCount: null == retryCount
          ? _value.retryCount
          : retryCount // ignore: cast_nullable_to_non_nullable
              as int,
      lastAccessedAt: freezed == lastAccessedAt
          ? _value.lastAccessedAt
          : lastAccessedAt // ignore: cast_nullable_to_non_nullable
              as DateTime?,
    ));
  }
}

/// @nodoc

class _$VideoControllerStateImpl extends _VideoControllerState {
  const _$VideoControllerStateImpl(
      {required this.videoId,
      required this.controller,
      required this.state,
      required this.createdAt,
      required this.priority,
      this.retryCount = 0,
      this.lastAccessedAt})
      : super._();

  @override
  final String videoId;
  @override
  final VideoPlayerController controller;
  @override
  final VideoState state;
  @override
  final DateTime createdAt;
  @override
  final PreloadPriority priority;
  @override
  @JsonKey()
  final int retryCount;
  @override
  final DateTime? lastAccessedAt;

  @override
  String toString() {
    return 'VideoControllerState(videoId: $videoId, controller: $controller, state: $state, createdAt: $createdAt, priority: $priority, retryCount: $retryCount, lastAccessedAt: $lastAccessedAt)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$VideoControllerStateImpl &&
            (identical(other.videoId, videoId) || other.videoId == videoId) &&
            (identical(other.controller, controller) ||
                other.controller == controller) &&
            (identical(other.state, state) || other.state == state) &&
            (identical(other.createdAt, createdAt) ||
                other.createdAt == createdAt) &&
            (identical(other.priority, priority) ||
                other.priority == priority) &&
            (identical(other.retryCount, retryCount) ||
                other.retryCount == retryCount) &&
            (identical(other.lastAccessedAt, lastAccessedAt) ||
                other.lastAccessedAt == lastAccessedAt));
  }

  @override
  int get hashCode => Object.hash(runtimeType, videoId, controller, state,
      createdAt, priority, retryCount, lastAccessedAt);

  /// Create a copy of VideoControllerState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$VideoControllerStateImplCopyWith<_$VideoControllerStateImpl>
      get copyWith =>
          __$$VideoControllerStateImplCopyWithImpl<_$VideoControllerStateImpl>(
              this, _$identity);
}

abstract class _VideoControllerState extends VideoControllerState {
  const factory _VideoControllerState(
      {required final String videoId,
      required final VideoPlayerController controller,
      required final VideoState state,
      required final DateTime createdAt,
      required final PreloadPriority priority,
      final int retryCount,
      final DateTime? lastAccessedAt}) = _$VideoControllerStateImpl;
  const _VideoControllerState._() : super._();

  @override
  String get videoId;
  @override
  VideoPlayerController get controller;
  @override
  VideoState get state;
  @override
  DateTime get createdAt;
  @override
  PreloadPriority get priority;
  @override
  int get retryCount;
  @override
  DateTime? get lastAccessedAt;

  /// Create a copy of VideoControllerState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$VideoControllerStateImplCopyWith<_$VideoControllerStateImpl>
      get copyWith => throw _privateConstructorUsedError;
}

/// @nodoc
mixin _$VideoMemoryStats {
  int get totalControllers => throw _privateConstructorUsedError;
  int get readyControllers => throw _privateConstructorUsedError;
  int get loadingControllers => throw _privateConstructorUsedError;
  int get failedControllers => throw _privateConstructorUsedError;
  double get estimatedMemoryMB => throw _privateConstructorUsedError;
  bool get isMemoryPressure => throw _privateConstructorUsedError;

  /// Create a copy of VideoMemoryStats
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $VideoMemoryStatsCopyWith<VideoMemoryStats> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $VideoMemoryStatsCopyWith<$Res> {
  factory $VideoMemoryStatsCopyWith(
          VideoMemoryStats value, $Res Function(VideoMemoryStats) then) =
      _$VideoMemoryStatsCopyWithImpl<$Res, VideoMemoryStats>;
  @useResult
  $Res call(
      {int totalControllers,
      int readyControllers,
      int loadingControllers,
      int failedControllers,
      double estimatedMemoryMB,
      bool isMemoryPressure});
}

/// @nodoc
class _$VideoMemoryStatsCopyWithImpl<$Res, $Val extends VideoMemoryStats>
    implements $VideoMemoryStatsCopyWith<$Res> {
  _$VideoMemoryStatsCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of VideoMemoryStats
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? totalControllers = null,
    Object? readyControllers = null,
    Object? loadingControllers = null,
    Object? failedControllers = null,
    Object? estimatedMemoryMB = null,
    Object? isMemoryPressure = null,
  }) {
    return _then(_value.copyWith(
      totalControllers: null == totalControllers
          ? _value.totalControllers
          : totalControllers // ignore: cast_nullable_to_non_nullable
              as int,
      readyControllers: null == readyControllers
          ? _value.readyControllers
          : readyControllers // ignore: cast_nullable_to_non_nullable
              as int,
      loadingControllers: null == loadingControllers
          ? _value.loadingControllers
          : loadingControllers // ignore: cast_nullable_to_non_nullable
              as int,
      failedControllers: null == failedControllers
          ? _value.failedControllers
          : failedControllers // ignore: cast_nullable_to_non_nullable
              as int,
      estimatedMemoryMB: null == estimatedMemoryMB
          ? _value.estimatedMemoryMB
          : estimatedMemoryMB // ignore: cast_nullable_to_non_nullable
              as double,
      isMemoryPressure: null == isMemoryPressure
          ? _value.isMemoryPressure
          : isMemoryPressure // ignore: cast_nullable_to_non_nullable
              as bool,
    ) as $Val);
  }
}

/// @nodoc
abstract class _$$VideoMemoryStatsImplCopyWith<$Res>
    implements $VideoMemoryStatsCopyWith<$Res> {
  factory _$$VideoMemoryStatsImplCopyWith(_$VideoMemoryStatsImpl value,
          $Res Function(_$VideoMemoryStatsImpl) then) =
      __$$VideoMemoryStatsImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {int totalControllers,
      int readyControllers,
      int loadingControllers,
      int failedControllers,
      double estimatedMemoryMB,
      bool isMemoryPressure});
}

/// @nodoc
class __$$VideoMemoryStatsImplCopyWithImpl<$Res>
    extends _$VideoMemoryStatsCopyWithImpl<$Res, _$VideoMemoryStatsImpl>
    implements _$$VideoMemoryStatsImplCopyWith<$Res> {
  __$$VideoMemoryStatsImplCopyWithImpl(_$VideoMemoryStatsImpl _value,
      $Res Function(_$VideoMemoryStatsImpl) _then)
      : super(_value, _then);

  /// Create a copy of VideoMemoryStats
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? totalControllers = null,
    Object? readyControllers = null,
    Object? loadingControllers = null,
    Object? failedControllers = null,
    Object? estimatedMemoryMB = null,
    Object? isMemoryPressure = null,
  }) {
    return _then(_$VideoMemoryStatsImpl(
      totalControllers: null == totalControllers
          ? _value.totalControllers
          : totalControllers // ignore: cast_nullable_to_non_nullable
              as int,
      readyControllers: null == readyControllers
          ? _value.readyControllers
          : readyControllers // ignore: cast_nullable_to_non_nullable
              as int,
      loadingControllers: null == loadingControllers
          ? _value.loadingControllers
          : loadingControllers // ignore: cast_nullable_to_non_nullable
              as int,
      failedControllers: null == failedControllers
          ? _value.failedControllers
          : failedControllers // ignore: cast_nullable_to_non_nullable
              as int,
      estimatedMemoryMB: null == estimatedMemoryMB
          ? _value.estimatedMemoryMB
          : estimatedMemoryMB // ignore: cast_nullable_to_non_nullable
              as double,
      isMemoryPressure: null == isMemoryPressure
          ? _value.isMemoryPressure
          : isMemoryPressure // ignore: cast_nullable_to_non_nullable
              as bool,
    ));
  }
}

/// @nodoc

class _$VideoMemoryStatsImpl extends _VideoMemoryStats {
  const _$VideoMemoryStatsImpl(
      {this.totalControllers = 0,
      this.readyControllers = 0,
      this.loadingControllers = 0,
      this.failedControllers = 0,
      this.estimatedMemoryMB = 0.0,
      this.isMemoryPressure = false})
      : super._();

  @override
  @JsonKey()
  final int totalControllers;
  @override
  @JsonKey()
  final int readyControllers;
  @override
  @JsonKey()
  final int loadingControllers;
  @override
  @JsonKey()
  final int failedControllers;
  @override
  @JsonKey()
  final double estimatedMemoryMB;
  @override
  @JsonKey()
  final bool isMemoryPressure;

  @override
  String toString() {
    return 'VideoMemoryStats(totalControllers: $totalControllers, readyControllers: $readyControllers, loadingControllers: $loadingControllers, failedControllers: $failedControllers, estimatedMemoryMB: $estimatedMemoryMB, isMemoryPressure: $isMemoryPressure)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$VideoMemoryStatsImpl &&
            (identical(other.totalControllers, totalControllers) ||
                other.totalControllers == totalControllers) &&
            (identical(other.readyControllers, readyControllers) ||
                other.readyControllers == readyControllers) &&
            (identical(other.loadingControllers, loadingControllers) ||
                other.loadingControllers == loadingControllers) &&
            (identical(other.failedControllers, failedControllers) ||
                other.failedControllers == failedControllers) &&
            (identical(other.estimatedMemoryMB, estimatedMemoryMB) ||
                other.estimatedMemoryMB == estimatedMemoryMB) &&
            (identical(other.isMemoryPressure, isMemoryPressure) ||
                other.isMemoryPressure == isMemoryPressure));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      totalControllers,
      readyControllers,
      loadingControllers,
      failedControllers,
      estimatedMemoryMB,
      isMemoryPressure);

  /// Create a copy of VideoMemoryStats
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$VideoMemoryStatsImplCopyWith<_$VideoMemoryStatsImpl> get copyWith =>
      __$$VideoMemoryStatsImplCopyWithImpl<_$VideoMemoryStatsImpl>(
          this, _$identity);
}

abstract class _VideoMemoryStats extends VideoMemoryStats {
  const factory _VideoMemoryStats(
      {final int totalControllers,
      final int readyControllers,
      final int loadingControllers,
      final int failedControllers,
      final double estimatedMemoryMB,
      final bool isMemoryPressure}) = _$VideoMemoryStatsImpl;
  const _VideoMemoryStats._() : super._();

  @override
  int get totalControllers;
  @override
  int get readyControllers;
  @override
  int get loadingControllers;
  @override
  int get failedControllers;
  @override
  double get estimatedMemoryMB;
  @override
  bool get isMemoryPressure;

  /// Create a copy of VideoMemoryStats
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$VideoMemoryStatsImplCopyWith<_$VideoMemoryStatsImpl> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
mixin _$VideoManagerState {
  /// Map of video ID to controller state
  Map<String, VideoControllerState> get controllers =>
      throw _privateConstructorUsedError;

  /// Current video index for preloading context
  int get currentIndex => throw _privateConstructorUsedError;

  /// Configuration for the video manager
  VideoManagerConfig? get config => throw _privateConstructorUsedError;

  /// Memory usage statistics
  VideoMemoryStats get memoryStats => throw _privateConstructorUsedError;

  /// Whether the manager is currently under memory pressure
  bool get isMemoryPressure => throw _privateConstructorUsedError;

  /// Currently playing video ID
  String? get currentlyPlayingId => throw _privateConstructorUsedError;

  /// Last cleanup timestamp
  DateTime? get lastCleanup => throw _privateConstructorUsedError;

  /// Whether the manager is disposed
  bool get isDisposed => throw _privateConstructorUsedError;

  /// Error state if the manager encounters issues
  String? get error => throw _privateConstructorUsedError;

  /// Number of successful preloads
  int get successfulPreloads => throw _privateConstructorUsedError;

  /// Number of failed loads
  int get failedLoads => throw _privateConstructorUsedError;

  /// Create a copy of VideoManagerState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  $VideoManagerStateCopyWith<VideoManagerState> get copyWith =>
      throw _privateConstructorUsedError;
}

/// @nodoc
abstract class $VideoManagerStateCopyWith<$Res> {
  factory $VideoManagerStateCopyWith(
          VideoManagerState value, $Res Function(VideoManagerState) then) =
      _$VideoManagerStateCopyWithImpl<$Res, VideoManagerState>;
  @useResult
  $Res call(
      {Map<String, VideoControllerState> controllers,
      int currentIndex,
      VideoManagerConfig? config,
      VideoMemoryStats memoryStats,
      bool isMemoryPressure,
      String? currentlyPlayingId,
      DateTime? lastCleanup,
      bool isDisposed,
      String? error,
      int successfulPreloads,
      int failedLoads});

  $VideoMemoryStatsCopyWith<$Res> get memoryStats;
}

/// @nodoc
class _$VideoManagerStateCopyWithImpl<$Res, $Val extends VideoManagerState>
    implements $VideoManagerStateCopyWith<$Res> {
  _$VideoManagerStateCopyWithImpl(this._value, this._then);

  // ignore: unused_field
  final $Val _value;
  // ignore: unused_field
  final $Res Function($Val) _then;

  /// Create a copy of VideoManagerState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? controllers = null,
    Object? currentIndex = null,
    Object? config = freezed,
    Object? memoryStats = null,
    Object? isMemoryPressure = null,
    Object? currentlyPlayingId = freezed,
    Object? lastCleanup = freezed,
    Object? isDisposed = null,
    Object? error = freezed,
    Object? successfulPreloads = null,
    Object? failedLoads = null,
  }) {
    return _then(_value.copyWith(
      controllers: null == controllers
          ? _value.controllers
          : controllers // ignore: cast_nullable_to_non_nullable
              as Map<String, VideoControllerState>,
      currentIndex: null == currentIndex
          ? _value.currentIndex
          : currentIndex // ignore: cast_nullable_to_non_nullable
              as int,
      config: freezed == config
          ? _value.config
          : config // ignore: cast_nullable_to_non_nullable
              as VideoManagerConfig?,
      memoryStats: null == memoryStats
          ? _value.memoryStats
          : memoryStats // ignore: cast_nullable_to_non_nullable
              as VideoMemoryStats,
      isMemoryPressure: null == isMemoryPressure
          ? _value.isMemoryPressure
          : isMemoryPressure // ignore: cast_nullable_to_non_nullable
              as bool,
      currentlyPlayingId: freezed == currentlyPlayingId
          ? _value.currentlyPlayingId
          : currentlyPlayingId // ignore: cast_nullable_to_non_nullable
              as String?,
      lastCleanup: freezed == lastCleanup
          ? _value.lastCleanup
          : lastCleanup // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      isDisposed: null == isDisposed
          ? _value.isDisposed
          : isDisposed // ignore: cast_nullable_to_non_nullable
              as bool,
      error: freezed == error
          ? _value.error
          : error // ignore: cast_nullable_to_non_nullable
              as String?,
      successfulPreloads: null == successfulPreloads
          ? _value.successfulPreloads
          : successfulPreloads // ignore: cast_nullable_to_non_nullable
              as int,
      failedLoads: null == failedLoads
          ? _value.failedLoads
          : failedLoads // ignore: cast_nullable_to_non_nullable
              as int,
    ) as $Val);
  }

  /// Create a copy of VideoManagerState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @pragma('vm:prefer-inline')
  $VideoMemoryStatsCopyWith<$Res> get memoryStats {
    return $VideoMemoryStatsCopyWith<$Res>(_value.memoryStats, (value) {
      return _then(_value.copyWith(memoryStats: value) as $Val);
    });
  }
}

/// @nodoc
abstract class _$$VideoManagerStateImplCopyWith<$Res>
    implements $VideoManagerStateCopyWith<$Res> {
  factory _$$VideoManagerStateImplCopyWith(_$VideoManagerStateImpl value,
          $Res Function(_$VideoManagerStateImpl) then) =
      __$$VideoManagerStateImplCopyWithImpl<$Res>;
  @override
  @useResult
  $Res call(
      {Map<String, VideoControllerState> controllers,
      int currentIndex,
      VideoManagerConfig? config,
      VideoMemoryStats memoryStats,
      bool isMemoryPressure,
      String? currentlyPlayingId,
      DateTime? lastCleanup,
      bool isDisposed,
      String? error,
      int successfulPreloads,
      int failedLoads});

  @override
  $VideoMemoryStatsCopyWith<$Res> get memoryStats;
}

/// @nodoc
class __$$VideoManagerStateImplCopyWithImpl<$Res>
    extends _$VideoManagerStateCopyWithImpl<$Res, _$VideoManagerStateImpl>
    implements _$$VideoManagerStateImplCopyWith<$Res> {
  __$$VideoManagerStateImplCopyWithImpl(_$VideoManagerStateImpl _value,
      $Res Function(_$VideoManagerStateImpl) _then)
      : super(_value, _then);

  /// Create a copy of VideoManagerState
  /// with the given fields replaced by the non-null parameter values.
  @pragma('vm:prefer-inline')
  @override
  $Res call({
    Object? controllers = null,
    Object? currentIndex = null,
    Object? config = freezed,
    Object? memoryStats = null,
    Object? isMemoryPressure = null,
    Object? currentlyPlayingId = freezed,
    Object? lastCleanup = freezed,
    Object? isDisposed = null,
    Object? error = freezed,
    Object? successfulPreloads = null,
    Object? failedLoads = null,
  }) {
    return _then(_$VideoManagerStateImpl(
      controllers: null == controllers
          ? _value._controllers
          : controllers // ignore: cast_nullable_to_non_nullable
              as Map<String, VideoControllerState>,
      currentIndex: null == currentIndex
          ? _value.currentIndex
          : currentIndex // ignore: cast_nullable_to_non_nullable
              as int,
      config: freezed == config
          ? _value.config
          : config // ignore: cast_nullable_to_non_nullable
              as VideoManagerConfig?,
      memoryStats: null == memoryStats
          ? _value.memoryStats
          : memoryStats // ignore: cast_nullable_to_non_nullable
              as VideoMemoryStats,
      isMemoryPressure: null == isMemoryPressure
          ? _value.isMemoryPressure
          : isMemoryPressure // ignore: cast_nullable_to_non_nullable
              as bool,
      currentlyPlayingId: freezed == currentlyPlayingId
          ? _value.currentlyPlayingId
          : currentlyPlayingId // ignore: cast_nullable_to_non_nullable
              as String?,
      lastCleanup: freezed == lastCleanup
          ? _value.lastCleanup
          : lastCleanup // ignore: cast_nullable_to_non_nullable
              as DateTime?,
      isDisposed: null == isDisposed
          ? _value.isDisposed
          : isDisposed // ignore: cast_nullable_to_non_nullable
              as bool,
      error: freezed == error
          ? _value.error
          : error // ignore: cast_nullable_to_non_nullable
              as String?,
      successfulPreloads: null == successfulPreloads
          ? _value.successfulPreloads
          : successfulPreloads // ignore: cast_nullable_to_non_nullable
              as int,
      failedLoads: null == failedLoads
          ? _value.failedLoads
          : failedLoads // ignore: cast_nullable_to_non_nullable
              as int,
    ));
  }
}

/// @nodoc

class _$VideoManagerStateImpl extends _VideoManagerState {
  const _$VideoManagerStateImpl(
      {final Map<String, VideoControllerState> controllers = const {},
      this.currentIndex = 0,
      this.config,
      this.memoryStats = const VideoMemoryStats(),
      this.isMemoryPressure = false,
      this.currentlyPlayingId,
      this.lastCleanup,
      this.isDisposed = false,
      this.error,
      this.successfulPreloads = 0,
      this.failedLoads = 0})
      : _controllers = controllers,
        super._();

  /// Map of video ID to controller state
  final Map<String, VideoControllerState> _controllers;

  /// Map of video ID to controller state
  @override
  @JsonKey()
  Map<String, VideoControllerState> get controllers {
    if (_controllers is EqualUnmodifiableMapView) return _controllers;
    // ignore: implicit_dynamic_type
    return EqualUnmodifiableMapView(_controllers);
  }

  /// Current video index for preloading context
  @override
  @JsonKey()
  final int currentIndex;

  /// Configuration for the video manager
  @override
  final VideoManagerConfig? config;

  /// Memory usage statistics
  @override
  @JsonKey()
  final VideoMemoryStats memoryStats;

  /// Whether the manager is currently under memory pressure
  @override
  @JsonKey()
  final bool isMemoryPressure;

  /// Currently playing video ID
  @override
  final String? currentlyPlayingId;

  /// Last cleanup timestamp
  @override
  final DateTime? lastCleanup;

  /// Whether the manager is disposed
  @override
  @JsonKey()
  final bool isDisposed;

  /// Error state if the manager encounters issues
  @override
  final String? error;

  /// Number of successful preloads
  @override
  @JsonKey()
  final int successfulPreloads;

  /// Number of failed loads
  @override
  @JsonKey()
  final int failedLoads;

  @override
  String toString() {
    return 'VideoManagerState(controllers: $controllers, currentIndex: $currentIndex, config: $config, memoryStats: $memoryStats, isMemoryPressure: $isMemoryPressure, currentlyPlayingId: $currentlyPlayingId, lastCleanup: $lastCleanup, isDisposed: $isDisposed, error: $error, successfulPreloads: $successfulPreloads, failedLoads: $failedLoads)';
  }

  @override
  bool operator ==(Object other) {
    return identical(this, other) ||
        (other.runtimeType == runtimeType &&
            other is _$VideoManagerStateImpl &&
            const DeepCollectionEquality()
                .equals(other._controllers, _controllers) &&
            (identical(other.currentIndex, currentIndex) ||
                other.currentIndex == currentIndex) &&
            (identical(other.config, config) || other.config == config) &&
            (identical(other.memoryStats, memoryStats) ||
                other.memoryStats == memoryStats) &&
            (identical(other.isMemoryPressure, isMemoryPressure) ||
                other.isMemoryPressure == isMemoryPressure) &&
            (identical(other.currentlyPlayingId, currentlyPlayingId) ||
                other.currentlyPlayingId == currentlyPlayingId) &&
            (identical(other.lastCleanup, lastCleanup) ||
                other.lastCleanup == lastCleanup) &&
            (identical(other.isDisposed, isDisposed) ||
                other.isDisposed == isDisposed) &&
            (identical(other.error, error) || other.error == error) &&
            (identical(other.successfulPreloads, successfulPreloads) ||
                other.successfulPreloads == successfulPreloads) &&
            (identical(other.failedLoads, failedLoads) ||
                other.failedLoads == failedLoads));
  }

  @override
  int get hashCode => Object.hash(
      runtimeType,
      const DeepCollectionEquality().hash(_controllers),
      currentIndex,
      config,
      memoryStats,
      isMemoryPressure,
      currentlyPlayingId,
      lastCleanup,
      isDisposed,
      error,
      successfulPreloads,
      failedLoads);

  /// Create a copy of VideoManagerState
  /// with the given fields replaced by the non-null parameter values.
  @JsonKey(includeFromJson: false, includeToJson: false)
  @override
  @pragma('vm:prefer-inline')
  _$$VideoManagerStateImplCopyWith<_$VideoManagerStateImpl> get copyWith =>
      __$$VideoManagerStateImplCopyWithImpl<_$VideoManagerStateImpl>(
          this, _$identity);
}

abstract class _VideoManagerState extends VideoManagerState {
  const factory _VideoManagerState(
      {final Map<String, VideoControllerState> controllers,
      final int currentIndex,
      final VideoManagerConfig? config,
      final VideoMemoryStats memoryStats,
      final bool isMemoryPressure,
      final String? currentlyPlayingId,
      final DateTime? lastCleanup,
      final bool isDisposed,
      final String? error,
      final int successfulPreloads,
      final int failedLoads}) = _$VideoManagerStateImpl;
  const _VideoManagerState._() : super._();

  /// Map of video ID to controller state
  @override
  Map<String, VideoControllerState> get controllers;

  /// Current video index for preloading context
  @override
  int get currentIndex;

  /// Configuration for the video manager
  @override
  VideoManagerConfig? get config;

  /// Memory usage statistics
  @override
  VideoMemoryStats get memoryStats;

  /// Whether the manager is currently under memory pressure
  @override
  bool get isMemoryPressure;

  /// Currently playing video ID
  @override
  String? get currentlyPlayingId;

  /// Last cleanup timestamp
  @override
  DateTime? get lastCleanup;

  /// Whether the manager is disposed
  @override
  bool get isDisposed;

  /// Error state if the manager encounters issues
  @override
  String? get error;

  /// Number of successful preloads
  @override
  int get successfulPreloads;

  /// Number of failed loads
  @override
  int get failedLoads;

  /// Create a copy of VideoManagerState
  /// with the given fields replaced by the non-null parameter values.
  @override
  @JsonKey(includeFromJson: false, includeToJson: false)
  _$$VideoManagerStateImplCopyWith<_$VideoManagerStateImpl> get copyWith =>
      throw _privateConstructorUsedError;
}
