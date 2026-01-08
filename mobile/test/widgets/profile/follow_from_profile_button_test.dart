// ABOUTME: Tests for FollowFromProfileButton widget using MyFollowingBloc
// ABOUTME: Validates follow/unfollow button state, tap behavior, and visibility logic

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/my_following/my_following_bloc.dart';
import 'package:openvine/blocs/others_followers/others_followers_bloc.dart';
import 'package:openvine/widgets/profile/follow_from_profile_button.dart';

class _MockMyFollowingBloc extends MockBloc<MyFollowingEvent, MyFollowingState>
    implements MyFollowingBloc {}

class _MockOthersFollowersBloc
    extends MockBloc<OthersFollowersEvent, OthersFollowersState>
    implements OthersFollowersBloc {}

void main() {
  group('FollowFromProfileButtonView', () {
    late _MockMyFollowingBloc mockMyFollowingBloc;
    late _MockOthersFollowersBloc mockOthersFollowersBloc;

    setUpAll(() {
      registerFallbackValue(const MyFollowingToggleRequested(''));
      registerFallbackValue(const OthersFollowersIncrementRequested(''));
      registerFallbackValue(const OthersFollowersDecrementRequested(''));
    });

    // Helper to create valid hex pubkeys (64 hex characters)
    String validPubkey(String suffix) {
      final hexSuffix = suffix.codeUnits
          .map((c) => c.toRadixString(16).padLeft(2, '0'))
          .join();
      return hexSuffix.padLeft(64, '0');
    }

    setUp(() {
      mockMyFollowingBloc = _MockMyFollowingBloc();
      mockOthersFollowersBloc = _MockOthersFollowersBloc();
    });

    Widget createTestWidget({
      required String pubkey,
      String? currentUserPubkey,
      bool includeOthersFollowersBloc = false,
    }) {
      Widget child = BlocProvider<MyFollowingBloc>.value(
        value: mockMyFollowingBloc,
        child: FollowFromProfileButtonView(
          pubkey: pubkey,
          currentUserPubkey: currentUserPubkey,
        ),
      );

      if (includeOthersFollowersBloc) {
        child = BlocProvider<OthersFollowersBloc>.value(
          value: mockOthersFollowersBloc,
          child: child,
        );
      }

      return MaterialApp(
        home: Scaffold(body: SizedBox(width: 200, child: child)),
      );
    }

    group('button state', () {
      testWidgets('shows ElevatedButton with "Follow" when not following', (
        tester,
      ) async {
        when(() => mockMyFollowingBloc.state).thenReturn(
          const MyFollowingState(
            status: MyFollowingStatus.success,
            followingPubkeys: [],
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
        when(() => mockMyFollowingBloc.state).thenReturn(
          MyFollowingState(
            status: MyFollowingStatus.success,
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
      testWidgets('dispatches MyFollowingToggleRequested when tapping Follow', (
        tester,
      ) async {
        final otherPubkey = validPubkey('other');
        when(() => mockMyFollowingBloc.state).thenReturn(
          const MyFollowingState(
            status: MyFollowingStatus.success,
            followingPubkeys: [],
          ),
        );

        await tester.pumpWidget(createTestWidget(pubkey: otherPubkey));
        await tester.pump();

        await tester.tap(find.text('Follow'));
        await tester.pump();

        final captured = verify(
          () => mockMyFollowingBloc.add(captureAny()),
        ).captured;
        expect(captured.length, 1);
        expect(captured.first, isA<MyFollowingToggleRequested>());
        expect(
          (captured.first as MyFollowingToggleRequested).pubkey,
          otherPubkey,
        );
      });

      testWidgets(
        'dispatches MyFollowingToggleRequested when tapping Following',
        (tester) async {
          final otherPubkey = validPubkey('other');
          when(() => mockMyFollowingBloc.state).thenReturn(
            MyFollowingState(
              status: MyFollowingStatus.success,
              followingPubkeys: [otherPubkey],
            ),
          );

          await tester.pumpWidget(createTestWidget(pubkey: otherPubkey));
          await tester.pump();

          await tester.tap(find.text('Following'));
          await tester.pump();

          final captured = verify(
            () => mockMyFollowingBloc.add(captureAny()),
          ).captured;
          expect(captured.length, 1);
          expect(captured.first, isA<MyFollowingToggleRequested>());
        },
      );
    });

    group('optimistic follower count update', () {
      testWidgets(
        'dispatches OthersFollowersIncrementRequested when following',
        (tester) async {
          final otherPubkey = validPubkey('other');
          final currentUserPubkey = validPubkey('me');

          when(() => mockMyFollowingBloc.state).thenReturn(
            const MyFollowingState(
              status: MyFollowingStatus.success,
              followingPubkeys: [],
            ),
          );
          when(() => mockOthersFollowersBloc.state).thenReturn(
            const OthersFollowersState(
              status: OthersFollowersStatus.success,
              followersPubkeys: [],
            ),
          );

          await tester.pumpWidget(
            createTestWidget(
              pubkey: otherPubkey,
              currentUserPubkey: currentUserPubkey,
              includeOthersFollowersBloc: true,
            ),
          );
          await tester.pump();

          await tester.tap(find.text('Follow'));
          await tester.pump();

          final captured = verify(
            () => mockOthersFollowersBloc.add(captureAny()),
          ).captured;
          expect(captured.length, 1);
          expect(captured.first, isA<OthersFollowersIncrementRequested>());
          expect(
            (captured.first as OthersFollowersIncrementRequested)
                .followerPubkey,
            currentUserPubkey,
          );
        },
      );

      testWidgets(
        'dispatches OthersFollowersDecrementRequested when unfollowing',
        (tester) async {
          final otherPubkey = validPubkey('other');
          final currentUserPubkey = validPubkey('me');

          when(() => mockMyFollowingBloc.state).thenReturn(
            MyFollowingState(
              status: MyFollowingStatus.success,
              followingPubkeys: [otherPubkey],
            ),
          );
          when(() => mockOthersFollowersBloc.state).thenReturn(
            OthersFollowersState(
              status: OthersFollowersStatus.success,
              followersPubkeys: [currentUserPubkey],
            ),
          );

          await tester.pumpWidget(
            createTestWidget(
              pubkey: otherPubkey,
              currentUserPubkey: currentUserPubkey,
              includeOthersFollowersBloc: true,
            ),
          );
          await tester.pump();

          await tester.tap(find.text('Following'));
          await tester.pump();

          final captured = verify(
            () => mockOthersFollowersBloc.add(captureAny()),
          ).captured;
          expect(captured.length, 1);
          expect(captured.first, isA<OthersFollowersDecrementRequested>());
          expect(
            (captured.first as OthersFollowersDecrementRequested)
                .followerPubkey,
            currentUserPubkey,
          );
        },
      );

      testWidgets(
        'does not dispatch to OthersFollowersBloc when not provided',
        (tester) async {
          final otherPubkey = validPubkey('other');
          final currentUserPubkey = validPubkey('me');

          when(() => mockMyFollowingBloc.state).thenReturn(
            const MyFollowingState(
              status: MyFollowingStatus.success,
              followingPubkeys: [],
            ),
          );

          await tester.pumpWidget(
            createTestWidget(
              pubkey: otherPubkey,
              currentUserPubkey: currentUserPubkey,
              // OthersFollowersBloc not provided
            ),
          );
          await tester.pump();

          await tester.tap(find.text('Follow'));
          await tester.pump();

          // Should not throw and should still dispatch to MyFollowingBloc
          verify(() => mockMyFollowingBloc.add(any())).called(1);
          verifyNever(() => mockOthersFollowersBloc.add(any()));
        },
      );
    });
  });
}
