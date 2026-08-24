// ABOUTME: Composition tests for the author cluster inside VideoOverlayActions.
// ABOUTME: The standalone VideoFollowButtonView tests prove the badge is 48dp,
// ABOUTME: but only this level can catch parent hit-test clipping or the row
// ABOUTME: paying for a badge that never draws.

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:follow_repository/follow_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/video_interactions/video_interactions_bloc.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/widgets/user_avatar.dart';
import 'package:openvine/widgets/video_feed_item/video_feed_item.dart';
import 'package:openvine/widgets/video_feed_item/video_follow_button.dart';
import 'package:reposts_repository/reposts_repository.dart';

import '../../builders/test_video_event_builder.dart';
import '../../helpers/test_provider_overrides.dart';

/// Mirrors `_avatarClusterSize` in video_feed_item.dart: the avatar block the
/// cluster falls back to when the badge draws nothing.
const double _avatarClusterSize = 58;

class _MockVideoInteractionsBloc extends Mock
    implements VideoInteractionsBloc {}

class _MockRepostsRepository extends Mock implements RepostsRepository {}

void main() {
  group('VideoOverlayActions author cluster', () {
    late _MockVideoInteractionsBloc interactions;
    late _MockRepostsRepository reposts;

    setUp(() {
      interactions = _MockVideoInteractionsBloc();
      reposts = _MockRepostsRepository();
      when(() => interactions.stream).thenAnswer((_) => const Stream.empty());
      when(
        () => interactions.state,
      ).thenReturn(const VideoInteractionsState());
      when(
        () => reposts.fetchEventReposters(
          eventId: any(named: 'eventId'),
          addressableId: any(named: 'addressableId'),
        ),
      ).thenAnswer((_) async => const <String>[]);
    });

    Future<void> pump(
      WidgetTester tester, {
      required bool alreadyFollowing,
    }) async {
      // The shared helper stubs watchMyFollowingCached to an EMPTY stream, so
      // MyFollowingBloc never leaves `loading` and the badge stays collapsed.
      // Yield one snapshot so `isReady` becomes true and the badge really draws.
      final follow = createMockFollowRepository();
      when(() => follow.isFollowing(any())).thenReturn(alreadyFollowing);
      when(follow.watchMyFollowingCached).thenAnswer(
        (_) => Stream.value(
          const CacheResult<FollowingSnapshot>.live(
            FollowingSnapshot(pubkeys: <String>[], count: 0),
          ),
        ),
      );
      final overrides = <dynamic>[
        repostsRepositoryProvider.overrideWithValue(reposts),
      ];

      await tester.pumpWidget(
        testProviderScope(
          additionalOverrides: overrides,
          // Via the named parameter, not additionalOverrides: the helper always
          // overrides followRepositoryProvider, and Riverpod rejects a second
          // override of the same provider in one container.
          mockFollowRepository: follow,
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: BlocProvider<VideoInteractionsBloc>.value(
                value: interactions,
                child: VideoOverlayActions(
                  video: TestVideoEventBuilder.create(),
                  isVisible: true,
                  isActive: true,
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      await tester.pump();
    }

    /// The Stack that holds the avatar and, when it draws, the follow badge.
    Finder cluster() => find
        .ancestor(of: find.byType(UserAvatar), matching: find.byType(Stack))
        .first;

    testWidgets('does not grow when the badge does not draw', (tester) async {
      await pump(tester, alreadyFollowing: true);

      // The widget is always CONSTRUCTED; what matters is that it draws
      // nothing and therefore occupies nothing.
      expect(tester.getSize(find.byType(VideoFollowButton)), Size.zero);

      // So the badge's 48dp target costs no height in the states where it
      // renders nothing — loading, already following, own video, blocked
      // author, preview mode. Before this, all of them paid 21dp.
      expect(tester.getSize(cluster()).height, _avatarClusterSize);
      expect(tester.getSize(cluster()).width, _avatarClusterSize);
    });

    testWidgets('the badge footprint is not clipped by its parent', (
      tester,
    ) async {
      await pump(tester, alreadyFollowing: false);

      final badge = find.byType(VideoFollowButton);
      if (badge.evaluate().isEmpty) {
        // The badge only draws once MyFollowingBloc reports success; if this
        // fixture never gets there the test would assert nothing, so say so
        // rather than passing vacuously.
        fail('follow badge did not render — fixture cannot prove clipping');
      }

      final parent = tester.getRect(cluster());
      final footprint = tester.getRect(badge);

      // Flutter rejects a hit outside a box BEFORE it reaches the child, and
      // `Clip.none` only affects painting. If the parent were still 58 the
      // badge's enlarged target would be silently clipped back to 27dp, and
      // the standalone widget test could not see it.
      expect(footprint.right, lessThanOrEqualTo(parent.right));
      expect(footprint.bottom, lessThanOrEqualTo(parent.bottom));
      expect(footprint.width, followButtonFootprint);
    });

    testWidgets('the badge semantics node is a 48dp labelled target', (
      tester,
    ) async {
      await pump(tester, alreadyFollowing: false);

      final node = tester.getSemantics(
        find.byWidgetPredicate(
          (widget) =>
              widget is Semantics &&
              widget.properties.identifier == 'follow_button',
        ),
      );

      // Asserted on this node rather than through meetsGuideline over the whole
      // overlay: the video title is still a 66.7x16 tap target, which is the
      // caption sizing left for design, so the overlay as a whole cannot pass
      // the tap-target guideline until that lands. Scoping keeps this test
      // about the badge instead of silently tracking someone else's decision.
      expect(node.rect.width, greaterThanOrEqualTo(48));
      expect(node.rect.height, greaterThanOrEqualTo(48));
      expect(node.label, isNotEmpty);
    });
  });
}
