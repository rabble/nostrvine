// ABOUTME: Tests that CuratedListService uses publishEventWithRetry for
// ABOUTME: kind 30005 publishes and gates local commit on acceptedByAny.

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/filter.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/curated_list_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockNostrClient extends Mock implements NostrClient {}

class _MockAuthService extends Mock implements AuthService {}

const _testPubkey =
    '0000000000000000000000000000000000000000000000000000000000000001';
const _videoId =
    '1111111111111111111111111111111111111111111111111111111111111111';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    registerFallbackValue(
      Event(_testPubkey, 30005, const [], '')
        ..id = 'e' * 64
        ..sig = 'sig',
    );
    registerFallbackValue(const RetryPolicy());
    registerFallbackValue(<Filter>[]);
    registerFallbackValue(<String>[]);
  });

  late _MockNostrClient nostr;
  late _MockAuthService auth;
  late SharedPreferences prefs;

  Event signed({required int kind, required List<List<String>> tags}) {
    return Event(_testPubkey, kind, tags, 'content')
      ..id = 'e' * 64
      ..sig = 'sig';
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    nostr = _MockNostrClient();
    auth = _MockAuthService();

    when(() => nostr.isInitialized).thenReturn(true);
    when(() => nostr.publicKey).thenReturn(_testPubkey);
    when(
      () => nostr.subscribe(
        any(),
        subscriptionId: any(named: 'subscriptionId'),
        tempRelays: any(named: 'tempRelays'),
        targetRelays: any(named: 'targetRelays'),
        onEose: any(named: 'onEose'),
      ),
    ).thenAnswer((_) => const Stream.empty());

    when(() => auth.isAuthenticated).thenReturn(true);
    when(() => auth.currentPublicKeyHex).thenReturn(_testPubkey);
    when(
      () => auth.createAndSignEvent(
        kind: any(named: 'kind'),
        content: any(named: 'content'),
        tags: any(named: 'tags'),
      ),
    ).thenAnswer((invocation) async {
      final kind = invocation.namedArguments[#kind] as int;
      final tags = invocation.namedArguments[#tags] as List<List<String>>;
      return signed(kind: kind, tags: tags);
    });
  });

  PublishOutcome acceptedOutcome() => PublishOutcome(
    eventId: 'e' * 64,
    acceptedBy: const {'wss://a'},
    rejectedBy: const {},
    noResponseFrom: const {},
  );

  PublishOutcome transientOutcome() => PublishOutcome(
    eventId: 'e' * 64,
    acceptedBy: const {},
    rejectedBy: const {},
    noResponseFrom: const {'wss://a'},
  );

  PublishOutcome rejectedOutcome() => PublishOutcome(
    eventId: 'e' * 64,
    acceptedBy: const {},
    rejectedBy: const {'wss://a': 'blocked: not allowed'},
    noResponseFrom: const {},
  );

  CuratedListService buildService() => CuratedListService(
    nostrService: nostr,
    authService: auth,
    prefs: prefs,
  );

  group('CuratedListService reliability (kind 30005)', () {
    test(
      'addVideoToListResult: accepted-by-any commits and reports success',
      () async {
        when(
          () => nostr.publishEventWithRetry(
            any(),
            policy: any(named: 'policy'),
            targetRelays: any(named: 'targetRelays'),
          ),
        ).thenAnswer((_) async => acceptedOutcome());

        final service = buildService();
        final created = await service.createList(name: 'My Picks');
        expect(created, isNotNull);

        final result = await service.addVideoToListResult(
          created!.id,
          _videoId,
        );

        expect(result.success, isTrue);
        expect(result.outcome?.acceptedBy, {'wss://a'});
        expect(result.feedback?.severity, PublishSeverity.success);

        final list = service.getListById(created.id);
        expect(list!.videoEventIds, [_videoId]);
      },
    );

    test(
      'addVideoToListResult: transient failure rolls back local state',
      () async {
        when(
          () => nostr.publishEventWithRetry(
            any(),
            policy: any(named: 'policy'),
            targetRelays: any(named: 'targetRelays'),
          ),
        ).thenAnswer((_) async => acceptedOutcome());

        final service = buildService();
        final created = await service.createList(name: 'My Picks');
        final listId = created!.id;

        // Next publish fails transiently.
        when(
          () => nostr.publishEventWithRetry(
            any(),
            policy: any(named: 'policy'),
            targetRelays: any(named: 'targetRelays'),
          ),
        ).thenAnswer((_) async => transientOutcome());

        final result = await service.addVideoToListResult(listId, _videoId);

        expect(result.success, isFalse);
        expect(result.feedback?.retryable, isTrue);
        expect(result.feedback?.messageKey, 'publish_no_relay_response');
        // Rollback: video must be gone.
        expect(service.getListById(listId)!.videoEventIds, isEmpty);
      },
    );

    test(
      'addVideoToListResult: permanent rejection surfaces reason, no commit',
      () async {
        when(
          () => nostr.publishEventWithRetry(
            any(),
            policy: any(named: 'policy'),
            targetRelays: any(named: 'targetRelays'),
          ),
        ).thenAnswer((_) async => acceptedOutcome());

        final service = buildService();
        final created = await service.createList(name: 'My Picks');
        final listId = created!.id;

        // Next publish is rejected permanently.
        when(
          () => nostr.publishEventWithRetry(
            any(),
            policy: any(named: 'policy'),
            targetRelays: any(named: 'targetRelays'),
          ),
        ).thenAnswer((_) async => rejectedOutcome());

        final result = await service.addVideoToListResult(listId, _videoId);

        expect(result.success, isFalse);
        expect(result.feedback?.retryable, isFalse);
        expect(result.feedback?.firstRejectionReason, 'blocked: not allowed');
        expect(service.getListById(listId)!.videoEventIds, isEmpty);
      },
    );

    test(
      'removeVideoFromListResult: transient failure restores the video',
      () async {
        when(
          () => nostr.publishEventWithRetry(
            any(),
            policy: any(named: 'policy'),
            targetRelays: any(named: 'targetRelays'),
          ),
        ).thenAnswer((_) async => acceptedOutcome());

        final service = buildService();
        final created = await service.createList(name: 'My Picks');
        final listId = created!.id;
        const secondVideoId =
            '3333333333333333333333333333333333333333333333333333333333333333';
        // Populate the list with two videos so removing one still leaves
        // a non-empty list (which triggers a relay publish per our
        // "skip empty lists" policy).
        await service.addVideoToListResult(listId, _videoId);
        await service.addVideoToListResult(listId, secondVideoId);
        expect(
          service.getListById(listId)!.videoEventIds,
          [_videoId, secondVideoId],
        );

        // Next publish fails transiently.
        when(
          () => nostr.publishEventWithRetry(
            any(),
            policy: any(named: 'policy'),
            targetRelays: any(named: 'targetRelays'),
          ),
        ).thenAnswer((_) async => transientOutcome());

        final result = await service.removeVideoFromListResult(
          listId,
          _videoId,
        );

        expect(result.success, isFalse);
        expect(result.feedback?.retryable, isTrue);
        // Rollback: both videos still present in the original order.
        expect(
          service.getListById(listId)!.videoEventIds,
          [_videoId, secondVideoId],
        );
      },
    );
  });
}
