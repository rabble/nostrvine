// ABOUTME: Widget tests for CommentItem with the split CommentComposerBloc +
// ABOUTME: CommentReactionsBloc provider tree.

import 'package:bloc_test/bloc_test.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:openvine/blocs/comments/comment_composer/comment_composer_bloc.dart';
import 'package:openvine/blocs/comments/comment_reactions/comment_reactions_bloc.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/providers/nostr_client_provider.dart';
import 'package:openvine/screens/comments/widgets/comment_item.dart';
import 'package:openvine/screens/comments/widgets/video_comment_player.dart';
import 'package:openvine/screens/video_detail_screen.dart';
import 'package:openvine/utils/nostr_key_utils.dart';
import 'package:openvine/widgets/linkified_text/linkified_text_widgets.dart';
import 'package:visibility_detector/visibility_detector.dart';

import '../../builders/comment_builder.dart';

class _FakeNostrClient implements NostrClient {
  const _FakeNostrClient();

  @override
  String get publicKey => '';

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

class _MockComposerBloc
    extends MockBloc<CommentComposerEvent, CommentComposerState>
    implements CommentComposerBloc {}

class _MockReactionsBloc
    extends MockBloc<CommentReactionsEvent, CommentReactionsState>
    implements CommentReactionsBloc {}

const _testHexPubkey =
    '0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef';
const _testRootEventId =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const _testRootAuthorPubkey =
    'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';

void main() {
  setUpAll(() {
    VisibilityDetectorController.instance.updateInterval = Duration.zero;
    registerFallbackValue(const CommentReplyToggled(''));
    registerFallbackValue(
      const CommentReactionsErrorCleared(),
    );
  });

  ({_MockComposerBloc composer, _MockReactionsBloc reactions}) buildMocks() {
    final composer = _MockComposerBloc();
    final reactions = _MockReactionsBloc();
    when(() => composer.state).thenReturn(const CommentComposerState());
    when(() => reactions.state).thenReturn(const CommentReactionsState());
    return (composer: composer, reactions: reactions);
  }

  Widget buildTestWidget(
    String content, {
    required _MockComposerBloc composerBloc,
    required _MockReactionsBloc reactionsBloc,
  }) {
    final comment = CommentBuilder()
        .withAuthorPubkey(_testHexPubkey)
        .withRootEventId(_testRootEventId)
        .withRootAuthorPubkey(_testRootAuthorPubkey)
        .withContent(content)
        .build();

    return ProviderScope(
      overrides: [
        nostrServiceProvider.overrideWithValue(const _FakeNostrClient()),
      ],
      child: MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: MultiBlocProvider(
            providers: [
              BlocProvider<CommentComposerBloc>.value(value: composerBloc),
              BlocProvider<CommentReactionsBloc>.value(value: reactionsBloc),
            ],
            child: SingleChildScrollView(child: CommentItem(comment: comment)),
          ),
        ),
      ),
    );
  }

  Text contentText(WidgetTester tester) {
    return tester.widget<Text>(
      find.descendant(
        of: find.byType(LinkifiedText),
        matching: find.byType(Text),
      ),
    );
  }

  testWidgets('renders bare npub mentions as interactive profile links', (
    tester,
  ) async {
    final mocks = buildMocks();
    final npub = NostrKeyUtils.encodePubKey(_testHexPubkey);

    await tester.pumpWidget(
      buildTestWidget(
        'My account is $npub',
        composerBloc: mocks.composer,
        reactionsBloc: mocks.reactions,
      ),
    );
    await tester.pump();

    expect(find.byType(LinkifiedText), findsOneWidget);
    final fallbackName = UserProfile.defaultDisplayNameFor(_testHexPubkey);
    expect(find.textContaining('@$fallbackName'), findsOneWidget);
  });

  testWidgets('renders comment urls with tappable spans', (tester) async {
    final mocks = buildMocks();

    await tester.pumpWidget(
      buildTestWidget(
        'checkout https://divine.video/leaderboard',
        composerBloc: mocks.composer,
        reactionsBloc: mocks.reactions,
      ),
    );
    await tester.pump();

    expect(find.byType(LinkifiedText), findsOneWidget);

    final text = contentText(tester);
    final textSpan = text.textSpan! as TextSpan;
    final spans = textSpan.children!.cast<TextSpan>();
    final linkSpan = spans.firstWhere(
      (span) => span.text == 'https://divine.video/leaderboard',
    );

    expect(linkSpan.recognizer, isA<TapGestureRecognizer>());
  });

  testWidgets('opens video comments with hydrated route data', (tester) async {
    final mocks = buildMocks();

    final comment = CommentBuilder()
        .withId(
          '232cc79d5c91b01d538b2111df380b521f8a927fa52de3844b5feac7aff40c2f',
        )
        .withAuthorPubkey(_testHexPubkey)
        .withRootEventId(_testRootEventId)
        .withRootAuthorPubkey(_testRootAuthorPubkey)
        .withContent('Ferns')
        .build()
        .copyWith(
          videoUrl:
              'https://media.divine.video/6ab6f26428369761ff7fda84166f5dc4981d93d43370c30171d74b036286b020',
          thumbnailUrl:
              'https://media.divine.video/748855341e45388bc6a2aeacccc68161b8da4a817b11b1e7527423582ec6d42b',
          videoDimensions: '1080x1920',
          videoDuration: 6,
          videoBlurhash:
              'vjIOqbD%t7M{~q%MM{WA?bWBWBt7t8Rjt7ofV[j@ayt7RjoffQWBogWAofay',
        );

    VideoDetailRouteExtra? capturedExtra;
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => Scaffold(
            body: MultiBlocProvider(
              providers: [
                BlocProvider<CommentComposerBloc>.value(value: mocks.composer),
                BlocProvider<CommentReactionsBloc>.value(
                  value: mocks.reactions,
                ),
              ],
              child: SingleChildScrollView(
                child: CommentItem(comment: comment),
              ),
            ),
          ),
        ),
        GoRoute(
          path: VideoDetailScreen.path,
          builder: (context, state) {
            capturedExtra = state.extra as VideoDetailRouteExtra?;
            return const Scaffold(body: Text('video route'));
          },
        ),
      ],
    );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          nostrServiceProvider.overrideWithValue(const _FakeNostrClient()),
        ],
        child: MaterialApp.router(
          routerConfig: router,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
        ),
      ),
    );
    await tester.pump();

    await tester.tap(find.bySemanticsLabel('Open video comment'));
    await tester.pumpAndSettle();

    expect(find.text('video route'), findsOneWidget);
    expect(capturedExtra?.initialVideo, isA<VideoEvent>());
    expect(capturedExtra?.initialVideo?.id, comment.id);
    expect(capturedExtra?.initialVideo?.videoUrl, comment.videoUrl);
    expect(capturedExtra?.initialVideo?.thumbnailUrl, comment.thumbnailUrl);
    expect(capturedExtra?.initialVideo?.title, comment.content);
    expect(capturedExtra?.initialVideo?.isVideoReply, isTrue);
    expect(capturedExtra?.initialVideo?.replyRootRouteId, _testRootEventId);
  });

  testWidgets('wraps the inline video player with rounded corners', (
    tester,
  ) async {
    final mocks = buildMocks();
    final comment = CommentBuilder()
        .withAuthorPubkey(_testHexPubkey)
        .withRootEventId(_testRootEventId)
        .withRootAuthorPubkey(_testRootAuthorPubkey)
        .withContent('Ferns')
        .build()
        .copyWith(
          videoUrl: 'https://media.divine.video/some-video.mp4',
          thumbnailUrl: 'https://media.divine.video/some-thumb.jpg',
          videoDimensions: '1080x1920',
          videoDuration: 6,
        );

    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          nostrServiceProvider.overrideWithValue(const _FakeNostrClient()),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: MultiBlocProvider(
              providers: [
                BlocProvider<CommentComposerBloc>.value(value: mocks.composer),
                BlocProvider<CommentReactionsBloc>.value(
                  value: mocks.reactions,
                ),
              ],
              child: SingleChildScrollView(
                child: CommentItem(comment: comment),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pump();

    final player = tester.widget<VideoCommentPlayer>(
      find.byType(VideoCommentPlayer),
    );
    expect(player.borderRadius, BorderRadius.circular(12));

    // Drain VisibilityDetector's 500ms debounce and the identity skeleton's
    // 7s fallthrough so no pending timers leak into the next test.
    await tester.pump(const Duration(seconds: 8));
    await tester.pumpAndSettle();
  });

  group('Identity skeleton (#4163 follow-up)', () {
    testWidgets(
      'wraps the author row in IdentitySkeletonizer with isLoading=true '
      'while the profile has not resolved',
      (tester) async {
        final mocks = buildMocks();

        await tester.pumpWidget(
          buildTestWidget(
            'hello',
            composerBloc: mocks.composer,
            reactionsBloc: mocks.reactions,
          ),
        );
        await tester.pump();

        final skeletonizer = tester.widget<IdentitySkeletonizer>(
          find.byType(IdentitySkeletonizer),
        );
        expect(
          skeletonizer.isLoading,
          isTrue,
          reason:
              'profile is null → IdentitySkeletonizer.isLoading should be true',
        );

        expect(
          find.text(UserProfile.generatedNameFor(_testHexPubkey)),
          findsOneWidget,
        );

        // Past the 7s fallthrough — let the timer fire and the switch
        // animation settle so no pending timers leak into the next test.
        await tester.pump(const Duration(seconds: 8));
        await tester.pumpAndSettle();
      },
    );
  });
}
