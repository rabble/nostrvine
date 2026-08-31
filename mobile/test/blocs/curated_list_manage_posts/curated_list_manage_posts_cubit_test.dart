// ABOUTME: Tests for CuratedListManagePostsCubit: selection toggling and
// ABOUTME: batch removal outcomes including partial failure and close-guard.

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/curated_list_manage_posts/curated_list_manage_posts_cubit.dart';
import 'package:openvine/services/curated_list_service.dart';

class _MockCuratedListService extends Mock implements CuratedListService {}

void main() {
  group(CuratedListManagePostsCubit, () {
    late _MockCuratedListService service;

    setUp(() {
      service = _MockCuratedListService();
    });

    CuratedListManagePostsCubit buildCubit() =>
        CuratedListManagePostsCubit(service: service, listId: 'list-1');

    group('togglePost', () {
      blocTest<CuratedListManagePostsCubit, CuratedListManagePostsState>(
        'adds then removes a video id',
        build: buildCubit,
        act: (cubit) => cubit
          ..togglePost('a')
          ..togglePost('b')
          ..togglePost('a'),
        expect: () => const [
          CuratedListManagePostsState(selectedVideoIds: {'a'}),
          CuratedListManagePostsState(selectedVideoIds: {'a', 'b'}),
          CuratedListManagePostsState(selectedVideoIds: {'b'}),
        ],
      );

      blocTest<CuratedListManagePostsCubit, CuratedListManagePostsState>(
        'is ignored while a removal is running',
        build: buildCubit,
        seed: () => const CuratedListManagePostsState(
          status: CuratedListManagePostsStatus.removing,
          selectedVideoIds: {'a'},
        ),
        act: (cubit) => cubit.togglePost('b'),
        expect: () => const <CuratedListManagePostsState>[],
      );
    });

    group('removeSelected', () {
      blocTest<CuratedListManagePostsCubit, CuratedListManagePostsState>(
        'does nothing with an empty selection',
        build: buildCubit,
        act: (cubit) => cubit.removeSelected(),
        expect: () => const <CuratedListManagePostsState>[],
        verify: (_) {
          verifyNever(() => service.removeVideoFromList(any(), any()));
        },
      );

      blocTest<CuratedListManagePostsCubit, CuratedListManagePostsState>(
        'removes every selected post and reports success',
        build: buildCubit,
        setUp: () {
          when(
            () => service.removeVideoFromList('list-1', any()),
          ).thenAnswer((_) async => true);
        },
        seed: () => const CuratedListManagePostsState(
          selectedVideoIds: {'a', 'b'},
        ),
        act: (cubit) => cubit.removeSelected(),
        expect: () => const [
          CuratedListManagePostsState(
            status: CuratedListManagePostsStatus.removing,
            selectedVideoIds: {'a', 'b'},
          ),
          CuratedListManagePostsState(
            status: CuratedListManagePostsStatus.success,
            removedCount: 2,
          ),
        ],
        verify: (_) {
          verify(() => service.removeVideoFromList('list-1', 'a')).called(1);
          verify(() => service.removeVideoFromList('list-1', 'b')).called(1);
        },
      );

      blocTest<CuratedListManagePostsCubit, CuratedListManagePostsState>(
        'reports failure with counts when one removal returns false',
        build: buildCubit,
        setUp: () {
          when(
            () => service.removeVideoFromList('list-1', 'a'),
          ).thenAnswer((_) async => true);
          when(
            () => service.removeVideoFromList('list-1', 'b'),
          ).thenAnswer((_) async => false);
        },
        seed: () => const CuratedListManagePostsState(
          selectedVideoIds: {'a', 'b'},
        ),
        act: (cubit) => cubit.removeSelected(),
        expect: () => const [
          CuratedListManagePostsState(
            status: CuratedListManagePostsStatus.removing,
            selectedVideoIds: {'a', 'b'},
          ),
          CuratedListManagePostsState(
            status: CuratedListManagePostsStatus.failure,
            removedCount: 1,
            failedCount: 1,
          ),
        ],
      );

      blocTest<CuratedListManagePostsCubit, CuratedListManagePostsState>(
        'counts a throwing removal as failed and keeps going',
        build: buildCubit,
        setUp: () {
          when(
            () => service.removeVideoFromList('list-1', 'a'),
          ).thenAnswer((_) async => throw Exception('relay down'));
          when(
            () => service.removeVideoFromList('list-1', 'b'),
          ).thenAnswer((_) async => true);
        },
        seed: () => const CuratedListManagePostsState(
          selectedVideoIds: {'a', 'b'},
        ),
        act: (cubit) => cubit.removeSelected(),
        expect: () => const [
          CuratedListManagePostsState(
            status: CuratedListManagePostsStatus.removing,
            selectedVideoIds: {'a', 'b'},
          ),
          CuratedListManagePostsState(
            status: CuratedListManagePostsStatus.failure,
            removedCount: 1,
            failedCount: 1,
          ),
        ],
        errors: () => [isA<Exception>()],
        verify: (_) {
          verify(() => service.removeVideoFromList('list-1', 'b')).called(1);
        },
      );

      test('does not throw when closed mid-removal', () async {
        final gate = Completer<bool>();
        when(
          () => service.removeVideoFromList('list-1', 'a'),
        ).thenAnswer((_) => gate.future);

        final cubit = buildCubit()..togglePost('a');
        final removal = cubit.removeSelected();
        await cubit.close();
        gate.complete(true);

        await expectLater(removal, completes);
      });
    });
  });
}
