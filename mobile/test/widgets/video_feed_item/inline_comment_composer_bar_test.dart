// ABOUTME: Widget tests for InlineCommentComposerBar — the bottom-of-screen
// ABOUTME: comment field used by the fullscreen video player on
// ABOUTME: Explore / Search / Profile entry points.

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/fullscreen_feed/fullscreen_feed_bloc.dart';
import 'package:openvine/blocs/inline_comment_composer/inline_comment_composer_cubit.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/widgets/video_feed_item/inline_comment_composer_bar.dart';

class _MockFullscreenFeedBloc
    extends MockBloc<FullscreenFeedEvent, FullscreenFeedState>
    implements FullscreenFeedBloc {}

class _MockInlineCommentComposerCubit
    extends MockCubit<InlineCommentComposerState>
    implements InlineCommentComposerCubit {}

void main() {
  group(InlineCommentComposerBar, () {
    late _MockFullscreenFeedBloc fullscreenBloc;
    late _MockInlineCommentComposerCubit composerCubit;

    VideoEvent buildVideo() {
      final now = DateTime.now();
      return VideoEvent(
        id: 'video-id',
        pubkey: 'author-pubkey',
        createdAt: now.millisecondsSinceEpoch ~/ 1000,
        timestamp: now,
        content: 'caption',
        videoUrl: 'https://example.com/v.mp4',
      );
    }

    FullscreenFeedState stateWithVideo(VideoEvent video) {
      return FullscreenFeedState(
        status: FullscreenFeedStatus.ready,
        videos: [video],
      );
    }

    setUpAll(() {
      registerFallbackValue(buildVideo());
    });

    setUp(() {
      fullscreenBloc = _MockFullscreenFeedBloc();
      composerCubit = _MockInlineCommentComposerCubit();

      when(
        () => fullscreenBloc.state,
      ).thenReturn(stateWithVideo(buildVideo()));
      when(
        () => composerCubit.state,
      ).thenReturn(const InlineCommentComposerState());
    });

    tearDown(() {
      fullscreenBloc.close();
      composerCubit.close();
    });

    Widget buildBar() {
      return MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: MultiBlocProvider(
            providers: [
              BlocProvider<FullscreenFeedBloc>.value(value: fullscreenBloc),
              BlocProvider<InlineCommentComposerCubit>.value(
                value: composerCubit,
              ),
            ],
            child: const Align(
              alignment: Alignment.bottomCenter,
              child: InlineCommentComposerBar(),
            ),
          ),
        ),
      );
    }

    testWidgets('renders the "Add comment..." hint', (tester) async {
      await tester.pumpWidget(buildBar());

      final l10n = lookupAppLocalizations(const Locale('en'));
      expect(find.text(l10n.videoOverlayCommentBarHint), findsOneWidget);
    });

    testWidgets('hides the send button when the field is empty', (
      tester,
    ) async {
      await tester.pumpWidget(buildBar());

      expect(
        find.bySemanticsIdentifier('inline_comment_composer_send_button'),
        findsNothing,
      );
    });

    testWidgets('shows the send button once the user types text', (
      tester,
    ) async {
      await tester.pumpWidget(buildBar());

      await tester.enterText(
        find.bySemanticsIdentifier('inline_comment_composer_field'),
        'hello',
      );
      await tester.pump();

      expect(
        find.bySemanticsIdentifier('inline_comment_composer_send_button'),
        findsOneWidget,
      );
    });

    testWidgets(
      'configures the field to grow from 1 to 5 lines on long input, '
      'matching the comments-sheet composer',
      (tester) async {
        await tester.pumpWidget(buildBar());

        final field = tester.widget<TextField>(
          find.descendant(
            of: find.bySemanticsIdentifier('inline_comment_composer_field'),
            matching: find.byType(TextField),
          ),
        );

        expect(field.minLines, 1);
        expect(field.maxLines, 5);
        expect(field.keyboardType, TextInputType.multiline);
      },
    );

    testWidgets(
      'still hides the send button when the field only has whitespace',
      (tester) async {
        await tester.pumpWidget(buildBar());

        await tester.enterText(
          find.bySemanticsIdentifier('inline_comment_composer_field'),
          '   \n  ',
        );
        await tester.pump();

        expect(
          find.bySemanticsIdentifier('inline_comment_composer_send_button'),
          findsNothing,
        );
      },
    );

    testWidgets(
      'tapping send forwards the text + active video to the cubit and '
      'clears the field',
      (tester) async {
        final activeVideo = buildVideo();
        when(
          () => fullscreenBloc.state,
        ).thenReturn(stateWithVideo(activeVideo));
        when(
          () => composerCubit.submit(
            video: any(named: 'video'),
            content: any(named: 'content'),
          ),
        ).thenAnswer((_) async {});

        await tester.pumpWidget(buildBar());
        await tester.enterText(
          find.bySemanticsIdentifier('inline_comment_composer_field'),
          'great video!',
        );
        await tester.pump();
        await tester.tap(
          find.bySemanticsIdentifier('inline_comment_composer_send_button'),
        );
        await tester.pump();

        verify(
          () => composerCubit.submit(
            video: activeVideo,
            content: 'great video!',
          ),
        ).called(1);

        // Field is cleared after submit so the send affordance disappears.
        expect(
          find.bySemanticsIdentifier('inline_comment_composer_send_button'),
          findsNothing,
        );
      },
    );

    testWidgets(
      'submitting via the keyboard send action triggers the cubit',
      (tester) async {
        when(
          () => composerCubit.submit(
            video: any(named: 'video'),
            content: any(named: 'content'),
          ),
        ).thenAnswer((_) async {});

        await tester.pumpWidget(buildBar());
        await tester.enterText(
          find.bySemanticsIdentifier('inline_comment_composer_field'),
          'hi',
        );
        await tester.testTextInput.receiveAction(TextInputAction.send);
        await tester.pump();

        verify(
          () => composerCubit.submit(
            video: any(named: 'video'),
            content: 'hi',
          ),
        ).called(1);
      },
    );

    testWidgets(
      'shows the success snackbar when the cubit emits submitted',
      (tester) async {
        whenListen<InlineCommentComposerState>(
          composerCubit,
          Stream.fromIterable(const [
            InlineCommentComposerState(
              status: InlineCommentComposerStatus.submitting,
            ),
            InlineCommentComposerState(
              status: InlineCommentComposerStatus.submitted,
            ),
          ]),
          initialState: const InlineCommentComposerState(),
        );

        await tester.pumpWidget(buildBar());
        await tester.pump();
        // Allow the snackbar entrance animation to settle.
        await tester.pump(const Duration(seconds: 1));

        final l10n = lookupAppLocalizations(const Locale('en'));
        expect(
          find.text(l10n.videoOverlayCommentPostedSnackbar),
          findsOneWidget,
        );
        verify(() => composerCubit.acknowledge()).called(1);
      },
    );

    testWidgets(
      'shows the failure snackbar when the cubit emits failure',
      (tester) async {
        whenListen<InlineCommentComposerState>(
          composerCubit,
          Stream.fromIterable(const [
            InlineCommentComposerState(
              status: InlineCommentComposerStatus.submitting,
            ),
            InlineCommentComposerState(
              status: InlineCommentComposerStatus.failure,
            ),
          ]),
          initialState: const InlineCommentComposerState(),
        );

        await tester.pumpWidget(buildBar());
        await tester.pump();
        await tester.pump(const Duration(seconds: 1));

        final l10n = lookupAppLocalizations(const Locale('en'));
        expect(
          find.text(l10n.videoOverlayCommentPostFailedSnackbar),
          findsOneWidget,
        );
        verify(() => composerCubit.acknowledge()).called(1);
      },
    );

    testWidgets('does nothing on send when there is no active video', (
      tester,
    ) async {
      when(
        () => fullscreenBloc.state,
      ).thenReturn(const FullscreenFeedState());

      await tester.pumpWidget(buildBar());
      await tester.enterText(
        find.bySemanticsIdentifier('inline_comment_composer_field'),
        'orphan',
      );
      await tester.pump();
      await tester.tap(
        find.bySemanticsIdentifier('inline_comment_composer_send_button'),
      );
      await tester.pump();

      verifyNever(
        () => composerCubit.submit(
          video: any(named: 'video'),
          content: any(named: 'content'),
        ),
      );
    });
  });
}
