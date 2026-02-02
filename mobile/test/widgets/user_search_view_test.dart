// ABOUTME: Tests for UserSearchView widget
// ABOUTME: Validates UI states for initial, loading, success, failure, and empty results

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/user_search/user_search_bloc.dart';
import 'package:openvine/widgets/user_search_view.dart';

import '../helpers/test_provider_overrides.dart';

class _MockUserSearchBloc extends MockBloc<UserSearchEvent, UserSearchState>
    implements UserSearchBloc {}

void main() {
  group('UserSearchView', () {
    late _MockUserSearchBloc mockBloc;

    setUp(() {
      mockBloc = _MockUserSearchBloc();
    });

    UserProfile createTestProfile(String pubkey, String displayName) {
      return UserProfile(
        pubkey: pubkey,
        displayName: displayName,
        createdAt: DateTime.now(),
        eventId: 'event-$pubkey',
        rawData: {'display_name': displayName},
      );
    }

    Widget createTestWidget() {
      return testMaterialApp(
        home: BlocProvider<UserSearchBloc>.value(
          value: mockBloc,
          child: const Scaffold(body: UserSearchView()),
        ),
        mockAuthService: createMockAuthService(),
        mockUserProfileService: createMockUserProfileService(),
      );
    }

    group('initial state', () {
      testWidgets('shows empty state with search icon and message', (
        tester,
      ) async {
        when(() => mockBloc.state).thenReturn(const UserSearchState());

        await tester.pumpWidget(createTestWidget());
        await tester.pump();

        expect(find.byIcon(Icons.person_search), findsOneWidget);
        expect(find.text('Search for users'), findsOneWidget);
      });
    });

    group('loading state', () {
      testWidgets('shows CircularProgressIndicator when loading', (
        tester,
      ) async {
        when(() => mockBloc.state).thenReturn(
          const UserSearchState(
            status: UserSearchStatus.loading,
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
          const UserSearchState(status: UserSearchStatus.success, query: 'xyz'),
        );

        await tester.pumpWidget(createTestWidget());
        await tester.pump();

        expect(find.byIcon(Icons.person_off), findsOneWidget);
        expect(find.text('No users found'), findsOneWidget);
      });

      testWidgets('shows ListView when results are available', (tester) async {
        final testProfiles = [
          createTestProfile('${'a' * 64}', 'Alice'),
          createTestProfile('${'b' * 64}', 'Bob'),
        ];

        when(() => mockBloc.state).thenReturn(
          UserSearchState(
            status: UserSearchStatus.success,
            query: 'test',
            results: testProfiles,
          ),
        );

        await tester.pumpWidget(createTestWidget());
        await tester.pump();

        expect(find.byType(ListView), findsOneWidget);
      });
    });

    group('failure state', () {
      testWidgets('shows error state with error icon and message', (
        tester,
      ) async {
        when(() => mockBloc.state).thenReturn(
          const UserSearchState(
            status: UserSearchStatus.failure,
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
          Stream<UserSearchState>.fromIterable([
            const UserSearchState(),
            const UserSearchState(
              status: UserSearchStatus.loading,
              query: 'alice',
            ),
          ]),
          initialState: const UserSearchState(),
        );

        await tester.pumpWidget(createTestWidget());

        // Initial state
        expect(find.byIcon(Icons.person_search), findsOneWidget);

        // Trigger state change
        await tester.pump();

        // Loading state
        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      });
    });
  });
}
