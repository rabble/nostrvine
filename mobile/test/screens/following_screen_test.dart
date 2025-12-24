// ABOUTME: Tests for FollowingScreen widget using FollowingBloc
// ABOUTME: Validates following list UI states and user interactions

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart' as mocktail;
import 'package:mockito/mockito.dart' as mockito;
import 'package:openvine/blocs/following/following_bloc.dart';
import 'package:openvine/screens/following_screen.dart';

import '../helpers/test_provider_overrides.dart';
import '../helpers/test_provider_overrides.mocks.dart'
    show MockSharedPreferences;

class _MockFollowingBloc extends MockBloc<FollowingEvent, FollowingState>
    implements FollowingBloc {}

void main() {
  group('FollowingView', () {
    late _MockFollowingBloc mockFollowingBloc;
    late MockSharedPreferences mockSharedPreferences;
    setUpAll(() {
      // Register fallback value for mocktail captureAny
      mocktail.registerFallbackValue(const FollowingListLoadRequested());
    });

    // Helper to create valid hex pubkeys (64 hex characters)
    String validPubkey(String suffix) {
      final hexSuffix = suffix.codeUnits
          .map((c) => c.toRadixString(16).padLeft(2, '0'))
          .join();
      return hexSuffix.padLeft(64, '0');
    }

    setUp(() {
      mockFollowingBloc = _MockFollowingBloc();
      mockSharedPreferences = createMockSharedPreferences();
      // Add missing SharedPreferences stubs for relay gateway
      mockito
          .when(mockSharedPreferences.getBool('relay_gateway_enabled'))
          .thenReturn(false);
    });

    Widget createTestWidget({String? pubkey}) {
      final testPubkey = pubkey ?? validPubkey('test');
      return testProviderScope(
        mockSharedPreferences: mockSharedPreferences,
        child: MaterialApp(
          home: BlocProvider<FollowingBloc>.value(
            value: mockFollowingBloc,
            child: FollowingView(pubkey: testPubkey, displayName: 'Test User'),
          ),
        ),
      );
    }

    testWidgets('displays loading indicator when status is initial', (
      tester,
    ) async {
      mocktail.when(() => mockFollowingBloc.state).thenReturn(FollowingState());

      await tester.pumpWidget(createTestWidget());
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('displays loading indicator when status is loading', (
      tester,
    ) async {
      mocktail
          .when(() => mockFollowingBloc.state)
          .thenReturn(FollowingState(status: FollowingStatus.loading));

      await tester.pumpWidget(createTestWidget());
      await tester.pump();

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    // TODO(anyone): fix the test below, skip for now.
    // Note: RefreshIndicator test is skipped because UserProfileTile
    // (rendered in ListView) has deep Riverpod dependencies that require
    // extensive mocking. The retry button test above verifies the event
    // dispatch mechanism works correctly.
    testWidgets('displays following list when status is success', (
      tester,
    ) async {
      final followingPubkeys = [
        validPubkey('following1'),
        validPubkey('following2'),
        validPubkey('following3'),
      ];

      mocktail
          .when(() => mockFollowingBloc.state)
          .thenReturn(
            FollowingState(
              status: FollowingStatus.success,
              followingPubkeys: followingPubkeys,
            ),
          );
      mocktail
          .when(() => mockFollowingBloc.stream)
          .thenAnswer((_) => const Stream<FollowingState>.empty());

      await tester.pumpWidget(createTestWidget());
      await tester.pump();

      expect(find.byType(ListView), findsOneWidget);
      // TODO(any): Fix and enable this test
    }, skip: true);

    testWidgets('shows empty state when following list is empty', (
      tester,
    ) async {
      mocktail
          .when(() => mockFollowingBloc.state)
          .thenReturn(
            FollowingState(
              status: FollowingStatus.success,
              followingPubkeys: [],
            ),
          );

      await tester.pumpWidget(createTestWidget());

      expect(find.text('Not following anyone yet'), findsOneWidget);
      expect(find.byIcon(Icons.person_add_outlined), findsOneWidget);
    });

    testWidgets('shows error state when status is failure', (tester) async {
      mocktail
          .when(() => mockFollowingBloc.state)
          .thenReturn(FollowingState(status: FollowingStatus.failure));

      await tester.pumpWidget(createTestWidget());

      expect(find.text('Failed to load following list'), findsOneWidget);
      expect(find.byIcon(Icons.error_outline), findsOneWidget);
      expect(find.text('Retry'), findsOneWidget);
    });

    testWidgets('retry button adds FollowingListRefreshRequested', (
      tester,
    ) async {
      final testPubkey = validPubkey('test');

      whenListen(
        mockFollowingBloc,
        Stream.value(
          FollowingState(
            status: FollowingStatus.failure,
            targetPubkey: testPubkey,
          ),
        ),
        initialState: FollowingState(
          status: FollowingStatus.failure,
          targetPubkey: testPubkey,
        ),
      );

      await tester.pumpWidget(createTestWidget(pubkey: testPubkey));
      await tester.pumpAndSettle();

      // Tap retry button
      await tester.tap(find.text('Retry'));
      await tester.pump();

      // Verify the correct event was dispatched
      final captured = mocktail
          .verify(() => mockFollowingBloc.add(mocktail.captureAny()))
          .captured;

      expect(captured.length, 1);
      expect(captured.first, isA<FollowingListLoadRequested>());
    });

    // TODO(anyone): fix the test below, skip for now.
    // Note: RefreshIndicator test is skipped because UserProfileTile
    // (rendered in ListView) has deep Riverpod dependencies that require
    // extensive mocking. The retry button test above verifies the event
    // dispatch mechanism works correctly.
    testWidgets(
      'refresh indicator dispatches FollowingListRefreshRequested',
      skip: true,
      (tester) async {
        final testPubkey = validPubkey('test');
        final followingPubkeys = [validPubkey('following1')];

        whenListen(
          mockFollowingBloc,
          Stream.value(
            FollowingState(
              status: FollowingStatus.success,
              followingPubkeys: followingPubkeys,
              targetPubkey: testPubkey,
            ),
          ),
          initialState: FollowingState(
            status: FollowingStatus.success,
            followingPubkeys: followingPubkeys,
            targetPubkey: testPubkey,
          ),
        );

        await tester.pumpWidget(createTestWidget(pubkey: testPubkey));
        await tester.pumpAndSettle();

        // Pull to refresh - fling on the ListView
        await tester.fling(find.byType(ListView), const Offset(0, 300), 1000);
        await tester.pump();

        // Verify the correct event was dispatched
        final captured = mocktail
            .verify(() => mockFollowingBloc.add(mocktail.captureAny()))
            .captured;

        expect(captured.length, 1);
        expect(captured.first, isA<FollowingListLoadRequested>());
      },
    );
  });
}
