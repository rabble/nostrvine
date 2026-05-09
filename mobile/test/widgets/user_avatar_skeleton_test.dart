// ABOUTME: Tests UserAvatar loading-skeleton behavior added by #4163.
// ABOUTME: Pins the Skeletonizer-vs-identicon contract.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/widgets/user_avatar.dart';
import 'package:skeletonizer/skeletonizer.dart';

void main() {
  // Real 64-char hex pubkey. Never truncate Nostr IDs in code or tests.
  const pubkey =
      '0000000000000000000000000000000000000000000000000000000000000001';

  Widget pumped(Widget child) => MaterialApp(
    home: Scaffold(body: Center(child: child)),
  );

  group('UserAvatar isLoading', () {
    testWidgets('wraps avatar in Skeletonizer when isLoading is true', (
      tester,
    ) async {
      await tester.pumpWidget(
        pumped(const UserAvatar(placeholderSeed: pubkey, isLoading: true)),
      );

      // bySubtype because Skeletonizer is abstract; the concrete widget
      // in the tree is the private _Skeletonizer subclass.
      expect(find.bySubtype<Skeletonizer>(), findsOneWidget);
    });

    testWidgets('does not render Skeletonizer when isLoading is false', (
      tester,
    ) async {
      await tester.pumpWidget(
        pumped(const UserAvatar(placeholderSeed: pubkey)),
      );

      expect(find.bySubtype<Skeletonizer>(), findsNothing);
    });

    testWidgets(
      'preserves the Semantics label when wrapped in Skeletonizer so '
      'screen readers still announce the loading avatar correctly',
      (tester) async {
        await tester.pumpWidget(
          pumped(
            const UserAvatar(
              placeholderSeed: pubkey,
              isLoading: true,
              semanticLabel: 'Profile picture',
            ),
          ),
        );

        expect(find.bySemanticsLabel('Profile picture'), findsOneWidget);
      },
    );
  });
}
