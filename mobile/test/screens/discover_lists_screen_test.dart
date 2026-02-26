// ABOUTME: Tests for DiscoverListsScreen pagination behavior
// ABOUTME: Verifies pagination stops re-triggering when no more lists found

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart' hide LogCategory;
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/list_providers.dart';
import 'package:openvine/screens/discover_lists_screen.dart';
import 'package:openvine/services/curated_list_service.dart';

import '../helpers/test_provider_overrides.dart';

class _MockCuratedListService extends Mock implements CuratedListService {}

/// Test subclass that exposes a mock service without requiring
/// the real async initialization (NostrClient, AuthService, etc.).
class _TestCuratedListsState extends CuratedListsState {
  _TestCuratedListsState(this._mockService);
  final CuratedListService? _mockService;

  @override
  CuratedListService? get service => _mockService;

  @override
  Future<List<CuratedList>> build() async => [];
}

/// Pre-populated DiscoveredLists notifier so the screen skips the
/// initial stream fetch (it only fetches when lists are empty).
class _PreloadedDiscoveredLists extends DiscoveredLists {
  _PreloadedDiscoveredLists(this._initialState);
  final DiscoveredListsState _initialState;

  @override
  DiscoveredListsState build() => _initialState;
}

CuratedList _makeList(String id, {DateTime? createdAt}) {
  return CuratedList(
    id: id,
    name: 'List $id',
    videoEventIds: ['video_$id'],
    createdAt: createdAt ?? DateTime(2025),
    updatedAt: createdAt ?? DateTime(2025),
  );
}

void main() {
  group(DiscoverListsScreen, () {
    late _MockCuratedListService mockService;
    late List<CuratedList> preloadedLists;

    setUp(() {
      mockService = _MockCuratedListService();

      // Create enough lists so auto-pagination doesn't kick in
      // (_minListsBeforeAutoPaginate = 10)
      preloadedLists = List.generate(
        15,
        (i) => _makeList(
          'list_$i',
          createdAt: DateTime(2025).subtract(Duration(hours: i)),
        ),
      );

      // Default: isSubscribedToList returns false
      when(() => mockService.isSubscribedToList(any())).thenReturn(false);
    });

    Widget buildSubject({
      List<CuratedList>? initialLists,
      DateTime? oldestTimestamp,
    }) {
      final lists = initialLists ?? preloadedLists;
      final oldest =
          oldestTimestamp ?? DateTime(2025).subtract(const Duration(hours: 14));

      return ProviderScope(
        overrides: [
          ...getStandardTestOverrides(),
          discoveredListsProvider.overrideWith(
            () => _PreloadedDiscoveredLists(
              DiscoveredListsState(lists: lists, oldestTimestamp: oldest),
            ),
          ),
          curatedListsStateProvider.overrideWith(
            () => _TestCuratedListsState(mockService),
          ),
        ],
        child: const MaterialApp(home: DiscoverListsScreen()),
      );
    }

    testWidgets(
      'scrolling to bottom again after finding no new lists should not '
      're-trigger pagination',
      (tester) async {
        // Each call gets a fresh StreamController. The stream stays open
        // (no data, no close) so _loadMoreLists relies on its 3-second
        // timeout timer to complete. The timeout fires within FakeAsync,
        // resolving the Completer and running the finally block.
        final controllers = <StreamController<List<CuratedList>>>[];

        when(
          () => mockService.streamPublicListsFromRelays(
            until: any(named: 'until'),
            excludeIds: any(named: 'excludeIds'),
          ),
        ).thenAnswer((_) {
          final c = StreamController<List<CuratedList>>();
          controllers.add(c);
          return c.stream;
        });

        await tester.pumpWidget(buildSubject());
        await tester.pump();
        await tester.pump();

        // Verify lists are shown and no spinner yet
        expect(find.byType(Card), findsWidgets);
        expect(find.byType(CircularProgressIndicator), findsNothing);

        // --- First scroll: triggers pagination ---
        await tester.drag(find.byType(ListView), const Offset(0, -5000));

        // pump() processes microtasks: _loadMoreLists starts, calls mock,
        // listens to stream, awaits completer. Stream stays open.
        await tester.pump();
        expect(controllers, hasLength(1));

        // Advance past the 3-second timeout. The timer fires within
        // FakeAsync: cancels subscription, completes the Completer.
        // elapse() also flushes microtasks after each timer, so the
        // continuation runs: finally block → _isLoadingMore = false.
        await tester.pump(const Duration(seconds: 4));
        // Extra pump to process any remaining microtasks + rebuild
        await tester.pump();

        // _loadMoreLists should have completed: spinner gone
        expect(
          find.byType(CircularProgressIndicator),
          findsNothing,
          reason: '_loadMoreLists should have completed via timeout',
        );

        // --- Second scroll: should NOT trigger pagination again ---
        // Scroll UP first so the subsequent scroll DOWN actually changes
        // the position and fires the _onScroll listener at the bottom.
        await tester.drag(find.byType(ListView), const Offset(0, 500));
        await tester.pump();
        await tester.drag(find.byType(ListView), const Offset(0, -5000));
        await tester.pump();
        await tester.pump(const Duration(seconds: 4));
        await tester.pump();

        // With _hasReachedEnd: _onScroll returns early → 1 controller
        // Without _hasReachedEnd: _loadMoreLists is called again → 2+
        expect(
          controllers.length,
          1,
          reason:
              '_loadMoreLists should not be called again after finding '
              'no new lists (controllers created: ${controllers.length})',
        );
      },
    );
  });
}
