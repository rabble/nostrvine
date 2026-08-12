// ABOUTME: Tests for NIP-62 account deletion service
// ABOUTME: Verifies kind 62 event creation, ALL_RELAYS tag, NIP-09 batch
// ABOUTME: deletion, and broadcast behavior

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/client_utils/keys.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/filter.dart';
import 'package:nostr_sdk/relay/publish_outcome.dart';
import 'package:nostr_sdk/relay/relay_type.dart';
import 'package:openvine/services/account_deletion_service.dart';
import 'package:openvine/services/auth_service.dart';

class _MockNostrClient extends Mock implements NostrClient {
  /// Drives the `timedOut` field of the record synthesized below, so tests
  /// keep stubbing the simpler [queryEvents] for the event list.
  bool queryTimedOut = false;

  @override
  Future<({List<Event> events, bool timedOut, bool noRelays})>
  queryEventsDetailed(
    List<Filter> filters, {
    String? subscriptionId,
    List<String>? tempRelays,
    List<int> relayTypes = RelayType.all,
    bool sendAfterAuth = false,
    bool useCache = true,
    bool useQueryPool = true,
    Duration timeout = const Duration(seconds: 5),
    bool requireAllRelaysSettled = false,
  }) async {
    final events = await queryEvents(filters);
    return (
      events: events,
      timedOut: queryTimedOut,
      noRelays: connectedRelays.isEmpty,
    );
  }
}

class _MockAuthService extends Mock implements AuthService {}

class _FakeEvent extends Fake implements Event {}

/// A relay returned `OK true`.
const _confirmed = PublishOutcome(
  eventId: 'confirmed',
  acceptedBy: ['wss://relay.example.com'],
  rejectedBy: <String, String>{},
  noResponseFrom: <String>[],
);

/// Every targeted relay returned `OK false`.
const _rejected = PublishOutcome(
  eventId: 'rejected',
  acceptedBy: <String>[],
  rejectedBy: {'wss://relay.example.com': 'blocked: test'},
  noResponseFrom: <String>[],
);

/// The relay received the event and never answered before the timeout.
///
/// A targeted relay always lands in one of the outcome's buckets, so leaving
/// all of them empty would describe a publish with no targets at all.
const _noRelayResponse = PublishOutcome(
  eventId: 'unreachable',
  acceptedBy: <String>[],
  rejectedBy: <String, String>{},
  noResponseFrom: <String>['wss://relay.example.com'],
);

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeEvent());
    registerFallbackValue(<Filter>[]);
  });

  group('AccountDeletionService', () {
    late _MockNostrClient mockNostrService;
    late _MockAuthService mockAuthService;
    late AccountDeletionService service;
    late String testPrivateKey;
    late String testPublicKey;

    Event createTestEvent({
      required String pubkey,
      required int kind,
      required List<List<String>> tags,
      required String content,
      String? id,
    }) {
      final event = Event(
        pubkey,
        kind,
        tags,
        content,
        createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      );
      event.id = id ?? 'test_event_${DateTime.now().millisecondsSinceEpoch}';
      event.sig = 'test_signature';
      return event;
    }

    setUp(() {
      testPrivateKey = generatePrivateKey();
      testPublicKey = getPublicKey(testPrivateKey);

      mockNostrService = _MockNostrClient();
      mockAuthService = _MockAuthService();
      service = AccountDeletionService(
        nostrService: mockNostrService,
        authService: mockAuthService,
      );

      when(() => mockAuthService.isAuthenticated).thenReturn(true);
      when(() => mockAuthService.currentPublicKeyHex).thenReturn(testPublicKey);
      when(
        () => mockNostrService.queryEvents(any()),
      ).thenAnswer((_) async => []);
      when(() => mockNostrService.isDisposed).thenReturn(false);
      when(
        () => mockNostrService.connectedRelays,
      ).thenReturn(['wss://relay.example.com']);
    });

    test('createNip62Event should create kind 62 event', () async {
      // Arrange
      final expectedEvent = createTestEvent(
        pubkey: testPublicKey,
        kind: 62,
        tags: [
          ['relay', 'ALL_RELAYS'],
        ],
        content: 'User requested account deletion',
      );

      when(
        () => mockAuthService.createAndSignEvent(
          kind: any(named: 'kind'),
          content: any(named: 'content'),
          tags: any(named: 'tags'),
        ),
      ).thenAnswer((_) async => expectedEvent);

      // Act
      final event = await service.createNip62Event(
        reason: 'User requested account deletion',
      );

      // Assert
      expect(event, isNotNull);

      // Verify createAndSignEvent was called with kind 62
      verify(
        () => mockAuthService.createAndSignEvent(
          kind: 62,
          content: any(named: 'content'),
          tags: any(named: 'tags'),
        ),
      ).called(1);
    });

    test('createNip62Event should include ALL_RELAYS tag', () async {
      // Arrange
      final expectedEvent = createTestEvent(
        pubkey: testPublicKey,
        kind: 62,
        tags: [
          ['relay', 'ALL_RELAYS'],
        ],
        content: 'User requested account deletion',
      );

      when(
        () => mockAuthService.createAndSignEvent(
          kind: any(named: 'kind'),
          content: any(named: 'content'),
          tags: any(named: 'tags'),
        ),
      ).thenAnswer((_) async => expectedEvent);

      // Act
      await service.createNip62Event(reason: 'User requested account deletion');

      // Assert - verify tags include ALL_RELAYS
      final captured = verify(
        () => mockAuthService.createAndSignEvent(
          kind: any(named: 'kind'),
          content: any(named: 'content'),
          tags: captureAny(named: 'tags'),
        ),
      ).captured;

      final tags = captured.first as List<List<String>>;
      expect(
        tags.any(
          (tag) =>
              tag.length == 2 && tag[0] == 'relay' && tag[1] == 'ALL_RELAYS',
        ),
        isTrue,
      );
    });

    test('deleteAccount should broadcast NIP-62 event', () async {
      // Arrange
      final expectedEvent = createTestEvent(
        pubkey: testPublicKey,
        kind: 62,
        tags: [
          ['relay', 'ALL_RELAYS'],
        ],
        content: 'User requested account deletion via Divine app',
      );

      when(
        () => mockAuthService.createAndSignEvent(
          kind: any(named: 'kind'),
          content: any(named: 'content'),
          tags: any(named: 'tags'),
        ),
      ).thenAnswer((_) async => expectedEvent);

      when(
        () => mockNostrService.publishEventAwaitOk(any()),
      ).thenAnswer((_) async => _confirmed);

      // Act
      await expectLater(service.deleteAccount(), completes);

      // Assert
      verify(() => mockNostrService.publishEventAwaitOk(any())).called(1);
    });

    test(
      'deleteAccount should return success when broadcast succeeds',
      () async {
        // Arrange
        final expectedEvent = createTestEvent(
          pubkey: testPublicKey,
          kind: 62,
          tags: [
            ['relay', 'ALL_RELAYS'],
          ],
          content: 'User requested account deletion via Divine app',
        );

        when(
          () => mockAuthService.createAndSignEvent(
            kind: any(named: 'kind'),
            content: any(named: 'content'),
            tags: any(named: 'tags'),
          ),
        ).thenAnswer((_) async => expectedEvent);

        when(
          () => mockNostrService.publishEventAwaitOk(any()),
        ).thenAnswer((_) async => _confirmed);

        // Act
        final result = await service.deleteAccount();

        // Assert
        expect(result.success, isTrue);
        expect(result.error, isNull);
      },
    );

    test('deleteAccount should return failure when publish fails', () async {
      // Arrange
      final expectedEvent = createTestEvent(
        pubkey: testPublicKey,
        kind: 62,
        tags: [
          ['relay', 'ALL_RELAYS'],
        ],
        content: 'User requested account deletion via Divine app',
      );

      when(
        () => mockAuthService.createAndSignEvent(
          kind: any(named: 'kind'),
          content: any(named: 'content'),
          tags: any(named: 'tags'),
        ),
      ).thenAnswer((_) async => expectedEvent);

      // publishEventAwaitOk reports every relay rejecting
      when(
        () => mockNostrService.publishEventAwaitOk(any()),
      ).thenAnswer((_) async => _rejected);

      // Act
      final result = await service.deleteAccount();

      // Assert
      expect(result.success, isFalse);
      expect(result.error, isNotNull);
      expect(result.error, contains('Failed to publish'));
    });

    test(
      'deleteAccount returns generic publish-failure message when no relay responds',
      () async {
        // Arrange
        final expectedEvent = createTestEvent(
          pubkey: testPublicKey,
          kind: 62,
          tags: [
            ['relay', 'ALL_RELAYS'],
          ],
          content: 'User requested account deletion via Divine app',
        );

        when(
          () => mockAuthService.createAndSignEvent(
            kind: any(named: 'kind'),
            content: any(named: 'content'),
            tags: any(named: 'tags'),
          ),
        ).thenAnswer((_) async => expectedEvent);

        when(
          () => mockNostrService.publishEventAwaitOk(any()),
        ).thenAnswer((_) async => _noRelayResponse);

        // Act
        final result = await service.deleteAccount();

        // Assert
        expect(result.success, isFalse);
        expect(result.error, contains('Failed to publish'));
      },
    );

    test('deleteAccount should fail when not authenticated', () async {
      // Arrange
      when(() => mockAuthService.isAuthenticated).thenReturn(false);

      // Act
      final result = await service.deleteAccount();

      // Assert
      expect(result.success, isFalse);
      expect(result.error, contains('Not authenticated'));

      // Verify publishEvent was NOT called
      verifyNever(() => mockNostrService.publishEventAwaitOk(any()));
    });

    test(
      'deleteAccount should fail when createAndSignEvent returns null',
      () async {
        // Arrange
        when(
          () => mockAuthService.createAndSignEvent(
            kind: any(named: 'kind'),
            content: any(named: 'content'),
            tags: any(named: 'tags'),
          ),
        ).thenAnswer((_) async => null);

        // Act
        final result = await service.deleteAccount();

        // Assert
        expect(result.success, isFalse);
        expect(result.error, contains('Failed to create deletion event'));

        // Verify publishEvent was NOT called
        verifyNever(() => mockNostrService.publishEventAwaitOk(any()));
      },
    );

    group('NIP-09 batch deletion', () {
      test('should fetch all user events before deletion', () async {
        // Arrange
        final nip62Event = createTestEvent(
          pubkey: testPublicKey,
          kind: 62,
          tags: [
            ['relay', 'ALL_RELAYS'],
          ],
          content: 'User requested account deletion via Divine app',
        );

        when(
          () => mockNostrService.queryEvents(any()),
        ).thenAnswer((_) async => []);
        when(
          () => mockAuthService.createAndSignEvent(
            kind: any(named: 'kind'),
            content: any(named: 'content'),
            tags: any(named: 'tags'),
          ),
        ).thenAnswer((_) async => nip62Event);
        when(
          () => mockNostrService.publishEventAwaitOk(any()),
        ).thenAnswer((_) async => _confirmed);

        // Act
        await service.deleteAccount();

        // Assert
        verify(() => mockNostrService.queryEvents(any())).called(1);
      });

      test(
        'should publish kind 5 events for user events before NIP-62',
        () async {
          // Arrange
          final userVideoEvent = createTestEvent(
            pubkey: testPublicKey,
            kind: 34236,
            tags: [],
            content: 'test video',
            id: 'video_event_1',
          );

          final kind5Event = createTestEvent(
            pubkey: testPublicKey,
            kind: 5,
            tags: [
              ['e', 'video_event_1'],
              ['k', '34236'],
            ],
            content: 'User requested account deletion via Divine app',
          );

          final nip62Event = createTestEvent(
            pubkey: testPublicKey,
            kind: 62,
            tags: [
              ['relay', 'ALL_RELAYS'],
            ],
            content: 'User requested account deletion via Divine app',
          );

          when(
            () => mockNostrService.queryEvents(any()),
          ).thenAnswer((_) async => [userVideoEvent]);

          var createCallCount = 0;
          when(
            () => mockAuthService.createAndSignEvent(
              kind: any(named: 'kind'),
              content: any(named: 'content'),
              tags: any(named: 'tags'),
            ),
          ).thenAnswer((_) async {
            createCallCount++;
            if (createCallCount == 1) return kind5Event;
            return nip62Event;
          });

          when(
            () => mockNostrService.publishEventAwaitOk(any()),
          ).thenAnswer((_) async => _confirmed);

          // Act
          final result = await service.deleteAccount();

          // Assert
          expect(result.success, isTrue);
          verify(() => mockNostrService.publishEventAwaitOk(any())).called(2);
        },
      );

      test('should group events by kind for batch deletion', () async {
        // Arrange
        final videoEvent1 = createTestEvent(
          pubkey: testPublicKey,
          kind: 34236,
          tags: [],
          content: 'video 1',
          id: 'video_1',
        );
        final videoEvent2 = createTestEvent(
          pubkey: testPublicKey,
          kind: 34236,
          tags: [],
          content: 'video 2',
          id: 'video_2',
        );
        final likeEvent = createTestEvent(
          pubkey: testPublicKey,
          kind: 7,
          tags: [],
          content: '+',
          id: 'like_1',
        );

        final kind5VideoEvent = createTestEvent(
          pubkey: testPublicKey,
          kind: 5,
          tags: [
            ['e', 'video_1'],
            ['e', 'video_2'],
            ['k', '34236'],
          ],
          content: 'deletion',
        );
        final kind5LikeEvent = createTestEvent(
          pubkey: testPublicKey,
          kind: 5,
          tags: [
            ['e', 'like_1'],
            ['k', '7'],
          ],
          content: 'deletion',
        );
        final nip62Event = createTestEvent(
          pubkey: testPublicKey,
          kind: 62,
          tags: [
            ['relay', 'ALL_RELAYS'],
          ],
          content: 'deletion',
        );

        when(
          () => mockNostrService.queryEvents(any()),
        ).thenAnswer((_) async => [videoEvent1, videoEvent2, likeEvent]);

        var createCallCount = 0;
        when(
          () => mockAuthService.createAndSignEvent(
            kind: any(named: 'kind'),
            content: any(named: 'content'),
            tags: any(named: 'tags'),
          ),
        ).thenAnswer((_) async {
          createCallCount++;
          if (createCallCount == 1) return kind5VideoEvent;
          if (createCallCount == 2) return kind5LikeEvent;
          return nip62Event;
        });

        when(
          () => mockNostrService.publishEventAwaitOk(any()),
        ).thenAnswer((_) async => _confirmed);

        // Act
        final result = await service.deleteAccount();

        // Assert
        expect(result.success, isTrue);
        expect(result.deletedEventsCount, equals(3));
        verify(() => mockNostrService.publishEventAwaitOk(any())).called(3);
      });

      test('should return deletedEventsCount in result', () async {
        // Arrange
        final userEvent = createTestEvent(
          pubkey: testPublicKey,
          kind: 1,
          tags: [],
          content: 'note',
          id: 'note_1',
        );

        final kind5Event = createTestEvent(
          pubkey: testPublicKey,
          kind: 5,
          tags: [
            ['e', 'note_1'],
            ['k', '1'],
          ],
          content: 'deletion',
        );
        final nip62Event = createTestEvent(
          pubkey: testPublicKey,
          kind: 62,
          tags: [
            ['relay', 'ALL_RELAYS'],
          ],
          content: 'deletion',
        );

        when(
          () => mockNostrService.queryEvents(any()),
        ).thenAnswer((_) async => [userEvent]);

        var createCallCount = 0;
        when(
          () => mockAuthService.createAndSignEvent(
            kind: any(named: 'kind'),
            content: any(named: 'content'),
            tags: any(named: 'tags'),
          ),
        ).thenAnswer((_) async {
          createCallCount++;
          if (createCallCount == 1) return kind5Event;
          return nip62Event;
        });

        when(
          () => mockNostrService.publishEventAwaitOk(any()),
        ).thenAnswer((_) async => _confirmed);

        // Act
        final result = await service.deleteAccount();

        // Assert
        expect(result.success, isTrue);
        expect(result.deletedEventsCount, equals(1));
      });

      test('should still publish NIP-62 even if no events found', () async {
        // Arrange
        final nip62Event = createTestEvent(
          pubkey: testPublicKey,
          kind: 62,
          tags: [
            ['relay', 'ALL_RELAYS'],
          ],
          content: 'deletion',
        );

        when(
          () => mockNostrService.queryEvents(any()),
        ).thenAnswer((_) async => []);
        when(
          () => mockAuthService.createAndSignEvent(
            kind: any(named: 'kind'),
            content: any(named: 'content'),
            tags: any(named: 'tags'),
          ),
        ).thenAnswer((_) async => nip62Event);
        when(
          () => mockNostrService.publishEventAwaitOk(any()),
        ).thenAnswer((_) async => _confirmed);

        // Act
        final result = await service.deleteAccount();

        // Assert
        expect(result.success, isTrue);
        expect(result.deletedEventsCount, equals(0));
        verify(() => mockNostrService.publishEventAwaitOk(any())).called(1);
      });

      test(
        'batch deletion does not count events when no relay responds',
        () async {
          // Arrange
          final userEvent = createTestEvent(
            pubkey: testPublicKey,
            kind: 1,
            tags: [],
            content: 'note',
            id: 'note_1',
          );
          final kind5Event = createTestEvent(
            pubkey: testPublicKey,
            kind: 5,
            tags: [
              ['e', 'note_1'],
              ['k', '1'],
            ],
            content: 'deletion',
          );
          final nip62Event = createTestEvent(
            pubkey: testPublicKey,
            kind: 62,
            tags: [
              ['relay', 'ALL_RELAYS'],
            ],
            content: 'deletion',
          );

          when(
            () => mockNostrService.queryEvents(any()),
          ).thenAnswer((_) async => [userEvent]);

          var createCallCount = 0;
          when(
            () => mockAuthService.createAndSignEvent(
              kind: any(named: 'kind'),
              content: any(named: 'content'),
              tags: any(named: 'tags'),
            ),
          ).thenAnswer((_) async {
            createCallCount++;
            if (createCallCount == 1) return kind5Event;
            return nip62Event;
          });

          var publishCallCount = 0;
          when(() => mockNostrService.publishEventAwaitOk(any())).thenAnswer((
            _,
          ) async {
            publishCallCount++;
            // First publish is the batch kind-5; second is NIP-62.
            if (publishCallCount == 1) return _noRelayResponse;
            return _confirmed;
          });

          // Act
          final result = await service.deleteAccount();

          // Assert — NIP-62 still succeeds; batch counted 0 because relay
          // was unreachable for kind-5.
          expect(result.success, isTrue);
          expect(result.deletedEventsCount, equals(0));
          expect(result.contentDeletionIncomplete, isTrue);
        },
      );

      test(
        'batch deletion does not count events when every relay rejects',
        () async {
          // Arrange
          final userEvent = createTestEvent(
            pubkey: testPublicKey,
            kind: 1,
            tags: [],
            content: 'note',
            id: 'note_2',
          );
          final kind5Event = createTestEvent(
            pubkey: testPublicKey,
            kind: 5,
            tags: [
              ['e', 'note_2'],
              ['k', '1'],
            ],
            content: 'deletion',
          );
          final nip62Event = createTestEvent(
            pubkey: testPublicKey,
            kind: 62,
            tags: [
              ['relay', 'ALL_RELAYS'],
            ],
            content: 'deletion',
          );

          when(
            () => mockNostrService.queryEvents(any()),
          ).thenAnswer((_) async => [userEvent]);

          var createCallCount = 0;
          when(
            () => mockAuthService.createAndSignEvent(
              kind: any(named: 'kind'),
              content: any(named: 'content'),
              tags: any(named: 'tags'),
            ),
          ).thenAnswer((_) async {
            createCallCount++;
            if (createCallCount == 1) return kind5Event;
            return nip62Event;
          });

          var publishCallCount = 0;
          when(() => mockNostrService.publishEventAwaitOk(any())).thenAnswer((
            _,
          ) async {
            publishCallCount++;
            // First publish is the batch kind-5; second is NIP-62.
            if (publishCallCount == 1) return _rejected;
            return _confirmed;
          });

          // Act
          final result = await service.deleteAccount();

          // Assert — NIP-62 still succeeds; batch counted 0 because send
          // failed.
          expect(result.success, isTrue);
          expect(result.deletedEventsCount, equals(0));
        },
      );
    });

    group('sweep target selection', () {
      // Regression for #6335: the sweep had no kind filter, so on every retry
      // it asked relays to delete its own prior kind-5 requests and the
      // kind-62 vanish request itself, growing the e-tag list each time. Both
      // are protocol no-ops (NIP-09: "Publishing a deletion request event
      // against a deletion request has no effect"; NIP-62 says the same for a
      // request to vanish), so this only ever wasted remote-signing
      // round-trips and asked the network to retract a legal notice.
      test("excludes the flow's own kind-5 and kind-62 events", () async {
        when(() => mockAuthService.isAuthenticated).thenReturn(true);
        when(
          () => mockAuthService.currentPublicKeyHex,
        ).thenReturn(testPublicKey);

        final note = createTestEvent(
          pubkey: testPublicKey,
          kind: 1,
          tags: const [],
          content: 'note',
          id: 'note_1',
        );
        final priorDeletion = createTestEvent(
          pubkey: testPublicKey,
          kind: 5,
          tags: const [
            ['e', 'note_1'],
          ],
          content: 'prior sweep',
          id: 'kind5_1',
        );
        final priorVanish = createTestEvent(
          pubkey: testPublicKey,
          kind: 62,
          tags: const [
            ['relay', 'ALL_RELAYS'],
          ],
          content: 'prior vanish',
          id: 'kind62_1',
        );

        when(
          () => mockNostrService.queryEvents(any()),
        ).thenAnswer((_) async => [note, priorDeletion, priorVanish]);

        final signedKinds = <int>[];
        when(
          () => mockAuthService.createAndSignEvent(
            kind: any(named: 'kind'),
            content: any(named: 'content'),
            tags: any(named: 'tags'),
          ),
        ).thenAnswer((invocation) async {
          final tags =
              invocation.namedArguments[const Symbol('tags')]
                  as List<List<String>>;
          for (final tag in tags) {
            if (tag.length >= 2 && tag[0] == 'k') {
              signedKinds.add(int.parse(tag[1]));
            }
          }
          return createTestEvent(
            pubkey: testPublicKey,
            kind: 5,
            tags: const [],
            content: 'deletion',
          );
        });
        when(
          () => mockNostrService.publishEventAwaitOk(any()),
        ).thenAnswer((_) async => _confirmed);

        await service.deleteAccount();

        // The kind-1 note is swept; the flow's own kind-5 and kind-62 are not.
        expect(signedKinds, contains(1));
        expect(signedKinds, isNot(contains(5)));
        expect(signedKinds, isNot(contains(62)));
      });

      // Regression for #6335: the sweep emitted `e` tags only. NIP-09 says
      // "When an `a` tag is used, relays SHOULD delete all versions of the
      // replaceable event up to the `created_at`", so with `e` alone every
      // prior version of an edited video survives on a relay that implements
      // NIP-09 but not NIP-62 — exactly the relays this sweep exists for.
      test(
        'emits an a tag for addressable kinds alongside the e tag',
        () async {
          when(() => mockAuthService.isAuthenticated).thenReturn(true);
          when(
            () => mockAuthService.currentPublicKeyHex,
          ).thenReturn(testPublicKey);

          final video = createTestEvent(
            pubkey: testPublicKey,
            kind: 34236,
            tags: const [
              ['d', 'my-vine-id'],
            ],
            content: 'video',
            id: 'video_1',
          );

          when(
            () => mockNostrService.queryEvents(any()),
          ).thenAnswer((_) async => [video]);

          List<List<String>>? kind5Tags;
          when(
            () => mockAuthService.createAndSignEvent(
              kind: any(named: 'kind'),
              content: any(named: 'content'),
              tags: any(named: 'tags'),
            ),
          ).thenAnswer((invocation) async {
            final tags =
                invocation.namedArguments[const Symbol('tags')]
                    as List<List<String>>;
            if (tags.any((tag) => tag.isNotEmpty && tag[0] == 'e')) {
              kind5Tags = tags;
            }
            return createTestEvent(
              pubkey: testPublicKey,
              kind: 5,
              tags: const [],
              content: 'deletion',
            );
          });
          when(
            () => mockNostrService.publishEventAwaitOk(any()),
          ).thenAnswer((_) async => _confirmed);

          await service.deleteAccount();

          expect(kind5Tags, isNotNull);
          // `contains` compares with `==`, and Dart lists use identity
          // equality, so each expected tag must be wrapped in `equals`.
          expect(kind5Tags, contains(equals(['e', 'video_1'])));
          expect(
            kind5Tags,
            contains(equals(['a', '34236:$testPublicKey:my-vine-id'])),
          );
        },
      );

      test('omits the a tag for non-addressable kinds', () async {
        when(() => mockAuthService.isAuthenticated).thenReturn(true);
        when(
          () => mockAuthService.currentPublicKeyHex,
        ).thenReturn(testPublicKey);

        final note = createTestEvent(
          pubkey: testPublicKey,
          kind: 1,
          tags: const [
            ['d', 'not-addressable'],
          ],
          content: 'note',
          id: 'note_1',
        );

        when(
          () => mockNostrService.queryEvents(any()),
        ).thenAnswer((_) async => [note]);

        List<List<String>>? kind5Tags;
        when(
          () => mockAuthService.createAndSignEvent(
            kind: any(named: 'kind'),
            content: any(named: 'content'),
            tags: any(named: 'tags'),
          ),
        ).thenAnswer((invocation) async {
          final tags =
              invocation.namedArguments[const Symbol('tags')]
                  as List<List<String>>;
          if (tags.any((tag) => tag.isNotEmpty && tag[0] == 'e')) {
            kind5Tags = tags;
          }
          return createTestEvent(
            pubkey: testPublicKey,
            kind: 5,
            tags: const [],
            content: 'deletion',
          );
        });
        when(
          () => mockNostrService.publishEventAwaitOk(any()),
        ).thenAnswer((_) async => _confirmed);

        await service.deleteAccount();

        expect(kind5Tags, isNotNull);
        expect(kind5Tags!.any((tag) => tag[0] == 'a'), isFalse);
      });

      // Regression for #6335: a failed relay query was swallowed into an empty
      // list, so the entire kind-5 sweep was skipped while the irreversible
      // vanish was still published — and the caller reported plain success.
      test('reports contentQueryFailed when the relay query throws', () async {
        when(() => mockAuthService.isAuthenticated).thenReturn(true);
        when(
          () => mockAuthService.currentPublicKeyHex,
        ).thenReturn(testPublicKey);
        when(
          () => mockNostrService.queryEvents(any()),
        ).thenThrow(Exception('relay unreachable'));
        when(
          () => mockAuthService.createAndSignEvent(
            kind: any(named: 'kind'),
            content: any(named: 'content'),
            tags: any(named: 'tags'),
          ),
        ).thenAnswer(
          (_) async => createTestEvent(
            pubkey: testPublicKey,
            kind: 62,
            tags: const [
              ['relay', 'ALL_RELAYS'],
            ],
            content: 'deletion',
          ),
        );
        when(
          () => mockNostrService.publishEventAwaitOk(any()),
        ).thenAnswer((_) async => _confirmed);

        final result = await service.deleteAccount();

        expect(result.success, isTrue);
        expect(result.contentQueryFailed, isTrue);
        expect(result.deletedEventsCount, equals(0));
      });

      test('contentQueryFailed is false on a healthy query', () async {
        when(() => mockAuthService.isAuthenticated).thenReturn(true);
        when(
          () => mockAuthService.currentPublicKeyHex,
        ).thenReturn(testPublicKey);
        when(
          () => mockNostrService.queryEvents(any()),
        ).thenAnswer((_) async => []);
        when(
          () => mockAuthService.createAndSignEvent(
            kind: any(named: 'kind'),
            content: any(named: 'content'),
            tags: any(named: 'tags'),
          ),
        ).thenAnswer(
          (_) async => createTestEvent(
            pubkey: testPublicKey,
            kind: 62,
            tags: const [
              ['relay', 'ALL_RELAYS'],
            ],
            content: 'deletion',
          ),
        );
        when(
          () => mockNostrService.publishEventAwaitOk(any()),
        ).thenAnswer((_) async => _confirmed);

        final result = await service.deleteAccount();

        expect(result.success, isTrue);
        expect(result.contentQueryFailed, isFalse);
      });

      test('reports contentQueryFailed when no relay is connected', () async {
        when(
          () => mockNostrService.connectedRelays,
        ).thenReturn(const <String>[]);
        when(
          () => mockAuthService.createAndSignEvent(
            kind: any(named: 'kind'),
            content: any(named: 'content'),
            tags: any(named: 'tags'),
          ),
        ).thenAnswer(
          (_) async => createTestEvent(
            pubkey: testPublicKey,
            kind: 62,
            tags: const [
              ['relay', 'ALL_RELAYS'],
            ],
            content: 'deletion',
          ),
        );
        when(
          () => mockNostrService.publishEventAwaitOk(any()),
        ).thenAnswer((_) async => _confirmed);

        final result = await service.deleteAccount();

        expect(result.success, isTrue);
        expect(result.contentQueryFailed, isTrue);
        expect(result.deletedEventsCount, equals(0));
      });

      test(
        'reports contentQueryFailed when the relay query times out',
        () async {
          mockNostrService.queryTimedOut = true;
          when(
            () => mockAuthService.createAndSignEvent(
              kind: any(named: 'kind'),
              content: any(named: 'content'),
              tags: any(named: 'tags'),
            ),
          ).thenAnswer(
            (_) async => createTestEvent(
              pubkey: testPublicKey,
              kind: 62,
              tags: const [
                ['relay', 'ALL_RELAYS'],
              ],
              content: 'deletion',
            ),
          );
          when(
            () => mockNostrService.publishEventAwaitOk(any()),
          ).thenAnswer((_) async => _confirmed);

          final result = await service.deleteAccount();

          expect(result.success, isTrue);
          expect(result.contentQueryFailed, isTrue);
          expect(result.deletedEventsCount, equals(0));
        },
      );
    });

    group('expectedPubkey binding', () {
      test(
        'aborts before signing when the account changes mid-deletion',
        () async {
          var current = testPublicKey;
          when(
            () => mockAuthService.currentPublicKeyHex,
          ).thenAnswer((_) => current);
          when(() => mockNostrService.queryEvents(any())).thenAnswer((_) async {
            // Account switches away during the event fetch, before any signing.
            current = 'a_different_pubkey_than_confirmed';
            return [
              createTestEvent(
                pubkey: testPublicKey,
                kind: 1,
                tags: const [],
                content: 'note',
              ),
            ];
          });

          final result = await service.deleteAccount(
            expectedPubkey: testPublicKey,
          );

          expect(result.success, isFalse);
          expect(result.error, contains('account changed'));
          expect(result.accountChanged, isTrue);
          verifyNever(
            () => mockAuthService.createAndSignEvent(
              kind: any(named: 'kind'),
              content: any(named: 'content'),
              tags: any(named: 'tags'),
            ),
          );
        },
      );

      test(
        'aborts at entry when expectedPubkey already differs from the signer',
        () async {
          when(
            () => mockAuthService.currentPublicKeyHex,
          ).thenReturn('a_different_pubkey_than_confirmed');

          final result = await service.deleteAccount(
            expectedPubkey: testPublicKey,
          );

          expect(result.success, isFalse);
          expect(result.accountChanged, isTrue);
          // Bailed before fetching or signing anything.
          verifyNever(() => mockNostrService.queryEvents(any()));
          verifyNever(
            () => mockAuthService.createAndSignEvent(
              kind: any(named: 'kind'),
              content: any(named: 'content'),
              tags: any(named: 'tags'),
            ),
          );
        },
      );

      test(
        'reaches signing when expectedPubkey stays the current account',
        () async {
          when(
            () => mockAuthService.currentPublicKeyHex,
          ).thenReturn(testPublicKey);
          when(
            () => mockNostrService.queryEvents(any()),
          ).thenAnswer((_) async => []);
          when(
            () => mockAuthService.createAndSignEvent(
              kind: any(named: 'kind'),
              content: any(named: 'content'),
              tags: any(named: 'tags'),
            ),
          ).thenAnswer((_) async => null);

          await service.deleteAccount(expectedPubkey: testPublicKey);

          // Guard passed with a matching account → reached the kind-62 signing.
          verify(
            () => mockAuthService.createAndSignEvent(
              kind: 62,
              content: any(named: 'content'),
              tags: any(named: 'tags'),
            ),
          ).called(1);
        },
      );
    });
  });
}
