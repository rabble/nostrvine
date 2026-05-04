import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Future<void> pump(WidgetTester tester, Widget child) =>
      tester.pumpWidget(MaterialApp(home: Scaffold(body: child)));

  group(IdentityChip, () {
    testWidgets('renders the identity handle', (tester) async {
      await pump(
        tester,
        IdentityChip(
          platformDisplayName: 'GitHub',
          identity: 'rabble',
          onTap: () {},
        ),
      );

      expect(find.text('rabble'), findsOneWidget);
    });

    testWidgets('invokes onTap when tapped', (tester) async {
      var tapped = false;
      await pump(
        tester,
        IdentityChip(
          platformDisplayName: 'GitHub',
          identity: 'rabble',
          onTap: () => tapped = true,
        ),
      );

      await tester.tap(find.byType(IdentityChip));
      expect(tapped, isTrue);
    });

    testWidgets('exposes "Verified <platform> account: <handle>" semantics', (
      tester,
    ) async {
      await pump(
        tester,
        IdentityChip(
          platformDisplayName: 'GitHub',
          identity: 'rabble',
          onTap: () {},
        ),
      );

      final semantics = tester.getSemantics(find.byType(IdentityChip).first);
      expect(semantics.label, contains('Verified GitHub account: rabble'));
    });

    testWidgets('renders provided icon ahead of the handle', (tester) async {
      await pump(
        tester,
        IdentityChip(
          platformDisplayName: 'GitHub',
          identity: 'rabble',
          icon: const Icon(Icons.link, key: Key('icon')),
          onTap: () {},
        ),
      );

      expect(find.byKey(const Key('icon')), findsOneWidget);
      expect(find.text('rabble'), findsOneWidget);
    });

    testWidgets('omits the icon slot when no icon is provided', (tester) async {
      await pump(
        tester,
        IdentityChip(
          platformDisplayName: 'GitHub',
          identity: 'rabble',
          onTap: () {},
        ),
      );

      expect(find.byType(Icon), findsNothing);
    });
  });
}
