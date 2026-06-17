// ABOUTME: Runs low-priority feed and notification warmups while the app is foreground idle.
// ABOUTME: Keeps warmups serialized, rate-limited, and non-critical.

import 'dart:async';

import 'package:unified_logger/unified_logger.dart';

/// App signals that can opportunistically trigger a lightweight warmup pass.
enum ForegroundIdleWarmupTrigger {
  /// Startup finished and the first frames have had time to settle.
  startupSettled,

  /// A foreground video has settled enough that tiny data requests are safe.
  videoPlaybackSettled,

  /// A periodic foreground-idle check fired.
  periodicIdleCheck,
}

/// Function used by the scheduler to request a warmup pass.
typedef ForegroundIdleWarmupRequest =
    Future<void> Function(ForegroundIdleWarmupTrigger trigger);

/// Starts delayed and periodic foreground-idle warmup requests.
class ForegroundIdleWarmupScheduler {
  /// Creates a scheduler.
  ForegroundIdleWarmupScheduler({
    required ForegroundIdleWarmupRequest requestWarmup,
    Duration startupDelay = const Duration(seconds: 10),
    Duration interval = const Duration(minutes: 5),
  }) : _requestWarmup = requestWarmup,
       _startupDelay = startupDelay,
       _interval = interval;

  final ForegroundIdleWarmupRequest _requestWarmup;
  final Duration _startupDelay;
  final Duration _interval;

  Timer? _startupTimer;
  Timer? _periodicTimer;

  /// Starts the scheduler once.
  void start() {
    if (_startupTimer != null || _periodicTimer != null) return;

    _startupTimer = Timer(_startupDelay, () {
      _requestSafely(ForegroundIdleWarmupTrigger.startupSettled);
    });
    _periodicTimer = Timer.periodic(_interval, (_) {
      _requestSafely(ForegroundIdleWarmupTrigger.periodicIdleCheck);
    });
  }

  /// Cancels all scheduled warmup requests.
  void stop() {
    _startupTimer?.cancel();
    _periodicTimer?.cancel();
    _startupTimer = null;
    _periodicTimer = null;
  }

  void _requestSafely(ForegroundIdleWarmupTrigger trigger) {
    unawaited(
      Future.sync(() => _requestWarmup(trigger)).catchError((Object error) {
        Log.warning(
          'Scheduled foreground idle warmup failed '
          '(${trigger.name}): $error',
          name: 'ForegroundIdleWarmupScheduler',
          category: LogCategory.system,
        );
      }),
    );
  }
}

/// Logical warmup surfaces.
enum ForegroundIdleWarmupTaskId {
  forYou,
  following,
  newVideos,
  popular,
  notifications,
}

/// A lightweight data warmup task.
class ForegroundIdleWarmupTask {
  /// Creates a warmup task.
  const ForegroundIdleWarmupTask({
    required this.id,
    required this.run,
    required this.cooldown,
  });

  /// Surface warmed by this task.
  final ForegroundIdleWarmupTaskId id;

  /// Minimum time between successful runs.
  final Duration cooldown;

  /// Performs the data-only warmup.
  final Future<void> Function() run;
}

/// Serial, best-effort coordinator for foreground-idle data warmups.
class ForegroundIdleWarmupCoordinator {
  /// Creates a coordinator.
  ForegroundIdleWarmupCoordinator({
    required List<ForegroundIdleWarmupTask> tasks,
    required bool Function() isForeground,
    required bool Function() isIdle,
    DateTime Function()? now,
  }) : _tasks = List.unmodifiable(tasks),
       _isForeground = isForeground,
       _isIdle = isIdle,
       _now = now ?? DateTime.now;

  final List<ForegroundIdleWarmupTask> _tasks;
  final bool Function() _isForeground;
  final bool Function() _isIdle;
  final DateTime Function() _now;

  final Map<ForegroundIdleWarmupTaskId, DateTime> _lastSuccessAt = {};
  Future<void>? _inFlight;

  /// Requests a best-effort warmup pass.
  ///
  /// If another pass is running, returns the same future. Each pass checks the
  /// foreground/idle gates before every task so user interaction can stop the
  /// queue quickly.
  Future<void> requestWarmup({
    required ForegroundIdleWarmupTrigger trigger,
  }) {
    final inFlight = _inFlight;
    if (inFlight != null) return inFlight;

    if (!_canRun) return Future<void>.value();

    final future = _run(trigger).whenComplete(() {
      _inFlight = null;
    });
    _inFlight = future;
    return future;
  }

  bool get _canRun => _isForeground() && _isIdle();

  Future<void> _run(ForegroundIdleWarmupTrigger trigger) async {
    for (final task in _tasks) {
      if (!_canRun) return;
      if (_isCoolingDown(task)) continue;

      try {
        await task.run();
        _lastSuccessAt[task.id] = _now();
      } catch (error) {
        Log.warning(
          'Foreground idle warmup failed '
          '(${task.id.name}, ${trigger.name}): $error',
          name: 'ForegroundIdleWarmupCoordinator',
          category: LogCategory.system,
        );
      }
    }
  }

  bool _isCoolingDown(ForegroundIdleWarmupTask task) {
    final lastSuccessAt = _lastSuccessAt[task.id];
    if (lastSuccessAt == null) return false;
    return _now().difference(lastSuccessAt) < task.cooldown;
  }
}
