import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('wrapping subtitle inside a 600-wide constrained list', (
    tester,
  ) async {
    await tester.binding.setSurfaceSize(const Size(900, 1200));
    addTearDown(() => tester.binding.setSurfaceSize(null));
    await tester.pumpWidget(
      MaterialApp(
        theme: VineTheme.theme,
        home: Scaffold(
          body: Align(
            alignment: Alignment.topCenter,
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 600),
              child: ListView(
                children: const [
                  DivineSwitchTile(
                    leadingIcon: DivineIconName.globe,
                    title: 'Client attribution',
                    subtitle:
                        'Include a Divine client tag on events you publish so '
                        'other Nostr apps can attribute them correctly.',
                    value: true,
                    onChanged: null,
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
    await tester.pumpAndSettle();
    expect(tester.takeException(), isNull);
  });
}
