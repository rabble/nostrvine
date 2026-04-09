import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/widgets/profile/profile_tab_empty_state.dart';

void main() {
  group(ProfileTabEmptyState, () {
    Widget buildSubject({
      DivineIconName icon = DivineIconName.heart,
      Color iconColor = VineTheme.lightText,
      String title = 'No Items',
      String subtitle = 'Nothing here yet',
      Color subtitleColor = VineTheme.lightText,
      VoidCallback? onRefresh,
    }) {
      return MaterialApp(
        theme: VineTheme.theme,
        home: Scaffold(
          body: ProfileTabEmptyState(
            icon: icon,
            iconColor: iconColor,
            title: title,
            subtitle: subtitle,
            subtitleColor: subtitleColor,
            onRefresh: onRefresh,
          ),
        ),
      );
    }

    group('renders', () {
      testWidgets('$DivineIcon with the given icon', (tester) async {
        await tester.pumpWidget(
          buildSubject(),
        );

        expect(find.byType(DivineIcon), findsWidgets);
      });

      testWidgets('title text', (tester) async {
        await tester.pumpWidget(buildSubject(title: 'No Videos Yet'));

        expect(find.text('No Videos Yet'), findsOneWidget);
      });

      testWidgets('subtitle text', (tester) async {
        await tester.pumpWidget(
          buildSubject(subtitle: 'Videos you like will appear here'),
        );

        expect(
          find.text('Videos you like will appear here'),
          findsOneWidget,
        );
      });

      testWidgets('$CustomScrollView with $SliverFillRemaining', (
        tester,
      ) async {
        await tester.pumpWidget(buildSubject());

        expect(find.byType(CustomScrollView), findsOneWidget);
        expect(find.byType(SliverFillRemaining), findsOneWidget);
      });

      testWidgets('no refresh button when onRefresh is null', (
        tester,
      ) async {
        await tester.pumpWidget(buildSubject());

        expect(find.byType(IconButton), findsNothing);
      });

      testWidgets('refresh button when onRefresh is provided', (
        tester,
      ) async {
        await tester.pumpWidget(buildSubject(onRefresh: () {}));

        expect(find.byType(IconButton), findsOneWidget);
      });
    });

    group('interactions', () {
      testWidgets('tapping refresh button calls onRefresh', (tester) async {
        var refreshCalled = false;
        await tester.pumpWidget(
          buildSubject(onRefresh: () => refreshCalled = true),
        );

        await tester.tap(find.byType(IconButton));

        expect(refreshCalled, isTrue);
      });
    });
  });
}
