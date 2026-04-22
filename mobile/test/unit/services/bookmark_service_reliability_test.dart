// ABOUTME: Tests that BookmarkService uses publishEventWithRetry for kind
// ABOUTME: 10003 / 30003 publishes and gates local commit on acceptedByAny.

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/filter.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/bookmark_service.dart';
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
      Event(_testPubkey, 10003, const [], '')
        ..id = 'f' * 64
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
    final event = Event(_testPubkey, kind, tags, 'content')
      ..id = 'e' * 64
      ..sig = 'sig';
    return event;
  }

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    prefs = await SharedPreferences.getInstance();
    nostr = _MockNostrClient();
    auth = _MockAuthService();

    when(() => nostr.isInitialized).thenReturn(true);
    when(() => nostr.publicKey).thenReturn(_testPubkey);
    // Subscribe is used by the list-service mixin when loading from relay.
    when(
      () => nostr.subscribe(
        any(),
        subscriptionId: any(named: 'subscriptionId'),
        tempRelays: any(named: 'tempRelays'),
        targetRelays: any(named: 'targetRelays'),
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
    noResponseFrom: const {'wss://a', 'wss://b'},
  );

  PublishOutcome rejectedOutcome() => PublishOutcome(
    eventId: 'e' * 64,
    acceptedBy: const {},
    rejectedBy: const {'wss://a': 'blocked: not allowed'},
    noResponseFrom: const {},
  );

  BookmarkService buildService() => BookmarkService(
    nostrService: nostr,
    authService: auth,
    prefs: prefs,
  );

  group('BookmarkService global bookmarks (kind 10003)', () {
    test(
      'success: accepted-by-any → commits local state and surfaces success',
      () async {
        when(
          () => nostr.publishEventWithRetry(
            any(),
            policy: any(named: 'policy'),
            targetRelays: any(named: 'targetRelays'),
          ),
        ).thenAnswer((_) async => acceptedOutcome());

        final service = buildService();
        final result = await service.addVideoToGlobalBookmarks(_videoId);

        expect(result.success, isTrue);
        expect(result.outcome, isNotNull);
        expect(result.feedback?.severity, PublishSeverity.success);
        expect(service.isVideoBookmarkedGlobally(_videoId), isTrue);
      },
    );

    test(
      'transient failure: retryable feedback, rollback local state',
      () async {
        when(
          () => nostr.publishEventWithRetry(
            any(),
            policy: any(named: 'policy'),
            targetRelays: any(named: 'targetRelays'),
          ),
        ).thenAnswer((_) async => transientOutcome());

        final service = buildService();
        final result = await service.addVideoToGlobalBookmarks(_videoId);

        expect(result.success, isFalse);
        expect(result.feedback?.retryable, isTrue);
        expect(result.feedback?.messageKey, 'publish_no_relay_response');
        // Rollback: bookmark not persisted locally.
        expect(service.isVideoBookmarkedGlobally(_videoId), isFalse);
      },
    );

    test(
      'permanent rejection: non-retryable feedback with reason, no commit',
      () async {
        when(
          () => nostr.publishEventWithRetry(
            any(),
            policy: any(named: 'policy'),
            targetRelays: any(named: 'targetRelays'),
          ),
        ).thenAnswer((_) async => rejectedOutcome());

        final service = buildService();
        final result = await service.addVideoToGlobalBookmarks(_videoId);

        expect(result.success, isFalse);
        expect(result.feedback?.retryable, isFalse);
        expect(result.feedback?.firstRejectionReason, 'blocked: not allowed');
        expect(service.isVideoBookmarkedGlobally(_videoId), isFalse);
      },
    );

    test(
      'remove: transient failure keeps item in bookmarks (rollback)',
      () async {
        // Seed: first add a bookmark successfully.
        when(
          () => nostr.publishEventWithRetry(
            any(),
            policy: any(named: 'policy'),
            targetRelays: any(named: 'targetRelays'),
          ),
        ).thenAnswer((_) async => acceptedOutcome());
        final service = buildService();
        await service.addVideoToGlobalBookmarks(_videoId);
        expect(service.isVideoBookmarkedGlobally(_videoId), isTrue);

        // Now remove under a transient failure; item should stay.
        when(
          () => nostr.publishEventWithRetry(
            any(),
            policy: any(named: 'policy'),
            targetRelays: any(named: 'targetRelays'),
          ),
        ).thenAnswer((_) async => transientOutcome());

        final result = await service.removeFromGlobalBookmarks(
          const BookmarkItem(type: 'e', id: _videoId),
        );

        expect(result.success, isFalse);
        expect(result.feedback?.retryable, isTrue);
        expect(service.isVideoBookmarkedGlobally(_videoId), isTrue);
      },
    );
  });

  group('BookmarkService bookmark sets (kind 30003)', () {
    test(
      'createBookmarkSet: success commits local state',
      () async {
        when(
          () => nostr.publishEventWithRetry(
            any(),
            policy: any(named: 'policy'),
            targetRelays: any(named: 'targetRelays'),
          ),
        ).thenAnswer((_) async => acceptedOutcome());

        final service = buildService();
        final result = await service.createBookmarkSet(name: 'Favourites');

        expect(result.success, isTrue);
        expect(result.set, isNotNull);
        expect(result.set!.name, 'Favourites');
        expect(service.bookmarkSets, hasLength(1));
      },
    );

    test(
      'createBookmarkSet: transient failure rolls back local state',
      () async {
        when(
          () => nostr.publishEventWithRetry(
            any(),
            policy: any(named: 'policy'),
            targetRelays: any(named: 'targetRelays'),
          ),
        ).thenAnswer((_) async => transientOutcome());

        final service = buildService();
        final result = await service.createBookmarkSet(name: 'Favourites');

        expect(result.success, isFalse);
        expect(result.feedback?.retryable, isTrue);
        expect(service.bookmarkSets, isEmpty);
      },
    );

    test(
      'deleteBookmarkSet: transient failure keeps set locally',
      () async {
        when(
          () => nostr.publishEventWithRetry(
            any(),
            policy: any(named: 'policy'),
            targetRelays: any(named: 'targetRelays'),
          ),
        ).thenAnswer((_) async => acceptedOutcome());

        final service = buildService();
        final createResult = await service.createBookmarkSet(
          name: 'Favourites',
        );
        final set = createResult.set!;

        expect(service.bookmarkSets, hasLength(1));
        verify(
          () => nostr.publishEventWithRetry(
            any(),
            policy: any(named: 'policy'),
            targetRelays: any(named: 'targetRelays'),
          ),
        ).called(1);

        when(
          () => nostr.publishEventWithRetry(
            any(),
            policy: any(named: 'policy'),
            targetRelays: any(named: 'targetRelays'),
          ),
        ).thenAnswer((_) async => transientOutcome());

        final deleted = await service.deleteBookmarkSet(set.id);

        expect(deleted, isFalse);
        expect(service.bookmarkSets.single.id, set.id);

        final captured = verify(
          () => nostr.publishEventWithRetry(
            captureAny(),
            policy: any(named: 'policy'),
            targetRelays: any(named: 'targetRelays'),
          ),
        ).captured;
        final deleteEvent = captured.single as Event;

        expect(deleteEvent.kind, 5);
        expect(
          deleteEvent.tags.any(
            (tag) =>
                tag.length >= 2 &&
                tag[0] == 'a' &&
                tag[1] == '30003:$_testPubkey:${set.id}',
          ),
          isTrue,
        );
        expect(
          deleteEvent.tags.any(
            (tag) => tag.length >= 2 && tag[0] == 'k' && tag[1] == '30003',
          ),
          isTrue,
        );
      },
    );
  });
}
