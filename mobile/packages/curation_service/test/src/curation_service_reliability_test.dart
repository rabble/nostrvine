// ABOUTME: Tests that CurationService uses publishEventWithRetry for kind
// ABOUTME: 30005 curation-set publishes and gates results on acceptedByAny.

import 'dart:async';

import 'package:curation_service/curation_service.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:likes_repository/likes_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/filter.dart';
import 'package:nostr_sdk/signer/nostr_signer.dart';

class _MockNostrClient extends Mock implements NostrClient {}

class _MockVideoEventCache extends Mock implements VideoEventCache {}

class _MockLikesRepository extends Mock implements LikesRepository {}

class _MockNostrSigner extends Mock implements NostrSigner {}

const _testPubkey =
    'a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6'
    'e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1b2';

Event _buildEvent({
  int kind = 30005,
  List<List<String>> tags = const [],
  String content = '',
}) {
  return Event(_testPubkey, kind, tags, content);
}

void main() {
  setUpAll(() {
    registerFallbackValue(<Filter>[]);
    registerFallbackValue(_buildEvent());
    registerFallbackValue(<String>[]);
    registerFallbackValue(const RetryPolicy());
  });

  late CurationService service;
  late _MockNostrClient mockNostr;
  late _MockVideoEventCache mockCache;
  late _MockLikesRepository mockLikes;
  late _MockNostrSigner mockSigner;

  setUp(() {
    mockNostr = _MockNostrClient();
    mockCache = _MockVideoEventCache();
    mockLikes = _MockLikesRepository();
    mockSigner = _MockNostrSigner();

    when(() => mockSigner.getPublicKey()).thenAnswer((_) async => _testPubkey);
    when(() => mockSigner.signEvent(any())).thenAnswer((invocation) async {
      final e = invocation.positionalArguments[0] as Event;
      return Event(e.pubkey, e.kind, e.tags, e.content);
    });

    when(() => mockNostr.connectedRelays).thenReturn([
      'wss://relay1.example.com',
    ]);
    when(
      () => mockNostr.subscribe(any()),
    ).thenAnswer((_) => const Stream.empty());

    when(() => mockCache.discoveryVideos).thenReturn([]);
    when(() => mockLikes.getLikeCounts(any())).thenAnswer((_) async => {});

    service = CurationService(
      nostrService: mockNostr,
      videoEventCache: mockCache,
      likesRepository: mockLikes,
      signer: mockSigner,
      divineTeamPubkeys: const [],
    );
  });

  PublishOutcome acceptedOutcome() => PublishOutcome(
    eventId: 'a' * 64,
    acceptedBy: const {'wss://a'},
    rejectedBy: const {},
    noResponseFrom: const {},
  );

  PublishOutcome transientOutcome() => PublishOutcome(
    eventId: 'a' * 64,
    acceptedBy: const {},
    rejectedBy: const {},
    noResponseFrom: const {'wss://a'},
  );

  PublishOutcome rejectedOutcome() => PublishOutcome(
    eventId: 'a' * 64,
    acceptedBy: const {},
    rejectedBy: const {'wss://a': 'blocked: not allowed'},
    noResponseFrom: const {},
  );

  group('CurationService reliability', () {
    test(
      'accepted-by-any → CurationResult.success with feedback.severity=success',
      () async {
        when(
          () => mockNostr.publishEventWithRetry(
            any(),
            policy: any(named: 'policy'),
            targetRelays: any(named: 'targetRelays'),
          ),
        ).thenAnswer((_) async => acceptedOutcome());

        final result = await service.publishCuration(
          id: 'curation_ok',
          title: 'Test',
          videoIds: const ['v1'],
        );

        expect(result.success, isTrue);
        expect(result.feedback?.severity, PublishSeverity.success);
        expect(result.feedback?.retryable, isFalse);
        expect(result.outcome?.acceptedBy, {'wss://a'});

        final status = service.getCurationPublishStatus('curation_ok');
        expect(status.isPublished, isTrue);
      },
    );

    test(
      'transient failure → CurationResult.failure, feedback.retryable=true',
      () async {
        when(
          () => mockNostr.publishEventWithRetry(
            any(),
            policy: any(named: 'policy'),
            targetRelays: any(named: 'targetRelays'),
          ),
        ).thenAnswer((_) async => transientOutcome());

        final result = await service.publishCuration(
          id: 'curation_transient',
          title: 'Test',
          videoIds: const ['v1'],
        );

        expect(result.success, isFalse);
        expect(result.feedback?.retryable, isTrue);
        expect(result.feedback?.messageKey, 'publish_no_relay_response');

        final status = service.getCurationPublishStatus('curation_transient');
        expect(status.isPublished, isFalse);
      },
    );

    test(
      'permanent rejection → retryable=false, firstRejectionReason surfaced',
      () async {
        when(
          () => mockNostr.publishEventWithRetry(
            any(),
            policy: any(named: 'policy'),
            targetRelays: any(named: 'targetRelays'),
          ),
        ).thenAnswer((_) async => rejectedOutcome());

        final result = await service.publishCuration(
          id: 'curation_rejected',
          title: 'Test',
          videoIds: const ['v1'],
        );

        expect(result.success, isFalse);
        expect(result.feedback?.retryable, isFalse);
        expect(result.feedback?.firstRejectionReason, 'blocked: not allowed');

        final status = service.getCurationPublishStatus('curation_rejected');
        expect(status.isPublished, isFalse);
      },
    );

    test(
      'duplicate concurrent publish returns duplicate failure',
      () async {
        // The first publish blocks indefinitely.
        when(
          () => mockNostr.publishEventWithRetry(
            any(),
            policy: any(named: 'policy'),
            targetRelays: any(named: 'targetRelays'),
          ),
        ).thenAnswer(
          (_) => Future<PublishOutcome>.delayed(
            const Duration(seconds: 10),
            acceptedOutcome,
          ),
        );

        // Start the first publish (don't await).
        unawaited(
          service.publishCuration(
            id: 'curation_dupe',
            title: 'Test',
            videoIds: const ['v1'],
          ),
        );

        // Give the first call a microtask to register.
        await Future<void>.delayed(Duration.zero);

        final duplicate = await service.publishCuration(
          id: 'curation_dupe',
          title: 'Test',
          videoIds: const ['v1'],
        );

        expect(duplicate.success, isFalse);
        expect(duplicate.duplicate, isTrue);
      },
    );
  });
}
