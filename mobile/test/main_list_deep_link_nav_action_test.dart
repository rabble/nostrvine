// ABOUTME: Regression tests for resolveListDeepLinkNavAction routing decision
// ABOUTME: Verifies list deep links push (keeping the stack), go (replacing
// ABOUTME: an existing list route), or skip (dedup) instead of always
// ABOUTME: calling router.go() which would obliterate the navigation stack.

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/main.dart' as app;
import 'package:openvine/screens/curated_list_by_author_screen.dart';
import 'package:openvine/screens/curated_list_feed_screen.dart';

void main() {
  const authorPubkey =
      'a1b2c3d4e5f6a7b8c9d0e1f2a3b4c5d6e7f8a9b0c1d2e3f4a5b6c7d8e9f0a1b2';
  final targetPath = CuratedListByAuthorScreen.pathFor(
    pubkey: authorPubkey,
    listId: 'my-vines',
  );

  group('resolveListDeepLinkNavAction', () {
    test(
      'returns skip when already on the list — duplicate link event, '
      'nothing new to do',
      () {
        final action = app.resolveListDeepLinkNavAction(
          currentLocation: targetPath,
          targetPath: targetPath,
        );
        expect(action, equals(app.ListDeepLinkNavAction.skip));
      },
    );

    test('returns go when a different deep-linked list is showing', () {
      const otherPubkey =
          'ffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff';
      final otherPath = CuratedListByAuthorScreen.pathFor(
        pubkey: otherPubkey,
        listId: 'other-list',
      );

      final action = app.resolveListDeepLinkNavAction(
        currentLocation: otherPath,
        targetPath: targetPath,
      );
      expect(action, equals(app.ListDeepLinkNavAction.go));
    });

    test(
      'returns go when an internally opened list (/list/:listId) is showing',
      () {
        final internalPath = CuratedListFeedScreen.pathForId('local-list');

        final action = app.resolveListDeepLinkNavAction(
          currentLocation: internalPath,
          targetPath: targetPath,
        );
        expect(action, equals(app.ListDeepLinkNavAction.go));
      },
    );

    test('returns push from a non-list route so back returns there', () {
      final action = app.resolveListDeepLinkNavAction(
        currentLocation: '/home/0',
        targetPath: targetPath,
      );
      expect(action, equals(app.ListDeepLinkNavAction.push));
    });

    test('returns push from the discover-lists route — /discover-lists is '
        'not under the /list/ prefix', () {
      final action = app.resolveListDeepLinkNavAction(
        currentLocation: '/discover-lists',
        targetPath: targetPath,
      );
      expect(action, equals(app.ListDeepLinkNavAction.push));
    });
  });
}
