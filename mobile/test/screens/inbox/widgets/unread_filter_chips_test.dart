// ABOUTME: Widget tests for UnreadFilterChips.
// ABOUTME: Verifies chip labels render and taps report the new filter value.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/screens/inbox/widgets/unread_filter_chips.dart';

void main() {
  group(UnreadFilterChips, () {
    Widget buildSubject({
      required bool unreadOnly,
      required ValueChanged<bool> onUnreadOnlyChanged,
    }) {
      return MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          body: UnreadFilterChips(
            unreadOnly: unreadOnly,
            onUnreadOnlyChanged: onUnreadOnlyChanged,
          ),
        ),
      );
    }

    testWidgets('renders All and Unread chips', (tester) async {
      await tester.pumpWidget(
        buildSubject(unreadOnly: false, onUnreadOnlyChanged: (_) {}),
      );

      final l10n = lookupAppLocalizations(const Locale('en'));
      expect(find.text(l10n.inboxFilterAll), findsOneWidget);
      expect(find.text(l10n.inboxFilterUnread), findsOneWidget);
    });

    testWidgets('tapping Unread reports true', (tester) async {
      bool? reported;
      await tester.pumpWidget(
        buildSubject(
          unreadOnly: false,
          onUnreadOnlyChanged: (value) => reported = value,
        ),
      );

      final l10n = lookupAppLocalizations(const Locale('en'));
      await tester.tap(find.text(l10n.inboxFilterUnread));
      await tester.pump();

      expect(reported, isTrue);
    });

    testWidgets('tapping All reports false', (tester) async {
      bool? reported;
      await tester.pumpWidget(
        buildSubject(
          unreadOnly: true,
          onUnreadOnlyChanged: (value) => reported = value,
        ),
      );

      final l10n = lookupAppLocalizations(const Locale('en'));
      await tester.tap(find.text(l10n.inboxFilterAll));
      await tester.pump();

      expect(reported, isFalse);
    });
  });
}
