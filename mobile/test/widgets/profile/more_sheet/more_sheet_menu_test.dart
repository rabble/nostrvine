// ABOUTME: Widget tests for MoreSheetMenu — verifies which actions render
// ABOUTME: based on follow / block state and the optional add-to-list/report flags.

import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/widgets/profile/more_sheet/more_sheet_menu.dart';

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));
  const displayName = 'Alice';

  Widget buildSubject({
    bool isFollowing = false,
    bool isBlocked = false,
    VoidCallback? onAddToList,
    VoidCallback? onReport,
    VoidCallback? onCopy,
    VoidCallback? onUnfollow,
    VoidCallback? onBlockTap,
  }) {
    return MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(
        body: MoreSheetMenu(
          displayName: displayName,
          isFollowing: isFollowing,
          isBlocked: isBlocked,
          onCopy: onCopy ?? () {},
          onUnfollow: onUnfollow ?? () {},
          onBlockTap: onBlockTap ?? () {},
          onAddToList: onAddToList,
          onReport: onReport,
        ),
      ),
    );
  }

  group(MoreSheetMenu, () {
    testWidgets('renders copy and block actions in default state', (
      tester,
    ) async {
      await tester.pumpWidget(buildSubject());

      expect(find.text(l10n.profileCopyPublicKey), findsOneWidget);
      expect(
        find.text(l10n.profileBlockDisplayName(displayName)),
        findsOneWidget,
      );
    });

    testWidgets('hides Unfollow when not following', (tester) async {
      await tester.pumpWidget(buildSubject());

      expect(
        find.text(l10n.profileUnfollowDisplayName(displayName)),
        findsNothing,
      );
    });

    testWidgets('renders Unfollow when following', (tester) async {
      await tester.pumpWidget(buildSubject(isFollowing: true));

      expect(
        find.text(l10n.profileUnfollowDisplayName(displayName)),
        findsOneWidget,
      );
    });

    testWidgets('renders Unblock label when blocked', (tester) async {
      await tester.pumpWidget(buildSubject(isBlocked: true));

      expect(
        find.text(l10n.profileUnblockDisplayName(displayName)),
        findsOneWidget,
      );
      expect(
        find.text(l10n.profileBlockDisplayName(displayName)),
        findsNothing,
      );
    });

    testWidgets('hides Report when onReport is null', (tester) async {
      await tester.pumpWidget(buildSubject());

      expect(
        find.text(l10n.profileReportDisplayName(displayName)),
        findsNothing,
      );
    });

    testWidgets('renders Report when onReport is provided', (tester) async {
      await tester.pumpWidget(buildSubject(onReport: () {}));

      expect(
        find.text(l10n.profileReportDisplayName(displayName)),
        findsOneWidget,
      );
    });

    testWidgets('tapping Report invokes onReport', (tester) async {
      var tapped = 0;
      await tester.pumpWidget(buildSubject(onReport: () => tapped++));

      await tester.tap(find.text(l10n.profileReportDisplayName(displayName)));
      await tester.pumpAndSettle();

      expect(tapped, equals(1));
    });

    testWidgets('Report action exposes button semantics', (tester) async {
      final semantics = tester.ensureSemantics();

      await tester.pumpWidget(buildSubject(onReport: () {}));

      final reportFinder = find.bySemanticsLabel(
        l10n.profileReportDisplayName(displayName),
      );
      expect(reportFinder, findsOneWidget);
      final semanticsNode = tester.getSemantics(reportFinder);
      final semanticsData = semanticsNode.getSemanticsData();
      expect(
        semanticsNode.label,
        equals(l10n.profileReportDisplayName(displayName)),
      );
      expect(semanticsData.flagsCollection.isButton, isTrue);
      expect(semanticsData.hasAction(ui.SemanticsAction.tap), isTrue);
      semantics.dispose();
    });

    testWidgets('hides Add to list when onAddToList is null', (tester) async {
      await tester.pumpWidget(buildSubject());

      expect(
        find.text(l10n.profileAddToListDisplayName(displayName)),
        findsNothing,
      );
    });

    testWidgets(
      'renders Add to list, Copy, Report, and Block when all enabled',
      (tester) async {
        await tester.pumpWidget(
          buildSubject(onAddToList: () {}, onReport: () {}),
        );

        expect(
          find.text(l10n.profileAddToListDisplayName(displayName)),
          findsOneWidget,
        );
        expect(find.text(l10n.profileCopyPublicKey), findsOneWidget);
        expect(
          find.text(l10n.profileReportDisplayName(displayName)),
          findsOneWidget,
        );
        expect(
          find.text(l10n.profileBlockDisplayName(displayName)),
          findsOneWidget,
        );
      },
    );
  });
}
