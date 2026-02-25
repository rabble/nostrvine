// ABOUTME: Unit tests for DisposedControllersTracker class
// ABOUTME: Tests the ChangeNotifier-based tracker for disposed video controllers

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/providers/individual_video_providers.dart';

void main() {
  group(DisposedControllersTracker, () {
    late DisposedControllersTracker tracker;
    late int notifyCount;

    setUp(() {
      tracker = DisposedControllersTracker();
      notifyCount = 0;
      tracker.addListener(() => notifyCount++);
    });

    tearDown(() {
      tracker.dispose();
    });

    group('markDisposed', () {
      test('adds videoId and notifies listeners', () async {
        tracker.markDisposed('video-1');

        expect(tracker.contains('video-1'), isTrue);
        // Notification is deferred to a microtask
        await Future<void>.delayed(Duration.zero);
        expect(notifyCount, equals(1));
      });

      test('does not notify when marking same videoId twice', () async {
        tracker.markDisposed('video-1');
        tracker.markDisposed('video-1');

        expect(tracker.contains('video-1'), isTrue);
        await Future<void>.delayed(Duration.zero);
        expect(notifyCount, equals(1));
      });

      test('tracks multiple videoIds independently', () async {
        tracker.markDisposed('video-1');
        tracker.markDisposed('video-2');
        tracker.markDisposed('video-3');

        expect(tracker.contains('video-1'), isTrue);
        expect(tracker.contains('video-2'), isTrue);
        expect(tracker.contains('video-3'), isTrue);
        await Future<void>.delayed(Duration.zero);
        expect(notifyCount, equals(3));
      });
    });

    group('clearDisposed', () {
      test('removes videoId and notifies listeners', () async {
        tracker.markDisposed('video-1');
        await Future<void>.delayed(Duration.zero);
        notifyCount = 0;

        tracker.clearDisposed('video-1');

        expect(tracker.contains('video-1'), isFalse);
        expect(notifyCount, equals(1));
      });

      test('does not notify when clearing non-existent videoId', () {
        tracker.clearDisposed('video-1');

        expect(tracker.contains('video-1'), isFalse);
        expect(notifyCount, equals(0));
      });

      test('clearing same videoId twice only notifies once', () async {
        tracker.markDisposed('video-1');
        await Future<void>.delayed(Duration.zero);
        notifyCount = 0;

        tracker.clearDisposed('video-1');
        tracker.clearDisposed('video-1');

        expect(tracker.contains('video-1'), isFalse);
        expect(notifyCount, equals(1));
      });
    });

    group('contains', () {
      test('returns false for unknown videoId', () {
        expect(tracker.contains('unknown'), isFalse);
      });

      test('returns true after markDisposed', () {
        tracker.markDisposed('video-1');

        expect(tracker.contains('video-1'), isTrue);
      });

      test('returns false after clearDisposed', () async {
        tracker.markDisposed('video-1');
        await Future<void>.delayed(Duration.zero);
        tracker.clearDisposed('video-1');

        expect(tracker.contains('video-1'), isFalse);
      });
    });

    group('ids', () {
      test('returns empty set initially', () {
        expect(tracker.ids, isEmpty);
      });

      test('returns set of all marked videoIds', () {
        tracker.markDisposed('video-1');
        tracker.markDisposed('video-2');

        expect(tracker.ids, containsAll(['video-1', 'video-2']));
        expect(tracker.ids.length, equals(2));
      });

      test('returns unmodifiable set', () {
        tracker.markDisposed('video-1');

        expect(
          () => tracker.ids.add('video-2'),
          throwsA(isA<UnsupportedError>()),
        );
      });

      test('does not include cleared videoIds', () async {
        tracker.markDisposed('video-1');
        tracker.markDisposed('video-2');
        await Future<void>.delayed(Duration.zero);
        tracker.clearDisposed('video-1');

        expect(tracker.ids, contains('video-2'));
        expect(tracker.ids, isNot(contains('video-1')));
        expect(tracker.ids.length, equals(1));
      });
    });
  });
}
