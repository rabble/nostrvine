// ABOUTME: Guards the people-lists route registration order after the #4508 split
// ABOUTME: /people-lists/new (literal) must be registered before /people-lists/:listId

import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  // go_router matches same-segment-count routes top-to-bottom. The literal
  // `/people-lists/new` (CreatePeopleListPage) and the parameterised
  // `/people-lists/:listId` (UserListPeopleScreen) have the same segment
  // count, so if the parameterised route is registered first it captures the
  // literal `new` as a list id and opens the wrong screen. The #4508 split
  // moved these routes into lists_routes.dart; this guard fails if a future
  // edit reorders them.
  group('people-lists route order (#4508)', () {
    test('CreatePeopleListPage route precedes UserListPeopleScreen route', () {
      final source = File(
        'lib/router/routes/lists_routes.dart',
      ).readAsStringSync();

      final createOffset = source.indexOf('CreatePeopleListPage.path');
      final userListOffset = source.indexOf('UserListPeopleScreen.path');

      expect(
        createOffset,
        isNonNegative,
        reason:
            'CreatePeopleListPage route marker not found in lists_routes.dart. '
            'Update this regression test to match the new marker.',
      );
      expect(
        userListOffset,
        greaterThan(createOffset),
        reason:
            'CreatePeopleListPage (/people-lists/new) must be registered '
            'before UserListPeopleScreen (/people-lists/:listId) so the '
            'literal `new` segment is not captured as a list id.',
      );
    });
  });
}
