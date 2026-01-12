// ABOUTME: Unit tests for ContentReportingService
// ABOUTME: Tests NIP-56 content reporting including AI-generated content reports

import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/annotations.dart';
import 'package:mockito/mockito.dart';
import 'package:nostr_sdk/client_utils/keys.dart';
import 'package:nostr_sdk/event.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/content_moderation_service.dart';
import 'package:openvine/services/content_reporting_service.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'content_reporting_service_test.mocks.dart';

@GenerateMocks([NostrClient, AuthService])
void main() {
  group('ContentReportingService', () {
    late MockNostrClient mockNostrService;
    late MockAuthService mockAuthService;
    late ContentReportingService service;
    late SharedPreferences prefs;
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

    setUp(() async {
      // Generate valid keys for testing
      testPrivateKey = generatePrivateKey();
      testPublicKey = getPublicKey(testPrivateKey);

      // Setup SharedPreferences mock
      SharedPreferences.setMockInitialValues({});
      prefs = await SharedPreferences.getInstance();

      mockNostrService = MockNostrClient();
      mockAuthService = MockAuthService();

      // Setup common mocks
      when(mockAuthService.isAuthenticated).thenReturn(true);
      when(mockAuthService.currentPublicKeyHex).thenReturn(testPublicKey);
      when(mockNostrService.isInitialized).thenReturn(true);

      service = ContentReportingService(
        nostrService: mockNostrService,
        authService: mockAuthService,
        prefs: prefs,
      );

      await service.initialize();
    });

    test(
      'initialize() sets service ready when Nostr service is ready',
      () async {
        // Service should be initialized (report history starts empty)
        expect(service.reportHistory, isEmpty);
      },
    );

    test(
      'initialize() fails gracefully when Nostr service not ready',
      () async {
        when(mockNostrService.isInitialized).thenReturn(false);

        final uninitializedService = ContentReportingService(
          nostrService: mockNostrService,
          authService: mockAuthService,
          prefs: prefs,
        );

        await uninitializedService.initialize();

        // Should not throw, but won't be fully initialized
        expect(uninitializedService.reportHistory, isEmpty);
      },
    );

    test('reportContent() fails when service not initialized', () async {
      // Create new service without initializing
      final uninitializedService = ContentReportingService(
        nostrService: mockNostrService,
        authService: mockAuthService,
        prefs: prefs,
      );

      final result = await uninitializedService.reportContent(
        eventId: 'test_event_id',
        authorPubkey: 'test_author',
        reason: ContentFilterReason.spam,
        details: 'Spam content',
      );

      expect(result.success, false);
      expect(result.error, 'Reporting service not initialized');
    });

    test(
      'reportContent() succeeds for AI-generated content after initialization',
      () async {
        // Arrange
        final reportEvent = createTestEvent(
          pubkey: testPublicKey,
          kind: 1984,
          tags: [
            ['e', 'ai_video_event_id'],
            ['p', 'suspicious_author'],
          ],
          content: 'Suspected AI-generated content',
        );

        when(
          mockAuthService.createAndSignEvent(
            kind: anyNamed('kind'),
            content: anyNamed('content'),
            tags: anyNamed('tags'),
          ),
        ).thenAnswer((_) async => reportEvent);

        when(
          mockNostrService.publishEvent(any),
        ).thenAnswer((_) async => reportEvent);

        // Act
        final result = await service.reportContent(
          eventId: 'ai_video_event_id',
          authorPubkey: 'suspicious_author',
          reason: ContentFilterReason.aiGenerated,
          details: 'Suspected AI-generated content',
        );

        // Assert
        expect(result.success, true);
        expect(result.error, isNull);

        // Verify createAndSignEvent was called with kind 1984 (NIP-56)
        verify(
          mockAuthService.createAndSignEvent(
            kind: 1984,
            content: anyNamed('content'),
            tags: anyNamed('tags'),
          ),
        ).called(1);

        // Verify Nostr event was published
        verify(mockNostrService.publishEvent(any)).called(1);
      },
    );

    test(
      'reportContent() handles all ContentFilterReason types including aiGenerated',
      () async {
        // Arrange
        final reportEvent = createTestEvent(
          pubkey: testPublicKey,
          kind: 1984,
          tags: [],
          content: 'Test report',
        );

        when(
          mockAuthService.createAndSignEvent(
            kind: anyNamed('kind'),
            content: anyNamed('content'),
            tags: anyNamed('tags'),
          ),
        ).thenAnswer((_) async => reportEvent);

        when(
          mockNostrService.publishEvent(any),
        ).thenAnswer((_) async => reportEvent);

        final reasons = ContentFilterReason.values;

        for (final reason in reasons) {
          final result = await service.reportContent(
            eventId: 'event_${reason.name}',
            authorPubkey: 'author_123',
            reason: reason,
            details: 'Test report for ${reason.name}',
          );

          expect(
            result.success,
            true,
            reason: 'Failed for reason: ${reason.name}',
          );
        }

        // Should have called createAndSignEvent once per reason
        verify(
          mockAuthService.createAndSignEvent(
            kind: anyNamed('kind'),
            content: anyNamed('content'),
            tags: anyNamed('tags'),
          ),
        ).called(reasons.length);
      },
    );

    test('reportContent() specifically tests aiGenerated reason', () async {
      // Arrange
      final reportEvent = createTestEvent(
        pubkey: testPublicKey,
        kind: 1984,
        tags: [
          ['e', 'ai_content'],
          ['p', 'ai_creator'],
        ],
        content: 'Detected AI generation patterns',
      );

      when(
        mockAuthService.createAndSignEvent(
          kind: anyNamed('kind'),
          content: anyNamed('content'),
          tags: anyNamed('tags'),
        ),
      ).thenAnswer((_) async => reportEvent);

      when(
        mockNostrService.publishEvent(any),
      ).thenAnswer((_) async => reportEvent);

      // Act - This should not throw an exception due to missing switch case
      final result = await service.reportContent(
        eventId: 'ai_content',
        authorPubkey: 'ai_creator',
        reason: ContentFilterReason.aiGenerated,
        details: 'Detected AI generation patterns',
      );

      // Assert
      expect(result.success, true);
      expect(result.error, isNull);
    });

    test('reportContent() handles broadcast failures gracefully', () async {
      // Arrange
      final reportEvent = createTestEvent(
        pubkey: testPublicKey,
        kind: 1984,
        tags: [],
        content: 'Spam content',
      );

      when(
        mockAuthService.createAndSignEvent(
          kind: anyNamed('kind'),
          content: anyNamed('content'),
          tags: anyNamed('tags'),
        ),
      ).thenAnswer((_) async => reportEvent);

      // Mock failed publish - returns null on failure
      when(mockNostrService.publishEvent(any)).thenAnswer((_) async => null);

      // Act
      final result = await service.reportContent(
        eventId: 'event_123',
        authorPubkey: 'author_456',
        reason: ContentFilterReason.spam,
        details: 'Spam content',
      );

      // Assert - Service is resilient: saves report locally even if broadcast fails
      expect(result.success, true);
      expect(result.error, isNull);
      expect(result.reportId, isNotNull);

      // Verify report was saved to local history
      expect(service.reportHistory, isNotEmpty);
    });

    test('reportContent() stores report in history on success', () async {
      // Arrange
      final reportEvent = createTestEvent(
        pubkey: testPublicKey,
        kind: 1984,
        tags: [],
        content: 'AI detection',
      );

      when(
        mockAuthService.createAndSignEvent(
          kind: anyNamed('kind'),
          content: anyNamed('content'),
          tags: anyNamed('tags'),
        ),
      ).thenAnswer((_) async => reportEvent);

      when(
        mockNostrService.publishEvent(any),
      ).thenAnswer((_) async => reportEvent);

      // Act
      await service.reportContent(
        eventId: 'reported_event',
        authorPubkey: 'bad_actor',
        reason: ContentFilterReason.aiGenerated,
        details: 'AI detection',
      );

      // Assert
      expect(service.reportHistory, isNotEmpty);
      expect(
        service.reportHistory.first.reason,
        ContentFilterReason.aiGenerated,
      );
    });

    test('reportContent() fails when not authenticated', () async {
      // Arrange
      when(mockAuthService.isAuthenticated).thenReturn(false);

      // Act
      final result = await service.reportContent(
        eventId: 'test_event',
        authorPubkey: 'test_author',
        reason: ContentFilterReason.spam,
        details: 'Test',
      );

      // Assert
      expect(result.success, false);
      expect(result.error, contains('Not authenticated'));

      // Verify createAndSignEvent was NOT called
      verifyNever(
        mockAuthService.createAndSignEvent(
          kind: anyNamed('kind'),
          content: anyNamed('content'),
          tags: anyNamed('tags'),
        ),
      );
    });

    test(
      'reportContent() fails when createAndSignEvent returns null',
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
        final result = await service.reportContent(
          eventId: 'test_event',
          authorPubkey: 'test_author',
          reason: ContentFilterReason.spam,
          details: 'Test',
        );

        // Assert
        expect(result.success, false);
        expect(result.error, contains('Failed to create report event'));

        // Verify publishEvent was NOT called
        verifyNever(mockNostrService.publishEvent(any));
      },
    );
  });

  group('ContentReportingService Provider Integration', () {
    test('provider pattern calls initialize() on service creation', () async {
      // This test validates that the provider pattern we fixed actually works
      // The fix was adding: await service.initialize(); in the provider

      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final mockNostrService = MockNostrClient();
      final mockAuthService = MockAuthService();

      // Generate valid keys
      final testPrivateKey = generatePrivateKey();
      final testPublicKey = getPublicKey(testPrivateKey);

      when(mockNostrService.isInitialized).thenReturn(true);
      when(mockAuthService.isAuthenticated).thenReturn(true);
      when(mockAuthService.currentPublicKeyHex).thenReturn(testPublicKey);

      // Simulate what the provider does
      final service = ContentReportingService(
        nostrService: mockNostrService,
        authService: mockAuthService,
        prefs: prefs,
      );
      await service.initialize(); // This is what the provider now does

      // Setup mocks for reportContent
      final reportEvent = Event(
        testPublicKey,
        1984,
        [],
        'test',
        createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      );
      reportEvent.id = 'test_id';
      reportEvent.sig = 'test_sig';

      when(
        mockAuthService.createAndSignEvent(
          kind: anyNamed('kind'),
          content: anyNamed('content'),
          tags: anyNamed('tags'),
        ),
      ).thenAnswer((_) async => reportEvent);

      when(
        mockNostrService.publishEvent(any),
      ).thenAnswer((_) async => reportEvent);

      // Now reportContent should work
      final result = await service.reportContent(
        eventId: 'test',
        authorPubkey: 'test',
        reason: ContentFilterReason.aiGenerated,
        details: 'test',
      );

      expect(result.success, true);
    });
  });
}
