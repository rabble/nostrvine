// ABOUTME: Pins that fadeUpwardsPage carries go_router page metadata
// ABOUTME: Regression test for PageLoadObserver reporting unknown_route

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/router/fade_upwards_page.dart';

class _FakeGoRouterState extends Fake implements GoRouterState {
  _FakeGoRouterState({
    required this.pageKey,
    this.name,
    this.path,
    this.pathParameters = const {},
    Uri? uri,
  }) : uri = uri ?? Uri.parse('/');

  @override
  final ValueKey<String> pageKey;

  @override
  final String? name;

  @override
  final String? path;

  @override
  final Map<String, String> pathParameters;

  @override
  final Uri uri;
}

void main() {
  group('fadeUpwardsPage', () {
    test('is a CustomTransitionPage (keeps the fade-upwards transition)', () {
      final page = fadeUpwardsPage(
        state: _FakeGoRouterState(
          pageKey: const ValueKey('video-recorder'),
          name: 'video-recorder',
          path: '/video-recorder',
        ),
        child: const SizedBox.shrink(),
      );

      expect(page, isA<CustomTransitionPage<void>>());
      expect(page.key, const ValueKey('video-recorder'));
    });

    test('carries the route name and restorationId so root-navigator '
        'observers resolve a real surface, not unknown_route', () {
      // A nameless CustomTransitionPage makes route.settings.name null,
      // which PageLoadObserver maps to `unknown_route` — the regression
      // this pins. See #5983.
      final page = fadeUpwardsPage(
        state: _FakeGoRouterState(
          pageKey: const ValueKey('video-recorder'),
          name: 'video-recorder',
          path: '/video-recorder',
        ),
        child: const SizedBox.shrink(),
      );

      expect(page.name, 'video-recorder');
      expect(page.restorationId, 'video-recorder');
    });

    test('falls back to the route path when the route has no name', () {
      final page = fadeUpwardsPage(
        state: _FakeGoRouterState(
          pageKey: const ValueKey('/drafts'),
          path: '/drafts',
        ),
        child: const SizedBox.shrink(),
      );

      expect(page.name, '/drafts');
    });

    test('merges path and query parameters into arguments', () {
      final page = fadeUpwardsPage(
        state: _FakeGoRouterState(
          pageKey: const ValueKey('clips'),
          name: 'clips',
          path: '/clips',
          pathParameters: const {'id': '42'},
          uri: Uri.parse('/clips?tab=recent'),
        ),
        child: const SizedBox.shrink(),
      );

      expect(page.arguments, {'id': '42', 'tab': 'recent'});
    });
  });
}
