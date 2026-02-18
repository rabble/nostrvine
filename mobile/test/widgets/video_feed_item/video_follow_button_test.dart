// ABOUTME: Tests for VideoFollowButton widget using MyFollowingBloc
// ABOUTME: Validates follow/unfollow button state, tap behavior, and styling

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/my_following/my_following_bloc.dart';
import 'package:openvine/widgets/video_feed_item/video_follow_button.dart';

class _MockMyFollowingBloc extends MockBloc<MyFollowingEvent, MyFollowingState>
    implements MyFollowingBloc {}

void main() {
  group('VideoFollowButtonView', () {
    late _MockMyFollowingBloc mockMyFollowingBloc;

    setUpAll(() {
      registerFallbackValue(const MyFollowingToggleRequested(''));
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
    });

    Widget createTestWidget({required String pubkey}) {
      return MaterialApp(
        home: Scaffold(
          body: BlocProvider<MyFollowingBloc>.value(
            value: mockMyFollowingBloc,
            child: VideoFollowButtonView(pubkey: pubkey),
          ),
        ),
      );
    }

    group('button state', () {
      testWidgets('shows follow icon when not following', (tester) async {
        when(() => mockMyFollowingBloc.state).thenReturn(
          const MyFollowingState(
            status: MyFollowingStatus.success,
            followingPubkeys: [],
          ),
        );

        await tester.pumpWidget(createTestWidget(pubkey: validPubkey('other')));
        await tester.pump();

        // Button uses SVG icons now - find by SvgPicture widget
        expect(find.byType(SvgPicture), findsOneWidget);
        expect(find.byType(GestureDetector), findsOneWidget);
      });

      testWidgets('has Follow semantic label when not following', (
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

        expect(find.bySemanticsLabel('Follow'), findsOneWidget);
      });

      testWidgets('shows following icon when following', (tester) async {
        final otherPubkey = validPubkey('other');
        when(() => mockMyFollowingBloc.state).thenReturn(
          MyFollowingState(
            status: MyFollowingStatus.success,
            followingPubkeys: [otherPubkey],
          ),
        );

        await tester.pumpWidget(createTestWidget(pubkey: otherPubkey));
        await tester.pump();

        // Button uses SVG icons now - find by SvgPicture widget
        expect(find.byType(SvgPicture), findsOneWidget);
        expect(find.byType(GestureDetector), findsOneWidget);
      });

      testWidgets('has Following semantic label when following', (
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

        expect(find.bySemanticsLabel('Following'), findsOneWidget);
      });
    });

    group('interactions', () {
      testWidgets(
        'dispatches MyFollowingToggleRequested on tap when not following',
        (tester) async {
          final otherPubkey = validPubkey('other');
          when(() => mockMyFollowingBloc.state).thenReturn(
            const MyFollowingState(
              status: MyFollowingStatus.success,
              followingPubkeys: [],
            ),
          );

          await tester.pumpWidget(createTestWidget(pubkey: otherPubkey));
          await tester.pump();

          await tester.tap(find.byType(GestureDetector));
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
        },
      );

      testWidgets(
        'dispatches MyFollowingToggleRequested on tap when following',
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

          await tester.tap(find.byType(GestureDetector));
          await tester.pump();

          final captured = verify(
            () => mockMyFollowingBloc.add(captureAny()),
          ).captured;
          expect(captured.length, 1);
          expect(captured.first, isA<MyFollowingToggleRequested>());
        },
      );
    });
  });
}
