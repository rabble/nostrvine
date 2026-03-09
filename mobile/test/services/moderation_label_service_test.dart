// ABOUTME: Tests for ModerationLabelService
// ABOUTME: Validates Kind 1985 label parsing including AI confidence metadata

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/filter.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/moderation_label_service.dart';

class _MockNostrClient extends Mock implements NostrClient {}

class _MockAuthService extends Mock implements AuthService {}

class _FakeFilter extends Fake implements Filter {}

/// Fake event for testing label processing.
class _FakeLabelEvent extends Fake implements Event {
  _FakeLabelEvent({required this.pubkey, required this.tags});

  @override
  final String pubkey;

  @override
  final List<List<String>> tags;
}

void main() {
  late _MockNostrClient mockNostrClient;
  late _MockAuthService mockAuthService;
  late ModerationLabelService service;

  setUpAll(() {
    registerFallbackValue(<Filter>[_FakeFilter()]);
  });

  setUp(() {
    mockNostrClient = _MockNostrClient();
    mockAuthService = _MockAuthService();
    service = ModerationLabelService(
      nostrClient: mockNostrClient,
      authService: mockAuthService,
    );
  });

  group(ModerationLabelService, () {
    group('_processLabelEvent', () {
      test('parses basic content-warning label', () async {
        when(() => mockNostrClient.queryEvents(any())).thenAnswer(
          (_) async => [
            _FakeLabelEvent(
              pubkey: ModerationLabelService.divineModerationPubkeyHex,
              tags: [
                ['L', 'content-warning'],
                ['l', 'nudity', 'content-warning'],
                ['e', 'target_event_id_abc'],
              ],
            ),
          ],
        );

        await service.subscribeToLabeler(
          ModerationLabelService.divineModerationPubkeyHex,
        );

        final warnings = service.getContentWarnings('target_event_id_abc');
        expect(warnings, hasLength(1));
        expect(warnings.first.labelValue, equals('nudity'));
        expect(
          warnings.first.labelerPubkey,
          equals(ModerationLabelService.divineModerationPubkeyHex),
        );
      });

      test('parses ai-generated label with confidence metadata', () async {
        const metadata =
            '{"confidence": 0.95, "source": "hiveai", "verified": true}';
        when(() => mockNostrClient.queryEvents(any())).thenAnswer(
          (_) async => [
            _FakeLabelEvent(
              pubkey: ModerationLabelService.divineModerationPubkeyHex,
              tags: [
                ['L', 'content-warning'],
                ['l', 'ai-generated', 'content-warning', metadata],
                ['e', 'event_123'],
              ],
            ),
          ],
        );

        await service.subscribeToLabeler(
          ModerationLabelService.divineModerationPubkeyHex,
        );

        final warnings = service.getContentWarnings('event_123');
        expect(warnings, hasLength(1));
        expect(warnings.first.labelValue, equals('ai-generated'));
        expect(warnings.first.confidence, equals(0.95));
        expect(warnings.first.source, equals('hiveai'));
        expect(warnings.first.isVerified, isTrue);
      });

      test('handles malformed metadata JSON gracefully', () async {
        when(() => mockNostrClient.queryEvents(any())).thenAnswer(
          (_) async => [
            _FakeLabelEvent(
              pubkey: ModerationLabelService.divineModerationPubkeyHex,
              tags: [
                ['L', 'content-warning'],
                ['l', 'ai-generated', 'content-warning', 'not-valid-json'],
                ['e', 'event_456'],
              ],
            ),
          ],
        );

        await service.subscribeToLabeler(
          ModerationLabelService.divineModerationPubkeyHex,
        );

        final warnings = service.getContentWarnings('event_456');
        expect(warnings, hasLength(1));
        expect(warnings.first.labelValue, equals('ai-generated'));
        expect(warnings.first.confidence, isNull);
        expect(warnings.first.source, isNull);
        expect(warnings.first.isVerified, isFalse);
      });

      test('indexes labels by content hash from x tag', () async {
        const metadata = '{"confidence": 0.12, "source": "hiveai"}';
        when(() => mockNostrClient.queryEvents(any())).thenAnswer(
          (_) async => [
            _FakeLabelEvent(
              pubkey: ModerationLabelService.divineModerationPubkeyHex,
              tags: [
                ['L', 'content-warning'],
                ['l', 'ai-generated', 'content-warning', metadata],
                ['e', 'event_789'],
                ['x', 'sha256_hash_of_content'],
              ],
            ),
          ],
        );

        await service.subscribeToLabeler(
          ModerationLabelService.divineModerationPubkeyHex,
        );

        final result = service.getAIDetectionByHash(
          'sha256_hash_of_content',
        );
        expect(result, isNotNull);
        expect(result!.score, equals(0.12));
        expect(result.source, equals('hiveai'));
        expect(result.isVerified, isFalse);
      });

      test('stores labels by pubkey when p tag present', () async {
        when(() => mockNostrClient.queryEvents(any())).thenAnswer(
          (_) async => [
            _FakeLabelEvent(
              pubkey: ModerationLabelService.divineModerationPubkeyHex,
              tags: [
                ['L', 'content-warning'],
                ['l', 'spam', 'content-warning'],
                ['p', 'target_pubkey_xyz'],
              ],
            ),
          ],
        );

        await service.subscribeToLabeler(
          ModerationLabelService.divineModerationPubkeyHex,
        );

        final labels = service.getLabelsForPubkey('target_pubkey_xyz');
        expect(labels, hasLength(1));
        expect(labels.first.labelValue, equals('spam'));
      });

      test('ignores events without content-warning namespace', () async {
        when(() => mockNostrClient.queryEvents(any())).thenAnswer(
          (_) async => [
            _FakeLabelEvent(
              pubkey: ModerationLabelService.divineModerationPubkeyHex,
              tags: [
                ['L', 'other-namespace'],
                ['l', 'some-label', 'other-namespace'],
                ['e', 'ignored_event'],
              ],
            ),
          ],
        );

        await service.subscribeToLabeler(
          ModerationLabelService.divineModerationPubkeyHex,
        );

        expect(service.hasContentWarning('ignored_event'), isFalse);
      });
    });

    group('getAIDetectionResult', () {
      test('returns result for event with ai-generated label', () async {
        const metadata = '{"confidence": 0.73, "source": "hiveai"}';
        when(() => mockNostrClient.queryEvents(any())).thenAnswer(
          (_) async => [
            _FakeLabelEvent(
              pubkey: ModerationLabelService.divineModerationPubkeyHex,
              tags: [
                ['L', 'content-warning'],
                ['l', 'ai-generated', 'content-warning', metadata],
                ['e', 'ai_event_1'],
              ],
            ),
          ],
        );

        await service.subscribeToLabeler(
          ModerationLabelService.divineModerationPubkeyHex,
        );

        final result = service.getAIDetectionResult('ai_event_1');
        expect(result, isNotNull);
        expect(result!.score, equals(0.73));
        expect(result.source, equals('hiveai'));
      });

      test('returns null for event without ai-generated label', () async {
        when(() => mockNostrClient.queryEvents(any())).thenAnswer(
          (_) async => [
            _FakeLabelEvent(
              pubkey: ModerationLabelService.divineModerationPubkeyHex,
              tags: [
                ['L', 'content-warning'],
                ['l', 'nudity', 'content-warning'],
                ['e', 'non_ai_event'],
              ],
            ),
          ],
        );

        await service.subscribeToLabeler(
          ModerationLabelService.divineModerationPubkeyHex,
        );

        final result = service.getAIDetectionResult('non_ai_event');
        expect(result, isNull);
      });

      test('returns null for unknown event ID', () {
        final result = service.getAIDetectionResult('unknown_id');
        expect(result, isNull);
      });
    });

    group('getAIDetectionByHash', () {
      test('returns null for unknown hash', () {
        final result = service.getAIDetectionByHash('unknown_hash');
        expect(result, isNull);
      });
    });

    group('hasContentWarning', () {
      test('returns false for unknown event', () {
        expect(service.hasContentWarning('unknown'), isFalse);
      });
    });
  });
}
