// ABOUTME: Tests that the local echo records published events and never lets
// ABOUTME: a failed cache write surface to the publish path.

import 'package:flutter_test/flutter_test.dart';
import 'package:nostr_sdk/event.dart';
import 'package:openvine/services/published_event_local_echo.dart';

const _pubkey =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';

Event _videoEvent() => Event(
  _pubkey,
  34236,
  [
    ['d', 'published-d-tag'],
  ],
  'a video',
);

void main() {
  group(PublishedEventLocalEcho, () {
    test('writes the published event through', () async {
      final written = <Event>[];
      final echo = PublishedEventLocalEcho((event) async => written.add(event));
      final event = _videoEvent();

      await echo.record(event);

      expect(written.single.id, equals(event.id));
    });

    test('swallows a failed write', () async {
      // The video is already live on the relay by this point. Losing the
      // read-back optimisation must not propagate into the publish path and
      // turn a successful publish into a failed one.
      final echo = PublishedEventLocalEcho(
        (_) async => throw Exception('disk full'),
      );

      await expectLater(echo.record(_videoEvent()), completes);
    });

    test('swallows a writer that throws synchronously', () async {
      final echo = PublishedEventLocalEcho((_) => throw StateError('closed'));

      await expectLater(echo.record(_videoEvent()), completes);
    });
  });
}
