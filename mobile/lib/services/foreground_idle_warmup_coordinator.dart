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
    if (_startupTimer != null || _periodicTimer != null) {
      Log.debug(
        'Foreground idle warmup scheduler already started',
        name: 'ForegroundIdleWarmupScheduler',
        category: LogCategory.system,
      );
      return;
    }

    Log.info(
      'Foreground idle warmup scheduler started '
      '(startupDelay=${_startupDelay.inSeconds}s, '
      'interval=${_interval.inMinutes}m)',
      name: 'ForegroundIdleWarmupScheduler',
      category: LogCategory.system,
    );

    _startupTimer = Timer(_startupDelay, () {
      _requestSafely(ForegroundIdleWarmupTrigger.startupSettled);
    });
    _periodicTimer = Timer.periodic(_interval, (_) {
      _requestSafely(ForegroundIdleWarmupTrigger.periodicIdleCheck);
    });
  }

  /// Cancels all scheduled warmup requests.
  void stop() {
    if (_startupTimer != null || _periodicTimer != null) {
      Log.info(
        'Foreground idle warmup scheduler stopped',
        name: 'ForegroundIdleWarmupScheduler',
        category: LogCategory.system,
      );
    }
    _startupTimer?.cancel();
    _periodicTimer?.cancel();
    _startupTimer = null;
    _periodicTimer = null;
  }

  void _requestSafely(ForegroundIdleWarmupTrigger trigger) {
    Log.info(
      'Foreground idle warmup scheduler fired (${trigger.name})',
      name: 'ForegroundIdleWarmupScheduler',
      category: LogCategory.system,
    );
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
    this.timeout = const Duration(seconds: 12),
  });

  /// Surface warmed by this task.
  final ForegroundIdleWarmupTaskId id;

  /// Minimum time between successful runs.
  final Duration cooldown;

  /// Maximum time this low-priority task may occupy the serial queue.
  final Duration timeout;

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
    if (inFlight != null) {
      Log.debug(
        'Foreground idle warmup coalesced (${trigger.name})',
        name: 'ForegroundIdleWarmupCoordinator',
        category: LogCategory.system,
      );
      return inFlight;
    }

    if (!_canRun) {
      Log.debug(
        'Foreground idle warmup skipped (${trigger.name}): '
        'foreground=${_isForeground()}, idle=${_isIdle()}',
        name: 'ForegroundIdleWarmupCoordinator',
        category: LogCategory.system,
      );
      return Future<void>.value();
    }

    final future = _run(trigger).whenComplete(() {
      _inFlight = null;
    });
    _inFlight = future;
    return future;
  }

  bool get _canRun => _isForeground() && _isIdle();

  Future<void> _run(ForegroundIdleWarmupTrigger trigger) async {
    Log.info(
      'Foreground idle warmup started (${trigger.name})',
      name: 'ForegroundIdleWarmupCoordinator',
      category: LogCategory.system,
    );

    for (final task in _tasks) {
      if (!_canRun) {
        Log.info(
          'Foreground idle warmup stopped before ${task.id.name}: '
          'foreground=${_isForeground()}, idle=${_isIdle()}',
          name: 'ForegroundIdleWarmupCoordinator',
          category: LogCategory.system,
        );
        return;
      }
      if (_isCoolingDown(task)) {
        Log.debug(
          'Foreground idle warmup skipped ${task.id.name}: cooling down',
          name: 'ForegroundIdleWarmupCoordinator',
          category: LogCategory.system,
        );
        continue;
      }

      try {
        Log.debug(
          'Foreground idle warmup running ${task.id.name}',
          name: 'ForegroundIdleWarmupCoordinator',
          category: LogCategory.system,
        );
        await task.run().timeout(task.timeout);
        _lastSuccessAt[task.id] = _now();
        Log.info(
          'Foreground idle warmup completed ${task.id.name}',
          name: 'ForegroundIdleWarmupCoordinator',
          category: LogCategory.system,
        );
      } on TimeoutException {
        Log.warning(
          'Foreground idle warmup timed out '
          '(${task.id.name}, ${trigger.name}, ${task.timeout.inSeconds}s)',
          name: 'ForegroundIdleWarmupCoordinator',
          category: LogCategory.system,
        );
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
