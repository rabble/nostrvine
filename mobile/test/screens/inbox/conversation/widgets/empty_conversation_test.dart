import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/screens/inbox/conversation/widgets/empty_conversation.dart';
import 'package:openvine/widgets/user_avatar.dart';

void main() {
  group(EmptyConversation, () {
    group('renders', () {
      testWidgets('renders $UserAvatar', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: EmptyConversation(displayName: 'Bob', onViewProfile: () {}),
            ),
          ),
        );

        expect(find.byType(UserAvatar), findsOneWidget);
      });

      testWidgets('renders display name', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: EmptyConversation(displayName: 'Bob', onViewProfile: () {}),
            ),
          ),
        );

        expect(find.text('Bob'), findsOneWidget);
      });

      testWidgets('renders nip05 when provided', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: EmptyConversation(
                displayName: 'Bob',
                nip05: 'bob@example.com',
                onViewProfile: () {},
              ),
            ),
          ),
        );

        expect(find.text('bob@example.com'), findsOneWidget);
      });

      testWidgets('does not render nip05 when null', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: EmptyConversation(displayName: 'Bob', onViewProfile: () {}),
            ),
          ),
        );

        // Only two Text widgets: display name and "View profile"
        expect(find.byType(Text), findsNWidgets(2));
      });

      testWidgets('renders "View profile" button text', (tester) async {
        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: EmptyConversation(displayName: 'Bob', onViewProfile: () {}),
            ),
          ),
        );

        expect(find.text('View profile'), findsOneWidget);
      });
    });

    group('interactions', () {
      testWidgets('calls onViewProfile when View profile is tapped', (
        tester,
      ) async {
        var wasCalled = false;

        await tester.pumpWidget(
          MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(
              body: EmptyConversation(
                displayName: 'Bob',
                onViewProfile: () => wasCalled = true,
              ),
            ),
          ),
        );

        await tester.tap(find.text('View profile'));
        await tester.pump();

        expect(wasCalled, isTrue);
      });
    });
  });
}
