// ABOUTME: Tests for NIP-62 account deletion service
// ABOUTME: Verifies kind 62 event creation, ALL_RELAYS tag, NIP-09 batch deletion, and broadcast behavior

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:nostr_sdk/client_utils/keys.dart';
import 'package:nostr_sdk/event.dart';
import 'package:openvine/services/account_deletion_service.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:nostr_client/nostr_client.dart';

import 'account_deletion_service_test.mocks.dart';

@GenerateMocks([NostrClient, AuthService])
void main() {
  group('AccountDeletionService', () {
    late MockNostrClient mockNostrService;
    late MockAuthService mockAuthService;
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

      mockNostrService = MockNostrClient();
      mockAuthService = MockAuthService();
      service = AccountDeletionService(
        nostrService: mockNostrService,
        authService: mockAuthService,
      );

      when(mockAuthService.isAuthenticated).thenReturn(true);
      when(mockAuthService.currentPublicKeyHex).thenReturn(testPublicKey);
      when(mockNostrService.queryEvents(any)).thenAnswer((_) async => []);
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
        mockAuthService.createAndSignEvent(
          kind: anyNamed('kind'),
          content: anyNamed('content'),
          tags: anyNamed('tags'),
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
        mockAuthService.createAndSignEvent(
          kind: 62,
          content: anyNamed('content'),
          tags: anyNamed('tags'),
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
        mockAuthService.createAndSignEvent(
          kind: anyNamed('kind'),
          content: anyNamed('content'),
          tags: anyNamed('tags'),
        ),
      ).thenAnswer((_) async => expectedEvent);

      // Act
      await service.createNip62Event(reason: 'User requested account deletion');

      // Assert - verify tags include ALL_RELAYS
      final captured = verify(
        mockAuthService.createAndSignEvent(
          kind: anyNamed('kind'),
          content: anyNamed('content'),
          tags: captureAnyNamed('tags'),
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
        content: 'User requested account deletion via diVine app',
      );

      when(
        mockAuthService.createAndSignEvent(
          kind: anyNamed('kind'),
          content: anyNamed('content'),
          tags: anyNamed('tags'),
        ),
      ).thenAnswer((_) async => expectedEvent);

      when(
        mockNostrService.publishEvent(any),
      ).thenAnswer((_) async => expectedEvent);

      // Act
      await expectLater(service.deleteAccount(), completes);

      // Assert
      verify(mockNostrService.publishEvent(any)).called(1);
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
          content: 'User requested account deletion via diVine app',
        );

        when(
          mockAuthService.createAndSignEvent(
            kind: anyNamed('kind'),
            content: anyNamed('content'),
            tags: anyNamed('tags'),
          ),
        ).thenAnswer((_) async => expectedEvent);

        when(
          mockNostrService.publishEvent(any),
        ).thenAnswer((_) async => expectedEvent);

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
        content: 'User requested account deletion via diVine app',
      );

      when(
        mockAuthService.createAndSignEvent(
          kind: anyNamed('kind'),
          content: anyNamed('content'),
          tags: anyNamed('tags'),
        ),
      ).thenAnswer((_) async => expectedEvent);

      // publishEvent returns null on failure
      when(mockNostrService.publishEvent(any)).thenAnswer((_) async => null);

      // Act
      final result = await service.deleteAccount();

      // Assert
      expect(result.success, isFalse);
      expect(result.error, isNotNull);
      expect(result.error, contains('Failed to publish'));
    });

    test('deleteAccount should fail when not authenticated', () async {
      // Arrange
      when(mockAuthService.isAuthenticated).thenReturn(false);

      // Act
      final result = await service.deleteAccount();

      // Assert
      expect(result.success, isFalse);
      expect(result.error, contains('Not authenticated'));

      // Verify publishEvent was NOT called
      verifyNever(mockNostrService.publishEvent(any));
    });

    test(
      'deleteAccount should fail when createAndSignEvent returns null',
      () async {
        // Arrange
        when(
          mockAuthService.createAndSignEvent(
            kind: anyNamed('kind'),
            content: anyNamed('content'),
            tags: anyNamed('tags'),
          ),
        ).thenAnswer((_) async => null);

        // Act
        final result = await service.deleteAccount();

        // Assert
        expect(result.success, isFalse);
        expect(result.error, contains('Failed to create deletion event'));

        // Verify publishEvent was NOT called
        verifyNever(mockNostrService.publishEvent(any));
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
          content: 'User requested account deletion via diVine app',
        );

        when(mockNostrService.queryEvents(any)).thenAnswer((_) async => []);
        when(
          mockAuthService.createAndSignEvent(
            kind: anyNamed('kind'),
            content: anyNamed('content'),
            tags: anyNamed('tags'),
          ),
        ).thenAnswer((_) async => nip62Event);
        when(
          mockNostrService.publishEvent(any),
        ).thenAnswer((_) async => nip62Event);

        // Act
        await service.deleteAccount();

        // Assert
        verify(mockNostrService.queryEvents(any)).called(1);
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
            content: 'User requested account deletion via diVine app',
          );

          final nip62Event = createTestEvent(
            pubkey: testPublicKey,
            kind: 62,
            tags: [
              ['relay', 'ALL_RELAYS'],
            ],
            content: 'User requested account deletion via diVine app',
          );

          when(
            mockNostrService.queryEvents(any),
          ).thenAnswer((_) async => [userVideoEvent]);

          var createCallCount = 0;
          when(
            mockAuthService.createAndSignEvent(
              kind: anyNamed('kind'),
              content: anyNamed('content'),
              tags: anyNamed('tags'),
            ),
          ).thenAnswer((_) async {
            createCallCount++;
            if (createCallCount == 1) return kind5Event;
            return nip62Event;
          });

          when(
            mockNostrService.publishEvent(any),
          ).thenAnswer((_) async => nip62Event);

          // Act
          final result = await service.deleteAccount();

          // Assert
          expect(result.success, isTrue);
          verify(mockNostrService.publishEvent(any)).called(2);
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
          mockNostrService.queryEvents(any),
        ).thenAnswer((_) async => [videoEvent1, videoEvent2, likeEvent]);

        var createCallCount = 0;
        when(
          mockAuthService.createAndSignEvent(
            kind: anyNamed('kind'),
            content: anyNamed('content'),
            tags: anyNamed('tags'),
          ),
        ).thenAnswer((_) async {
          createCallCount++;
          if (createCallCount == 1) return kind5VideoEvent;
          if (createCallCount == 2) return kind5LikeEvent;
          return nip62Event;
        });

        when(
          mockNostrService.publishEvent(any),
        ).thenAnswer((_) async => nip62Event);

        // Act
        final result = await service.deleteAccount();

        // Assert
        expect(result.success, isTrue);
        expect(result.deletedEventsCount, equals(3));
        verify(mockNostrService.publishEvent(any)).called(3);
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
          mockNostrService.queryEvents(any),
        ).thenAnswer((_) async => [userEvent]);

        var createCallCount = 0;
        when(
          mockAuthService.createAndSignEvent(
            kind: anyNamed('kind'),
            content: anyNamed('content'),
            tags: anyNamed('tags'),
          ),
        ).thenAnswer((_) async {
          createCallCount++;
          if (createCallCount == 1) return kind5Event;
          return nip62Event;
        });

        when(
          mockNostrService.publishEvent(any),
        ).thenAnswer((_) async => nip62Event);

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

        when(mockNostrService.queryEvents(any)).thenAnswer((_) async => []);
        when(
          mockAuthService.createAndSignEvent(
            kind: anyNamed('kind'),
            content: anyNamed('content'),
            tags: anyNamed('tags'),
          ),
        ).thenAnswer((_) async => nip62Event);
        when(
          mockNostrService.publishEvent(any),
        ).thenAnswer((_) async => nip62Event);

        // Act
        final result = await service.deleteAccount();

        // Assert
        expect(result.success, isTrue);
        expect(result.deletedEventsCount, equals(0));
        verify(mockNostrService.publishEvent(any)).called(1);
      });
    });
  });
}
