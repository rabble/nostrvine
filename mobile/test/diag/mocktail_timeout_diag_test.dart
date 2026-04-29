// ABOUTME: Pinned regression tests for the mocktail + Future.timeout gotcha.
// ABOUTME: When mocktail's thenAnswer((_) async => value) infers a non-nullable
// ABOUTME: Future<T>, .timeout(onTimeout: () => null) throws a runtime TypeError
// ABOUTME: because Null is not a subtype of FutureOr<T>. Production code in
// ABOUTME: video_event_publisher.dart sidesteps this by using try/catch on
// ABOUTME: TimeoutException; this file locks the gotcha so future contributors
// ABOUTME: don't reach for onTimeout when stubbing publishEvent in tests.

import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/event.dart';

class _MockNostrClient extends Mock implements NostrClient {}

class _FakeEvent extends Fake implements Event {}

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeEvent());
  });

  group('mocktail + Future.timeout interaction', () {
    late _MockNostrClient mock;
    late Event event;

    setUp(() {
      mock = _MockNostrClient();
      event = Event(
        '385c3a6ec0b9d57a4330dbd6284989be5bd00e41c535f9ca39b6ae7c521b81cd',
        1,
        const [],
        'diag',
      );
    });

    test(
      'plain mocktail thenAnswer + await returns the stubbed event',
      () async {
        when(
          () => mock.publishEvent(any()),
        ).thenAnswer((_) async => event);

        final result = await mock.publishEvent(event);

        expect(result, equals(event));
      },
    );

    test(
      'GOTCHA: mocktail thenAnswer((_) async => event) + .timeout(onTimeout: '
      '() => null) throws TypeError at runtime because the stubbed Future has '
      'lost the ? nullability of the declared signature',
      () async {
        when(
          () => mock.publishEvent(any()),
        ).thenAnswer((_) async => event);

        await expectLater(
          () async => mock
              .publishEvent(event)
              .timeout(
                const Duration(seconds: 30),
                onTimeout: () => null,
              ),
          throwsA(
            isA<TypeError>().having(
              (e) => e.toString(),
              'message',
              contains("'() => Null' is not a subtype of"),
            ),
          ),
          reason:
              'If this assertion starts failing because no error was thrown, '
              'mocktail or Dart fixed the inference and the try/catch '
              'workaround in video_event_publisher.dart can be dropped.',
        );
      },
    );

    test(
      'WORKAROUND A: try/catch on TimeoutException avoids the closure-cast '
      'trap (this is the production-code shape)',
      () async {
        when(
          () => mock.publishEvent(any()),
        ).thenAnswer((_) async => event);

        Event? result;
        try {
          result = await mock
              .publishEvent(event)
              .timeout(const Duration(seconds: 30));
        } on TimeoutException {
          result = null;
        }

        expect(result, equals(event));
      },
    );

    test(
      'WORKAROUND B: stubbing with Future<Event?>.value(event) preserves '
      'nullability so onTimeout: () => null also works',
      () async {
        when(
          () => mock.publishEvent(any()),
        ).thenAnswer((_) => Future<Event?>.value(event));

        final result = await mock
            .publishEvent(event)
            .timeout(
              const Duration(seconds: 30),
              onTimeout: () => null,
            );

        expect(result, equals(event));
      },
    );

    test(
      'sanity: plain Future.value with the right type + .timeout works',
      () async {
        // Confirms the gotcha is mocktail-specific, not a Dart stdlib issue.
        final source = Future<Event?>.value(event);
        final result = await source.timeout(
          const Duration(seconds: 30),
          onTimeout: () => null,
        );
        expect(result, equals(event));
      },
    );
  });
}
