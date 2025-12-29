// ABOUTME: Tests for FollowFromProfileButton widget using FollowingBloc
// ABOUTME: Validates follow/unfollow button state, tap behavior, and visibility logic

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/following/following_bloc.dart';
import 'package:openvine/widgets/profile/follow_from_profile_button.dart';

class _MockFollowingBloc extends MockBloc<FollowingEvent, FollowingState>
    implements FollowingBloc {}

void main() {
  group('FollowFromProfileButtonView', () {
    late _MockFollowingBloc mockFollowingBloc;

    setUpAll(() {
      registerFallbackValue(const FollowToggleRequested(''));
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
    });

    Widget createTestWidget({required String pubkey}) {
      return MaterialApp(
        home: Scaffold(
          body: SizedBox(
            width: 200,
            child: BlocProvider<FollowingBloc>.value(
              value: mockFollowingBloc,
              child: FollowFromProfileButtonView(pubkey: pubkey),
            ),
          ),
        ),
      );
    }

    group('button state', () {
      testWidgets('shows ElevatedButton with "Follow" when not following', (
        tester,
      ) async {
        when(() => mockFollowingBloc.state).thenReturn(
          FollowingState(
            status: FollowingStatus.success,
            followingPubkeys: const [],
          ),
        );

        await tester.pumpWidget(createTestWidget(pubkey: validPubkey('other')));
        await tester.pump();

        expect(find.text('Follow'), findsOneWidget);
        expect(find.byType(ElevatedButton), findsOneWidget);
        expect(find.byType(OutlinedButton), findsNothing);
      });

      testWidgets('shows OutlinedButton with "Following" when following', (
        tester,
      ) async {
        final otherPubkey = validPubkey('other');
        when(() => mockFollowingBloc.state).thenReturn(
          FollowingState(
            status: FollowingStatus.success,
            followingPubkeys: [otherPubkey],
          ),
        );

        await tester.pumpWidget(createTestWidget(pubkey: otherPubkey));
        await tester.pump();

        expect(find.text('Following'), findsOneWidget);
        expect(find.byType(OutlinedButton), findsOneWidget);
        expect(find.byType(ElevatedButton), findsNothing);
      });
    });

    group('interactions', () {
      testWidgets('dispatches FollowToggleRequested when tapping Follow', (
        tester,
      ) async {
        final otherPubkey = validPubkey('other');
        when(() => mockFollowingBloc.state).thenReturn(
          FollowingState(
            status: FollowingStatus.success,
            followingPubkeys: const [],
          ),
        );

        await tester.pumpWidget(createTestWidget(pubkey: otherPubkey));
        await tester.pump();

        await tester.tap(find.text('Follow'));
        await tester.pump();

        final captured = verify(
          () => mockFollowingBloc.add(captureAny()),
        ).captured;
        expect(captured.length, 1);
        expect(captured.first, isA<FollowToggleRequested>());
        expect((captured.first as FollowToggleRequested).pubkey, otherPubkey);
      });

      testWidgets('dispatches FollowToggleRequested when tapping Following', (
        tester,
      ) async {
        final otherPubkey = validPubkey('other');
        when(() => mockFollowingBloc.state).thenReturn(
          FollowingState(
            status: FollowingStatus.success,
            followingPubkeys: [otherPubkey],
          ),
        );

        await tester.pumpWidget(createTestWidget(pubkey: otherPubkey));
        await tester.pump();

        await tester.tap(find.text('Following'));
        await tester.pump();

        final captured = verify(
          () => mockFollowingBloc.add(captureAny()),
        ).captured;
        expect(captured.length, 1);
        expect(captured.first, isA<FollowToggleRequested>());
      });
    });
  });
}
