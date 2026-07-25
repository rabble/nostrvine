// ABOUTME: Eligibility gate + persistence for the OS-native review prompt.
// ABOUTME: Prompts only engaged, store-installed creators (>10 videos,
// ABOUTME: sustained use), with a per-user cooldown after each prompt.

import 'package:app_update_repository/app_update_repository.dart';
import 'package:meta/meta.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Inputs evaluated by [AppReviewPromptService.shouldShow].
@immutable
class ReviewEligibilityInputs {
  const ReviewEligibilityInputs({
    required this.pubkey,
    required this.videoCount,
    required this.installSource,
    required this.sessionCount,
    required this.daysSinceFirstLaunch,
  });

  /// Hex pubkey of the currently signed-in account.
  final String pubkey;

  /// Server-authoritative count of videos this account has published
  /// (from `ProfileStats.videoCount`).
  final int videoCount;

  /// How this install was distributed.
  final InstallSource installSource;

  /// Cold-start count for this install (from [AppEngagementStore]).
  final int sessionCount;

  /// Whole days since the install's first cold start
  /// (from [AppEngagementStore]).
  final int daysSinceFirstLaunch;
}

/// Eligibility gate and per-user cooldown for the in-app review prompt.
///
/// Design notes:
/// - The native review card (`InAppReview.requestReview()`) is **opaque**: it
///   never reports whether the user rated or dismissed. So "stop forever after
///   they rate" isn't reliably detectable — we apply a [cooldown] after every
///   prompt attempt and let the OS's own ~3/year throttle handle the rest.
/// - Cooldown keys are pubkey-scoped so switching accounts resets eligibility
///   cleanly (each account gets its own first impression).
/// - Only Play Store and App Store installs are eligible; TestFlight,
///   Zapstore, and sideloaded builds can't rate on the consumer stores.
class AppReviewPromptService {
  AppReviewPromptService({
    required SharedPreferences sharedPreferences,
    this.minimumVideoCount = defaultMinimumVideoCount,
    this.minimumSessionCount = defaultMinimumSessionCount,
    this.minimumDaysSinceFirstLaunch = defaultMinimumDaysSinceFirstLaunch,
    this.cooldown = defaultCooldown,
    DateTime Function()? now,
  }) : _prefs = sharedPreferences,
       _now = now ?? DateTime.now;

  final SharedPreferences _prefs;
  final DateTime Function() _now;

  /// Video count required to be eligible. Default is >10 videos.
  final int minimumVideoCount;

  /// Cold-start count required to be eligible (unless [daysSinceFirstLaunch]
  /// already exceeds [minimumDaysSinceFirstLaunch]).
  final int minimumSessionCount;

  /// Days-of-use required to be eligible (unless [sessionCount] already
  /// exceeds [minimumSessionCount]).
  final int minimumDaysSinceFirstLaunch;

  /// Per-user cooldown applied after every prompt attempt.
  final Duration cooldown;

  /// Default eligibility thresholds.
  static const defaultMinimumVideoCount = 10;
  static const defaultMinimumSessionCount = 10;
  static const defaultMinimumDaysSinceFirstLaunch = 14;

  /// Default per-user cooldown (~6 months). The OS still applies its own
  /// ~3-prompts/year throttle on top of this.
  static const defaultCooldown = Duration(days: 180);

  /// SharedPreferences key prefixes (pubkey-suffixed).
  static const _dismissedAtPrefix = 'review_prompt_dismissed_at_';
  static const _completedPrefix = 'review_prompt_completed_';

  String _dismissedAtKey(String pubkey) => '$_dismissedAtPrefix$pubkey';
  String _completedKey(String pubkey) => '$_completedPrefix$pubkey';

  /// Returns `true` only when every eligibility condition is met and the
  /// per-user cooldown has elapsed.
  ///
  /// Conditions (all required):
  /// 1. Install source is Play Store or App Store.
  /// 2. `videoCount` strictly exceeds [minimumVideoCount].
  /// 3. Sustained use: `sessionCount >= minimumSessionCount`
  ///    OR `daysSinceFirstLaunch >= minimumDaysSinceFirstLaunch`.
  /// 4. No prior "completed" flag for this pubkey (safety hatch for the case
  ///    where a future, more-transparent review API lets us detect a rating).
  /// 5. The per-user cooldown has elapsed since the last prompt attempt.
  bool shouldShow(ReviewEligibilityInputs inputs, {DateTime? now}) {
    final referenceNow = now ?? _now();

    // (1) Store installs only — TestFlight/Zapstore/sideload can't review.
    if (inputs.installSource != InstallSource.playStore &&
        inputs.installSource != InstallSource.appStore) {
      return false;
    }

    // (2) Genuinely invested creator.
    if (inputs.videoCount <= minimumVideoCount) return false;

    // (3) Sustained use — either enough sessions or enough days on the install.
    final sustainedUse =
        inputs.sessionCount >= minimumSessionCount ||
        inputs.daysSinceFirstLaunch >= minimumDaysSinceFirstLaunch;
    if (!sustainedUse) return false;

    // (4) Safety hatch: a future review API may report completion. Until then
    //     the native card stays opaque and this flag is never set.
    if (_prefs.getBool(_completedKey(inputs.pubkey)) ?? false) return false;

    // (5) Per-user cooldown after the most recent prompt attempt.
    final dismissedMillis = _prefs.getInt(_dismissedAtKey(inputs.pubkey));
    if (dismissedMillis != null) {
      final dismissedAt = DateTime.fromMillisecondsSinceEpoch(dismissedMillis);
      if (referenceNow.difference(dismissedAt) < cooldown) return false;
    }

    return true;
  }

  /// Records that a prompt attempt was made (shown OR skipped by the OS), so
  /// the per-user cooldown begins. The native card is opaque, so this fires
  /// after every call to `InAppReview.requestReview()`, regardless of outcome.
  Future<void> recordShown(String pubkey, {DateTime? now}) async {
    final at = (now ?? _now()).millisecondsSinceEpoch;
    await _prefs.setInt(_dismissedAtKey(pubkey), at);
  }

  /// Marks a pubkey as having completed a review. Currently unused by the
  /// coordinator (the native API is opaque); retained so a future,
  /// observable review surface can flip it without changing this service's API.
  Future<void> recordCompleted(String pubkey) async {
    await _prefs.setBool(_completedKey(pubkey), true);
  }

  /// Resets all review-prompt state for [pubkey]. Test-helper / future
  /// debug-screen affordance; not called from production paths today.
  Future<void> reset(String pubkey) async {
    await _prefs.remove(_dismissedAtKey(pubkey));
    await _prefs.remove(_completedKey(pubkey));
  }
}
