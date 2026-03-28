// ABOUTME: Tests for ModerationLabelService
// ABOUTME: Validates Kind 1985 label parsing including AI confidence metadata

import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/filter.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/moderation_label_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

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
  late SharedPreferences mockPrefs;
  late ModerationLabelService service;

  setUpAll(() {
    registerFallbackValue(<Filter>[_FakeFilter()]);
  });

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    mockPrefs = await SharedPreferences.getInstance();
    mockNostrClient = _MockNostrClient();
    mockAuthService = _MockAuthService();
    service = ModerationLabelService(
      nostrClient: mockNostrClient,
      authService: mockAuthService,
      sharedPreferences: mockPrefs,
    );
  });

  group(ModerationLabelService, () {
    group('_processLabelEvent', () {
      test('parses basic content-warning label', () async {
        when(() => mockNostrClient.queryEvents(any())).thenAnswer(
          (_) async => [
            _FakeLabelEvent(
              pubkey: service.divineModerationPubkeyHex,
              tags: [
                ['L', 'content-warning'],
                ['l', 'nudity', 'content-warning'],
                ['e', 'target_event_id_abc'],
              ],
            ),
          ],
        );

        await service.subscribeToLabeler(
          service.divineModerationPubkeyHex,
        );

        final warnings = service.getContentWarnings('target_event_id_abc');
        expect(warnings, hasLength(1));
        expect(warnings.first.labelValue, equals('nudity'));
        expect(
          warnings.first.labelerPubkey,
          equals(service.divineModerationPubkeyHex),
        );
      });

      test('parses ai-generated label with confidence metadata', () async {
        const metadata =
            '{"confidence": 0.95, "source": "hiveai", "verified": true}';
        when(() => mockNostrClient.queryEvents(any())).thenAnswer(
          (_) async => [
            _FakeLabelEvent(
              pubkey: service.divineModerationPubkeyHex,
              tags: [
                ['L', 'content-warning'],
                ['l', 'ai-generated', 'content-warning', metadata],
                ['e', 'event_123'],
              ],
            ),
          ],
        );

        await service.subscribeToLabeler(
          service.divineModerationPubkeyHex,
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
              pubkey: service.divineModerationPubkeyHex,
              tags: [
                ['L', 'content-warning'],
                ['l', 'ai-generated', 'content-warning', 'not-valid-json'],
                ['e', 'event_456'],
              ],
            ),
          ],
        );

        await service.subscribeToLabeler(
          service.divineModerationPubkeyHex,
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
              pubkey: service.divineModerationPubkeyHex,
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
          service.divineModerationPubkeyHex,
        );

        final result = service.getAIDetectionByHash(
          'sha256_hash_of_content',
        );
        expect(result, isNotNull);
        expect(result!.score, equals(0.12));
        expect(result.source, equals('hiveai'));
        expect(result.isVerified, isFalse);
      });

      test(
        'stores content-warning labels by addressable id from a tag',
        () async {
          const addressableId =
              '30311:creator_pubkey_hex:codex-staging-video-replaceable-id';

          when(() => mockNostrClient.queryEvents(any())).thenAnswer(
            (_) async => [
              _FakeLabelEvent(
                pubkey: service.divineModerationPubkeyHex,
                tags: [
                  ['L', 'content-warning'],
                  ['l', 'nudity', 'content-warning'],
                  ['a', addressableId],
                ],
              ),
            ],
          );

          await service.subscribeToLabeler(
            service.divineModerationPubkeyHex,
          );

          final labels = service.getContentWarningsByAddressableId(
            addressableId,
          );
          expect(labels, hasLength(1));
          expect(labels.first.labelValue, equals('nudity'));
        },
      );

      test(
        'stores content-warning labels by content hash from x tag',
        () async {
          when(() => mockNostrClient.queryEvents(any())).thenAnswer(
            (_) async => [
              _FakeLabelEvent(
                pubkey: service.divineModerationPubkeyHex,
                tags: [
                  ['L', 'content-warning'],
                  ['l', 'graphic-media', 'content-warning'],
                  ['x', 'sha256_content_warning_hash'],
                ],
              ),
            ],
          );

          await service.subscribeToLabeler(
            service.divineModerationPubkeyHex,
          );

          final labels = service.getContentWarningsByHash(
            'sha256_content_warning_hash',
          );
          expect(labels, hasLength(1));
          expect(labels.first.labelValue, equals('graphic-media'));
        },
      );

      test('stores labels by pubkey when p tag present', () async {
        when(() => mockNostrClient.queryEvents(any())).thenAnswer(
          (_) async => [
            _FakeLabelEvent(
              pubkey: service.divineModerationPubkeyHex,
              tags: [
                ['L', 'content-warning'],
                ['l', 'spam', 'content-warning'],
                ['p', 'target_pubkey_xyz'],
              ],
            ),
          ],
        );

        await service.subscribeToLabeler(
          service.divineModerationPubkeyHex,
        );

        final labels = service.getLabelsForPubkey('target_pubkey_xyz');
        expect(labels, hasLength(1));
        expect(labels.first.labelValue, equals('spam'));
      });

      test('ignores events without content-warning namespace', () async {
        when(() => mockNostrClient.queryEvents(any())).thenAnswer(
          (_) async => [
            _FakeLabelEvent(
              pubkey: service.divineModerationPubkeyHex,
              tags: [
                ['L', 'other-namespace'],
                ['l', 'some-label', 'other-namespace'],
                ['e', 'ignored_event'],
              ],
            ),
          ],
        );

        await service.subscribeToLabeler(
          service.divineModerationPubkeyHex,
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
              pubkey: service.divineModerationPubkeyHex,
              tags: [
                ['L', 'content-warning'],
                ['l', 'ai-generated', 'content-warning', metadata],
                ['e', 'ai_event_1'],
              ],
            ),
          ],
        );

        await service.subscribeToLabeler(
          service.divineModerationPubkeyHex,
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
              pubkey: service.divineModerationPubkeyHex,
              tags: [
                ['L', 'content-warning'],
                ['l', 'nudity', 'content-warning'],
                ['e', 'non_ai_event'],
              ],
            ),
          ],
        );

        await service.subscribeToLabeler(
          service.divineModerationPubkeyHex,
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

    group('followed labelers', () {
      test('enables followed pubkeys as trusted labelers', () async {
        const followedLabeler =
            'abcdefabcdefabcdefabcdefabcdefabcdefabcdefabcdefabcdefabcdefabcd';
        when(() => mockNostrClient.queryEvents(any())).thenAnswer(
          (_) async => [
            _FakeLabelEvent(
              pubkey: followedLabeler,
              tags: [
                ['L', 'content-warning'],
                ['l', 'nudity', 'content-warning'],
                ['e', 'followed_event'],
              ],
            ),
          ],
        );

        await service.setFollowingModerationEnabled(
          true,
          followedPubkeys: [followedLabeler],
        );

        expect(service.isFollowingModerationEnabled, isTrue);
        expect(service.getContentWarnings('followed_event'), hasLength(1));
      });

      test('disabling followed labelers removes their cached labels', () async {
        const followedLabeler =
            'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
        when(() => mockNostrClient.queryEvents(any())).thenAnswer(
          (_) async => [
            _FakeLabelEvent(
              pubkey: followedLabeler,
              tags: [
                ['L', 'content-warning'],
                ['l', 'violence', 'content-warning'],
                ['e', 'followed_event_2'],
              ],
            ),
          ],
        );

        await service.setFollowingModerationEnabled(
          true,
          followedPubkeys: [followedLabeler],
        );
        expect(service.getContentWarnings('followed_event_2'), hasLength(1));

        await service.setFollowingModerationEnabled(false);

        expect(service.isFollowingModerationEnabled, isFalse);
        expect(service.getContentWarnings('followed_event_2'), isEmpty);
      });

      test(
        'disabling followed labelers keeps explicitly subscribed labelers',
        () async {
          const explicitLabeler =
              'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc';
          when(() => mockNostrClient.queryEvents(any())).thenAnswer(
            (_) async => [
              _FakeLabelEvent(
                pubkey: explicitLabeler,
                tags: [
                  ['L', 'content-warning'],
                  ['l', 'graphic-media', 'content-warning'],
                  ['e', 'explicit_event'],
                ],
              ),
            ],
          );

          await service.addLabeler(explicitLabeler);
          await service.setFollowingModerationEnabled(
            true,
            followedPubkeys: [explicitLabeler],
          );
          await service.setFollowingModerationEnabled(false);

          expect(service.getContentWarnings('explicit_event'), hasLength(1));
        },
      );
    });
  });
}
