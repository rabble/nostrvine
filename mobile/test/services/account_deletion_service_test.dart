// ABOUTME: Tests for NIP-62 account deletion service
// ABOUTME: Verifies kind 62 event creation, ALL_RELAYS tag, and broadcast behavior

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
    }) {
      final event = Event(
        pubkey,
        kind,
        tags,
        content,
        createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      );
      event.id = 'test_event_${DateTime.now().millisecondsSinceEpoch}';
      event.sig = 'test_signature';
      return event;
    }

    setUp(() {
      // Generate valid keys for testing
      testPrivateKey = generatePrivateKey();
      testPublicKey = getPublicKey(testPrivateKey);

      mockNostrService = MockNostrClient();
      mockAuthService = MockAuthService();
      service = AccountDeletionService(
        nostrService: mockNostrService,
        authService: mockAuthService,
      );

      // Setup common mocks
      when(mockAuthService.isAuthenticated).thenReturn(true);
      when(mockAuthService.currentPublicKeyHex).thenReturn(testPublicKey);
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

      when(mockNostrService.broadcast(any)).thenAnswer(
        (_) async => NostrBroadcastResult(
          event: expectedEvent,
          successCount: 3,
          totalRelays: 3,
          results: {'relay1': true, 'relay2': true, 'relay3': true},
          errors: {},
        ),
      );

      // Act
      await expectLater(service.deleteAccount(), completes);

      // Assert
      verify(mockNostrService.broadcast(any)).called(1);
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

        when(mockNostrService.broadcast(any)).thenAnswer(
          (_) async => NostrBroadcastResult(
            event: expectedEvent,
            successCount: 3,
            totalRelays: 3,
            results: {'relay1': true, 'relay2': true, 'relay3': true},
            errors: {},
          ),
        );

        // Act
        final result = await service.deleteAccount();

        // Assert
        expect(result.success, isTrue);
        expect(result.error, isNull);
      },
    );

    test('deleteAccount should return failure when broadcast fails', () async {
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

      when(mockNostrService.broadcast(any)).thenAnswer(
        (_) async => NostrBroadcastResult(
          event: expectedEvent,
          successCount: 0,
          totalRelays: 3,
          results: {'relay1': false, 'relay2': false, 'relay3': false},
          errors: {'relay1': 'error1', 'relay2': 'error2', 'relay3': 'error3'},
        ),
      );

      // Act
      final result = await service.deleteAccount();

      // Assert
      expect(result.success, isFalse);
      expect(result.error, isNotNull);
      expect(result.error, contains('Failed to broadcast'));
    });

    test('deleteAccount should fail when not authenticated', () async {
      // Arrange
      when(mockAuthService.isAuthenticated).thenReturn(false);

      // Act
      final result = await service.deleteAccount();

      // Assert
      expect(result.success, isFalse);
      expect(result.error, contains('Not authenticated'));

      // Verify broadcast was NOT called
      verifyNever(mockNostrService.broadcast(any));
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

        // Verify broadcast was NOT called
        verifyNever(mockNostrService.broadcast(any));
      },
    );
  });
}
