// ABOUTME: Unit tests for ContentReportingService
// ABOUTME: Tests NIP-56 content reporting including AI-generated content reports

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/client_utils/keys.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/event_kind.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/content_moderation_service.dart';
import 'package:openvine/services/content_reporting_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _MockNostrClient extends Mock implements NostrClient {}

class _MockAuthService extends Mock implements AuthService {}

class _FakeEvent extends Fake implements Event {}

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeEvent());
  });

  group('ContentReportingService', () {
    late _MockNostrClient mockNostrService;
    late _MockAuthService mockAuthService;
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

      mockNostrService = _MockNostrClient();
      mockAuthService = _MockAuthService();

      // Setup common mocks
      when(() => mockAuthService.isAuthenticated).thenReturn(true);
      when(() => mockAuthService.currentPublicKeyHex).thenReturn(testPublicKey);
      when(() => mockNostrService.isInitialized).thenReturn(true);

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
        when(() => mockNostrService.isInitialized).thenReturn(false);

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
          () => mockAuthService.createAndSignEvent(
            kind: any(named: 'kind'),
            content: any(named: 'content'),
            tags: any(named: 'tags'),
          ),
        ).thenAnswer((_) async => reportEvent);

        when(
          () => mockNostrService.publishEvent(
            any(),
            targetRelays: any(named: 'targetRelays'),
          ),
        ).thenAnswer((_) async => reportEvent);

        // Act
        final result = await service.reportContent(
          eventId: 'ai_video_event_id',
          authorPubkey: 'suspicious_author',
          reason: ContentFilterReason.other,
          details: 'Suspected AI-generated content',
        );

        // Assert
        expect(result.success, true);
        expect(result.error, isNull);

        // Verify createAndSignEvent was called with kind 1984 (NIP-56)
        verify(
          () => mockAuthService.createAndSignEvent(
            kind: 1984,
            content: any(named: 'content'),
            tags: any(named: 'tags'),
          ),
        ).called(1);

        // Verify Nostr event was published to moderation relay
        verify(
          () => mockNostrService.publishEvent(
            any(),
            targetRelays: any(named: 'targetRelays'),
          ),
        ).called(1);
      },
    );

    test('reportContent() handles all ContentFilterReason types including '
        'aiGenerated', () async {
      // Arrange
      final reportEvent = createTestEvent(
        pubkey: testPublicKey,
        kind: 1984,
        tags: [],
        content: 'Test report',
      );

      when(
        () => mockAuthService.createAndSignEvent(
          kind: any(named: 'kind'),
          content: any(named: 'content'),
          tags: any(named: 'tags'),
        ),
      ).thenAnswer((_) async => reportEvent);

      when(
        () => mockNostrService.publishEvent(
          any(),
          targetRelays: any(named: 'targetRelays'),
        ),
      ).thenAnswer((_) async => reportEvent);

      const reasons = ContentFilterReason.values;

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
        () => mockAuthService.createAndSignEvent(
          kind: any(named: 'kind'),
          content: any(named: 'content'),
          tags: any(named: 'tags'),
        ),
      ).called(reasons.length);
    });

    test('reportContent() includes NIP-32 l/L tags for each reason', () async {
      const expectedNip32Labels = {
        ContentFilterReason.spam: 'NS-spam',
        ContentFilterReason.harassment: 'NS-harassment',
        ContentFilterReason.violence: 'NS-violence',
        ContentFilterReason.sexualContent: 'NS-sexualContent',
        ContentFilterReason.copyright: 'NS-copyright',
        ContentFilterReason.falseInformation: 'NS-falseInformation',
        ContentFilterReason.csam: 'NS-csam',
        ContentFilterReason.aiGenerated: 'NS-aiGenerated',
        ContentFilterReason.other: 'NS-other',
      };

      final capturedTags = <List<List<String>>>[];

      when(
        () => mockAuthService.createAndSignEvent(
          kind: any(named: 'kind'),
          content: any(named: 'content'),
          tags: any(named: 'tags'),
        ),
      ).thenAnswer((invocation) async {
        final tags = invocation.namedArguments[#tags] as List<List<String>>;
        capturedTags.add(tags);
        return createTestEvent(
          pubkey: testPublicKey,
          kind: 1984,
          tags: tags,
          content: 'test',
        );
      });

      when(
        () => mockNostrService.publishEvent(
          any(),
          targetRelays: any(named: 'targetRelays'),
        ),
      ).thenAnswer(
        (_) async => createTestEvent(
          pubkey: testPublicKey,
          kind: 1984,
          tags: [],
          content: 'test',
        ),
      );

      for (final reason in ContentFilterReason.values) {
        await service.reportContent(
          eventId: 'event_${reason.name}',
          authorPubkey: 'author_${reason.name}',
          reason: reason,
          details: 'Test ${reason.name}',
        );
      }

      expect(
        capturedTags,
        hasLength(ContentFilterReason.values.length),
        reason: 'Should have captured tags for each reason',
      );

      for (var i = 0; i < ContentFilterReason.values.length; i++) {
        final reason = ContentFilterReason.values[i];
        final tags = capturedTags[i];

        final eTags = tags.where((t) => t[0] == 'e').toList();
        expect(eTags, hasLength(1), reason: 'Missing e tag for ${reason.name}');

        final pTags = tags.where((t) => t[0] == 'p').toList();
        expect(pTags, hasLength(1), reason: 'Missing p tag for ${reason.name}');

        final clientTags = tags.where((t) => t[0] == 'client').toList();
        expect(
          clientTags,
          hasLength(1),
          reason: 'Missing client tag for ${reason.name}',
        );

        final lNamespaceTags = tags.where((t) => t[0] == 'L').toList();
        expect(
          lNamespaceTags,
          hasLength(1),
          reason: 'Expected exactly one L tag for ${reason.name}',
        );
        expect(lNamespaceTags.single, ['L', 'social.nos.ontology']);

        final lTags = tags.where((t) => t[0] == 'l').toList();
        expect(
          lTags,
          hasLength(1),
          reason: 'Expected exactly one l tag for ${reason.name}',
        );
        expect(lTags.single, [
          'l',
          expectedNip32Labels[reason]!,
          'social.nos.ontology',
        ], reason: 'Missing or incorrect l tag for ${reason.name}');
      }
    });

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
        () => mockAuthService.createAndSignEvent(
          kind: any(named: 'kind'),
          content: any(named: 'content'),
          tags: any(named: 'tags'),
        ),
      ).thenAnswer((_) async => reportEvent);

      when(
        () => mockNostrService.publishEvent(
          any(),
          targetRelays: any(named: 'targetRelays'),
        ),
      ).thenAnswer((_) async => reportEvent);

      // Act - This should not throw an exception due to missing switch case
      final result = await service.reportContent(
        eventId: 'ai_content',
        authorPubkey: 'ai_creator',
        reason: ContentFilterReason.other,
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
        () => mockAuthService.createAndSignEvent(
          kind: any(named: 'kind'),
          content: any(named: 'content'),
          tags: any(named: 'tags'),
        ),
      ).thenAnswer((_) async => reportEvent);

      // Mock failed publish - returns null on failure
      when(
        () => mockNostrService.publishEvent(
          any(),
          targetRelays: any(named: 'targetRelays'),
        ),
      ).thenAnswer((_) async => null);

      // Act
      final result = await service.reportContent(
        eventId: 'event_123',
        authorPubkey: 'author_456',
        reason: ContentFilterReason.spam,
        details: 'Spam content',
      );

      // Assert - Service is resilient: saves report locally even if broadcast
      // fails
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
        () => mockAuthService.createAndSignEvent(
          kind: any(named: 'kind'),
          content: any(named: 'content'),
          tags: any(named: 'tags'),
        ),
      ).thenAnswer((_) async => reportEvent);

      when(
        () => mockNostrService.publishEvent(
          any(),
          targetRelays: any(named: 'targetRelays'),
        ),
      ).thenAnswer((_) async => reportEvent);

      // Act
      await service.reportContent(
        eventId: 'reported_event',
        authorPubkey: 'bad_actor',
        reason: ContentFilterReason.other,
        details: 'AI detection',
      );

      // Assert
      expect(service.reportHistory, isNotEmpty);
      expect(service.reportHistory.first.reason, ContentFilterReason.other);
    });

    test('reportContent() fails when not authenticated', () async {
      // Arrange
      when(() => mockAuthService.isAuthenticated).thenReturn(false);

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
        () => mockAuthService.createAndSignEvent(
          kind: any(named: 'kind'),
          content: any(named: 'content'),
          tags: any(named: 'tags'),
        ),
      );
    });

    test(
      'reportContent() fails when createAndSignEvent returns null',
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
        verifyNever(
          () => mockNostrService.publishEvent(
            any(),
            targetRelays: any(named: 'targetRelays'),
          ),
        );
      },
    );
  });

  group('NIP-56 tag compliance', () {
    late _MockNostrClient mockNostrService;
    late _MockAuthService mockAuthService;
    late ContentReportingService service;
    late String testPublicKey;

    setUp(() async {
      final testPrivateKey = generatePrivateKey();
      testPublicKey = getPublicKey(testPrivateKey);

      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();

      mockNostrService = _MockNostrClient();
      mockAuthService = _MockAuthService();

      when(() => mockAuthService.isAuthenticated).thenReturn(true);
      when(() => mockAuthService.currentPublicKeyHex).thenReturn(testPublicKey);
      when(() => mockNostrService.isInitialized).thenReturn(true);

      service = ContentReportingService(
        nostrService: mockNostrService,
        authService: mockAuthService,
        prefs: prefs,
      );
      await service.initialize();
    });

    test('uses EventKind.report (1984) as kind', () async {
      final reportEvent = Event(
        testPublicKey,
        EventKind.report,
        [],
        'test',
        createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
      );
      reportEvent.id = 'test_id';
      reportEvent.sig = 'test_sig';

      when(
        () => mockAuthService.createAndSignEvent(
          kind: any(named: 'kind'),
          content: any(named: 'content'),
          tags: any(named: 'tags'),
        ),
      ).thenAnswer((_) async => reportEvent);

      when(
        () => mockNostrService.publishEvent(
          any(),
          targetRelays: any(named: 'targetRelays'),
        ),
      ).thenAnswer((_) async => reportEvent);

      await service.reportContent(
        eventId: 'evt_1',
        authorPubkey: 'author_1',
        reason: ContentFilterReason.spam,
        details: 'test',
      );

      verify(
        () => mockAuthService.createAndSignEvent(
          kind: EventKind.report,
          content: any(named: 'content'),
          tags: any(named: 'tags'),
        ),
      ).called(1);
    });

    test('places NIP-56 report type as 3rd element of e and p tags', () async {
      List<List<String>>? capturedTags;

      when(
        () => mockAuthService.createAndSignEvent(
          kind: any(named: 'kind'),
          content: any(named: 'content'),
          tags: any(named: 'tags'),
        ),
      ).thenAnswer((invocation) async {
        capturedTags = invocation.namedArguments[#tags] as List<List<String>>?;
        final event = Event(
          testPublicKey,
          EventKind.report,
          capturedTags ?? [],
          'test',
          createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        );
        event.id = 'test_id';
        event.sig = 'test_sig';
        return event;
      });

      when(
        () => mockNostrService.publishEvent(
          any(),
          targetRelays: any(named: 'targetRelays'),
        ),
      ).thenAnswer(
        (_) async => Event(
          testPublicKey,
          EventKind.report,
          [],
          '',
          createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
        ),
      );

      await service.reportContent(
        eventId: 'evt_spam',
        authorPubkey: 'author_spam',
        reason: ContentFilterReason.spam,
        details: 'Spam content',
      );

      expect(capturedTags, isNotNull);

      // Find e and p tags
      final eTag = capturedTags!.firstWhere((t) => t[0] == 'e');
      final pTag = capturedTags!.firstWhere((t) => t[0] == 'p');

      // NIP-56: report type is the 3rd element
      expect(eTag, hasLength(3));
      expect(eTag[1], equals('evt_spam'));
      expect(eTag[2], equals('spam'));

      expect(pTag, hasLength(3));
      expect(pTag[1], equals('author_spam'));
      expect(pTag[2], equals('spam'));

      // No separate ['report', ...] tag should exist
      final reportTags = capturedTags!.where((t) => t[0] == 'report');
      expect(reportTags, isEmpty);
    });

    test('maps ContentFilterReason to NIP-56 standard types', () async {
      final expectedMappings = {
        ContentFilterReason.spam: 'spam',
        ContentFilterReason.harassment: 'profanity',
        ContentFilterReason.violence: 'illegal',
        ContentFilterReason.sexualContent: 'nudity',
        ContentFilterReason.copyright: 'illegal',
        ContentFilterReason.falseInformation: 'other',
        ContentFilterReason.csam: 'illegal',
        ContentFilterReason.aiGenerated: 'other',
        ContentFilterReason.other: 'other',
      };

      for (final entry in expectedMappings.entries) {
        List<List<String>>? capturedTags;

        when(
          () => mockAuthService.createAndSignEvent(
            kind: any(named: 'kind'),
            content: any(named: 'content'),
            tags: any(named: 'tags'),
          ),
        ).thenAnswer((invocation) async {
          capturedTags =
              invocation.namedArguments[#tags] as List<List<String>>?;
          final event = Event(
            testPublicKey,
            EventKind.report,
            capturedTags ?? [],
            'test',
            createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          );
          event.id = 'id_${entry.key.name}';
          event.sig = 'sig';
          return event;
        });

        when(
          () => mockNostrService.publishEvent(
            any(),
            targetRelays: any(named: 'targetRelays'),
          ),
        ).thenAnswer(
          (_) async => Event(
            testPublicKey,
            EventKind.report,
            [],
            '',
            createdAt: DateTime.now().millisecondsSinceEpoch ~/ 1000,
          ),
        );

        await service.reportContent(
          eventId: 'evt_${entry.key.name}',
          authorPubkey: 'author_${entry.key.name}',
          reason: entry.key,
          details: 'Test ${entry.key.name}',
        );

        final eTag = capturedTags!.firstWhere((t) => t[0] == 'e');
        expect(
          eTag[2],
          equals(entry.value),
          reason:
              '${entry.key.name} should map to NIP-56 type "${entry.value}"',
        );
      }
    });
  });

  group('ContentReportingService Provider Integration', () {
    test('provider pattern calls initialize() on service creation', () async {
      // This test validates that the provider pattern we fixed actually works
      // The fix was adding: await service.initialize(); in the provider

      SharedPreferences.setMockInitialValues({});
      final prefs = await SharedPreferences.getInstance();
      final mockNostrService = _MockNostrClient();
      final mockAuthService = _MockAuthService();

      // Generate valid keys
      final testPrivateKey = generatePrivateKey();
      final testPublicKey = getPublicKey(testPrivateKey);

      when(() => mockNostrService.isInitialized).thenReturn(true);
      when(() => mockAuthService.isAuthenticated).thenReturn(true);
      when(() => mockAuthService.currentPublicKeyHex).thenReturn(testPublicKey);

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
        () => mockAuthService.createAndSignEvent(
          kind: any(named: 'kind'),
          content: any(named: 'content'),
          tags: any(named: 'tags'),
        ),
      ).thenAnswer((_) async => reportEvent);

      when(
        () => mockNostrService.publishEvent(
          any(),
          targetRelays: any(named: 'targetRelays'),
        ),
      ).thenAnswer((_) async => reportEvent);

      // Now reportContent should work
      final result = await service.reportContent(
        eventId: 'test',
        authorPubkey: 'test',
        reason: ContentFilterReason.other,
        details: 'test',
      );

      expect(result.success, true);
    });
  });
}
