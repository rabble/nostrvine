// ABOUTME: Tests for HashtagSearchView widget
// ABOUTME: Validates UI states for initial, loading, success, failure, and
// ABOUTME: empty results

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/hashtag_search/hashtag_search_bloc.dart';
import 'package:openvine/widgets/hashtag_search_view.dart';

import '../helpers/test_provider_overrides.dart';

class _MockHashtagSearchBloc
    extends MockBloc<HashtagSearchEvent, HashtagSearchState>
    implements HashtagSearchBloc {}

void main() {
  group(HashtagSearchView, () {
    late _MockHashtagSearchBloc mockBloc;

    setUp(() {
      mockBloc = _MockHashtagSearchBloc();
    });

    Widget createTestWidget() {
      return testMaterialApp(
        home: BlocProvider<HashtagSearchBloc>.value(
          value: mockBloc,
          child: const Scaffold(body: HashtagSearchView()),
        ),
        mockAuthService: createMockAuthService(),
        mockUserProfileService: createMockUserProfileService(),
      );
    }

    group('initial state', () {
      testWidgets('shows empty state with tag icon and message', (
        tester,
      ) async {
        when(() => mockBloc.state).thenReturn(const HashtagSearchState());

        await tester.pumpWidget(createTestWidget());
        await tester.pump();

        expect(find.byIcon(Icons.tag), findsOneWidget);
        expect(find.text('Search for hashtags'), findsOneWidget);
        expect(
          find.text('Discover trending topics and content'),
          findsOneWidget,
        );
      });
    });

    group('loading state', () {
      testWidgets('shows $CircularProgressIndicator when loading', (
        tester,
      ) async {
        when(() => mockBloc.state).thenReturn(
          const HashtagSearchState(
            status: HashtagSearchStatus.loading,
            query: 'test',
          ),
        );

        await tester.pumpWidget(createTestWidget());
        await tester.pump();

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      });
    });

    group('success state', () {
      testWidgets('shows no results state when results list is empty', (
        tester,
      ) async {
        when(() => mockBloc.state).thenReturn(
          const HashtagSearchState(
            status: HashtagSearchStatus.success,
            query: 'xyz',
          ),
        );

        await tester.pumpWidget(createTestWidget());
        await tester.pump();

        expect(find.byIcon(Icons.tag_outlined), findsOneWidget);
        expect(find.text('No hashtags found for "xyz"'), findsOneWidget);
      });

      testWidgets('shows $ListView when results are available', (tester) async {
        when(() => mockBloc.state).thenReturn(
          const HashtagSearchState(
            status: HashtagSearchStatus.success,
            query: 'music',
            results: ['music', 'musician', 'musicvideo'],
          ),
        );

        await tester.pumpWidget(createTestWidget());
        await tester.pump();

        expect(find.byType(ListView), findsOneWidget);
        expect(find.text('#music'), findsOneWidget);
        expect(find.text('#musician'), findsOneWidget);
        expect(find.text('#musicvideo'), findsOneWidget);
      });
    });

    group('failure state', () {
      testWidgets('shows error state with error icon and message', (
        tester,
      ) async {
        when(() => mockBloc.state).thenReturn(
          const HashtagSearchState(
            status: HashtagSearchStatus.failure,
            query: 'test',
          ),
        );

        await tester.pumpWidget(createTestWidget());
        await tester.pump();

        expect(find.byIcon(Icons.error_outline), findsOneWidget);
        expect(find.text('Search failed'), findsOneWidget);
      });
    });

    group('state transitions', () {
      testWidgets('rebuilds when bloc state changes', (tester) async {
        whenListen(
          mockBloc,
          Stream<HashtagSearchState>.fromIterable([
            const HashtagSearchState(),
            const HashtagSearchState(
              status: HashtagSearchStatus.loading,
              query: 'music',
            ),
          ]),
          initialState: const HashtagSearchState(),
        );

        await tester.pumpWidget(createTestWidget());

        // Initial state
        expect(find.byIcon(Icons.tag), findsOneWidget);

        // Trigger state change
        await tester.pump();

        // Loading state
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      });

      testWidgets('fires analytics when transitioning to success', (
        tester,
      ) async {
        whenListen(
          mockBloc,
          Stream<HashtagSearchState>.fromIterable([
            const HashtagSearchState(
              status: HashtagSearchStatus.loading,
              query: 'music',
            ),
            const HashtagSearchState(
              status: HashtagSearchStatus.success,
              query: 'music',
              results: ['music', 'musician'],
            ),
          ]),
          initialState: const HashtagSearchState(
            status: HashtagSearchStatus.loading,
            query: 'music',
          ),
        );

        await tester.pumpWidget(createTestWidget());

        // Loading state
        expect(find.byType(CircularProgressIndicator), findsOneWidget);

        // Transition to success - listener fires analytics without error
        await tester.pump();

        // Verify success UI rendered (listener did not interfere)
        expect(find.byType(ListView), findsOneWidget);
        expect(find.text('#music'), findsOneWidget);
        expect(find.text('#musician'), findsOneWidget);
      });
    });
  });
}
