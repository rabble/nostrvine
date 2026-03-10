// ABOUTME: Widget tests for MessagesTab
// ABOUTME: Tests empty state, FAB, and subtitle rendering

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/screens/inbox/messages_tab.dart';
import 'package:openvine/widgets/inbox/people_bar.dart';

void main() {
  group(MessagesTab, () {
    Widget buildSubject() {
      return UncontrolledProviderScope(
        container: ProviderContainer(
          overrides: [dmRepositoryProvider.overrideWithValue(null)],
        ),
        child: const MaterialApp(home: Scaffold(body: MessagesTab())),
      );
    }

    group('renders', () {
      testWidgets('renders $MessagesTab', (tester) async {
        await tester.pumpWidget(buildSubject());

        expect(find.byType(MessagesTab), findsOneWidget);
      });

      testWidgets('hides $PeopleBar when users list is empty', (tester) async {
        await tester.pumpWidget(buildSubject());

        expect(find.byType(PeopleBar), findsNothing);
      });

      testWidgets('renders empty state title text', (tester) async {
        await tester.pumpWidget(buildSubject());

        expect(find.text('No messages yet'), findsOneWidget);
      });

      testWidgets('renders empty state subtitle text', (tester) async {
        await tester.pumpWidget(buildSubject());

        expect(
          find.text("That + button won't bite."),
          findsOneWidget,
        );
      });

      testWidgets('renders compose FAB with add icon', (tester) async {
        await tester.pumpWidget(buildSubject());

        expect(
          find.bySemanticsLabel('Compose new message'),
          findsOneWidget,
        );
        expect(find.byIcon(Icons.add), findsOneWidget);
      });
    });
  });
}
