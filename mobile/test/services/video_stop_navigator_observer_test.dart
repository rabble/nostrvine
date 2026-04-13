import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/services/video_stop_navigator_observer.dart';

void main() {
  group(VideoStopNavigatorObserver, () {
    late VideoStopNavigatorObserver observer;

    setUp(() {
      observer = VideoStopNavigatorObserver();
    });

    test('can be instantiated', () {
      expect(observer, isA<NavigatorObserver>());
    });

    test('handles null navigator gracefully in didPush', () {
      // navigator is null when observer is not attached to a Navigator.
      // This should not throw.
      final route = _FakeRoute(name: 'test-route');
      expect(
        () => observer.didPush(route, null),
        returnsNormally,
      );
    });

    test('handles null navigator gracefully in didStartUserGesture', () {
      final route = _FakeRoute(name: 'test-route');
      expect(
        () => observer.didStartUserGesture(route, null),
        returnsNormally,
      );
    });

    test('skips video disposal for PopupRoute in didPush', () {
      final route = _FakePopupRoute();
      // Should return early without attempting to access navigator.
      expect(
        () => observer.didPush(route, null),
        returnsNormally,
      );
    });

    test('skips video disposal for PopupRoute in didStartUserGesture', () {
      final route = _FakePopupRoute();
      expect(
        () => observer.didStartUserGesture(route, null),
        returnsNormally,
      );
    });
  });
}

class _FakeRoute extends Fake implements Route<dynamic> {
  _FakeRoute({this.name});

  final String? name;

  @override
  RouteSettings get settings => RouteSettings(name: name);

  @override
  bool get isActive => true;
}

class _FakePopupRoute extends Fake implements PopupRoute<dynamic> {
  @override
  RouteSettings get settings => const RouteSettings(name: 'popup');

  @override
  bool get isActive => true;
}
