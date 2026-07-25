// ABOUTME: Mounts once in the widget tree to evaluate the in-app review
// ABOUTME: gate on auth settle, profile-stats load, and app foreground.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:models/models.dart';
import 'package:openvine/features/app_review/app_review_analytics.dart';
import 'package:openvine/providers/analytics_providers.dart';
import 'package:openvine/providers/app_foreground_provider.dart';
import 'package:openvine/providers/auth_providers.dart';
import 'package:openvine/providers/install_source_provider.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/providers/user_profile_providers.dart';
import 'package:openvine/services/app_engagement_store.dart';
import 'package:openvine/services/app_review_prompt_service.dart';
import 'package:openvine/services/auth_service.dart' show AuthState;
import 'package:openvine/services/install_source_service.dart';

/// Provides the [InstallSourceResolver]. Override in tests.
final installSourceResolverProvider = Provider<InstallSourceResolver>(
  (ref) => const InstallSourceService(),
);

/// Provides the [AppReviewPromptService].
final appReviewPromptServiceProvider = Provider<AppReviewPromptService>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return AppReviewPromptService(sharedPreferences: prefs);
});

/// Provides the [AppEngagementStore].
final appEngagementStoreProvider = Provider<AppEngagementStore>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return AppEngagementStore(sharedPreferences: prefs);
});

/// A zero-size widget that evaluates the review gate whenever auth settles,
/// the current user's profile stats update, or the app returns to the
/// foreground. Mount exactly once near the root of the widget tree.
///
/// Renders nothing; its only job is to call [InAppReview.requestReview] when
/// all eligibility conditions in [AppReviewPromptService.shouldShow] are met.
class AppReviewCoordinator extends ConsumerStatefulWidget {
  const AppReviewCoordinator({super.key, this.child});

  /// The rest of the app tree. Included so the coordinator can wrap the app
  /// without an extra nesting level.
  final Widget? child;

  @override
  ConsumerState<AppReviewCoordinator> createState() =>
      _AppReviewCoordinatorState();
}

class _AppReviewCoordinatorState extends ConsumerState<AppReviewCoordinator>
    with WidgetsBindingObserver {
  final InAppReview _inAppReview = InAppReview.instance;
  bool _evaluating = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Re-evaluate when the user returns to the app: that's the "actively
    // engaging" moment. Avoids prompting during background or transitions.
    if (state == AppLifecycleState.resumed) {
      _maybePrompt();
    }
  }

  @override
  Widget build(BuildContext context) {
    // Subscribe to auth + foreground state + current user's stats so a change
    // in any of them re-triggers evaluation. The actual gating work happens in
    // _maybePrompt, gated to one in-flight evaluation at a time.
    ref.watch(currentAuthStateProvider);
    ref.watch(appForegroundProvider);
    final pubkey = ref.watch(authServiceProvider).currentPublicKeyHex;
    // Explicit annotation: the family StreamProvider's inferred type is
    // non-obvious, and documenting it makes the subscription's shape clear.
    AsyncValue<ProfileStats?>? statsValue;
    if (pubkey != null) {
      // Family provider: watching with the pubkey re-subscribes when the
      // active account changes.
      statsValue = ref.watch(userProfileStatsReactiveProvider(pubkey));
    }
    // Schedule evaluation after this build so any provider change (auth
    // settle, stats load, foreground return) gets a chance to fire the gate.
    if (statsValue != null && statsValue.hasValue) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _maybePrompt());
    }
    return widget.child ?? const SizedBox.shrink();
  }

  Future<void> _maybePrompt() async {
    if (_evaluating) return;
    _evaluating = true;
    try {
      await _evaluateAndPrompt();
    } finally {
      _evaluating = false;
    }
  }

  Future<void> _evaluateAndPrompt() async {
    if (!mounted) return;
    final authService = ref.read(authServiceProvider);
    if (authService.authState != AuthState.authenticated) return;
    final pubkey = authService.currentPublicKeyHex;
    if (pubkey == null) return;

    // Read the current stats from the live subscription. This avoids a second
    // async round-trip to the DB and naturally waits until stats have loaded
    // (the build method only schedules a prompt when statsValue.hasValue).
    final statsValue = ref.read(userProfileStatsReactiveProvider(pubkey));
    final stats = statsValue.value;
    final videoCount = stats?.videoCount ?? 0;
    if (videoCount <= AppReviewPromptService.defaultMinimumVideoCount) return;

    final engagement = ref.read(appEngagementStoreProvider);
    final service = ref.read(appReviewPromptServiceProvider);
    final installSource = ref.read(installSourceProvider);
    final analytics = ref.read(analyticsEventSinkProvider);

    final inputs = ReviewEligibilityInputs(
      pubkey: pubkey,
      videoCount: videoCount,
      installSource: installSource,
      sessionCount: engagement.sessionCount,
      daysSinceFirstLaunch: engagement.daysSinceFirstLaunch(),
    );

    if (!service.shouldShow(inputs)) return;

    trackInAppReviewEligible(
      analytics: analytics,
      installSource: installSource,
      videoCount: videoCount,
      sessionCount: inputs.sessionCount,
      daysSinceFirstLaunch: inputs.daysSinceFirstLaunch,
    );

    // Record the cooldown BEFORE showing so a crash or OS throttle can't
    // cause a tight re-prompt loop. The OS applies its own ~3/year ceiling on
    // top of this.
    await service.recordShown(pubkey);

    // Wait for a stable frame so the native card layers over settled UI and
    // never competes with a route transition (Apple/Google reject cards shown
    // mid-transition).
    if (!mounted) return;
    final frameCompleter = Completer<void>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!frameCompleter.isCompleted) frameCompleter.complete();
    });
    await frameCompleter.future;

    try {
      // isAvailable guards desktop/web where the native card can't show.
      if (!mounted) return;
      if (!await _inAppReview.isAvailable()) return;
      if (!mounted) return;
      await _inAppReview.requestReview();
      trackInAppReviewPrompted(analytics: analytics);
    } catch (error) {
      trackInAppReviewRequestFailed(analytics: analytics, error: error);
    }
  }
}
