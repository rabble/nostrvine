// ABOUTME: Privacy-safe analytics helpers for the in-app review prompt.
// ABOUTME: Buckets the video count and never logs pubkeys.

import 'dart:async';

import 'package:analytics/analytics.dart';
import 'package:app_update_repository/app_update_repository.dart';

/// Records that a user met all eligibility conditions and would have been
/// prompted (the OS may still throttle this to no-op).
void trackInAppReviewEligible({
  required AnalyticsEventSink analytics,
  required InstallSource installSource,
  required int videoCount,
  required int sessionCount,
  required int daysSinceFirstLaunch,
}) {
  unawaited(
    analytics.logEvent(
      name: 'in_app_review_eligible',
      parameters: {
        'install_source': installSource.name,
        'video_count_bucket': _videoCountBucket(videoCount),
        'session_count': sessionCount,
        'days_since_first_launch': daysSinceFirstLaunch,
      },
    ),
  );
}

/// Records that the native review card was actually requested. The OS does
/// not report whether the user rated or dismissed, so this is the terminal
/// event of the prompt flow.
void trackInAppReviewPrompted({required AnalyticsEventSink analytics}) {
  unawaited(
    analytics.logEvent(
      name: 'in_app_review_prompted',
      parameters: const {},
    ),
  );
}

/// Records that requesting the native review card threw. Used to monitor
/// platform-API breakage without surfacing the raw exception to users.
void trackInAppReviewRequestFailed({
  required AnalyticsEventSink analytics,
  required Object error,
}) {
  unawaited(
    analytics.logEvent(
      name: 'in_app_review_request_failed',
      parameters: {'error_type': error.runtimeType.toString()},
    ),
  );
}

/// Buckets the video count so the analytics payload cannot be used to
/// reconstruct an exact posting history. >10 is the only bucket the gate
/// cares about, so coarser buckets above that preserve all signal.
String _videoCountBucket(int count) {
  if (count <= 0) return '0';
  if (count <= 5) return '1-5';
  if (count <= 10) return '6-10';
  if (count <= 25) return '11-25';
  if (count <= 50) return '26-50';
  if (count <= 100) return '51-100';
  return '100+';
}
