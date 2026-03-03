// ABOUTME: Tests for DraftsLibraryState classes
// ABOUTME: Verifies equality and props for all state types

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/blocs/drafts_library/drafts_library_bloc.dart';
import 'package:openvine/models/divine_video_draft.dart';

void main() {
  group('DraftsLibraryState', () {
    DivineVideoDraft createDraft({String? id}) {
      return DivineVideoDraft(
        id: id ?? 'draft-${DateTime.now().millisecondsSinceEpoch}',
        clips: const [],
        title: 'Test Draft',
        description: 'Test Description',
        hashtags: const {},
        selectedApproach: 'default',
        createdAt: DateTime(2026),
        lastModified: DateTime(2026),
        publishStatus: PublishStatus.draft,
        publishAttempts: 0,
      );
    }

    group(DraftsLibraryInitial, () {
      test('supports value equality', () {
        expect(
          const DraftsLibraryInitial(),
          equals(const DraftsLibraryInitial()),
        );
      });

      test('props are empty', () {
        expect(const DraftsLibraryInitial().props, isEmpty);
      });
    });

    group(DraftsLibraryLoading, () {
      test('supports value equality', () {
        expect(
          const DraftsLibraryLoading(),
          equals(const DraftsLibraryLoading()),
        );
      });

      test('props are empty', () {
        expect(const DraftsLibraryLoading().props, isEmpty);
      });
    });

    group(DraftsLibraryLoaded, () {
      test('supports value equality', () {
        final draft = createDraft(id: 'draft1');
        expect(
          DraftsLibraryLoaded(drafts: [draft]),
          equals(DraftsLibraryLoaded(drafts: [draft])),
        );
      });

      test('empty lists are equal', () {
        expect(
          const DraftsLibraryLoaded(drafts: []),
          equals(const DraftsLibraryLoaded(drafts: [])),
        );
      });

      test('different drafts are not equal', () {
        expect(
          DraftsLibraryLoaded(drafts: [createDraft(id: 'draft1')]),
          isNot(
            equals(DraftsLibraryLoaded(drafts: [createDraft(id: 'draft2')])),
          ),
        );
      });

      test('props contains drafts, deleteResult, and deleteError', () {
        final drafts = [createDraft(id: 'draft1')];
        expect(
          DraftsLibraryLoaded(drafts: drafts).props,
          [drafts, null, null],
        );
        expect(
          DraftsLibraryLoaded(
            drafts: drafts,
            deleteResult: DeleteResult.success,
          ).props,
          [drafts, DeleteResult.success, null],
        );
        expect(
          DraftsLibraryLoaded(
            drafts: drafts,
            deleteResult: DeleteResult.failure,
            deleteError: 'error',
          ).props,
          [drafts, DeleteResult.failure, 'error'],
        );
      });

      test('states with different deleteResult are not equal', () {
        final drafts = [createDraft(id: 'draft1')];
        expect(
          DraftsLibraryLoaded(drafts: drafts),
          isNot(
            equals(
              DraftsLibraryLoaded(
                drafts: drafts,
                deleteResult: DeleteResult.success,
              ),
            ),
          ),
        );
      });

      test('clearDeleteResult returns state without deleteResult', () {
        final drafts = [createDraft(id: 'draft1')];
        final stateWithResult = DraftsLibraryLoaded(
          drafts: drafts,
          deleteResult: DeleteResult.success,
        );

        final cleared = stateWithResult.clearDeleteResult();

        expect(cleared.drafts, equals(drafts));
        expect(cleared.deleteResult, isNull);
        expect(cleared.deleteError, isNull);
      });
    });

    group(DraftsLibraryError, () {
      test('supports value equality', () {
        expect(
          const DraftsLibraryError(message: 'error message'),
          equals(const DraftsLibraryError(message: 'error message')),
        );
      });

      test('different messages are not equal', () {
        expect(
          const DraftsLibraryError(message: 'error 1'),
          isNot(equals(const DraftsLibraryError(message: 'error 2'))),
        );
      });

      test('props contains message', () {
        expect(
          const DraftsLibraryError(message: 'error').props,
          ['error'],
        );
      });
    });
  });
}
