// ABOUTME: Regression test for #3503 — verifies that the BlocProvider for
// VideoInteractionsBloc on a pooled feed item recreates its bloc when any
// of the three repository providers (likes, comments, reposts) is rebuilt.
//
// The production sites mirror this pattern at:
//   - mobile/lib/screens/feed/video_feed_page.dart (_PooledVideoFeedItem,
//     _WebVideoFeedItem)
//   - mobile/lib/screens/feed/pooled_fullscreen_video_feed_screen.dart
//     (_PooledFullscreenItem, _WebFullscreenItem)
// Each does `ref.watch(...)` on the three repos and gates the BlocProvider
// with a composite ValueKey of the three identity hashes. When any
// provider rebuilds (auth flip / sign-out / account switch), the key
// changes, the stale bloc is closed, and a fresh one wraps the new repos.

@Tags(['skip_very_good_optimization'])
import 'package:comments_repository/comments_repository.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/legacy.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:likes_repository/likes_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/video_interactions/video_interactions_bloc.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:reposts_repository/reposts_repository.dart';

class _MockLikesRepository extends Mock implements LikesRepository {}

class _MockCommentsRepository extends Mock implements CommentsRepository {}

class _MockRepostsRepository extends Mock implements RepostsRepository {}

/// Mirror of the production BlocProvider pattern from `_PooledVideoFeedItem`
/// in `mobile/lib/screens/feed/video_feed_page.dart`. Kept in this test
/// file because the production widget is private; reviewers should verify
/// this fixture stays in sync with the four production call sites.
class _Fixture extends ConsumerWidget {
  const _Fixture();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final likesRepository = ref.watch(likesRepositoryProvider);
    final commentsRepository = ref.watch(commentsRepositoryProvider);
    final repostsRepository = ref.watch(repostsRepositoryProvider);

    return BlocProvider<VideoInteractionsBloc>(
      key: ValueKey(
        Object.hash(
          identityHashCode(likesRepository),
          identityHashCode(commentsRepository),
          identityHashCode(repostsRepository),
        ),
      ),
      create: (_) =>
          VideoInteractionsBloc(
              eventId: 'test-event',
              authorPubkey: 'test-pubkey',
              likesRepository: likesRepository,
              commentsRepository: commentsRepository,
              repostsRepository: repostsRepository,
            )
            ..add(const VideoInteractionsSubscriptionRequested())
            ..add(const VideoInteractionsFetchRequested()),
      child: const _Probe(),
    );
  }
}

class _Probe extends StatelessWidget {
  const _Probe();

  @override
  Widget build(BuildContext context) => const SizedBox.shrink();
}

/// Toggle a `StateProvider<int>` to force `likesRepositoryProvider` to
/// rebuild and return a different mock — mirrors what happens in
/// production when auth flips (the real provider also rebuilds and
/// returns a fresh repository instance).
final _likesRepoSwap = StateProvider<int>((ref) => 0);

void main() {
  group('Pooled video feed item — BlocProvider repo-swap (#3503)', () {
    late _MockLikesRepository mockLikesA;
    late _MockLikesRepository mockLikesB;
    late _MockCommentsRepository mockComments;
    late _MockRepostsRepository mockReposts;

    setUp(() {
      mockLikesA = _MockLikesRepository();
      mockLikesB = _MockLikesRepository();
      mockComments = _MockCommentsRepository();
      mockReposts = _MockRepostsRepository();

      // VideoInteractionsBloc subscribes to these on construction
      // (VideoInteractionsSubscriptionRequested) and fetches counts
      // (VideoInteractionsFetchRequested). Stub them on both mocks so the
      // bloc can run without throwing during the test.
      when(
        mockLikesA.watchLikedEventIds,
      ).thenAnswer((_) => const Stream<List<String>>.empty());
      when(
        mockLikesB.watchLikedEventIds,
      ).thenAnswer((_) => const Stream<List<String>>.empty());
      when(() => mockLikesA.isLiked(any())).thenAnswer((_) async => false);
      when(() => mockLikesB.isLiked(any())).thenAnswer((_) async => false);
      when(
        () => mockLikesA.getLikeCount(
          any(),
          addressableId: any(named: 'addressableId'),
        ),
      ).thenAnswer((_) async => 0);
      when(
        () => mockLikesB.getLikeCount(
          any(),
          addressableId: any(named: 'addressableId'),
        ),
      ).thenAnswer((_) async => 0);
      when(
        mockReposts.watchRepostedAddressableIds,
      ).thenAnswer((_) => const Stream<Set<String>>.empty());
      when(
        () => mockReposts.getRepostCountByEventId(any()),
      ).thenAnswer((_) async => 0);
      when(
        () => mockComments.getCommentsCount(
          any(),
          rootAddressableId: any(named: 'rootAddressableId'),
        ),
      ).thenAnswer((_) async => 0);
    });

    testWidgets(
      'swaps VideoInteractionsBloc when likesRepositoryProvider rebuilds',
      (tester) async {
        final container = ProviderContainer(
          overrides: [
            likesRepositoryProvider.overrideWith((ref) {
              final v = ref.watch(_likesRepoSwap);
              return v == 0 ? mockLikesA : mockLikesB;
            }),
            commentsRepositoryProvider.overrideWith((_) => mockComments),
            repostsRepositoryProvider.overrideWith((_) => mockReposts),
          ],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(home: _Fixture()),
          ),
        );

        // Capture the bloc that was created when the fixture first built.
        final probeContext = tester.element(find.byType(_Probe));
        final blocA = BlocProvider.of<VideoInteractionsBloc>(probeContext);
        expect(
          blocA.isClosed,
          isFalse,
          reason: 'initial bloc should be alive',
        );

        // Flip the toggle. likesRepositoryProvider rebuilds, _Fixture's
        // watch fires, the composite ValueKey changes, BlocProvider
        // unmounts blocA and creates a new bloc wrapping mockLikesB.
        container.read(_likesRepoSwap.notifier).state = 1;
        await tester.pump();

        final probeContextAfter = tester.element(find.byType(_Probe));
        final blocB = BlocProvider.of<VideoInteractionsBloc>(probeContextAfter);

        expect(
          blocB,
          isNot(same(blocA)),
          reason:
              'BlocProvider should create a new bloc when the composite '
              'repo key changes — without this fix, the first feed items '
              'snapshot a stale repository at cold launch and like '
              'attempts throw `Bad state: No public key available`',
        );
        // (Cleanup of the old bloc is handled by BlocProvider.dispose →
        // bloc.close(); not asserted here because the close future is not
        // awaited in dispose and pumping it through reliably in widget
        // tests adds fragility for no extra guarantee.)
      },
    );

    testWidgets(
      'preserves the same VideoInteractionsBloc when no repo identity changes',
      (tester) async {
        final container = ProviderContainer(
          overrides: [
            likesRepositoryProvider.overrideWith((ref) {
              ref.watch(_likesRepoSwap);
              return mockLikesA;
            }),
            commentsRepositoryProvider.overrideWith((_) => mockComments),
            repostsRepositoryProvider.overrideWith((_) => mockReposts),
          ],
        );
        addTearDown(container.dispose);

        await tester.pumpWidget(
          UncontrolledProviderScope(
            container: container,
            child: const MaterialApp(home: _Fixture()),
          ),
        );

        final blocA = BlocProvider.of<VideoInteractionsBloc>(
          tester.element(find.byType(_Probe)),
        );

        // Force the override to re-run, but keep returning the same mock
        // — the composite key (built from identity hashes) must stay the
        // same, so BlocProvider keeps the same bloc.
        container.read(_likesRepoSwap.notifier).state = 1;
        await tester.pump();

        final blocAfter = BlocProvider.of<VideoInteractionsBloc>(
          tester.element(find.byType(_Probe)),
        );

        expect(
          blocAfter,
          same(blocA),
          reason:
              'identical repo identities should keep the same bloc — '
              'the composite key prevents unnecessary churn on rebuilds',
        );
      },
    );
  });
}
