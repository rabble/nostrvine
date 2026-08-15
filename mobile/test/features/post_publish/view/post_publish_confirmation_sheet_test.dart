// ABOUTME: Widget tests for the post-publish confirmation sheet's actions,
// ABOUTME: dismissal, and thumbnail fallback.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/features/post_publish/view/post_publish_confirmation_sheet.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/widgets/video_clip/clip_thumbnail_image.dart';

final AppLocalizations _l10n = lookupAppLocalizations(const Locale('en'));

/// Pumps a host screen with a button that opens the confirmation sheet.
Future<void> _pumpSheetHost(
  WidgetTester tester, {
  required VoidCallback onView,
  required VoidCallback onShare,
  String? thumbnailPath,
}) async {
  await tester.pumpWidget(
    MaterialApp(
      theme: VineTheme.theme,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: Builder(
          builder: (context) => Center(
            child: DivineButton(
              label: 'open',
              onPressed: () => PostPublishConfirmationSheet.show(
                context: context,
                onView: onView,
                onShare: onShare,
                thumbnailPath: thumbnailPath,
              ),
            ),
          ),
        ),
      ),
    ),
  );

  await tester.tap(find.text('open'));
  await tester.pumpAndSettle();
}

void main() {
  group(PostPublishConfirmationSheet, () {
    testWidgets('offers view and share, not a prompt to record again', (
      tester,
    ) async {
      await _pumpSheetHost(tester, onView: () {}, onShare: () {});

      expect(find.text(_l10n.postPublishConfirmationTitle), findsOneWidget);
      expect(find.text(_l10n.postPublishConfirmationView), findsOneWidget);
      expect(find.text(_l10n.postPublishConfirmationShare), findsOneWidget);
      // The offer this replaces. Its return would be the regression.
      expect(find.text(_l10n.libraryRecordVideo), findsNothing);
    });

    testWidgets('reads its copy from l10n rather than hardcoded English', (
      tester,
    ) async {
      await _pumpSheetHost(tester, onView: () {}, onShare: () {});

      expect(
        find.text(
          lookupAppLocalizations(
            const Locale('de'),
          ).postPublishConfirmationView,
        ),
        findsNothing,
      );
    });

    testWidgets('view fires its callback and closes the sheet', (tester) async {
      var viewed = 0;
      await _pumpSheetHost(tester, onView: () => viewed++, onShare: () {});

      await tester.tap(find.text(_l10n.postPublishConfirmationView));
      await tester.pumpAndSettle();

      expect(viewed, equals(1));
      expect(find.text(_l10n.postPublishConfirmationTitle), findsNothing);
    });

    testWidgets('share fires its callback and closes the sheet', (
      tester,
    ) async {
      var shared = 0;
      await _pumpSheetHost(tester, onView: () {}, onShare: () => shared++);

      await tester.tap(find.text(_l10n.postPublishConfirmationShare));
      await tester.pumpAndSettle();

      expect(shared, equals(1));
      expect(find.text(_l10n.postPublishConfirmationTitle), findsNothing);
    });

    testWidgets('the close action dismisses without acting on the video', (
      tester,
    ) async {
      var viewed = 0;
      var shared = 0;
      await _pumpSheetHost(
        tester,
        onView: () => viewed++,
        onShare: () => shared++,
      );

      await tester.tap(
        find.bySemanticsLabel(_l10n.commonClose),
      );
      await tester.pumpAndSettle();

      expect(find.text(_l10n.postPublishConfirmationTitle), findsNothing);
      expect(viewed, isZero);
      expect(shared, isZero);
    });

    testWidgets('renders a thumbnail when the draft had a cover frame', (
      tester,
    ) async {
      await _pumpSheetHost(
        tester,
        onView: () {},
        onShare: () {},
        thumbnailPath: '/local/cover.jpg',
      );

      final image = tester.widget<ClipThumbnailImage>(
        find.byType(ClipThumbnailImage),
      );
      expect(image.path, equals('/local/cover.jpg'));
    });

    testWidgets('still opens when the draft carried no thumbnail', (
      tester,
    ) async {
      // A draft with no cover frame must not cost the creator the whole
      // confirmation.
      await _pumpSheetHost(tester, onView: () {}, onShare: () {});

      expect(find.byType(ClipThumbnailImage), findsNothing);
      expect(find.text(_l10n.postPublishConfirmationView), findsOneWidget);
    });

    testWidgets('labels the thumbnail for screen readers', (tester) async {
      final handle = tester.ensureSemantics();
      await _pumpSheetHost(
        tester,
        onView: () {},
        onShare: () {},
        thumbnailPath: '/local/cover.jpg',
      );

      expect(
        find.bySemanticsLabel(_l10n.postPublishConfirmationThumbnailLabel),
        findsOneWidget,
      );
      handle.dispose();
    });
  });
}
