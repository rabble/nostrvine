// ABOUTME: Widget tests for the comment options modal (delete, flag).
// ABOUTME: Option-row taps and the flag sheet's pinned Submit at large text.

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/screens/comments/widgets/comment_options_modal.dart';
import 'package:openvine/services/content_moderation_types.dart';

void main() {
  group(CommentOptionsModal, () {
    testWidgets('delete option responds when tapping the icon-label gap', (
      tester,
    ) async {
      CommentOptionResult? result;

      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => Scaffold(
              body: Builder(
                builder: (context) {
                  return TextButton(
                    onPressed: () async {
                      result = await CommentOptionsModal.showForOwnComment(
                        context,
                        commentId:
                            'comment0123456789abcdef0123456789abcdef01234567',
                        commentContent: 'test comment',
                      );
                    },
                    child: const Text('Open options'),
                  );
                },
              ),
            ),
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp.router(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      );

      await tester.tap(find.text('Open options'));
      await tester.pumpAndSettle();

      final deleteText = find.text('Delete');
      final deleteIcon = find.byType(SvgPicture).last;
      expect(deleteText, findsOneWidget);
      expect(deleteIcon, findsOneWidget);

      final textRect = tester.getRect(deleteText);
      final iconRect = tester.getRect(deleteIcon);

      await tester.tapAt(
        Offset(
          (iconRect.right + textRect.left) / 2,
          textRect.center.dy,
        ),
      );
      await tester.pumpAndSettle();

      expect(result, isA<CommentDeleteResult>());
    });

    testWidgets(
      'flag content Submit stays pinned and reachable with every reason at '
      'large text scale',
      (tester) async {
        // Reproduces the reported bug: on a phone-height viewport at the 1.35
        // accessibility text scale, the 11 reason tiles + Submit exceed the
        // sheet height. The unfixed sheet did not scroll, clipping Submit
        // off-screen; the fix pins Submit below the scrolling reasons so it
        // stays visible.
        tester.view.physicalSize = const Size(1179, 2556); // iPhone 16 Pro
        tester.view.devicePixelRatio = 3;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        // Capture raw framework errors (e.g. RenderFlex overflow) directly,
        // bypassing the inspector describe-transform that otherwise masks the
        // real error and hangs pumpAndSettle.
        final caughtErrors = <FlutterErrorDetails>[];
        final previousOnError = FlutterError.onError;
        FlutterError.onError = caughtErrors.add;
        addTearDown(() => FlutterError.onError = previousOnError);

        // Flutter's TextPainter asserts `debugSize == size` when a
        // RenderParagraph is scrolled under a non-1.0 textScale in tests — a
        // framework issue, not this widget. Everything else (an overflow in
        // particular) is a real error the fix must prevent.
        List<String> unexpectedErrors() => caughtErrors
            .map((e) => e.exceptionAsString())
            .where((e) => !e.contains('debugSize == size'))
            .toList();

        CommentOptionResult? result;

        final router = GoRouter(
          routes: [
            GoRoute(
              path: '/',
              builder: (context, state) => Scaffold(
                body: Builder(
                  builder: (context) {
                    return TextButton(
                      onPressed: () async {
                        result =
                            await CommentOptionsModal.showForOtherUserIntegrated(
                              context,
                              authorPubkey:
                                  'author0123456789abcdef0123456789abcdef012'
                                  '3456789ab',
                            );
                      },
                      child: const Text('Open options'),
                    );
                  },
                ),
              ),
            ),
          ],
        );

        await tester.pumpWidget(
          MaterialApp.router(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            builder: (context, child) => MediaQuery.withClampedTextScaling(
              minScaleFactor: 1.35,
              maxScaleFactor: 1.35,
              child: child!,
            ),
            routerConfig: router,
          ),
        );

        final l10n = lookupAppLocalizations(const Locale('en'));

        // Bounded pumps rather than pumpAndSettle: an overflow in the sheet
        // would otherwise trigger a Flutter inspector error-describe cascade
        // that never settles, masking the real failure.
        Future<void> settle() async {
          await tester.pump();
          await tester.pump(const Duration(milliseconds: 400));
        }

        await tester.tap(find.text('Open options'));
        await settle();

        // Options sheet -> choose Flag Content.
        await tester.tap(find.text(l10n.commentOptionsFlagContentLabel));
        await settle();

        // Opening the sheet must not overflow — the unfixed sheet clipped
        // Submit off-screen here.
        expect(unexpectedErrors(), isEmpty, reason: 'overflow on sheet open');

        // Submit is pinned: on-screen and hittable before any scroll (the
        // unfixed sheet clipped it off-screen).
        final submit = find.widgetWithText(
          ElevatedButton,
          l10n.commentOptionsFlagSubmit,
        );
        expect(submit, findsOneWidget);
        final viewportHeight =
            tester.view.physicalSize.height / tester.view.devicePixelRatio;
        final submitRect = tester.getRect(submit);
        expect(submitRect.top, greaterThanOrEqualTo(0));
        expect(submitRect.bottom, lessThanOrEqualTo(viewportHeight));

        // The last reason must be reachable by scrolling and must sit above
        // the pinned Submit — never hidden behind it.
        final lastReason = find.text(l10n.reportReasonOther);
        await tester.ensureVisible(lastReason);
        await settle();
        // Submit did not move when the reasons scrolled: it is pinned, not
        // part of the scroll view.
        expect(tester.getRect(submit), submitRect);
        expect(tester.getCenter(lastReason).dy, lessThan(submitRect.top));
        await tester.tap(lastReason);
        await settle();

        // Submit is still pinned; submitting reports the last reason.
        await tester.tap(submit);
        await settle();
        expect(result, isA<CommentReportResult>());
        expect(
          (result! as CommentReportResult).reason,
          ContentFilterReason.other,
        );

        // No real framework error anywhere in the open -> select -> submit
        // -> dismiss flow. The debugSize allowlist is coupled to an
        // SDK-internal string, so also assert the real hazard — an overflow —
        // directly and message-stably.
        expect(
          caughtErrors.where((e) => e.exceptionAsString().contains('overflow')),
          isEmpty,
          reason: 'flag sheet overflowed',
        );
        expect(
          unexpectedErrors(),
          isEmpty,
          reason: 'unexpected framework error',
        );
      },
    );

    testWidgets('flag reason tiles expose selectable button semantics', (
      tester,
    ) async {
      final semanticsHandle = tester.ensureSemantics();

      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () =>
                      CommentOptionsModal.showForOtherUserIntegrated(
                        context,
                        authorPubkey:
                            'author0123456789abcdef0123456789abcdef012'
                            '3456789ab',
                      ),
                  child: const Text('Open options'),
                ),
              ),
            ),
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp.router(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      );

      final l10n = lookupAppLocalizations(const Locale('en'));

      await tester.tap(find.text('Open options'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.commentOptionsFlagContentLabel));
      await tester.pumpAndSettle();

      // Each reason is a labelled, selectable button for screen readers (it
      // was a bare GestureDetector exposing no button role).
      final harassment = find.text(l10n.reportReasonHarassment);
      expect(
        tester.getSemantics(harassment),
        isSemantics(isButton: true, isSelected: false),
      );
      expect(
        tester.getSemantics(harassment).label,
        contains(l10n.reportReasonHarassment),
      );

      semanticsHandle.dispose();
    });

    testWidgets('flag Submit is disabled until a reason is selected', (
      tester,
    ) async {
      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => Scaffold(
              body: Builder(
                builder: (context) => TextButton(
                  onPressed: () =>
                      CommentOptionsModal.showForOtherUserIntegrated(
                        context,
                        authorPubkey:
                            'author0123456789abcdef0123456789abcdef012'
                            '3456789ab',
                      ),
                  child: const Text('Open options'),
                ),
              ),
            ),
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp.router(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          routerConfig: router,
        ),
      );

      final l10n = lookupAppLocalizations(const Locale('en'));

      await tester.tap(find.text('Open options'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(l10n.commentOptionsFlagContentLabel));
      await tester.pumpAndSettle();

      final submit = find.widgetWithText(
        ElevatedButton,
        l10n.commentOptionsFlagSubmit,
      );

      // Submit is disabled (onPressed null) until a reason is chosen.
      expect(tester.widget<ElevatedButton>(submit).onPressed, isNull);

      // Choosing a reason enables it.
      await tester.tap(find.text(l10n.reportReasonHarassment));
      await tester.pumpAndSettle();
      expect(tester.widget<ElevatedButton>(submit).onPressed, isNotNull);
    });
  });
}
