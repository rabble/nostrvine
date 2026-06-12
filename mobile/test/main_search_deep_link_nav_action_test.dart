// ABOUTME: Regression tests for resolveSearchDeepLinkNavAction routing decision
// ABOUTME: Verifies search deep links push (keeping the stack), go (replacing
// ABOUTME: an existing search route), or skip (dedup) instead of always
// ABOUTME: calling router.go() which obliterated the navigation stack.

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/main.dart' as app;
import 'package:openvine/screens/search_results/view/search_results_page.dart';

void main() {
  final targetPath = SearchResultsPage.pathForQuery(
    'vine classics',
    requestFocusOnMount: false,
  );

  group('resolveSearchDeepLinkNavAction', () {
    group('same route (currentLocation == targetPath)', () {
      test(
        'returns skip when already on the search query — duplicate link '
        'event, nothing new to do',
        () {
          final action = app.resolveSearchDeepLinkNavAction(
            currentLocation: targetPath,
            targetPath: targetPath,
          );
          expect(action, equals(app.SearchDeepLinkNavAction.skip));
        },
      );
    });

    group('already on the search surface (replacing in-place)', () {
      test(
        'returns go when a different search query is currently visible',
        () {
          final otherPath = SearchResultsPage.pathForQuery(
            'dog tricks',
            requestFocusOnMount: false,
          );

          final action = app.resolveSearchDeepLinkNavAction(
            currentLocation: otherPath,
            targetPath: targetPath,
          );
          expect(action, equals(app.SearchDeepLinkNavAction.go));
        },
      );

      test(
        'returns go from the empty search screen (no prefilled query)',
        () {
          final action = app.resolveSearchDeepLinkNavAction(
            currentLocation: SearchResultsPage.emptyPath,
            targetPath: targetPath,
          );
          expect(action, equals(app.SearchDeepLinkNavAction.go));
        },
      );

      test(
        'returns go from the empty search screen with mount focus '
        '(/search-results?focus=1)',
        () {
          final action = app.resolveSearchDeepLinkNavAction(
            currentLocation: SearchResultsPage.pathForEmptyQuery(
              requestFocusOnMount: true,
            ),
            targetPath: targetPath,
          );
          expect(action, equals(app.SearchDeepLinkNavAction.go));
        },
      );

      // Same query but the current location carries ?focus=1 while the deep
      // link target does not. The paths differ, so this is not a skip; both
      // are the same search surface, so the resolver replaces in-place (go)
      // rather than stacking a second copy of the same query.
      test(
        'returns go from the same query with ?focus=1 — replace, not stack',
        () {
          final focusedPath = SearchResultsPage.pathForQuery(
            'vine classics',
            requestFocusOnMount: true,
          );

          final action = app.resolveSearchDeepLinkNavAction(
            currentLocation: focusedPath,
            targetPath: targetPath,
          );
          expect(action, equals(app.SearchDeepLinkNavAction.go));
        },
      );
    });

    group('coming from a non-search route', () {
      // Regression: a search deep link from the home feed used to call
      // router.go(), wiping the navigation stack and leaving no way back.
      test(
        'returns push from the home feed so back returns to the main screen',
        () {
          final action = app.resolveSearchDeepLinkNavAction(
            currentLocation: '/home/0',
            targetPath: targetPath,
          );
          expect(action, equals(app.SearchDeepLinkNavAction.push));
        },
      );

      test(
        'returns push from the explore screen so back returns there',
        () {
          final action = app.resolveSearchDeepLinkNavAction(
            currentLocation: '/explore',
            targetPath: targetPath,
          );
          expect(action, equals(app.SearchDeepLinkNavAction.push));
        },
      );

      test(
        'returns push from a profile route (cross-type navigation)',
        () {
          final action = app.resolveSearchDeepLinkNavAction(
            currentLocation:
                '/profile/npub1abcdefghijklmnopqrstuvwxyz0123456789abcdefghijklmnopqrstuvwx',
            targetPath: targetPath,
          );
          expect(action, equals(app.SearchDeepLinkNavAction.push));
        },
      );
    });
  });
}
