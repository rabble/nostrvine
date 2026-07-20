// ABOUTME: Tests for DraftsLibraryEvent classes
// ABOUTME: Verifies equality and props for all event types

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/blocs/drafts_library/drafts_library_bloc.dart';

void main() {
  group('DraftsLibraryEvent', () {
    group(DraftsLibraryLoadRequested, () {
      test('supports value equality', () {
        expect(
          const DraftsLibraryLoadRequested(),
          equals(const DraftsLibraryLoadRequested()),
        );
      });

      test('props are empty', () {
        expect(const DraftsLibraryLoadRequested().props, isEmpty);
      });
    });

    group(DraftsLibraryDuplicateRequested, () {
      test('supports value equality', () {
        expect(
          const DraftsLibraryDuplicateRequested('draft1', newTitle: 'Copy'),
          equals(
            const DraftsLibraryDuplicateRequested('draft1', newTitle: 'Copy'),
          ),
        );
      });

      test('different draftIds are not equal', () {
        expect(
          const DraftsLibraryDuplicateRequested('draft1'),
          isNot(equals(const DraftsLibraryDuplicateRequested('draft2'))),
        );
      });

      test('different titles are not equal', () {
        expect(
          const DraftsLibraryDuplicateRequested('draft1', newTitle: 'A'),
          isNot(
            equals(
              const DraftsLibraryDuplicateRequested('draft1', newTitle: 'B'),
            ),
          ),
        );
      });

      test('props contains draftId and newTitle', () {
        expect(
          const DraftsLibraryDuplicateRequested(
            'draft1',
            newTitle: 'Copy',
          ).props,
          ['draft1', 'Copy'],
        );
      });
    });

    group(DraftsLibraryDeleteRequested, () {
      test('supports value equality', () {
        expect(
          const DraftsLibraryDeleteRequested('draft1'),
          equals(const DraftsLibraryDeleteRequested('draft1')),
        );
      });

      test('different draftIds are not equal', () {
        expect(
          const DraftsLibraryDeleteRequested('draft1'),
          isNot(equals(const DraftsLibraryDeleteRequested('draft2'))),
        );
      });

      test('props contains draftId', () {
        expect(const DraftsLibraryDeleteRequested('draft1').props, ['draft1']);
      });
    });
  });
}
