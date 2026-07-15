// ABOUTME: Tests for ModerationLabelService
// ABOUTME: Validates Kind 1985 label parsing including AI confidence metadata

import 'dart:async';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/filter.dart';
import 'package:nostr_sdk/nip05/nip05_validor.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/moderation_label_service.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:unified_logger/unified_logger.dart';

import '../helpers/test_pubkeys.dart';

class _MockNostrClient extends Mock implements NostrClient {}

class _MockAuthService extends Mock implements AuthService {}

class _FakeFilter extends Fake implements Filter {}

/// Serves a canned `nostr.json` so the NIP-05 leg resolves without a network.
class _FakeNip05Adapter implements HttpClientAdapter {
  _FakeNip05Adapter(this._body);

  final String _body;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<Uint8List>? requestStream,
    Future<void>? cancelFuture,
  ) async => ResponseBody.fromString(
    _body,
    200,
    headers: {
      Headers.contentTypeHeader: [Headers.jsonContentType],
    },
  );

  @override
  void close({bool force = false}) {}
}

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

  group('pinned-key mismatch logging (#4948 tier 1)', () {
    const pin = ModerationLabelService.fallbackModerationPubkeyHex;
    const divergentKey = syntheticTestPubkey;
    const resolvedPubkeyPrefsKey = 'divine_moderation_resolved_pubkey';

    late LogCaptureService logCapture;
    late HttpClientAdapter originalAdapter;

    setUp(() async {
      logCapture = LogCaptureService();
      await logCapture.clearAllLogs();
      originalAdapter = Nip05Validor.dio.httpClientAdapter;
    });

    tearDown(() async {
      // Restore the shared static adapter: an unrestored swap would strand
      // every later suite in the merged isolate on this fake.
      Nip05Validor.dio.httpClientAdapter = originalAdapter;
      await logCapture.clearAllLogs();
    });

    ModerationLabelService buildService({bool canQueryRelays = false}) =>
        ModerationLabelService(
          nostrClient: mockNostrClient,
          authService: mockAuthService,
          sharedPreferences: mockPrefs,
          canQueryRelays: () => canQueryRelays,
        );

    List<String> pinWarnings() => logCapture
        .getRecentLogs(minLevel: LogLevel.warning)
        .map((entry) => entry.message)
        .where((message) => message.contains('diverges from the key pinned'))
        .toList();

    test('stays silent when the adopted key is the pinned key', () async {
      final service = buildService();

      await service.ensureLoaded();

      expect(service.divineModerationPubkeyHex, pin);
      expect(pinWarnings(), isEmpty);
    });

    test('warns when a persisted key diverges from the pin', () async {
      await mockPrefs.setString(resolvedPubkeyPrefsKey, divergentKey);
      final service = buildService();

      await service.ensureLoaded();

      expect(
        service.divineModerationPubkeyHex,
        divergentKey,
        reason:
            'tier 1 keeps NIP-05 authoritative; the warning is advisory '
            'and must not change which key is trusted',
      );
      expect(pinWarnings(), hasLength(1));
    });

    test('names both keys in full so the warning is actionable', () async {
      await mockPrefs.setString(resolvedPubkeyPrefsKey, divergentKey);

      await buildService().ensureLoaded();

      expect(pinWarnings().single, contains(divergentKey));
      expect(pinWarnings().single, contains(pin));
    });

    test('does not warn when a persisted key differs only by case', () async {
      await mockPrefs.setString(resolvedPubkeyPrefsKey, pin.toUpperCase());

      await buildService().ensureLoaded();

      expect(
        pinWarnings(),
        isEmpty,
        reason:
            'NIP-05 mandates lowercase hex, but an uppercase answer is '
            'the same identity — warning on it would cry wolf',
      );
    });

    test('canonicalizes a persisted key that differs only by case', () async {
      await mockPrefs.setString(resolvedPubkeyPrefsKey, pin.toUpperCase());

      final service = buildService();
      await service.ensureLoaded();

      expect(
        service.divineModerationPubkeyHex,
        pin,
        reason:
            'the adopted identity feeds the subscription filter, and event '
            'authors are lowercase on the wire — storing the uppercase form '
            'would silently match no events',
      );
    });

    test('warns when NIP-05 resolves to a key that is not the pin', () async {
      Nip05Validor.dio.httpClientAdapter = _FakeNip05Adapter(
        '{"names":{"moderation":"$divergentKey"}}',
      );
      when(
        () => mockNostrClient.queryEvents(any()),
      ).thenAnswer((_) async => <Event>[]);
      final service = buildService(canQueryRelays: true);

      await service.initialize();

      expect(service.divineModerationPubkeyHex, divergentKey);
      expect(pinWarnings(), hasLength(1));
      expect(pinWarnings().single, contains(divergentKey));
    });
  });

  group(ModerationLabelService, () {
    test(
      'addLabeler preserves saved labelers before relay session is ready',
      () async {
        const existingLabeler =
            '1111111111111111111111111111111111111111111111111111111111111111';
        const newLabeler =
            '2222222222222222222222222222222222222222222222222222222222222222';

        SharedPreferences.setMockInitialValues({
          'subscribed_labeler_pubkeys': [existingLabeler],
          'divine_moderation_resolved_pubkey':
              ModerationLabelService.fallbackModerationPubkeyHex,
          'divine_moderation_resolved_at': DateTime.now().toIso8601String(),
        });
        final prefs = await SharedPreferences.getInstance();
        final gatedService = ModerationLabelService(
          nostrClient: mockNostrClient,
          authService: mockAuthService,
          sharedPreferences: prefs,
          canQueryRelays: () => false,
        );

        await gatedService.addLabeler(newLabeler);

        final saved = prefs.getStringList('subscribed_labeler_pubkeys');
        expect(
          saved,
          containsAll([
            existingLabeler,
            newLabeler,
            ModerationLabelService.fallbackModerationPubkeyHex,
          ]),
        );
        verifyNever(() => mockNostrClient.queryEvents(any()));
      },
    );

    test('ensureLoaded hydrates prefs without querying relays', () async {
      const existingLabeler =
          '1111111111111111111111111111111111111111111111111111111111111111';

      SharedPreferences.setMockInitialValues({
        'subscribed_labeler_pubkeys': [existingLabeler],
        'following_moderation_enabled': true,
      });
      final prefs = await SharedPreferences.getInstance();
      final localOnlyService = ModerationLabelService(
        nostrClient: mockNostrClient,
        authService: mockAuthService,
        sharedPreferences: prefs,
        canQueryRelays: () => false,
      );

      await localOnlyService.ensureLoaded();

      expect(localOnlyService.isFollowingModerationEnabled, isTrue);
      expect(localOnlyService.customLabelers, contains(existingLabeler));
      verifyNever(() => mockNostrClient.queryEvents(any()));
    });

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

        await service.subscribeToLabeler(service.divineModerationPubkeyHex);

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

        await service.subscribeToLabeler(service.divineModerationPubkeyHex);

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

        await service.subscribeToLabeler(service.divineModerationPubkeyHex);

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

        await service.subscribeToLabeler(service.divineModerationPubkeyHex);

        final result = service.getAIDetectionByHash('sha256_hash_of_content');
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

          await service.subscribeToLabeler(service.divineModerationPubkeyHex);

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

          await service.subscribeToLabeler(service.divineModerationPubkeyHex);

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

        await service.subscribeToLabeler(service.divineModerationPubkeyHex);

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

        await service.subscribeToLabeler(service.divineModerationPubkeyHex);

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

        await service.subscribeToLabeler(service.divineModerationPubkeyHex);

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

        await service.subscribeToLabeler(service.divineModerationPubkeyHex);

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

      test(
        'retries followed labelers enabled before relay readiness',
        () async {
          const followedLabeler =
              'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
          var canQueryRelays = false;
          final gatedService = ModerationLabelService(
            nostrClient: mockNostrClient,
            authService: mockAuthService,
            sharedPreferences: mockPrefs,
            canQueryRelays: () => canQueryRelays,
          );
          when(() => mockNostrClient.queryEvents(any())).thenAnswer(
            (_) async => [
              _FakeLabelEvent(
                pubkey: followedLabeler,
                tags: [
                  ['L', 'content-warning'],
                  ['l', 'nudity', 'content-warning'],
                  ['e', 'deferred_followed_event'],
                ],
              ),
            ],
          );

          await gatedService.setFollowingModerationEnabled(
            true,
            followedPubkeys: [followedLabeler],
          );

          expect(gatedService.isFollowingModerationEnabled, isTrue);
          expect(
            gatedService.getContentWarnings('deferred_followed_event'),
            isEmpty,
          );
          verifyNever(() => mockNostrClient.queryEvents(any()));

          canQueryRelays = true;
          await gatedService.syncFollowedLabelers([followedLabeler]);

          expect(
            gatedService.getContentWarnings('deferred_followed_event'),
            hasLength(1),
          );
          verify(() => mockNostrClient.queryEvents(any())).called(1);
        },
      );

      test('coalesces concurrent labeler subscriptions', () async {
        const labeler =
            'dddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddddd';
        final events = Completer<List<Event>>();
        when(() => mockNostrClient.queryEvents(any())).thenAnswer(
          (_) => events.future,
        );

        final firstSubscribe = service.subscribeToLabeler(labeler);
        final secondSubscribe = service.subscribeToLabeler(labeler);
        await Future<void>.delayed(Duration.zero);

        verify(() => mockNostrClient.queryEvents(any())).called(1);

        events.complete([
          _FakeLabelEvent(
            pubkey: labeler,
            tags: [
              ['L', 'content-warning'],
              ['l', 'nudity', 'content-warning'],
              ['e', 'coalesced_event'],
            ],
          ),
        ]);
        await Future.wait([firstSubscribe, secondSubscribe]);

        expect(service.getContentWarnings('coalesced_event'), hasLength(1));
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
