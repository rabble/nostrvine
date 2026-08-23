// ABOUTME: Pins the difference between getPosition and recordedPosition
// ABOUTME: getPosition defaults notifications to 0, which hid a routing bug

import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/router/providers/providers.dart';

void main() {
  late StreamController<String> locations;
  late ProviderContainer container;

  setUp(() {
    locations = StreamController<String>.broadcast();
    container = ProviderContainer(
      overrides: [
        routerLocationStreamProvider.overrideWithValue(locations.stream),
      ],
    );
    container.read(lastTabPositionProvider);
    container.listen(pageContextProvider, (_, _) {});
  });

  tearDown(() {
    container.dispose();
    locations.close();
  });

  Future<void> visit(List<String> paths) async {
    for (final path in paths) {
      locations.add(path);
      await pumpEventQueue();
    }
  }

  group('LastTabPosition', () {
    group('getPosition', () {
      test('defaults notifications to 0 even when never visited', () {
        expect(
          container
              .read(lastTabPositionProvider.notifier)
              .getPosition(RouteType.notifications),
          equals(0),
          reason:
              'This default is the whole reason recordedPosition exists — a '
              'caller cannot tell "never opened" from "opened at index 0".',
        );
      });

      test('leaves explore null so it opens in grid mode', () {
        expect(
          container
              .read(lastTabPositionProvider.notifier)
              .getPosition(RouteType.explore),
          isNull,
        );
      });
    });

    group('recordedPosition', () {
      // Regression for #3337: back navigation to tab 2 read getPosition, got
      // 0, and sent a user who had only ever opened the Inbox into the
      // notification video feed instead.
      test('is null for notifications until one is actually opened', () {
        expect(
          container
              .read(lastTabPositionProvider.notifier)
              .recordedPosition(RouteType.notifications),
          isNull,
        );
      });

      test('reports the index once a notification feed is visited', () async {
        await visit(['/notifications/3']);

        expect(
          container
              .read(lastTabPositionProvider.notifier)
              .recordedPosition(RouteType.notifications),
          equals(3),
        );
      });

      test(
        'stays null for notifications after only visiting the inbox',
        () async {
          await visit(['/home/0', '/inbox']);

          expect(
            container
                .read(lastTabPositionProvider.notifier)
                .recordedPosition(RouteType.notifications),
            isNull,
            reason: '/inbox is RouteType.inbox, not a notification feed',
          );
        },
      );
    });
  });
}
