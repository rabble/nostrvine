// ABOUTME: Testable orchestration for the OS-native in-app review prompt.
// ABOUTME: Owns platform availability, cooldown ordering, and analytics.

import 'dart:async';

import 'package:analytics/analytics.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:in_app_review/in_app_review.dart';
import 'package:openvine/features/app_review/app_review_analytics.dart';
import 'package:openvine/services/app_review_prompt_service.dart';

/// Minimal platform facade around [InAppReview] for coordinator tests.
abstract interface class AppReviewPlatform {
  Future<bool> isAvailable();

  Future<void> requestReview();
}

/// [InAppReview]-backed platform facade.
class InAppReviewPlatform implements AppReviewPlatform {
  InAppReviewPlatform({InAppReview? inAppReview})
    : _inAppReview = inAppReview ?? InAppReview.instance;

  final InAppReview _inAppReview;

  @override
  Future<bool> isAvailable() => _inAppReview.isAvailable();

  @override
  Future<void> requestReview() => _inAppReview.requestReview();
}

/// Waits until the UI has had a stable frame before showing the native card.
abstract interface class AppReviewFrameScheduler {
  Future<bool> waitForStableFrame();
}

/// Flutter binding backed frame scheduler.
class WidgetsAppReviewFrameScheduler implements AppReviewFrameScheduler {
  const WidgetsAppReviewFrameScheduler({
    this.timeout = const Duration(seconds: 2),
  });

  final Duration timeout;

  @override
  Future<bool> waitForStableFrame() async {
    final completer = Completer<void>();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!completer.isCompleted) completer.complete();
    });
    WidgetsBinding.instance.ensureVisualUpdate();

    try {
      await completer.future.timeout(timeout);
      return true;
    } on TimeoutException {
      return false;
    }
  }
}

/// Coordinates one in-flight review evaluation at a time.
class AppReviewCoordinatorCubit extends Cubit<bool> {
  AppReviewCoordinatorCubit({
    required AppReviewPromptService service,
    required AnalyticsEventSink analytics,
    required AppReviewPlatform reviewPlatform,
    required AppReviewFrameScheduler frameScheduler,
  }) : _service = service,
       _analytics = analytics,
       _reviewPlatform = reviewPlatform,
       _frameScheduler = frameScheduler,
       super(false);

  final AppReviewPromptService _service;
  final AnalyticsEventSink _analytics;
  final AppReviewPlatform _reviewPlatform;
  final AppReviewFrameScheduler _frameScheduler;

  bool get isEvaluating => state;

  Future<void> evaluate({
    required ReviewEligibilityInputs inputs,
    required bool Function() isActive,
  }) async {
    if (isClosed || state) return;
    emit(true);
    try {
      await _evaluate(inputs: inputs, isActive: isActive);
    } finally {
      if (!isClosed) emit(false);
    }
  }

  Future<void> _evaluate({
    required ReviewEligibilityInputs inputs,
    required bool Function() isActive,
  }) async {
    bool canContinue() => !isClosed && isActive();

    if (!_service.shouldShow(inputs)) return;
    if (!canContinue()) return;
    if (!await _frameScheduler.waitForStableFrame()) return;
    if (!canContinue()) return;

    try {
      if (!await _reviewPlatform.isAvailable()) return;
      if (!canContinue()) return;

      trackInAppReviewEligible(
        analytics: _analytics,
        installSource: inputs.installSource,
        videoCount: inputs.videoCount,
        sessionCount: inputs.sessionCount,
        daysSinceFirstLaunch: inputs.daysSinceFirstLaunch,
      );

      // Start cooldown immediately before the native request. That avoids a
      // tight re-prompt loop if the OS call crashes while not burning cooldown
      // for unavailable platforms or an unmounted app.
      await _service.recordShown(inputs.pubkey);
      if (!canContinue()) return;
      await _reviewPlatform.requestReview();
      trackInAppReviewPrompted(analytics: _analytics);
    } catch (error) {
      trackInAppReviewRequestFailed(analytics: _analytics, error: error);
    }
  }
}
