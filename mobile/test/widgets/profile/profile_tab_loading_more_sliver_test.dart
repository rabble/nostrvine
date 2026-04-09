import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/widgets/profile/profile_tab_loading_more_sliver.dart';

void main() {
  group(ProfileTabLoadingMoreSliver, () {
    Widget buildSubject() {
      return MaterialApp(
        theme: VineTheme.theme,
        home: const Scaffold(
          body: CustomScrollView(
            slivers: [ProfileTabLoadingMoreSliver()],
          ),
        ),
      );
    }

    group('renders', () {
      testWidgets('$CircularProgressIndicator', (tester) async {
        await tester.pumpWidget(buildSubject());

        expect(find.byType(CircularProgressIndicator), findsOneWidget);
      });

      testWidgets('$SliverToBoxAdapter', (tester) async {
        await tester.pumpWidget(buildSubject());

        expect(find.byType(SliverToBoxAdapter), findsOneWidget);
      });

      testWidgets('centered with padding', (tester) async {
        await tester.pumpWidget(buildSubject());

        expect(find.byType(Center), findsOneWidget);
        expect(find.byType(Padding), findsOneWidget);
      });
    });
  });
}
