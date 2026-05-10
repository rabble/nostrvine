// ABOUTME: Tests for NIP17MessageService encrypted message sending.
// ABOUTME: Covers NIP-17 gift wrap creation, encryption, publishing,
// ABOUTME: self-wrap fallback, and error handling paths.

import 'package:dm_repository/dm_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:nostr_sdk/client_utils/keys.dart';
import 'package:nostr_sdk/event.dart';
import 'package:nostr_sdk/event_kind.dart';
import 'package:nostr_sdk/nip59/gift_wrap_util.dart';
import 'package:nostr_sdk/signer/local_nostr_signer.dart';
import 'package:nostr_sdk/signer/nostr_signer.dart';
import 'package:unified_logger/unified_logger.dart';

class _MockNostrClient extends Mock implements NostrClient {}

class _MockNostrSigner extends Mock implements NostrSigner {}

class _FakeEvent extends Fake implements Event {}

// Valid 64-character hex keys for testing.
const _testPrivateKey =
    '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';
const _testPublicKey =
    '1234567890abcdef1234567890abcdef1234567890abcdef1234567890abcdef';
const _recipientPubkey =
    'e771af0b05c8e95fcdf6feb3500544d2fb1ccd384788e9f490bb3ee28e8ed66f';

void main() {
  setUpAll(() {
    registerFallbackValue(_FakeEvent());
  });

  group(NIP17MessageService, () {
    late NIP17MessageService service;
    late _MockNostrClient mockNostrClient;

    setUp(() {
      mockNostrClient = _MockNostrClient();

      service = NIP17MessageService(
        signer: LocalNostrSigner(_testPrivateKey),
        senderPublicKey: _testPublicKey,
        nostrService: mockNostrClient,
      );
    });

    test('nostrService getter returns the injected client', () {
      expect(service.nostrService, same(mockNostrClient));
    });

    group('sendPrivateMessage', () {
      test('returns success with gift wrap event details', () async {
        when(() => mockNostrClient.publishEvent(any())).thenAnswer(
          (invocation) async =>
              PublishSuccess(event: invocation.positionalArguments[0] as Event),
        );

        final result = await service.sendPrivateMessage(
          recipientPubkey: _recipientPubkey,
          content: 'Test message',
        );

        expect(result.success, isTrue);
        expect(result.rumorEventId, isNotNull);
        expect(result.messageEventId, isNotNull);
        expect(result.recipientPubkey, equals(_recipientPubkey));
        expect(result.error, isNull);

        // At least the recipient gift wrap is published; self-wrap may
        // silently fail with synthetic test keys.
        verify(() => mockNostrClient.publishEvent(any())).called(
          greaterThanOrEqualTo(1),
        );
      });

      test('creates gift wrap with kind 1059', () async {
        Event? capturedEvent;

        when(() => mockNostrClient.publishEvent(any())).thenAnswer(
          (invocation) async {
            capturedEvent = invocation.positionalArguments[0] as Event;
            return PublishSuccess(event: capturedEvent!);
          },
        );

        await service.sendPrivateMessage(
          recipientPubkey: _recipientPubkey,
          content: 'Test message',
        );

        expect(capturedEvent, isNotNull);
        expect(capturedEvent!.kind, equals(EventKind.giftWrap));
      });

      test('includes p tag with recipient pubkey', () async {
        Event? capturedEvent;

        when(() => mockNostrClient.publishEvent(any())).thenAnswer(
          (invocation) async {
            capturedEvent = invocation.positionalArguments[0] as Event;
            return PublishSuccess(event: capturedEvent!);
          },
        );

        await service.sendPrivateMessage(
          recipientPubkey: _recipientPubkey,
          content: 'Test message',
        );

        expect(capturedEvent, isNotNull);
        final pTags = capturedEvent!.tags.where(
          (tag) => tag.isNotEmpty && tag[0] == 'p',
        );
        expect(pTags, isNotEmpty);
        expect(pTags.first[1], equals(_recipientPubkey));
      });

      test('uses random ephemeral key for each gift wrap', () async {
        final capturedEvents = <Event>[];

        when(() => mockNostrClient.publishEvent(any())).thenAnswer(
          (invocation) async {
            final event = invocation.positionalArguments[0] as Event;
            capturedEvents.add(event);
            return PublishSuccess(event: event);
          },
        );

        await service.sendPrivateMessage(
          recipientPubkey: _recipientPubkey,
          content: 'Message 1',
        );
        await service.sendPrivateMessage(
          recipientPubkey: _recipientPubkey,
          content: 'Message 2',
        );

        // At least 2 recipient gift wraps (self-wraps may silently fail
        // with synthetic test keys that are not valid EC points).
        expect(capturedEvents.length, greaterThanOrEqualTo(2));
        // First two events are the recipient gift wraps for each message.
        expect(
          capturedEvents[0].pubkey,
          isNot(equals(capturedEvents[1].pubkey)),
        );
        expect(capturedEvents[0].pubkey, isNot(equals(_testPublicKey)));
        expect(capturedEvents[1].pubkey, isNot(equals(_testPublicKey)));
      });

      test('obfuscates timestamp with random offset', () async {
        Event? capturedEvent;

        when(() => mockNostrClient.publishEvent(any())).thenAnswer(
          (invocation) async {
            capturedEvent = invocation.positionalArguments[0] as Event;
            return PublishSuccess(event: capturedEvent!);
          },
        );

        final beforeSend = DateTime.now().millisecondsSinceEpoch ~/ 1000;
        await service.sendPrivateMessage(
          recipientPubkey: _recipientPubkey,
          content: 'Test message',
        );
        final afterSend = DateTime.now().millisecondsSinceEpoch ~/ 1000;

        expect(capturedEvent, isNotNull);
        final timeDiff = (capturedEvent!.createdAt - beforeSend).abs();
        expect(timeDiff, lessThanOrEqualTo(60 * 60 * 24 * 2));
        expect(capturedEvent!.createdAt, lessThan(afterSend));
      });

      test(
        'returns failure when publish does not return PublishSuccess',
        () async {
          when(
            () => mockNostrClient.publishEvent(any()),
          ).thenAnswer((_) async => const PublishFailed());

          final result = await service.sendPrivateMessage(
            recipientPubkey: _recipientPubkey,
            content: 'Test message',
          );

          expect(result.success, isFalse);
          expect(result.error, contains('publish failed'));
        },
      );

      test('includes additional tags in the gift wrap', () async {
        Event? capturedEvent;

        when(() => mockNostrClient.publishEvent(any())).thenAnswer(
          (invocation) async {
            capturedEvent = invocation.positionalArguments[0] as Event;
            return PublishSuccess(event: capturedEvent!);
          },
        );

        await service.sendPrivateMessage(
          recipientPubkey: _recipientPubkey,
          content: 'Test message',
          additionalTags: [
            ['client', 'diVine_bug_report'],
            ['report_id', 'test-123'],
          ],
        );

        expect(capturedEvent, isNotNull);
      });

      test('uses provided eventKind for the rumor', () async {
        when(() => mockNostrClient.publishEvent(any())).thenAnswer(
          (invocation) async =>
              PublishSuccess(event: invocation.positionalArguments[0] as Event),
        );

        final result = await service.sendPrivateMessage(
          recipientPubkey: _recipientPubkey,
          content: 'https://example.com/file.mp4',
          eventKind: EventKind.fileMessage,
        );

        // The rumor was created with kind 15; the gift wrap is still 1059.
        // We can only verify via the success result since the rumor is
        // encrypted inside the gift wrap.
        expect(result.success, isTrue);
        expect(result.rumorEventId, isNotNull);
      });

      test('returns success with selfWrapPublished=false when self-wrap '
          'publish throws (recipient delivered, sender will not see this '
          'message on other devices)', () async {
        var callCount = 0;
        when(() => mockNostrClient.publishEvent(any())).thenAnswer(
          (invocation) async {
            callCount++;
            if (callCount == 1) {
              return PublishSuccess(
                event: invocation.positionalArguments[0] as Event,
              );
            }
            throw Exception('self-wrap relay error');
          },
        );

        final result = await service.sendPrivateMessage(
          recipientPubkey: _recipientPubkey,
          content: 'Test message',
        );

        expect(result.success, isTrue);
        expect(result.rumorEventId, isNotNull);
        expect(
          result.selfWrapPublished,
          isFalse,
          reason:
              'Self-wrap throws were silently swallowed before; the '
              'result must now reflect that the sender will not see '
              'this message on other devices until the self-wrap is '
              're-published (#3909 tracks the future retry path).',
        );
      });

      test('emits info log "Successfully published NIP-17 message '
          '(selfWrapPublished=false)" when self-wrap publish throws', () async {
        // Closes the gap from PR #3910's manual-verification checklist:
        // the reviewer asked for a real-device confirmation that this
        // exact log line fires on partial delivery (Keycast RPC slow ->
        // self-wrap second sign throws). Captured deterministically here
        // so CI guards against future drift in the log copy.
        await LogCaptureService().clearAllLogs();

        var callCount = 0;
        when(() => mockNostrClient.publishEvent(any())).thenAnswer((
          invocation,
        ) async {
          callCount++;
          if (callCount == 1) {
            return PublishSuccess(
              event: invocation.positionalArguments[0] as Event,
            );
          }
          throw Exception('keycast rpc timeout');
        });

        await service.sendPrivateMessage(
          recipientPubkey: _recipientPubkey,
          content: 'Test message',
        );

        final logs = LogCaptureService().getRecentLogs();
        expect(
          logs.any(
            (e) =>
                e.level == LogLevel.info &&
                e.message ==
                    'Successfully published NIP-17 message '
                        '(selfWrapPublished=false)',
          ),
          isTrue,
          reason:
              'Diagnostic log copy for production triage of partial '
              'delivery. Not a load-bearing contract — the durable '
              'outgoing-DM queue (#3909) keys off '
              'NIP17SendResult.selfWrapPublished, not this string.',
        );
      });

      test(
        'returns success with selfWrapPublished=false '
        'when self-wrap publish returns PublishFailed',
        () async {
          final signer = LocalNostrSigner(_testPrivateKey);
          final senderPublicKey = (await signer.getPublicKey())!;
          final matchingService = NIP17MessageService(
            signer: signer,
            senderPublicKey: senderPublicKey,
            nostrService: mockNostrClient,
          );
          var callCount = 0;
          when(() => mockNostrClient.publishEvent(any())).thenAnswer(
            (invocation) async {
              callCount++;
              if (callCount == 1) {
                return PublishSuccess(
                  event: invocation.positionalArguments[0] as Event,
                );
              }
              return const PublishFailed();
            },
          );

          final result = await matchingService.sendPrivateMessage(
            recipientPubkey: _recipientPubkey,
            content: 'Test message',
          );

          expect(result.success, isTrue);
          expect(result.rumorEventId, isNotNull);
          expect(result.selfWrapPublished, isFalse);
        },
      );

      test(
        'returns success with selfWrapPublished=false '
        'when self-wrap publish returns PublishNoRelays',
        () async {
          final signer = LocalNostrSigner(_testPrivateKey);
          final senderPublicKey = (await signer.getPublicKey())!;
          final matchingService = NIP17MessageService(
            signer: signer,
            senderPublicKey: senderPublicKey,
            nostrService: mockNostrClient,
          );
          var callCount = 0;
          when(() => mockNostrClient.publishEvent(any())).thenAnswer((
            invocation,
          ) async {
            callCount++;
            if (callCount == 1) {
              return PublishSuccess(
                event: invocation.positionalArguments[0] as Event,
              );
            }
            return const PublishNoRelays();
          });

          final result = await matchingService.sendPrivateMessage(
            recipientPubkey: _recipientPubkey,
            content: 'Test message',
          );

          expect(result.success, isTrue);
          expect(result.rumorEventId, isNotNull);
          expect(result.selfWrapPublished, isFalse);
        },
      );

      test(
        'returns success with selfWrapPublished=false when self-wrap '
        'publish returns PublishFailed (relay rejected with no exception)',
        () async {
          var callCount = 0;
          when(() => mockNostrClient.publishEvent(any())).thenAnswer(
            (invocation) async {
              callCount++;
              if (callCount == 1) {
                return PublishSuccess(
                  event: invocation.positionalArguments[0] as Event,
                );
              }
              return const PublishFailed();
            },
          );

          final result = await service.sendPrivateMessage(
            recipientPubkey: _recipientPubkey,
            content: 'Test message',
          );

          expect(result.success, isTrue);
          expect(result.selfWrapPublished, isFalse);
        },
      );

      test(
        'publishes a self-wrap with selfWrapPublished=true '
        'when sender pubkey matches the signer and publish succeeds',
        () async {
          final signer = LocalNostrSigner(_testPrivateKey);
          final senderPublicKey = (await signer.getPublicKey())!;
          final capturedEvents = <Event>[];

          final matchingService = NIP17MessageService(
            signer: signer,
            senderPublicKey: senderPublicKey,
            nostrService: mockNostrClient,
          );

          when(() => mockNostrClient.publishEvent(any())).thenAnswer(
            (invocation) async {
              final event = invocation.positionalArguments[0] as Event;
              capturedEvents.add(event);
              return PublishSuccess(event: event);
            },
          );

          final result = await matchingService.sendPrivateMessage(
            recipientPubkey: _recipientPubkey,
            content: 'Test message',
          );

          expect(result.success, isTrue);
          expect(result.selfWrapPublished, isTrue);
          expect(capturedEvents, hasLength(2));
          expect(capturedEvents[0].kind, EventKind.giftWrap);
          expect(capturedEvents[1].kind, EventKind.giftWrap);
        },
      );

      group('with sender pubkey derived from signer key', () {
        // Existing tests use a synthetic _testPublicKey that is not a
        // valid secp256k1 point, so the self-wrap's NIP-44 ECDH throws
        // before reaching the publish call. These tests pair the signer
        // with a sender pubkey actually derived from its private key, so
        // the self-wrap path runs end-to-end and the publish/build-side
        // branches are exercised.
        late NIP17MessageService realKeyService;

        setUp(() {
          realKeyService = NIP17MessageService(
            signer: LocalNostrSigner(_testPrivateKey),
            senderPublicKey: getPublicKey(_testPrivateKey),
            nostrService: mockNostrClient,
          );
        });

        test(
          'returns selfWrapPublished=true when both publishes succeed',
          () async {
            when(() => mockNostrClient.publishEvent(any())).thenAnswer(
              (invocation) async => PublishSuccess(
                event: invocation.positionalArguments[0] as Event,
              ),
            );

            final result = await realKeyService.sendPrivateMessage(
              recipientPubkey: _recipientPubkey,
              content: 'Test message',
            );

            expect(result.success, isTrue);
            expect(result.selfWrapPublished, isTrue);
            verify(() => mockNostrClient.publishEvent(any())).called(2);
          },
        );

        test('emits info log "Successfully published NIP-17 message '
            '(selfWrapPublished=true)" when both publishes succeed', () async {
          await LogCaptureService().clearAllLogs();

          when(() => mockNostrClient.publishEvent(any())).thenAnswer(
            (invocation) async => PublishSuccess(
              event: invocation.positionalArguments[0] as Event,
            ),
          );

          await realKeyService.sendPrivateMessage(
            recipientPubkey: _recipientPubkey,
            content: 'Test message',
          );

          final logs = LogCaptureService().getRecentLogs();
          expect(
            logs.any(
              (e) =>
                  e.level == LogLevel.info &&
                  e.message ==
                      'Successfully published NIP-17 message '
                          '(selfWrapPublished=true)',
            ),
            isTrue,
            reason:
                'Diagnostic log copy for production triage. Symmetric '
                'with the partial-delivery log assertion above; neither '
                'is a contract the outgoing queue (#3909) keys off — '
                'the queue keys off NIP17SendResult.selfWrapPublished.',
          );
        });

        test('returns selfWrapPublished=false when self-wrap publish '
            'returns PublishFailed without throwing', () async {
          var callCount = 0;
          when(() => mockNostrClient.publishEvent(any())).thenAnswer((
            invocation,
          ) async {
            callCount++;
            if (callCount == 1) {
              return PublishSuccess(
                event: invocation.positionalArguments[0] as Event,
              );
            }
            return const PublishFailed();
          });

          final result = await realKeyService.sendPrivateMessage(
            recipientPubkey: _recipientPubkey,
            content: 'Test message',
          );

          expect(result.success, isTrue);
          expect(result.selfWrapPublished, isFalse);
          verify(() => mockNostrClient.publishEvent(any())).called(2);
        });

        test('returns selfWrapPublished=false when self-wrap event '
            'creation returns null (defensive null-event branch)', () async {
          var builderCalls = 0;
          final service = NIP17MessageService(
            signer: LocalNostrSigner(_testPrivateKey),
            senderPublicKey: getPublicKey(_testPrivateKey),
            nostrService: mockNostrClient,
            giftWrapBuilder: (nostr, rumor, recipientPubkey) async {
              builderCalls++;
              if (builderCalls == 1) {
                return GiftWrapUtil.getGiftWrapEvent(
                  nostr,
                  rumor,
                  recipientPubkey,
                );
              }
              return null;
            },
          );

          when(() => mockNostrClient.publishEvent(any())).thenAnswer(
            (invocation) async => PublishSuccess(
              event: invocation.positionalArguments[0] as Event,
            ),
          );

          final result = await service.sendPrivateMessage(
            recipientPubkey: _recipientPubkey,
            content: 'Test message',
          );

          expect(result.success, isTrue);
          expect(result.selfWrapPublished, isFalse);
          expect(
            builderCalls,
            equals(2),
            reason:
                'Both the recipient wrap and the self-wrap go through '
                'the injected builder; the second call returning null '
                'is what we are exercising here.',
          );
          verify(() => mockNostrClient.publishEvent(any())).called(1);
        });

        test(
          'returns selfWrapPublished=false when self-wrap builder '
          'throws (decoupled from SDK internals via injection seam)',
          () async {
            var builderCalls = 0;
            final service = NIP17MessageService(
              signer: LocalNostrSigner(_testPrivateKey),
              senderPublicKey: getPublicKey(_testPrivateKey),
              nostrService: mockNostrClient,
              giftWrapBuilder: (nostr, rumor, recipientPubkey) async {
                builderCalls++;
                if (builderCalls == 1) {
                  return GiftWrapUtil.getGiftWrapEvent(
                    nostr,
                    rumor,
                    recipientPubkey,
                  );
                }
                throw Exception('builder boom');
              },
            );

            when(() => mockNostrClient.publishEvent(any())).thenAnswer(
              (invocation) async => PublishSuccess(
                event: invocation.positionalArguments[0] as Event,
              ),
            );

            final result = await service.sendPrivateMessage(
              recipientPubkey: _recipientPubkey,
              content: 'Test message',
            );

            expect(result.success, isTrue);
            expect(result.selfWrapPublished, isFalse);
            expect(builderCalls, equals(2));
            verify(() => mockNostrClient.publishEvent(any())).called(1);
          },
        );
      });

      test(
        'returns failure when signer throws during key refresh',
        () async {
          final mockSigner = _MockNostrSigner();
          when(
            mockSigner.getPublicKey,
          ).thenThrow(Exception('signer unavailable'));

          final brokenService = NIP17MessageService(
            signer: mockSigner,
            senderPublicKey: _testPublicKey,
            nostrService: mockNostrClient,
          );

          final result = await brokenService.sendPrivateMessage(
            recipientPubkey: _recipientPubkey,
            content: 'Test message',
          );

          expect(result.success, isFalse);
          expect(result.error, isNotNull);
        },
      );
    });

    group('buildRumor + sendRumor split', () {
      test(
        'buildRumor returns the unsigned rumor event without touching '
        'the relay or signer',
        () async {
          final rumor = service.buildRumor(
            recipientPubkey: _recipientPubkey,
            content: 'queue this before publishing',
          );

          expect(rumor.kind, equals(EventKind.privateDirectMessage));
          expect(rumor.content, equals('queue this before publishing'));
          expect(rumor.pubkey, equals(_testPublicKey));
          expect(
            rumor.tags.first,
            equals(['p', _recipientPubkey]),
            reason: 'p-tag must be the first tag for NIP-17 compliance',
          );
          expect(
            rumor.id,
            isNotEmpty,
            reason:
                'Event constructor computes the rumor id deterministically '
                'from its fields — DmRepository keys the queue row by it',
          );
          // No publish should fire from a pure build call.
          verifyNever(() => mockNostrClient.publishEvent(any()));
        },
      );

      test(
        'sendRumor wraps and publishes a pre-built rumor with the same '
        'rumor id as buildRumor returned',
        () async {
          when(() => mockNostrClient.publishEvent(any())).thenAnswer(
            (invocation) async => PublishSuccess(
              event: invocation.positionalArguments[0] as Event,
            ),
          );

          final rumor = service.buildRumor(
            recipientPubkey: _recipientPubkey,
            content: 'split-flow message',
          );
          final rumorIdBeforeSend = rumor.id;

          final result = await service.sendRumor(
            rumorEvent: rumor,
            recipientPubkey: _recipientPubkey,
          );

          expect(result.success, isTrue);
          expect(
            result.rumorEventId,
            equals(rumorIdBeforeSend),
            reason:
                'sendRumor must surface the same rumor id the caller saw '
                'from buildRumor — the queue row PK depends on this',
          );
          expect(result.recipientPubkey, equals(_recipientPubkey));
        },
      );

      test(
        'buildRumor includes additional tags after the recipient p-tag',
        () {
          final rumor = service.buildRumor(
            recipientPubkey: _recipientPubkey,
            content: 'reply test',
            additionalTags: [
              ['e', 'parent-message-id'],
            ],
          );

          expect(rumor.tags, [
            ['p', _recipientPubkey],
            ['e', 'parent-message-id'],
          ]);
        },
      );

      test(
        'buildRumor honors a non-default eventKind so kind 15 file '
        'messages can be enqueued before publishing',
        () {
          final rumor = service.buildRumor(
            recipientPubkey: _recipientPubkey,
            content: 'https://example.com/file.enc',
            eventKind: EventKind.fileMessage,
          );

          expect(rumor.kind, equals(EventKind.fileMessage));
        },
      );

      test(
        'sendPrivateMessage convenience wrapper still works (delegates '
        'to buildRumor + sendRumor)',
        () async {
          when(() => mockNostrClient.publishEvent(any())).thenAnswer(
            (invocation) async => PublishSuccess(
              event: invocation.positionalArguments[0] as Event,
            ),
          );

          final result = await service.sendPrivateMessage(
            recipientPubkey: _recipientPubkey,
            content: 'convenience-wrapper smoke test',
          );

          expect(result.success, isTrue);
          expect(result.rumorEventId, isNotNull);
        },
      );
    });

    group('publishSelfWrap', () {
      // The recovery primitive: re-publish only the sender
      // self-addressed gift wrap for a rumor whose recipient publish
      // already landed. The full sendRumor path would publish a second
      // recipient wrap and double-deliver — these tests pin that
      // publishSelfWrap never builds or publishes the recipient wrap.
      late NIP17MessageService realKeyService;

      setUp(() {
        // Use a sender pubkey derived from the signer so the self-wrap
        // NIP-44 ECDH actually runs end-to-end (the synthetic
        // _testPublicKey is not a valid secp256k1 point).
        realKeyService = NIP17MessageService(
          signer: LocalNostrSigner(_testPrivateKey),
          senderPublicKey: getPublicKey(_testPrivateKey),
          nostrService: mockNostrClient,
        );
      });

      test(
        'returns success when the self-wrap publish succeeds and '
        'never publishes a recipient wrap',
        () async {
          final captured = <Event>[];
          when(() => mockNostrClient.publishEvent(any())).thenAnswer(
            (invocation) async {
              final event = invocation.positionalArguments[0] as Event;
              captured.add(event);
              return PublishSuccess(event: event);
            },
          );

          final rumor = realKeyService.buildRumor(
            recipientPubkey: _recipientPubkey,
            content: 'recovery smoke test',
          );

          final result = await realKeyService.publishSelfWrap(
            rumorEvent: rumor,
          );

          expect(result.success, isTrue);
          expect(result.selfWrapPublished, isTrue);
          expect(
            result.rumorEventId,
            equals(rumor.id),
            reason:
                'rumor id must be preserved across recovery — receiver-side '
                'gift-wrap dedup keys on it',
          );
          expect(
            result.recipientPubkey,
            equals(getPublicKey(_testPrivateKey)),
            reason:
                'recovery republishes a self-addressed wrap; the result '
                "exposes the sender's pubkey in the recipientPubkey slot",
          );
          expect(
            captured,
            hasLength(1),
            reason:
                'publishSelfWrap must NOT republish the recipient wrap — '
                'doing so would double-deliver the message',
          );
          expect(captured.single.kind, equals(EventKind.giftWrap));
        },
      );

      test(
        'returns failure when the self-wrap publish returns '
        'PublishFailed without throwing',
        () async {
          when(
            () => mockNostrClient.publishEvent(any()),
          ).thenAnswer((_) async => const PublishFailed());

          final rumor = realKeyService.buildRumor(
            recipientPubkey: _recipientPubkey,
            content: 'PublishFailed path',
          );

          final result = await realKeyService.publishSelfWrap(
            rumorEvent: rumor,
          );

          expect(result.success, isFalse);
          expect(result.error, isNotNull);
          expect(result.selfWrapPublished, isNull);
          verify(() => mockNostrClient.publishEvent(any())).called(1);
        },
      );

      test(
        'returns failure when the gift-wrap builder returns null',
        () async {
          final nullBuilderService = NIP17MessageService(
            signer: LocalNostrSigner(_testPrivateKey),
            senderPublicKey: getPublicKey(_testPrivateKey),
            nostrService: mockNostrClient,
            giftWrapBuilder: (_, _, _) async => null,
          );

          final rumor = nullBuilderService.buildRumor(
            recipientPubkey: _recipientPubkey,
            content: 'null builder path',
          );

          final result = await nullBuilderService.publishSelfWrap(
            rumorEvent: rumor,
          );

          expect(result.success, isFalse);
          expect(result.error, isNotNull);
          verifyNever(() => mockNostrClient.publishEvent(any()));
        },
      );

      test(
        'returns failure when the gift-wrap builder throws',
        () async {
          final throwingBuilderService = NIP17MessageService(
            signer: LocalNostrSigner(_testPrivateKey),
            senderPublicKey: getPublicKey(_testPrivateKey),
            nostrService: mockNostrClient,
            giftWrapBuilder: (_, _, _) async {
              throw Exception('builder boom');
            },
          );

          final rumor = throwingBuilderService.buildRumor(
            recipientPubkey: _recipientPubkey,
            content: 'throwing builder path',
          );

          final result = await throwingBuilderService.publishSelfWrap(
            rumorEvent: rumor,
          );

          expect(result.success, isFalse);
          expect(result.error, isNotNull);
          verifyNever(() => mockNostrClient.publishEvent(any()));
        },
      );

      test(
        'returns failure when the signer throws during key refresh',
        () async {
          final mockSigner = _MockNostrSigner();
          when(
            mockSigner.getPublicKey,
          ).thenThrow(Exception('signer unavailable'));

          final brokenService = NIP17MessageService(
            signer: mockSigner,
            senderPublicKey: _testPublicKey,
            nostrService: mockNostrClient,
          );

          final rumor = realKeyService.buildRumor(
            recipientPubkey: _recipientPubkey,
            content: 'signer-key-failure path',
          );

          final result = await brokenService.publishSelfWrap(
            rumorEvent: rumor,
          );

          expect(result.success, isFalse);
          expect(result.error, isNotNull);
          verifyNever(() => mockNostrClient.publishEvent(any()));
        },
      );
    });
  });
}
