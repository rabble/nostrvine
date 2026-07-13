// ABOUTME: Auto-sweeps the durable pending-profile-save slot (#3161) and
// ABOUTME: re-drives the queued kind-0 publish via
// ABOUTME: ProfileRepository.drivePendingSave. Triggered by app-foreground
// ABOUTME: transitions and connectivity/relay-reconnect; mirrors
// ABOUTME: OutgoingDmRetryService.

import 'dart:async';

import 'package:db_client/db_client.dart';
import 'package:meta/meta.dart';
import 'package:openvine/services/crash_reporting_service.dart';
import 'package:profile_repository/profile_repository.dart';
import 'package:unified_logger/unified_logger.dart';

/// Crashlytics `reason:` suffix for the sweep's top-level catch. Inlined as a
/// single site per `error_handling.md` (a dedicated *ReportableSites class is
/// only warranted once a feature has 2+ migrated sites).
const _sweepTopLevelSite = 'ProfileSaveRetryService.sweepTopLevel';

/// Backoff configuration for [ProfileSaveRetryService].
///
/// Defaults match `OutgoingDmRetryConfig` / `PendingActionRetryConfig`
/// (5 retries, 2s → 5min, 2× backoff).
class ProfileSaveRetryConfig {
  const ProfileSaveRetryConfig({
    this.maxRetries = 5,
    this.initialDelay = const Duration(seconds: 2),
    this.maxDelay = const Duration(minutes: 5),
    this.backoffMultiplier = 2.0,
  });

  /// Maximum publish attempts before the slot is marked failed.
  final int maxRetries;

  /// Delay before the second attempt (the first retry).
  final Duration initialDelay;

  /// Upper bound on the backoff delay.
  final Duration maxDelay;

  /// Multiplier applied per prior attempt.
  final double backoffMultiplier;

  /// Minimum gap required before a row whose previous attempt count is
  /// [retryCount] may be retried. Clamped at [maxDelay].
  Duration backoffFor(int retryCount) {
    if (retryCount <= 0) return Duration.zero;
    var ms = initialDelay.inMilliseconds.toDouble();
    for (var i = 0; i < retryCount; i++) {
      ms *= backoffMultiplier;
      if (ms >= maxDelay.inMilliseconds) return maxDelay;
    }
    return Duration(milliseconds: ms.round());
  }
}

/// Re-drives the single durable pending profile/username save for one account
/// until a relay confirms the kind-0 publish, then the slot clears itself.
///
/// **Triggers:** [appForegroundStream] transitions to `true`, and each event on
/// [retryTriggerStream] (wired to connectivity/relay-reconnect). The provider
/// seeds the foreground stream with the current state on subscription, so the
/// cold-start sweep fires automatically.
///
/// **Re-entrancy:** a sweep already in progress short-circuits the next
/// trigger; the deferred work is picked up on the next transition.
///
/// **Per-row backoff:** a slot whose `lastAttemptAt + backoff(retryCount)` is
/// in the future is skipped this pass.
///
/// **Terminal state:** once [ProfileSaveRetryConfig.maxRetries] is reached, or
/// the divine.video username claim fails permanently (taken/reserved), the slot
/// is marked `failed` and left for the user to retry manually via [retryNow].
class ProfileSaveRetryService {
  ProfileSaveRetryService({
    required ProfileRepository profileRepository,
    required PendingProfileSavesDao pendingProfileSavesDao,
    required String userPubkey,
    required Stream<bool> appForegroundStream,
    Stream<void>? retryTriggerStream,
    ProfileSaveRetryConfig retryConfig = const ProfileSaveRetryConfig(),
    DateTime Function() now = DateTime.now,
    CrashReportingService? crashReporting,
  }) : _profileRepository = profileRepository,
       _dao = pendingProfileSavesDao,
       _userPubkey = userPubkey,
       _appForegroundStream = appForegroundStream,
       _retryTriggerStream = retryTriggerStream,
       _retryConfig = retryConfig,
       _now = now,
       _crashReporting = crashReporting ?? CrashReportingService.instance;

  final ProfileRepository _profileRepository;
  final PendingProfileSavesDao _dao;
  final String _userPubkey;
  final Stream<bool> _appForegroundStream;
  final Stream<void>? _retryTriggerStream;
  final ProfileSaveRetryConfig _retryConfig;
  final DateTime Function() _now;
  final CrashReportingService _crashReporting;

  StreamSubscription<bool>? _foregroundSubscription;
  StreamSubscription<void>? _retryTriggerSubscription;
  bool _isInitialized = false;
  bool _isSweeping = false;

  bool get isInitialized => _isInitialized;

  @visibleForTesting
  bool get isSweeping => _isSweeping;

  /// Subscribe to the trigger streams and run a cold-start sweep. Idempotent.
  Future<void> initialize() async {
    if (_isInitialized) return;
    _isInitialized = true;

    // A slot left `syncing` by an app-kill mid-publish is reset to `pending`
    // so this session retries it.
    await _profileRepository.resetInterruptedPendingSave(_userPubkey);

    _foregroundSubscription = _appForegroundStream.listen((foreground) {
      if (foreground) unawaited(sweep());
    });
    _retryTriggerSubscription = _retryTriggerStream?.listen((_) {
      unawaited(sweep());
    });

    // The cold-start sweep is driven by the foreground stream, which the
    // provider seeds with the current state on subscription (mirrors
    // OutgoingDmRetryService) — no explicit sweep() call needed here.

    Log.info(
      'initialized for $_userPubkey',
      name: 'ProfileSaveRetryService',
      category: LogCategory.system,
    );
  }

  /// Cancel the trigger subscriptions and mark the service un-init. Idempotent.
  Future<void> dispose() async {
    await _foregroundSubscription?.cancel();
    _foregroundSubscription = null;
    await _retryTriggerSubscription?.cancel();
    _retryTriggerSubscription = null;
    _isInitialized = false;
  }

  /// Reset a `failed` slot back to `pending` (fresh retry budget) and sweep.
  /// Wired to the UI's manual "retry" affordance.
  Future<void> retryNow() async {
    final entry = await _dao.get(_userPubkey);
    if (entry == null) return;
    // Re-upsert resets retryCount → 0, status → pending, lastError → null.
    await _dao.upsert(
      PendingProfileSaveEntry(
        userPubkey: entry.userPubkey,
        payloadJson: entry.payloadJson,
        claimConfirmed: entry.claimConfirmed,
        queuedAt: _now(),
      ),
    );
    await sweep();
  }

  /// One pass over the pending-save slot. Public so tests and the manual-retry
  /// path can drive it directly.
  @visibleForTesting
  Future<void> sweep() async {
    if (_isSweeping) {
      Log.debug(
        'sweep already in progress, skipping',
        name: 'ProfileSaveRetryService',
        category: LogCategory.system,
      );
      return;
    }
    _isSweeping = true;

    try {
      final entry = await _dao.get(_userPubkey);
      if (entry == null) return;

      // A failed slot awaits a manual retry — don't auto-retry it.
      if (entry.status == PendingProfileSaveStatus.failed) return;

      // Per-row backoff.
      final lastAttempt = entry.lastAttemptAt;
      if (lastAttempt != null) {
        final gap = _now().difference(lastAttempt);
        if (gap < _retryConfig.backoffFor(entry.retryCount)) return;
      }

      await _dao.markStatus(
        userPubkey: _userPubkey,
        status: PendingProfileSaveStatus.syncing,
      );

      final outcome = await _profileRepository.drivePendingSave(_userPubkey);

      switch (outcome) {
        case PendingSaveDriveOutcome.confirmed:
        case PendingSaveDriveOutcome.noPendingSave:
          // Slot cleared by the repository (confirmed) or already gone.
          break;
        case PendingSaveDriveOutcome.permanentFailure:
          await _dao.markStatus(
            userPubkey: _userPubkey,
            status: PendingProfileSaveStatus.failed,
            lastError: 'Username claim failed permanently (taken/reserved)',
          );
        case PendingSaveDriveOutcome.retryableFailure:
          if (entry.retryCount + 1 >= _retryConfig.maxRetries) {
            await _dao.markStatus(
              userPubkey: _userPubkey,
              status: PendingProfileSaveStatus.failed,
              lastError:
                  'Could not publish after ${_retryConfig.maxRetries} attempts',
            );
          } else {
            await _dao.incrementRetry(_userPubkey);
            await _dao.markStatus(
              userPubkey: _userPubkey,
              status: PendingProfileSaveStatus.pending,
            );
          }
      }
    } on Object catch (e, stackTrace) {
      Log.error(
        'sweep failed: $e',
        name: 'ProfileSaveRetryService',
        category: LogCategory.system,
        error: e,
        stackTrace: stackTrace,
      );
      unawaited(
        _crashReporting.recordError(
          e,
          stackTrace,
          reason: _sweepTopLevelSite,
        ),
      );
    } finally {
      _isSweeping = false;
    }
  }
}
