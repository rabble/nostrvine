# Surface Analytics Observability Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make Firebase analytics useful for diagnosing slow user-visible screens and overlays, starting with the comments sheet.

**Architecture:** Disable native automatic screen reporting that produces `FlutterViewController` / `MainActivity` rows, replace generic route logging with app-owned semantic screen names, and add surface load telemetry that measures the milestones users actually wait on: intent, first frame, first meaningful content, completion, and failure. Keep BLoCs free of Firebase dependencies by recording comments load outcomes from UI listeners around existing BLoC state transitions.

**Tech Stack:** Flutter, Dart, go_router, Firebase Analytics, Firebase Performance, BLoC, Riverpod, `ScreenAnalyticsService`, `PageLoadHistory`, widget/service tests

---

## Current Evidence

- `PageLoadObserver` is installed in `mobile/lib/router/app_router.dart`, but it skips `PopupRoute`s, so modal surfaces like comments sheets are not globally timed.
- `ScreenAnalyticsService` already emits `screen_load`, `screen_data_loaded`, `screen_time`, and `screen_view`, but most screens do not call `trackScreenView` and many route names are missing.
- Firebase currently shows native class rows like `FlutterViewController` and `MainActivity`, which are not actionable screen names.
- `CommentsScreen.show` opens comments as a modal bottom sheet and wires `CommentsListBloc`, but does not record timing from tap/open to comments success, empty state, or failure.
- Divine Brain search for prior mobile analytics/performance-monitoring decisions returned no relevant results for: `Firebase Analytics performance monitoring screen_view screen_load screen_data_loaded mobile observability slow screens comments divine-mobile`.

## File Structure

| File | Action | Responsibility |
|------|--------|----------------|
| `docs/ANALYTICS_OBSERVABILITY.md` | Create | Current analytics contract, event vocabulary, dashboard queries, Divine Brain verification workflow |
| `mobile/lib/services/analytics_surface.dart` | Create | Stable semantic names and parameter keys for screens/surfaces |
| `mobile/lib/services/analytics_event_sink.dart` | Create | Testable abstraction over Firebase Analytics |
| `mobile/lib/services/firebase_analytics_event_sink.dart` | Create | Firebase-backed analytics sink |
| `mobile/lib/services/surface_performance_tracker.dart` | Create | Surface lifecycle timing and one terminal event per load |
| `mobile/lib/services/screen_analytics_service.dart` | Modify | Use semantic names, optional sink injection, keep legacy event compatibility where useful |
| `mobile/lib/services/page_load_observer.dart` | Modify | Log semantic route screen views and page visible timings through the app-owned service |
| `mobile/lib/router/app_router.dart` | Modify | Remove generic `FirebaseAnalyticsObserver`, add route names for high-value routes, keep `PageLoadObserver` |
| `mobile/ios/Runner/Info.plist` | Modify | Disable Firebase automatic native screen reporting |
| `mobile/android/app/src/main/AndroidManifest.xml` | Modify | Disable Firebase automatic native screen reporting |
| `mobile/lib/screens/comments/comments_screen.dart` | Modify | Instrument comments sheet open, visible, success, empty, failure, and dismiss |
| `mobile/test/services/*analytics*` | Modify/Create | Unit coverage for schema, screen naming, and surface timing |
| `mobile/test/screens/comments/comments_screen_test.dart` | Modify/Create if existing | Widget coverage for comments sheet telemetry |

---

### Task 1: Document The Analytics Contract And Divine Brain Check

**Files:**
- Create: `docs/ANALYTICS_OBSERVABILITY.md`

- [ ] **Step 1: Create the current analytics contract doc**

Create `docs/ANALYTICS_OBSERVABILITY.md`:

```markdown
# Analytics Observability

Status: Current
Validated against: `mobile/lib/services/screen_analytics_service.dart`,
`mobile/lib/services/page_load_observer.dart`,
`mobile/lib/screens/comments/comments_screen.dart`.

## Purpose

Analytics must answer operational questions:

- Which user-visible screens or surfaces are slow?
- How slow are they at p50, p75, p95, and p99?
- Did the user see real content, an empty state, or an error?
- Is slowness isolated to an entry point, platform, app version, network type,
  or feature flag?

## Naming

Use semantic snake_case names, never Flutter/native class names.

Examples:

- `home_feed`
- `explore`
- `profile`
- `video_detail`
- `comments_sheet`
- `settings`
- `notifications`

Do not log Nostr event IDs, pubkeys, npubs, nsecs, user-entered search text,
comment text, or raw URLs in analytics parameters.

## Core Events

### `screen_view`

Logged when the user navigates to a full-screen route.

Required parameters:

- `screen_name`
- `entry_point`
- `route_name`

### `surface_load`

Logged once when a user-visible surface reaches a terminal load state.

Required parameters:

- `surface_name`
- `entry_point`
- `result`: `success`, `empty`, `failure`, or `dismissed`
- `visible_ms`
- `data_ms`
- `total_ms`
- `slow_bucket`: `under_1s`, `1_3s`, `3_5s`, `5_10s`, or `over_10s`

Optional safe parameters:

- `item_count`
- `initial_count`
- `has_more`
- `sort_mode`
- `feature_flag`

## Comments Sheet

The comments sheet must measure:

- tap/open intent to first rendered sheet frame
- tap/open intent to comments success, empty state, or failure
- count loaded
- whether video replies were enabled
- whether the user dismissed before data loaded

## Firebase Console Checks

Use Firebase Analytics events to inspect:

- `surface_load` filtered by `surface_name = comments_sheet`
- `slow_bucket` distribution
- p95/p99 in BigQuery export when available
- app version and platform breakdowns

Use Firebase Performance to inspect:

- network request traces for media/API domains
- custom traces only when the span represents a real user wait

## Divine Brain Check

Divine Brain is read-only from agent tooling. To make this contract discoverable
there, keep this document and the implementation PR detailed enough for the
GitHub ingest pipeline.

Before changing analytics behavior, search Divine Brain for recent context:

```text
Firebase Analytics mobile screen_view surface_load observability divine-mobile
```

After this PR merges and Brain's hourly ingest has run, verify that Brain can
find this contract by searching:

```text
analytics observability comments_sheet surface_load divine-mobile
```
```

- [ ] **Step 2: Commit the documentation contract**

Run:

```bash
git add docs/ANALYTICS_OBSERVABILITY.md docs/superpowers/plans/2026-06-12-surface-analytics-observability.md
git commit -m "docs(analytics): define mobile observability contract"
```

Expected: commit succeeds. This is the durable "add it to Divine Brain" path once the PR is merged and Brain ingests GitHub.

---

### Task 2: Stop Useless Native Screen Rows

**Files:**
- Modify: `mobile/ios/Runner/Info.plist`
- Modify: `mobile/android/app/src/main/AndroidManifest.xml`
- Modify: `mobile/lib/router/app_router.dart`
- Test: `mobile/test/services/page_load_observer_test.dart`

- [ ] **Step 1: Add native config regression checks**

Create or extend a native config test under `mobile/test/services/analytics_native_config_test.dart`:

```dart
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  group('Firebase Analytics native config', () {
    test('iOS disables automatic native screen reporting', () {
      final plist = File('ios/Runner/Info.plist').readAsStringSync();

      expect(plist, contains('<key>FirebaseAutomaticScreenReportingEnabled</key>'));
      expect(plist, contains('<false/>'));
    });

    test('Android disables automatic native screen reporting', () {
      final manifest = File(
        'android/app/src/main/AndroidManifest.xml',
      ).readAsStringSync();

      expect(
        manifest,
        contains('google_analytics_automatic_screen_reporting_enabled'),
      );
      expect(manifest, contains('android:value="false"'));
    });
  });
}
```

- [ ] **Step 2: Run the native config test and verify it fails**

Run from `mobile/`:

```bash
flutter test test/services/analytics_native_config_test.dart
```

Expected: FAIL because neither platform disables automatic native screen reporting yet.

- [ ] **Step 3: Disable native automatic screen reporting**

Add this to `mobile/ios/Runner/Info.plist` near existing Firebase keys:

```xml
<key>FirebaseAutomaticScreenReportingEnabled</key>
<false/>
```

Add this inside the `<application>` block in `mobile/android/app/src/main/AndroidManifest.xml`:

```xml
<meta-data
    android:name="google_analytics_automatic_screen_reporting_enabled"
    android:value="false" />
```

- [ ] **Step 4: Remove the generic Firebase route observer**

Modify `_buildRouterObservers()` in `mobile/lib/router/app_router.dart` so it no longer adds `FirebaseAnalyticsObserver`.

Keep:

```dart
final observers = <NavigatorObserver>[
  routeObserver,
  PageLoadObserver(),
  VideoStopNavigatorObserver(),
];
```

Remove:

```dart
if (Firebase.apps.isNotEmpty) {
  observers.add(
    FirebaseAnalyticsObserver(analytics: FirebaseAnalytics.instance),
  );
}
```

Also remove imports that become unused.

- [ ] **Step 5: Run the config and observer tests**

Run from `mobile/`:

```bash
flutter test test/services/analytics_native_config_test.dart test/services/page_load_observer_test.dart
```

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add mobile/ios/Runner/Info.plist mobile/android/app/src/main/AndroidManifest.xml mobile/lib/router/app_router.dart mobile/test/services/analytics_native_config_test.dart mobile/test/services/page_load_observer_test.dart
git commit -m "fix(analytics): disable native automatic screen reporting"
```

---

### Task 3: Add Semantic Analytics Names And A Testable Sink

**Files:**
- Create: `mobile/lib/services/analytics_surface.dart`
- Create: `mobile/lib/services/analytics_event_sink.dart`
- Create: `mobile/lib/services/firebase_analytics_event_sink.dart`
- Test: `mobile/test/services/analytics_surface_test.dart`
- Test: `mobile/test/services/analytics_event_sink_test.dart`

- [ ] **Step 1: Write surface-name tests**

Create `mobile/test/services/analytics_surface_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/services/analytics_surface.dart';

void main() {
  group('AnalyticsSurface', () {
    test('core surface names are stable snake_case values', () {
      expect(AnalyticsSurface.homeFeed, 'home_feed');
      expect(AnalyticsSurface.explore, 'explore');
      expect(AnalyticsSurface.profile, 'profile');
      expect(AnalyticsSurface.videoDetail, 'video_detail');
      expect(AnalyticsSurface.commentsSheet, 'comments_sheet');
      expect(AnalyticsSurface.settings, 'settings');
    });

    test('slowBucket classifies user-visible waits', () {
      expect(AnalyticsSurface.slowBucket(999), 'under_1s');
      expect(AnalyticsSurface.slowBucket(1000), '1_3s');
      expect(AnalyticsSurface.slowBucket(3000), '3_5s');
      expect(AnalyticsSurface.slowBucket(5000), '5_10s');
      expect(AnalyticsSurface.slowBucket(10000), 'over_10s');
    });
  });
}
```

- [ ] **Step 2: Run the test and verify it fails**

Run from `mobile/`:

```bash
flutter test test/services/analytics_surface_test.dart
```

Expected: FAIL because `analytics_surface.dart` does not exist.

- [ ] **Step 3: Create semantic names**

Create `mobile/lib/services/analytics_surface.dart`:

```dart
// ABOUTME: Stable semantic names and safe parameter helpers for analytics.

abstract final class AnalyticsSurface {
  static const homeFeed = 'home_feed';
  static const explore = 'explore';
  static const notifications = 'notifications';
  static const inbox = 'inbox';
  static const profile = 'profile';
  static const videoDetail = 'video_detail';
  static const commentsSheet = 'comments_sheet';
  static const settings = 'settings';
  static const searchResults = 'search_results';
  static const videoRecorder = 'video_recorder';
  static const videoEditor = 'video_editor';
  static const unknownRoute = 'unknown_route';

  static String slowBucket(int totalMs) {
    if (totalMs < 1000) return 'under_1s';
    if (totalMs < 3000) return '1_3s';
    if (totalMs < 5000) return '3_5s';
    if (totalMs < 10000) return '5_10s';
    return 'over_10s';
  }

  static String sanitizeName(String value) {
    final normalized = value
        .trim()
        .replaceAll(RegExp(r'[^A-Za-z0-9_]+'), '_')
        .replaceAll(RegExp(r'_+'), '_')
        .toLowerCase();
    return normalized.isEmpty ? unknownRoute : normalized;
  }
}

abstract final class AnalyticsParam {
  static const screenName = 'screen_name';
  static const surfaceName = 'surface_name';
  static const routeName = 'route_name';
  static const entryPoint = 'entry_point';
  static const result = 'result';
  static const visibleMs = 'visible_ms';
  static const dataMs = 'data_ms';
  static const totalMs = 'total_ms';
  static const slowBucket = 'slow_bucket';
  static const itemCount = 'item_count';
  static const initialCount = 'initial_count';
  static const hasMore = 'has_more';
  static const featureFlag = 'feature_flag';
}

abstract final class SurfaceLoadResult {
  static const success = 'success';
  static const empty = 'empty';
  static const failure = 'failure';
  static const dismissed = 'dismissed';
}
```

- [ ] **Step 4: Add a testable analytics sink**

Create `mobile/lib/services/analytics_event_sink.dart`:

```dart
// ABOUTME: Testable abstraction over analytics event delivery.

abstract interface class AnalyticsEventSink {
  Future<void> logEvent({
    required String name,
    required Map<String, Object> parameters,
  });

  Future<void> logScreenView({
    required String screenName,
    String? screenClass,
    Map<String, Object>? parameters,
  });
}

class NoOpAnalyticsEventSink implements AnalyticsEventSink {
  const NoOpAnalyticsEventSink();

  @override
  Future<void> logEvent({
    required String name,
    required Map<String, Object> parameters,
  }) async {}

  @override
  Future<void> logScreenView({
    required String screenName,
    String? screenClass,
    Map<String, Object>? parameters,
  }) async {}
}
```

Create `mobile/lib/services/firebase_analytics_event_sink.dart`:

```dart
// ABOUTME: Firebase-backed implementation of the analytics event sink.

import 'package:firebase_analytics/firebase_analytics.dart';
import 'package:openvine/services/analytics_event_sink.dart';

class FirebaseAnalyticsEventSink implements AnalyticsEventSink {
  FirebaseAnalyticsEventSink({FirebaseAnalytics? analytics})
    : _analytics = analytics ?? FirebaseAnalytics.instance;

  final FirebaseAnalytics _analytics;

  @override
  Future<void> logEvent({
    required String name,
    required Map<String, Object> parameters,
  }) {
    return _analytics.logEvent(name: name, parameters: parameters);
  }

  @override
  Future<void> logScreenView({
    required String screenName,
    String? screenClass,
    Map<String, Object>? parameters,
  }) {
    return _analytics.logScreenView(
      screenName: screenName,
      screenClass: screenClass,
      parameters: parameters,
    );
  }
}
```

- [ ] **Step 5: Run the surface tests**

```bash
flutter test test/services/analytics_surface_test.dart
```

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add mobile/lib/services/analytics_surface.dart mobile/lib/services/analytics_event_sink.dart mobile/lib/services/firebase_analytics_event_sink.dart mobile/test/services/analytics_surface_test.dart
git commit -m "feat(analytics): add semantic surface names"
```

---

### Task 4: Replace Generic Route Screen Views With App-Owned Screen Views

**Files:**
- Modify: `mobile/lib/services/page_load_observer.dart`
- Modify: `mobile/lib/services/screen_analytics_service.dart`
- Modify: `mobile/lib/router/app_router.dart`
- Test: `mobile/test/services/page_load_observer_test.dart`
- Test: `mobile/test/services/screen_analytics_service_test.dart`

- [ ] **Step 1: Add tests for route name normalization**

Extend `mobile/test/services/page_load_observer_test.dart` with a test that pushes a named route and verifies the observer can use the semantic name without crashing:

```dart
testWidgets('uses semantic route settings names for analytics', (tester) async {
  await tester.pumpWidget(
    MaterialApp(
      navigatorObservers: [observer],
      home: const Scaffold(body: Text('Home')),
      onGenerateRoute: (settings) {
        if (settings.name == '/video/123') {
          return MaterialPageRoute<void>(
            settings: const RouteSettings(name: 'video_detail'),
            builder: (_) => const Scaffold(body: Text('Video Detail')),
          );
        }
        return null;
      },
    ),
  );

  final context = tester.element(find.text('Home'));
  Navigator.of(context).pushNamed('/video/123');
  await tester.pumpAndSettle();

  expect(find.text('Video Detail'), findsOneWidget);
});
```

- [ ] **Step 2: Update `ScreenAnalyticsService` to use `AnalyticsEventSink`**

Change the test constructor to accept an `AnalyticsEventSink` and default production construction to `FirebaseAnalyticsEventSink` when Firebase is available. Keep existing public methods so current call sites keep compiling:

```dart
ScreenAnalyticsService._({
  AnalyticsEventSink? sink,
}) : _sink = sink ?? _createFirebaseSink(),
     _bypassAnalytics = false;

@visibleForTesting
ScreenAnalyticsService.testInstance({AnalyticsEventSink? sink})
  : _sink = sink ?? const NoOpAnalyticsEventSink(),
    _bypassAnalytics = true;
```

Replace direct `_analytics?.logEvent(...)` and `_analytics?.logScreenView(...)` calls with `_sink.logEvent(...)` and `_sink.logScreenView(...)`.

- [ ] **Step 3: Make route screen view logging explicit**

In `PageLoadObserver.didPush`, after deriving the semantic screen name, call:

```dart
_analytics.trackScreenView(
  screenName,
  params: {
    AnalyticsParam.routeName: screenName,
    AnalyticsParam.entryPoint: 'navigation',
  },
);
```

Keep `startScreenLoad` and `markContentVisible` so the existing `screen_load` event and developer options history still work.

- [ ] **Step 4: Add names to high-volume routes**

In `mobile/lib/router/app_router.dart`, add `name:` for the routes that should dominate Firebase reports:

```dart
GoRoute(
  name: AnalyticsSurface.homeFeed,
  path: VideoFeedPage.pathWithIndex,
  ...
)
GoRoute(
  name: AnalyticsSurface.explore,
  path: ExploreScreen.path,
  ...
)
GoRoute(
  name: AnalyticsSurface.notifications,
  path: NotificationsPage.pathWithIndex,
  ...
)
GoRoute(
  name: AnalyticsSurface.inbox,
  path: InboxPage.path,
  ...
)
GoRoute(
  name: AnalyticsSurface.profile,
  path: ProfileScreenRouter.path,
  ...
)
GoRoute(
  name: AnalyticsSurface.videoDetail,
  path: VideoDetailScreen.path,
  ...
)
GoRoute(
  name: AnalyticsSurface.settings,
  path: SettingsScreen.path,
  ...
)
```

Do not change paths or navigation behavior.

- [ ] **Step 5: Run focused tests**

Run from `mobile/`:

```bash
flutter test test/services/screen_analytics_service_test.dart test/services/page_load_observer_test.dart
```

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add mobile/lib/services/screen_analytics_service.dart mobile/lib/services/page_load_observer.dart mobile/lib/router/app_router.dart mobile/test/services/screen_analytics_service_test.dart mobile/test/services/page_load_observer_test.dart
git commit -m "fix(analytics): log semantic route screen views"
```

---

### Task 5: Add Surface Performance Tracking

**Files:**
- Create: `mobile/lib/services/surface_performance_tracker.dart`
- Test: `mobile/test/services/surface_performance_tracker_test.dart`
- Modify: `mobile/lib/widgets/app_lifecycle_handler.dart`

- [ ] **Step 1: Write failing service tests**

Create `mobile/test/services/surface_performance_tracker_test.dart`:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/services/analytics_event_sink.dart';
import 'package:openvine/services/analytics_surface.dart';
import 'package:openvine/services/surface_performance_tracker.dart';

class RecordingAnalyticsEventSink implements AnalyticsEventSink {
  final events = <({String name, Map<String, Object> parameters})>[];

  @override
  Future<void> logEvent({
    required String name,
    required Map<String, Object> parameters,
  }) async {
    events.add((name: name, parameters: parameters));
  }

  @override
  Future<void> logScreenView({
    required String screenName,
    String? screenClass,
    Map<String, Object>? parameters,
  }) async {}
}

void main() {
  group(SurfacePerformanceTracker, () {
    late RecordingAnalyticsEventSink sink;
    late SurfacePerformanceTracker tracker;

    setUp(() {
      sink = RecordingAnalyticsEventSink();
      tracker = SurfacePerformanceTracker.testInstance(sink: sink);
    });

    test('logs one surface_load event with semantic parameters', () async {
      tracker.startSurfaceLoad(
        AnalyticsSurface.commentsSheet,
        params: const {
          AnalyticsParam.entryPoint: 'feed_button',
          AnalyticsParam.initialCount: 12,
        },
      );
      tracker.markSurfaceVisible(AnalyticsSurface.commentsSheet);
      await tracker.completeSurfaceLoad(
        AnalyticsSurface.commentsSheet,
        result: SurfaceLoadResult.success,
        metrics: const {
          AnalyticsParam.itemCount: 10,
          AnalyticsParam.hasMore: true,
        },
      );

      expect(sink.events, hasLength(1));
      expect(sink.events.single.name, 'surface_load');
      expect(
        sink.events.single.parameters[AnalyticsParam.surfaceName],
        AnalyticsSurface.commentsSheet,
      );
      expect(
        sink.events.single.parameters[AnalyticsParam.result],
        SurfaceLoadResult.success,
      );
      expect(sink.events.single.parameters[AnalyticsParam.itemCount], 10);
    });

    test('dismissed surfaces complete instead of leaking active sessions', () async {
      tracker.startSurfaceLoad(AnalyticsSurface.commentsSheet);
      await tracker.completeSurfaceLoad(
        AnalyticsSurface.commentsSheet,
        result: SurfaceLoadResult.dismissed,
      );

      expect(tracker.activeSessionCount, 0);
      expect(sink.events.single.parameters[AnalyticsParam.result], 'dismissed');
    });
  });
}
```

- [ ] **Step 2: Run the tests and verify they fail**

Run from `mobile/`:

```bash
flutter test test/services/surface_performance_tracker_test.dart
```

Expected: FAIL because `SurfacePerformanceTracker` does not exist.

- [ ] **Step 3: Implement `SurfacePerformanceTracker`**

Create `mobile/lib/services/surface_performance_tracker.dart`:

```dart
// ABOUTME: Tracks user-visible surface load timing with semantic analytics.

import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:openvine/services/analytics_event_sink.dart';
import 'package:openvine/services/analytics_surface.dart';
import 'package:openvine/services/firebase_analytics_event_sink.dart';
import 'package:unified_logger/unified_logger.dart';

const _maxSurfaceSessionAge = Duration(seconds: 60);

class SurfacePerformanceTracker {
  factory SurfacePerformanceTracker() =>
      _instance ??= SurfacePerformanceTracker._();

  SurfacePerformanceTracker._({AnalyticsEventSink? sink})
      : _sink = sink ?? FirebaseAnalyticsEventSink();

  @visibleForTesting
  SurfacePerformanceTracker.testInstance({AnalyticsEventSink? sink})
      : _sink = sink ?? const NoOpAnalyticsEventSink();

  static SurfacePerformanceTracker? _instance;

  @visibleForTesting
  static void resetInstance() {
    _instance?._activeSessions.clear();
    _instance = null;
  }

  final AnalyticsEventSink _sink;
  final Map<String, _SurfaceLoadSession> _activeSessions = {};

  int get activeSessionCount => _activeSessions.length;

  void resetAllSessions() {
    _activeSessions.clear();
  }

  void startSurfaceLoad(String surfaceName, {Map<String, Object>? params}) {
    final safeName = AnalyticsSurface.sanitizeName(surfaceName);
    _activeSessions[safeName] = _SurfaceLoadSession(
      surfaceName: safeName,
      startedAt: DateTime.now(),
      params: params ?? const {},
    );
  }

  void markSurfaceVisible(String surfaceName) {
    final session = _sessionFor(surfaceName);
    if (session == null) return;
    session.visibleAt ??= DateTime.now();
  }

  Future<void> completeSurfaceLoad(
    String surfaceName, {
    required String result,
    Map<String, Object>? metrics,
  }) async {
    final safeName = AnalyticsSurface.sanitizeName(surfaceName);
    final session = _activeSessions.remove(safeName);
    if (session == null || _isStale(session)) return;

    final completedAt = DateTime.now();
    final visibleMs = session.visibleAt == null
        ? -1
        : session.visibleAt!.difference(session.startedAt).inMilliseconds;
    final totalMs = completedAt.difference(session.startedAt).inMilliseconds;

    final params = <String, Object>{
      AnalyticsParam.surfaceName: safeName,
      AnalyticsParam.result: result,
      AnalyticsParam.visibleMs: visibleMs,
      AnalyticsParam.dataMs: totalMs,
      AnalyticsParam.totalMs: totalMs,
      AnalyticsParam.slowBucket: AnalyticsSurface.slowBucket(totalMs),
      ...session.params,
      ...?metrics,
    };

    await _sink.logEvent(name: 'surface_load', parameters: params);

    final slowFlag = totalMs >= 3000 ? ' [SLOW]' : '';
    UnifiedLogger.info(
      'PERF: $safeName surface result=$result total=${totalMs}ms$slowFlag',
      name: 'SurfacePerf',
    );
  }

  _SurfaceLoadSession? _sessionFor(String surfaceName) {
    final safeName = AnalyticsSurface.sanitizeName(surfaceName);
    final session = _activeSessions[safeName];
    if (session == null) return null;
    if (_isStale(session)) {
      _activeSessions.remove(safeName);
      return null;
    }
    return session;
  }

  bool _isStale(_SurfaceLoadSession session) {
    return DateTime.now().difference(session.startedAt) > _maxSurfaceSessionAge;
  }
}

class _SurfaceLoadSession {
  _SurfaceLoadSession({
    required this.surfaceName,
    required this.startedAt,
    required this.params,
  });

  final String surfaceName;
  final DateTime startedAt;
  final Map<String, Object> params;
  DateTime? visibleAt;
}
```

- [ ] **Step 4: Reset surface sessions on app resume**

In `mobile/lib/widgets/app_lifecycle_handler.dart`, wherever `ScreenAnalyticsService().resetAllSessions()` is called on resume, also call:

```dart
SurfacePerformanceTracker().resetAllSessions();
```

- [ ] **Step 5: Run tests**

Run from `mobile/`:

```bash
flutter test test/services/surface_performance_tracker_test.dart test/services/screen_analytics_service_test.dart
```

Expected: PASS.

- [ ] **Step 6: Commit**

```bash
git add mobile/lib/services/surface_performance_tracker.dart mobile/lib/widgets/app_lifecycle_handler.dart mobile/test/services/surface_performance_tracker_test.dart
git commit -m "feat(analytics): add surface performance tracker"
```

---

### Task 6: Instrument Comments Sheet Perceived Load

**Files:**
- Modify: `mobile/lib/screens/comments/comments_screen.dart`
- Test: `mobile/test/screens/comments/comments_screen_test.dart`

- [ ] **Step 1: Add comments telemetry widget coverage**

Add or extend comments screen tests to verify that comments success logs a terminal surface event. Use `SurfacePerformanceTracker.testInstance` with `RecordingAnalyticsEventSink` from the service test, or move that helper into `mobile/test/helpers/recording_analytics_event_sink.dart`.

The test should exercise:

```dart
expect(
  sink.events.where((event) => event.name == 'surface_load'),
  hasLength(1),
);
expect(
  sink.events.single.parameters[AnalyticsParam.surfaceName],
  AnalyticsSurface.commentsSheet,
);
expect(
  sink.events.single.parameters[AnalyticsParam.result],
  anyOf(SurfaceLoadResult.success, SurfaceLoadResult.empty),
);
```

- [ ] **Step 2: Run the comments telemetry test and verify it fails**

Run from `mobile/`:

```bash
flutter test test/screens/comments/comments_screen_test.dart
```

Expected: FAIL because comments does not call `SurfacePerformanceTracker` yet.

- [ ] **Step 3: Start the comments surface load on open**

In `CommentsScreen.show`, before `context.showVideoPausingVineBottomSheet`, add:

```dart
final surfaceTracker = SurfacePerformanceTracker();
surfaceTracker.startSurfaceLoad(
  AnalyticsSurface.commentsSheet,
  params: {
    AnalyticsParam.entryPoint: 'feed_comment_button',
    if (seedCommentCount != null) AnalyticsParam.initialCount: seedCommentCount,
    AnalyticsParam.featureFlag: showVideoReplies
        ? 'video_replies_enabled'
        : 'video_replies_disabled',
  },
);
```

- [ ] **Step 4: Mark the sheet visible after first frame**

Wrap the comments sheet body in a small stateful widget or add an existing body `initState` callback that runs:

```dart
WidgetsBinding.instance.addPostFrameCallback((_) {
  SurfacePerformanceTracker().markSurfaceVisible(
    AnalyticsSurface.commentsSheet,
  );
});
```

- [ ] **Step 5: Complete on comments success, empty, or failure**

Add a `BlocListener<CommentsListBloc, CommentsListState>` around the comments body. When `status` changes from `loading` to `success`:

```dart
final result = state.commentsById.isEmpty
    ? SurfaceLoadResult.empty
    : SurfaceLoadResult.success;
unawaited(
  SurfacePerformanceTracker().completeSurfaceLoad(
    AnalyticsSurface.commentsSheet,
    result: result,
    metrics: {
      AnalyticsParam.itemCount: state.commentsById.length,
      AnalyticsParam.hasMore: state.hasMoreContent,
      'sort_mode': state.sortMode.name,
    },
  ),
);
```

When `status` changes from `loading` to `failure`:

```dart
unawaited(
  SurfacePerformanceTracker().completeSurfaceLoad(
    AnalyticsSurface.commentsSheet,
    result: SurfaceLoadResult.failure,
    metrics: const {'failure_type': 'comments_load_failed'},
  ),
);
```

- [ ] **Step 6: Complete as dismissed if the sheet closes before data finishes**

Await the `showVideoPausingVineBottomSheet` future and then call dismissed completion. This is safe because `completeSurfaceLoad` is a no-op after success/failure removes the active session:

```dart
return context
    .showVideoPausingVineBottomSheet<void>(...)
    .whenComplete(() {
      unawaited(
        SurfacePerformanceTracker().completeSurfaceLoad(
          AnalyticsSurface.commentsSheet,
          result: SurfaceLoadResult.dismissed,
        ),
      );
    });
```

- [ ] **Step 7: Run comments tests**

Run from `mobile/`:

```bash
flutter test test/screens/comments/comments_screen_test.dart test/services/surface_performance_tracker_test.dart
```

Expected: PASS.

- [ ] **Step 8: Commit**

```bash
git add mobile/lib/screens/comments/comments_screen.dart mobile/test/screens/comments/comments_screen_test.dart
git commit -m "feat(comments): track comments sheet load performance"
```

---

### Task 7: Add Debug Visibility And Dashboard Handoff

**Files:**
- Modify: `mobile/lib/services/page_load_history.dart`
- Modify: `mobile/lib/screens/developer_options_screen.dart`
- Modify: `docs/ANALYTICS_OBSERVABILITY.md`
- Test: `mobile/test/services/page_load_history_test.dart`

- [ ] **Step 1: Add a `surfaceName`/`result` capable record shape**

Extend `PageLoadRecord` only if needed to display `surface_load` records in Developer Options. Keep existing fields compatible:

```dart
final String? result;
final String? source;
```

Use `source = 'route'` for route loads and `source = 'surface'` for comments sheet loads.

- [ ] **Step 2: Show recent slow surfaces in Developer Options**

Add a small section under existing page load history that shows:

- surface/screen name
- result
- visible ms
- data/total ms
- slow marker

No user-facing production copy changes are required because Developer Options is internal/debug.

- [ ] **Step 3: Update the analytics doc with Firebase dashboard instructions**

Append:

```markdown
## First Dashboard To Build

Create a Firebase/GA4 exploration or BigQuery query for:

- event name: `surface_load`
- dimension: `surface_name`
- dimension: `slow_bucket`
- dimension: `result`
- metric: event count
- metric: p95/p99 of `total_ms`

First target filter:

```text
surface_name = comments_sheet
```
```

- [ ] **Step 4: Run focused tests**

Run from `mobile/`:

```bash
flutter test test/services/page_load_history_test.dart
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add mobile/lib/services/page_load_history.dart mobile/lib/screens/developer_options_screen.dart mobile/test/services/page_load_history_test.dart docs/ANALYTICS_OBSERVABILITY.md
git commit -m "feat(analytics): show slow surfaces in developer options"
```

---

### Task 8: Verification, Firebase Sanity Check, And Divine Brain Follow-Up

**Files:**
- Review all touched files
- No new code files

- [ ] **Step 1: Run focused service and comments tests**

Run from `mobile/`:

```bash
flutter test \
  test/services/analytics_surface_test.dart \
  test/services/analytics_native_config_test.dart \
  test/services/screen_analytics_service_test.dart \
  test/services/page_load_observer_test.dart \
  test/services/surface_performance_tracker_test.dart \
  test/screens/comments/comments_screen_test.dart
```

Expected: PASS.

- [ ] **Step 2: Run analyzer for touched app paths**

Run from `mobile/`:

```bash
flutter analyze \
  lib/services \
  lib/router/app_router.dart \
  lib/screens/comments/comments_screen.dart \
  lib/widgets/app_lifecycle_handler.dart \
  test/services \
  test/screens/comments
```

Expected: no analyzer errors.

- [ ] **Step 3: Manually verify Firebase event shape in a debug/profile run**

Run the app, open a feed video's comments, wait for comments to load, then close the sheet.

Expected debug logs include:

```text
PERF: comments_sheet surface result=success total=<n>ms
```

Expected Firebase DebugView or next-day console data includes:

- `screen_view` with useful `screen_name` values like `home_feed`, `explore`, `video_detail`
- no new `FlutterViewController` / `MainActivity` rows from app-owned logging
- `surface_load` with `surface_name = comments_sheet`
- `slow_bucket` for comments loads over 3 seconds

- [ ] **Step 4: Search Divine Brain before PR description**

Run a Divine Brain search:

```text
Firebase Analytics mobile screen_view surface_load observability divine-mobile
```

Expected: either this plan/docs appear if already ingested, or no prior context appears. Include the result in the PR description.

- [ ] **Step 5: Open the PR**

Run:

```bash
git status --short
git log --oneline origin/main..HEAD
gh pr create \
  --base main \
  --title "feat(analytics): track semantic mobile surface performance" \
  --body "$(cat <<'EOF'
## Summary
- disables Firebase native automatic screen rows that produce `FlutterViewController` / `MainActivity`
- logs app-owned semantic screen names
- adds `surface_load` timing for user-visible surfaces
- instruments the comments sheet as the first slow-surface target
- documents the analytics contract and Divine Brain verification workflow

## Verification
- flutter test test/services/analytics_surface_test.dart test/services/analytics_native_config_test.dart test/services/screen_analytics_service_test.dart test/services/page_load_observer_test.dart test/services/surface_performance_tracker_test.dart test/screens/comments/comments_screen_test.dart
- flutter analyze lib/services lib/router/app_router.dart lib/screens/comments/comments_screen.dart lib/widgets/app_lifecycle_handler.dart test/services test/screens/comments

## Divine Brain
- Pre-implementation search found no prior mobile analytics contract for this exact topic.
- After merge, Brain should ingest docs/ANALYTICS_OBSERVABILITY.md from GitHub.
EOF
)"
```

Expected: PR opens against `main` with a semantic title.

- [ ] **Step 6: Verify post-merge Brain ingest**

After the PR merges and the hourly Divine Brain ingest has run, search:

```text
analytics observability comments_sheet surface_load divine-mobile
```

Expected: Brain returns the analytics contract or implementation PR. If not, inspect Brain's GitHub ingest status.

---

## Self-Review

- Spec coverage: The plan fixes useless Firebase screen rows, adds semantic screen names, adds real perceived-load telemetry for comments, and makes the analytics contract discoverable through the GitHub-to-Divine-Brain ingest path.
- Placeholder scan: No unresolved placeholders or unspecified test commands remain.
- Type consistency: `AnalyticsSurface`, `AnalyticsParam`, `SurfaceLoadResult`, `AnalyticsEventSink`, and `SurfacePerformanceTracker` names are consistent across tasks.
- Scope check: This is intentionally scoped to route screen naming plus comments sheet performance. Other slow surfaces should be added after this lands by reusing `SurfacePerformanceTracker`.
