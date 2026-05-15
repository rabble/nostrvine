// ABOUTME: Unit tests for OutgoingDmRetryService — pinned contracts:
// ABOUTME: dispatches recipient: sent / self: failed rows to recoverSelfWrap,
// ABOUTME: dispatches recipient: failed rows to recoverFullSend,
// ABOUTME: never republishes recipient wraps for already-sent rows,
// ABOUTME: applies per-row backoff.

import 'dart:async';

import 'package:db_client/db_client.dart';
import 'package:dm_repository/dm_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart' show NIP17SendResult;
import 'package:openvine/services/outgoing_dm_retry_service.dart';

class _MockDmRepository extends Mock implements DmRepository {}

class _MockOutgoingDmsDao extends Mock implements OutgoingDmsDao {}

const _ownerPubkey =
    '0000000000000000000000000000000000000000000000000000000000000001';
const _otherOwner =
    '0000000000000000000000000000000000000000000000000000000000000002';
const _recipientPubkey =
    '0000000000000000000000000000000000000000000000000000000000000099';

OutgoingDm _row({
  required String id,
  required OutgoingWrapStatus recipient,
  required OutgoingWrapStatus self,
  int retryCount = 0,
  DateTime? lastAttemptAt,
  String ownerPubkey = _ownerPubkey,
}) {
  return OutgoingDm(
    id: id,
    conversationId: 'conv:$id',
    recipientPubkey: _recipientPubkey,
    content: 'hello',
    createdAt: 1700000000,
    rumorEventJson: '{}',
    recipientWrapStatus: recipient,
    selfWrapStatus: self,
    queuedAt: DateTime.utc(2026),
    ownerPubkey: ownerPubkey,
    retryCount: retryCount,
    lastAttemptAt: lastAttemptAt,
  );
}

NIP17SendResult _successResult(String rumorId) => NIP17SendResult.success(
  rumorEventId: rumorId,
  messageEventId: 'wrap:$rumorId',
  recipientPubkey: _ownerPubkey,
);

NIP17SendResult _failureResult(String reason) =>
    NIP17SendResult.failure(reason);

void main() {
  late _MockDmRepository dmRepository;
  late _MockOutgoingDmsDao dao;
  late StreamController<bool> foregroundController;

  setUp(() {
    dmRepository = _MockDmRepository();
    dao = _MockOutgoingDmsDao();
    foregroundController = StreamController<bool>.broadcast();

    // Permissive defaults so individual tests only stub what they care about.
    when(
      () => dao.getRetryableForOwner(
        ownerPubkey: any(named: 'ownerPubkey'),
        maxRetries: any(named: 'maxRetries'),
      ),
    ).thenAnswer((_) async => const <OutgoingDm>[]);
    when(() => dao.incrementRetry(any())).thenAnswer((_) async => true);
  });

  tearDown(() async {
    await foregroundController.close();
  });

  OutgoingDmRetryService buildService({
    OutgoingDmRetryConfig retryConfig = const OutgoingDmRetryConfig(),
    DateTime Function()? now,
  }) {
    return OutgoingDmRetryService(
      dmRepository: dmRepository,
      outgoingDmsDao: dao,
      userPubkey: _ownerPubkey,
      appForegroundStream: foregroundController.stream,
      retryConfig: retryConfig,
      now: now ?? () => DateTime.utc(2026, 5, 10, 12),
    );
  }

  group(OutgoingDmRetryService, () {
    group('initialize', () {
      test('subscribes to the foreground stream', () async {
        final service = buildService();
        await service.initialize();
        expect(service.isInitialized, isTrue);
        expect(foregroundController.hasListener, isTrue);
        await service.dispose();
      });

      test('is idempotent — second call does not double-subscribe', () async {
        final service = buildService();
        await service.initialize();
        await service.initialize();
        expect(foregroundController.hasListener, isTrue);
        // The second initialize did not throw and the service stayed init.
        expect(service.isInitialized, isTrue);
        await service.dispose();
      });

      test('dispose cancels the foreground subscription', () async {
        final service = buildService();
        await service.initialize();
        await service.dispose();
        expect(foregroundController.hasListener, isFalse);
        expect(service.isInitialized, isFalse);
      });

      test(
        'foreground=true triggers a sweep; foreground=false does not',
        () async {
          when(
            () => dao.getRetryableForOwner(
              ownerPubkey: any(named: 'ownerPubkey'),
              maxRetries: any(named: 'maxRetries'),
            ),
          ).thenAnswer((_) async => const <OutgoingDm>[]);

          final service = buildService();
          await service.initialize();

          foregroundController.add(false);
          await Future<void>.delayed(Duration.zero);
          verifyNever(
            () => dao.getRetryableForOwner(
              ownerPubkey: any(named: 'ownerPubkey'),
              maxRetries: any(named: 'maxRetries'),
            ),
          );

          foregroundController.add(true);
          await Future<void>.delayed(Duration.zero);
          verify(
            () => dao.getRetryableForOwner(
              ownerPubkey: _ownerPubkey,
              maxRetries: 5,
            ),
          ).called(1);

          await service.dispose();
        },
      );
    });

    group('sweep dispatch', () {
      test(
        'dispatches recipient: sent / self: failed rows to recoverSelfWrap',
        () async {
          final row = _row(
            id: 'rumor1',
            recipient: OutgoingWrapStatus.sent,
            self: OutgoingWrapStatus.failed,
          );
          when(
            () => dao.getRetryableForOwner(
              ownerPubkey: any(named: 'ownerPubkey'),
              maxRetries: any(named: 'maxRetries'),
            ),
          ).thenAnswer((_) async => [row]);
          when(
            () => dmRepository.recoverSelfWrap(rumorId: any(named: 'rumorId')),
          ).thenAnswer((_) async => _successResult('rumor1'));

          final service = buildService();
          await service.sweep();

          verify(
            () => dmRepository.recoverSelfWrap(rumorId: 'rumor1'),
          ).called(1);
          // recoverSelfWrap deletes the row on success — no incrementRetry.
          verifyNever(() => dao.incrementRetry(any()));
        },
      );

      test(
        'dispatches recipient: failed rows to recoverFullSend (not '
        'recoverSelfWrap)',
        () async {
          final row = _row(
            id: 'rumor2',
            recipient: OutgoingWrapStatus.failed,
            self: OutgoingWrapStatus.failed,
          );
          when(
            () => dao.getRetryableForOwner(
              ownerPubkey: any(named: 'ownerPubkey'),
              maxRetries: any(named: 'maxRetries'),
            ),
          ).thenAnswer((_) async => [row]);
          when(
            () => dmRepository.recoverFullSend(rumorId: any(named: 'rumorId')),
          ).thenAnswer((_) async => _successResult('rumor2'));

          final service = buildService();
          await service.sweep();

          verify(
            () => dmRepository.recoverFullSend(rumorId: 'rumor2'),
          ).called(1);
          // recoverSelfWrap is reserved for the recipient-sent / self-failed
          // case; recipient-failed rows must go through recoverFullSend so
          // the recipient publish is replayed alongside the self-wrap.
          verifyNever(
            () => dmRepository.recoverSelfWrap(rumorId: any(named: 'rumorId')),
          );
          // recoverFullSend's success path finalizes the row by either
          // deleting it (full delivery) or marking recipient sent / self
          // failed (partial). Either way no retry bump is needed.
          verifyNever(() => dao.incrementRetry(any()));
        },
      );

      test(
        'recoverFullSend publish-failure path bumps incrementRetry once',
        () async {
          final row = _row(
            id: 'rumor2b',
            recipient: OutgoingWrapStatus.failed,
            self: OutgoingWrapStatus.failed,
            retryCount: 1,
            lastAttemptAt: DateTime.utc(2025),
          );
          when(
            () => dao.getRetryableForOwner(
              ownerPubkey: any(named: 'ownerPubkey'),
              maxRetries: any(named: 'maxRetries'),
            ),
          ).thenAnswer((_) async => [row]);
          when(
            () => dmRepository.recoverFullSend(rumorId: any(named: 'rumorId')),
          ).thenAnswer((_) async => _failureResult('relay still down'));

          await buildService().sweep();

          verify(
            () => dmRepository.recoverFullSend(rumorId: 'rumor2b'),
          ).called(1);
          verify(() => dao.incrementRetry('rumor2b')).called(1);
        },
      );

      test('publish-failure path bumps incrementRetry once', () async {
        final row = _row(
          id: 'rumor3',
          recipient: OutgoingWrapStatus.sent,
          self: OutgoingWrapStatus.failed,
          retryCount: 1,
          // lastAttemptAt is far enough in the past that backoff doesn't gate.
          lastAttemptAt: DateTime.utc(2025),
        );
        when(
          () => dao.getRetryableForOwner(
            ownerPubkey: any(named: 'ownerPubkey'),
            maxRetries: any(named: 'maxRetries'),
          ),
        ).thenAnswer((_) async => [row]);
        when(
          () => dmRepository.recoverSelfWrap(rumorId: any(named: 'rumorId')),
        ).thenAnswer((_) async => _failureResult('relay timeout'));

        final service = buildService();
        await service.sweep();

        verify(() => dmRepository.recoverSelfWrap(rumorId: 'rumor3')).called(1);
        verify(() => dao.incrementRetry('rumor3')).called(1);
      });

      test('multiple State A rows are processed independently', () async {
        final rows = [
          _row(
            id: 'a',
            recipient: OutgoingWrapStatus.sent,
            self: OutgoingWrapStatus.failed,
          ),
          _row(
            id: 'b',
            recipient: OutgoingWrapStatus.sent,
            self: OutgoingWrapStatus.failed,
          ),
        ];
        when(
          () => dao.getRetryableForOwner(
            ownerPubkey: any(named: 'ownerPubkey'),
            maxRetries: any(named: 'maxRetries'),
          ),
        ).thenAnswer((_) async => rows);
        when(
          () => dmRepository.recoverSelfWrap(rumorId: any(named: 'rumorId')),
        ).thenAnswer((inv) async {
          final id = inv.namedArguments[#rumorId] as String;
          return _successResult(id);
        });

        await buildService().sweep();

        verify(() => dmRepository.recoverSelfWrap(rumorId: 'a')).called(1);
        verify(() => dmRepository.recoverSelfWrap(rumorId: 'b')).called(1);
      });

      test('exits early when getRetryableForOwner is empty', () async {
        when(
          () => dao.getRetryableForOwner(
            ownerPubkey: any(named: 'ownerPubkey'),
            maxRetries: any(named: 'maxRetries'),
          ),
        ).thenAnswer((_) async => const <OutgoingDm>[]);

        await buildService().sweep();

        verifyNever(
          () => dmRepository.recoverSelfWrap(rumorId: any(named: 'rumorId')),
        );
        verifyNever(() => dao.incrementRetry(any()));
      });
    });

    group('per-row backoff', () {
      test(
        'skips a row whose lastAttemptAt + backoff is still in the future',
        () async {
          final now = DateTime.utc(2026, 5, 10, 12);
          // retryCount=2 with default config gives backoff 8s. lastAttempt is
          // 1s ago — well within the gate.
          final row = _row(
            id: 'rumor4',
            recipient: OutgoingWrapStatus.sent,
            self: OutgoingWrapStatus.failed,
            retryCount: 2,
            lastAttemptAt: now.subtract(const Duration(seconds: 1)),
          );
          when(
            () => dao.getRetryableForOwner(
              ownerPubkey: any(named: 'ownerPubkey'),
              maxRetries: any(named: 'maxRetries'),
            ),
          ).thenAnswer((_) async => [row]);

          await buildService(now: () => now).sweep();

          verifyNever(
            () => dmRepository.recoverSelfWrap(rumorId: any(named: 'rumorId')),
          );
        },
      );

      test(
        'dispatches a row whose lastAttemptAt is older than the backoff',
        () async {
          final now = DateTime.utc(2026, 5, 10, 12);
          // retryCount=1 → backoff 4s. lastAttempt is 30s ago — over the gate.
          final row = _row(
            id: 'rumor5',
            recipient: OutgoingWrapStatus.sent,
            self: OutgoingWrapStatus.failed,
            retryCount: 1,
            lastAttemptAt: now.subtract(const Duration(seconds: 30)),
          );
          when(
            () => dao.getRetryableForOwner(
              ownerPubkey: any(named: 'ownerPubkey'),
              maxRetries: any(named: 'maxRetries'),
            ),
          ).thenAnswer((_) async => [row]);
          when(
            () => dmRepository.recoverSelfWrap(rumorId: any(named: 'rumorId')),
          ).thenAnswer((_) async => _successResult('rumor5'));

          await buildService(now: () => now).sweep();

          verify(
            () => dmRepository.recoverSelfWrap(rumorId: 'rumor5'),
          ).called(1);
        },
      );

      test(
        'a fresh row (lastAttemptAt == null) is always dispatched',
        () async {
          final row = _row(
            id: 'rumor6',
            recipient: OutgoingWrapStatus.sent,
            self: OutgoingWrapStatus.failed,
          );
          when(
            () => dao.getRetryableForOwner(
              ownerPubkey: any(named: 'ownerPubkey'),
              maxRetries: any(named: 'maxRetries'),
            ),
          ).thenAnswer((_) async => [row]);
          when(
            () => dmRepository.recoverSelfWrap(rumorId: any(named: 'rumorId')),
          ).thenAnswer((_) async => _successResult('rumor6'));

          await buildService().sweep();

          verify(
            () => dmRepository.recoverSelfWrap(rumorId: 'rumor6'),
          ).called(1);
        },
      );
    });

    group('error handling', () {
      test(
        'contains a top-level DAO failure and clears the in-progress flag',
        () async {
          when(
            () => dao.getRetryableForOwner(
              ownerPubkey: any(named: 'ownerPubkey'),
              maxRetries: any(named: 'maxRetries'),
            ),
          ).thenThrow(Exception('database locked'));

          final service = buildService();

          await expectLater(service.sweep(), completes);
          expect(service.isSweeping, isFalse);
          verifyNever(
            () => dmRepository.recoverSelfWrap(rumorId: any(named: 'rumorId')),
          );
          verifyNever(() => dao.incrementRetry(any()));
        },
      );

      test(
        'StateError aborts the pass; remaining rows are not dispatched',
        () async {
          // Two rows; the first throws StateError. The loop must not advance to
          // the second — auth-not-ready is a per-pass issue, not per-row.
          final rows = [
            _row(
              id: 'a',
              recipient: OutgoingWrapStatus.sent,
              self: OutgoingWrapStatus.failed,
            ),
            _row(
              id: 'b',
              recipient: OutgoingWrapStatus.sent,
              self: OutgoingWrapStatus.failed,
            ),
          ];
          when(
            () => dao.getRetryableForOwner(
              ownerPubkey: any(named: 'ownerPubkey'),
              maxRetries: any(named: 'maxRetries'),
            ),
          ).thenAnswer((_) async => rows);
          when(
            () => dmRepository.recoverSelfWrap(rumorId: 'a'),
          ).thenThrow(StateError('repo not initialized'));

          await buildService().sweep();

          verify(() => dmRepository.recoverSelfWrap(rumorId: 'a')).called(1);
          verifyNever(() => dmRepository.recoverSelfWrap(rumorId: 'b'));
          // Did not bump retry — no attempt was actually made.
          verifyNever(() => dao.incrementRetry(any()));
        },
      );

      test('ArgumentError skips the row but continues with the next', () async {
        final rows = [
          _row(
            id: 'a',
            recipient: OutgoingWrapStatus.sent,
            self: OutgoingWrapStatus.failed,
          ),
          _row(
            id: 'b',
            recipient: OutgoingWrapStatus.sent,
            self: OutgoingWrapStatus.failed,
          ),
        ];
        when(
          () => dao.getRetryableForOwner(
            ownerPubkey: any(named: 'ownerPubkey'),
            maxRetries: any(named: 'maxRetries'),
          ),
        ).thenAnswer((_) async => rows);
        when(
          () => dmRepository.recoverSelfWrap(rumorId: 'a'),
        ).thenThrow(ArgumentError.value('a', 'rumorId', 'no queued row'));
        when(
          () => dmRepository.recoverSelfWrap(rumorId: 'b'),
        ).thenAnswer((_) async => _successResult('b'));

        await buildService().sweep();

        verify(() => dmRepository.recoverSelfWrap(rumorId: 'a')).called(1);
        verify(() => dmRepository.recoverSelfWrap(rumorId: 'b')).called(1);
        // Did not bump retry on the missing-row case — terminal, not
        // "row failed to publish."
        verifyNever(() => dao.incrementRetry('a'));
      });

      test(
        'unexpected throw bumps retry and continues with the next row',
        () async {
          final rows = [
            _row(
              id: 'a',
              recipient: OutgoingWrapStatus.sent,
              self: OutgoingWrapStatus.failed,
            ),
            _row(
              id: 'b',
              recipient: OutgoingWrapStatus.sent,
              self: OutgoingWrapStatus.failed,
            ),
          ];
          when(
            () => dao.getRetryableForOwner(
              ownerPubkey: any(named: 'ownerPubkey'),
              maxRetries: any(named: 'maxRetries'),
            ),
          ).thenAnswer((_) async => rows);
          when(
            () => dmRepository.recoverSelfWrap(rumorId: 'a'),
          ).thenThrow(Exception('relay disconnected'));
          when(
            () => dmRepository.recoverSelfWrap(rumorId: 'b'),
          ).thenAnswer((_) async => _successResult('b'));

          await buildService().sweep();

          verify(() => dao.incrementRetry('a')).called(1);
          verify(() => dmRepository.recoverSelfWrap(rumorId: 'b')).called(1);
        },
      );
    });

    group('contract: dispatches the correct primitive per row state', () {
      // Pin the strategy table: recipient: sent / self: failed →
      // recoverSelfWrap (never republishes recipient); recipient: failed
      // → recoverFullSend (replays both wraps; safe via NIP-17 receiver
      // dedup). The sweep must never reach for sendMessage /
      // sendGroupMessage / sendPrivateMessage which would mint a fresh
      // rumor and zombify the queue row.
      test(
        'a full pass over assorted retryable rows dispatches each row to '
        'the right primitive',
        () async {
          final rows = [
            _row(
              id: 'a',
              recipient: OutgoingWrapStatus.sent,
              self: OutgoingWrapStatus.failed,
            ),
            _row(
              id: 'b',
              recipient: OutgoingWrapStatus.failed,
              self: OutgoingWrapStatus.failed,
            ),
            _row(
              id: 'c',
              recipient: OutgoingWrapStatus.sent,
              self: OutgoingWrapStatus.failed,
            ),
          ];
          when(
            () => dao.getRetryableForOwner(
              ownerPubkey: any(named: 'ownerPubkey'),
              maxRetries: any(named: 'maxRetries'),
            ),
          ).thenAnswer((_) async => rows);
          when(
            () => dmRepository.recoverSelfWrap(rumorId: any(named: 'rumorId')),
          ).thenAnswer((inv) async {
            final id = inv.namedArguments[#rumorId] as String;
            return _successResult(id);
          });
          when(
            () => dmRepository.recoverFullSend(rumorId: any(named: 'rumorId')),
          ).thenAnswer((inv) async {
            final id = inv.namedArguments[#rumorId] as String;
            return _successResult(id);
          });

          await buildService().sweep();

          // The sweep never mints a fresh rumor via the user-facing send
          // primitives — that would zombify the queue row by enqueueing a
          // new one with a different id.
          verifyNever(
            () => dmRepository.sendMessage(
              recipientPubkey: any(named: 'recipientPubkey'),
              content: any(named: 'content'),
            ),
          );
          verifyNever(
            () => dmRepository.sendGroupMessage(
              recipientPubkeys: any(named: 'recipientPubkeys'),
              content: any(named: 'content'),
            ),
          );

          // Strategy A: recipient: sent / self: failed → recoverSelfWrap.
          verify(() => dmRepository.recoverSelfWrap(rumorId: 'a')).called(1);
          verify(() => dmRepository.recoverSelfWrap(rumorId: 'c')).called(1);
          verifyNever(() => dmRepository.recoverSelfWrap(rumorId: 'b'));

          // Strategy B: recipient: failed → recoverFullSend.
          verify(() => dmRepository.recoverFullSend(rumorId: 'b')).called(1);
          verifyNever(() => dmRepository.recoverFullSend(rumorId: 'a'));
          verifyNever(() => dmRepository.recoverFullSend(rumorId: 'c'));
        },
      );

      test(
        'recoverFullSend is never invoked for rows where recipient is '
        'already sent',
        () async {
          // Any row where recipientWrapStatus == sent must route through
          // recoverSelfWrap, never recoverFullSend. recoverFullSend's
          // idempotent guard would defer to recoverSelfWrap internally
          // anyway, but the dispatcher should not even hand it those
          // rows — keeps the strategy table readable.
          final row = _row(
            id: 'sent-row',
            recipient: OutgoingWrapStatus.sent,
            self: OutgoingWrapStatus.failed,
          );
          when(
            () => dao.getRetryableForOwner(
              ownerPubkey: any(named: 'ownerPubkey'),
              maxRetries: any(named: 'maxRetries'),
            ),
          ).thenAnswer((_) async => [row]);
          when(
            () => dmRepository.recoverSelfWrap(rumorId: any(named: 'rumorId')),
          ).thenAnswer((_) async => _successResult('sent-row'));

          await buildService().sweep();

          verifyNever(
            () => dmRepository.recoverFullSend(rumorId: any(named: 'rumorId')),
          );
        },
      );
    });

    group('recoverFullSend error handling', () {
      test(
        'StateError from recoverFullSend aborts the pass without bumping '
        'retry',
        () async {
          final rows = [
            _row(
              id: 'a',
              recipient: OutgoingWrapStatus.failed,
              self: OutgoingWrapStatus.failed,
            ),
            _row(
              id: 'b',
              recipient: OutgoingWrapStatus.failed,
              self: OutgoingWrapStatus.failed,
            ),
          ];
          when(
            () => dao.getRetryableForOwner(
              ownerPubkey: any(named: 'ownerPubkey'),
              maxRetries: any(named: 'maxRetries'),
            ),
          ).thenAnswer((_) async => rows);
          when(
            () => dmRepository.recoverFullSend(rumorId: 'a'),
          ).thenThrow(StateError('repo not initialized'));

          await buildService().sweep();

          verify(() => dmRepository.recoverFullSend(rumorId: 'a')).called(1);
          verifyNever(() => dmRepository.recoverFullSend(rumorId: 'b'));
          verifyNever(() => dao.incrementRetry(any()));
        },
      );

      test(
        'ArgumentError from recoverFullSend skips the row and continues',
        () async {
          final rows = [
            _row(
              id: 'a',
              recipient: OutgoingWrapStatus.failed,
              self: OutgoingWrapStatus.failed,
            ),
            _row(
              id: 'b',
              recipient: OutgoingWrapStatus.failed,
              self: OutgoingWrapStatus.failed,
            ),
          ];
          when(
            () => dao.getRetryableForOwner(
              ownerPubkey: any(named: 'ownerPubkey'),
              maxRetries: any(named: 'maxRetries'),
            ),
          ).thenAnswer((_) async => rows);
          when(
            () => dmRepository.recoverFullSend(rumorId: 'a'),
          ).thenThrow(ArgumentError.value('a', 'rumorId', 'no queued row'));
          when(
            () => dmRepository.recoverFullSend(rumorId: 'b'),
          ).thenAnswer((_) async => _successResult('b'));

          await buildService().sweep();

          verify(() => dmRepository.recoverFullSend(rumorId: 'a')).called(1);
          verify(() => dmRepository.recoverFullSend(rumorId: 'b')).called(1);
          verifyNever(() => dao.incrementRetry('a'));
        },
      );

      test(
        'unexpected throw from recoverFullSend bumps retry and continues',
        () async {
          final rows = [
            _row(
              id: 'a',
              recipient: OutgoingWrapStatus.failed,
              self: OutgoingWrapStatus.failed,
            ),
            _row(
              id: 'b',
              recipient: OutgoingWrapStatus.failed,
              self: OutgoingWrapStatus.failed,
            ),
          ];
          when(
            () => dao.getRetryableForOwner(
              ownerPubkey: any(named: 'ownerPubkey'),
              maxRetries: any(named: 'maxRetries'),
            ),
          ).thenAnswer((_) async => rows);
          when(
            () => dmRepository.recoverFullSend(rumorId: 'a'),
          ).thenThrow(Exception('relay disconnected'));
          when(
            () => dmRepository.recoverFullSend(rumorId: 'b'),
          ).thenAnswer((_) async => _successResult('b'));

          await buildService().sweep();

          verify(() => dao.incrementRetry('a')).called(1);
          verify(() => dmRepository.recoverFullSend(rumorId: 'b')).called(1);
        },
      );
    });

    group('re-entrancy', () {
      test(
        'a sweep already in progress short-circuits a second invocation',
        () async {
          final completer = Completer<NIP17SendResult>();
          final row = _row(
            id: 'rumor7',
            recipient: OutgoingWrapStatus.sent,
            self: OutgoingWrapStatus.failed,
          );
          when(
            () => dao.getRetryableForOwner(
              ownerPubkey: any(named: 'ownerPubkey'),
              maxRetries: any(named: 'maxRetries'),
            ),
          ).thenAnswer((_) async => [row]);
          when(
            () => dmRepository.recoverSelfWrap(rumorId: any(named: 'rumorId')),
          ).thenAnswer((_) => completer.future);

          final service = buildService();
          final first = service.sweep();
          // Yield so the first sweep gets past the in-progress flag set.
          await Future<void>.delayed(Duration.zero);
          expect(service.isSweeping, isTrue);

          // Second call returns immediately without entering the loop.
          await service.sweep();
          verify(
            () => dao.getRetryableForOwner(
              ownerPubkey: _ownerPubkey,
              maxRetries: any(named: 'maxRetries'),
            ),
          ).called(1);

          completer.complete(_successResult('rumor7'));
          await first;
          expect(service.isSweeping, isFalse);
        },
      );
    });

    group('account scope', () {
      test(
        'queries getRetryableForOwner with the constructor-provided pubkey',
        () async {
          when(
            () => dao.getRetryableForOwner(
              ownerPubkey: any(named: 'ownerPubkey'),
              maxRetries: any(named: 'maxRetries'),
            ),
          ).thenAnswer((_) async => const <OutgoingDm>[]);

          // Build with a service for a SPECIFIC user; verify the query is
          // scoped to them. The DAO filter is the account-isolation
          // boundary — pin it here so a future refactor can't drop it.
          final service = OutgoingDmRetryService(
            dmRepository: dmRepository,
            outgoingDmsDao: dao,
            userPubkey: _otherOwner,
            appForegroundStream: foregroundController.stream,
          );

          await service.sweep();

          verify(
            () => dao.getRetryableForOwner(
              ownerPubkey: _otherOwner,
              maxRetries: any(named: 'maxRetries'),
            ),
          ).called(1);
        },
      );
    });
  });

  group(OutgoingDmRetryConfig, () {
    const cfg = OutgoingDmRetryConfig();

    test('retry 0 returns Duration.zero (no gate on the first attempt)', () {
      expect(cfg.backoffFor(0), Duration.zero);
    });

    test('retry 1 returns initialDelay × multiplier', () {
      expect(cfg.backoffFor(1), const Duration(seconds: 4));
    });

    test('retry growth caps at maxDelay', () {
      // Default config: 2s × 2^N — after enough retries we hit 5min cap.
      expect(cfg.backoffFor(20), cfg.maxDelay);
    });
  });
}
