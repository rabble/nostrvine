// ABOUTME: Tests for VideoFollowButton widget using FollowingBloc
// ABOUTME: Validates follow/unfollow button state, tap behavior, and styling

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/following/following_bloc.dart';
import 'package:openvine/widgets/video_feed_item/video_follow_button.dart';

class _MockFollowingBloc extends MockBloc<FollowingEvent, FollowingState>
    implements FollowingBloc {}

void main() {
  group('VideoFollowButtonView', () {
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
          body: BlocProvider<FollowingBloc>.value(
            value: mockFollowingBloc,
            child: VideoFollowButtonView(pubkey: pubkey),
          ),
        ),
      );
    }

    group('button state', () {
      testWidgets('shows "Follow" when not following', (tester) async {
        when(() => mockFollowingBloc.state).thenReturn(
          FollowingState(
            status: FollowingStatus.success,
            followingPubkeys: const [],
          ),
        );

        await tester.pumpWidget(createTestWidget(pubkey: validPubkey('other')));
        await tester.pump();

        expect(find.text('Follow'), findsOneWidget);
        expect(find.text('Following'), findsNothing);
      });

      testWidgets('shows "Following" when following', (tester) async {
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
        expect(find.text('Follow'), findsNothing);
      });
    });

    group('interactions', () {
      testWidgets('dispatches FollowToggleRequested on tap', (tester) async {
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

      testWidgets('dispatches FollowToggleRequested when tapping "Following"', (
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
