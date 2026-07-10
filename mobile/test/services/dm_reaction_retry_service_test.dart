// ABOUTME: Unit tests for DmReactionRetryService — pinned contracts:
// ABOUTME: re-drives failed/interrupted own reactions via retry(), skips when
// ABOUTME: the repo isn't initialized, holds back too-young pending reactions,
// ABOUTME: applies backoff, and stops after maxRetries.

import 'dart:async';

import 'package:dm_repository/dm_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/services/dm_reaction_retry_service.dart';

class _MockDmReactionsRepository extends Mock
    implements DmReactionsRepository {}

const _authorPubkey =
    '0000000000000000000000000000000000000000000000000000000000000099';

DmReactionRetryTarget _target({
  required String rumorId,
  String publishStatus = 'failed',
  int createdAt = 1700000000,
}) => DmReactionRetryTarget(
  rumorId: rumorId,
  targetMessageAuthor: _authorPubkey,
  publishStatus: publishStatus,
  createdAt: createdAt,
);

DmReactionPublishResult _ok(String id) =>
    DmReactionPublishResult(success: true, rumorId: id);

DmReactionPublishResult _fail(String id) => DmReactionPublishResult(
  success: false,
  rumorId: id,
  errorMessage: 'relay down',
);

void main() {
  late _MockDmReactionsRepository repository;
  late StreamController<bool> foregroundController;

  setUp(() {
    repository = _MockDmReactionsRepository();
    foregroundController = StreamController<bool>.broadcast();

    // Permissive defaults; each test overrides what it cares about.
    when(() => repository.isInitialized).thenReturn(true);
    when(
      repository.retryableReactions,
    ).thenAnswer((_) async => const <DmReactionRetryTarget>[]);
    when(
      repository.retryableDeletions,
    ).thenAnswer((_) async => const <DmReactionRetryTarget>[]);
    when(
      () => repository.retry(
        rumorId: any(named: 'rumorId'),
        targetMessageAuthor: any(named: 'targetMessageAuthor'),
      ),
    ).thenAnswer((_) async => _ok('r'));
    when(
      () => repository.retryDeletion(
        rumorId: any(named: 'rumorId'),
        targetMessageAuthor: any(named: 'targetMessageAuthor'),
      ),
    ).thenAnswer((_) async => _ok('r'));
  });

  tearDown(() async {
    await foregroundController.close();
  });

  DmReactionRetryService buildService({
    DmReactionRetryConfig retryConfig = const DmReactionRetryConfig(),
    DateTime Function()? now,
    Stream<void>? retryTriggerStream,
  }) {
    return DmReactionRetryService(
      reactionsRepository: repository,
      appForegroundStream: foregroundController.stream,
      retryTriggerStream: retryTriggerStream,
      retryConfig: retryConfig,
      now: now ?? () => DateTime.utc(2026, 5, 10, 12),
    );
  }

  group(DmReactionRetryService, () {
    test(
      'initialize subscribes to the foreground stream, dispose cancels',
      () async {
        final service = buildService();
        await service.initialize();
        expect(service.isInitialized, isTrue);
        expect(foregroundController.hasListener, isTrue);

        await service.dispose();
        expect(service.isInitialized, isFalse);
        expect(foregroundController.hasListener, isFalse);
      },
    );

    test('a foreground transition to true triggers a sweep', () async {
      when(
        repository.retryableReactions,
      ).thenAnswer((_) async => [_target(rumorId: 'r1')]);
      when(
        () => repository.retry(
          rumorId: 'r1',
          targetMessageAuthor: _authorPubkey,
        ),
      ).thenAnswer((_) async => _ok('r1'));

      final service = buildService();
      await service.initialize();
      foregroundController.add(true);
      // Let the async sweep run.
      await Future<void>.delayed(Duration.zero);

      verify(
        () => repository.retry(
          rumorId: 'r1',
          targetMessageAuthor: _authorPubkey,
        ),
      ).called(1);
      await service.dispose();
    });

    test('re-drives a failed reaction via retry', () async {
      when(
        repository.retryableReactions,
      ).thenAnswer((_) async => [_target(rumorId: 'r1')]);
      when(
        () => repository.retry(
          rumorId: 'r1',
          targetMessageAuthor: _authorPubkey,
        ),
      ).thenAnswer((_) async => _ok('r1'));

      await buildService().sweep();

      verify(
        () => repository.retry(
          rumorId: 'r1',
          targetMessageAuthor: _authorPubkey,
        ),
      ).called(1);
    });

    test('does nothing when the repository is not initialized', () async {
      when(() => repository.isInitialized).thenReturn(false);

      await buildService().sweep();

      verifyNever(repository.retryableReactions);
      verifyNever(
        () => repository.retry(
          rumorId: any(named: 'rumorId'),
          targetMessageAuthor: any(named: 'targetMessageAuthor'),
        ),
      );
    });

    test(
      'holds back a pending reaction younger than the min-age guard',
      () async {
        final now = DateTime.utc(2026, 5, 10, 12);
        final youngCreatedAt =
            now.subtract(const Duration(seconds: 5)).millisecondsSinceEpoch ~/
            1000;
        when(repository.retryableReactions).thenAnswer(
          (_) async => [
            _target(
              rumorId: 'r1',
              publishStatus: 'pending',
              createdAt: youngCreatedAt,
            ),
          ],
        );

        await buildService(now: () => now).sweep();

        verifyNever(
          () => repository.retry(
            rumorId: any(named: 'rumorId'),
            targetMessageAuthor: any(named: 'targetMessageAuthor'),
          ),
        );
      },
    );

    test('re-drives a pending reaction older than the min-age guard', () async {
      final now = DateTime.utc(2026, 5, 10, 12);
      final oldCreatedAt =
          now.subtract(const Duration(seconds: 60)).millisecondsSinceEpoch ~/
          1000;
      when(repository.retryableReactions).thenAnswer(
        (_) async => [
          _target(
            rumorId: 'r1',
            publishStatus: 'pending',
            createdAt: oldCreatedAt,
          ),
        ],
      );
      when(
        () => repository.retry(
          rumorId: 'r1',
          targetMessageAuthor: _authorPubkey,
        ),
      ).thenAnswer((_) async => _ok('r1'));

      await buildService(now: () => now).sweep();

      verify(
        () => repository.retry(
          rumorId: 'r1',
          targetMessageAuthor: _authorPubkey,
        ),
      ).called(1);
    });

    test(
      'skips a just-failed reaction while inside the backoff window',
      () async {
        when(
          repository.retryableReactions,
        ).thenAnswer((_) async => [_target(rumorId: 'r1')]);
        when(
          () => repository.retry(
            rumorId: 'r1',
            targetMessageAuthor: _authorPubkey,
          ),
        ).thenAnswer((_) async => _fail('r1'));

        // now is fixed, so the second sweep is inside the backoff window.
        final service = buildService();
        await service.sweep();
        await service.sweep();

        verify(
          () => repository.retry(
            rumorId: 'r1',
            targetMessageAuthor: _authorPubkey,
          ),
        ).called(1);
      },
    );

    test('stops re-driving a reaction after maxRetries', () async {
      var clock = DateTime.utc(2026, 5, 10, 12);
      when(
        repository.retryableReactions,
      ).thenAnswer((_) async => [_target(rumorId: 'r1')]);
      when(
        () => repository.retry(
          rumorId: 'r1',
          targetMessageAuthor: _authorPubkey,
        ),
      ).thenAnswer((_) async => _fail('r1'));

      final service = buildService(
        retryConfig: const DmReactionRetryConfig(
          maxRetries: 2,
          initialDelay: Duration(milliseconds: 1),
        ),
        now: () => clock,
      );

      // Three sweeps, each past the (tiny) backoff window — only the first two
      // attempt a retry; the third is dropped as exhausted.
      await service.sweep();
      clock = clock.add(const Duration(seconds: 10));
      await service.sweep();
      clock = clock.add(const Duration(seconds: 10));
      await service.sweep();

      verify(
        () => repository.retry(
          rumorId: 'r1',
          targetMessageAuthor: _authorPubkey,
        ),
      ).called(2);
    });

    test(
      'a sweep already in progress short-circuits the next trigger',
      () async {
        final gate = Completer<DmReactionPublishResult>();
        when(
          repository.retryableReactions,
        ).thenAnswer((_) async => [_target(rumorId: 'r1')]);
        when(
          () => repository.retry(
            rumorId: 'r1',
            targetMessageAuthor: _authorPubkey,
          ),
        ).thenAnswer((_) => gate.future);

        final service = buildService();
        final first = service.sweep();
        // Let the first sweep reach the awaiting retry() call.
        await Future<void>.delayed(Duration.zero);
        // Second sweep sees _isSweeping and returns immediately.
        await service.sweep();

        gate.complete(_ok('r1'));
        await first;

        verify(
          () => repository.retry(
            rumorId: 'r1',
            targetMessageAuthor: _authorPubkey,
          ),
        ).called(1);
      },
    );

    test('a retry-trigger event (reconnect) triggers a sweep', () async {
      final triggerController = StreamController<void>.broadcast();
      addTearDown(triggerController.close);
      when(
        repository.retryableReactions,
      ).thenAnswer((_) async => [_target(rumorId: 'r1')]);

      final service = buildService(
        retryTriggerStream: triggerController.stream,
      );
      await service.initialize();
      triggerController.add(null);
      await Future<void>.delayed(Duration.zero);

      verify(
        () => repository.retry(
          rumorId: 'r1',
          targetMessageAuthor: _authorPubkey,
        ),
      ).called(1);
      await service.dispose();
    });

    test('re-drives a pending removal via retryDeletion', () async {
      when(repository.retryableDeletions).thenAnswer(
        (_) async => [
          _target(rumorId: 'd1', publishStatus: 'deletion_pending'),
        ],
      );
      when(
        () => repository.retryDeletion(
          rumorId: 'd1',
          targetMessageAuthor: _authorPubkey,
        ),
      ).thenAnswer((_) async => _ok('d1'));

      await buildService().sweep();

      verify(
        () => repository.retryDeletion(
          rumorId: 'd1',
          targetMessageAuthor: _authorPubkey,
        ),
      ).called(1);
    });

    test(
      'a removal is re-driven regardless of the pending min-age guard',
      () async {
        final now = DateTime.utc(2026, 5, 10, 12);
        final youngCreatedAt =
            now.subtract(const Duration(seconds: 5)).millisecondsSinceEpoch ~/
            1000;
        when(repository.retryableDeletions).thenAnswer(
          (_) async => [
            _target(
              rumorId: 'd1',
              publishStatus: 'deletion_pending',
              createdAt: youngCreatedAt,
            ),
          ],
        );
        when(
          () => repository.retryDeletion(
            rumorId: 'd1',
            targetMessageAuthor: _authorPubkey,
          ),
        ).thenAnswer((_) async => _ok('d1'));

        await buildService(now: () => now).sweep();

        // Unlike an add, a 'deletion_pending' row is never in-flight for the
        // sweep, so the min-age guard must not hold it back.
        verify(
          () => repository.retryDeletion(
            rumorId: 'd1',
            targetMessageAuthor: _authorPubkey,
          ),
        ).called(1);
      },
    );

    test(
      'add-phase retry exhaustion does NOT starve the later removal — the '
      'attempt budget is namespaced per phase (add vs del) even though the '
      'row keeps its rumor id across the failed -> deletion_pending flip',
      () async {
        var clock = DateTime.utc(2026, 5, 10, 12);

        // Phase 1: the reaction fails its full add-retry budget.
        when(
          repository.retryableReactions,
        ).thenAnswer((_) async => [_target(rumorId: 'x1')]);
        when(
          () => repository.retry(
            rumorId: 'x1',
            targetMessageAuthor: _authorPubkey,
          ),
        ).thenAnswer((_) async => _fail('x1'));

        final service = buildService(
          retryConfig: const DmReactionRetryConfig(
            maxRetries: 2,
            initialDelay: Duration(milliseconds: 1),
          ),
          now: () => clock,
        );

        await service.sweep();
        clock = clock.add(const Duration(seconds: 10));
        await service.sweep();
        clock = clock.add(const Duration(seconds: 10));
        await service.sweep(); // third add attempt dropped as exhausted

        verify(
          () => repository.retry(
            rumorId: 'x1',
            targetMessageAuthor: _authorPubkey,
          ),
        ).called(2);

        // Phase 2: the user removes that reaction. The row keeps rumor id
        // 'x1' but is now a 'deletion_pending' removal. Its kind-5 must
        // re-drive with a FRESH budget — a bare-id budget would inherit the
        // exhausted add count and skip the removal for the rest of the
        // session, leaving the counterparty with a reaction you removed.
        when(
          repository.retryableReactions,
        ).thenAnswer((_) async => const <DmReactionRetryTarget>[]);
        when(repository.retryableDeletions).thenAnswer(
          (_) async => [
            _target(rumorId: 'x1', publishStatus: 'deletion_pending'),
          ],
        );
        when(
          () => repository.retryDeletion(
            rumorId: 'x1',
            targetMessageAuthor: _authorPubkey,
          ),
        ).thenAnswer((_) async => _ok('x1'));

        clock = clock.add(const Duration(seconds: 10));
        await service.sweep();

        verify(
          () => repository.retryDeletion(
            rumorId: 'x1',
            targetMessageAuthor: _authorPubkey,
          ),
        ).called(1);
      },
    );
  });
}
