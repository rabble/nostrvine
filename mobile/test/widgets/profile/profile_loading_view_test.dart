// ABOUTME: Tests for ProfileLoadingView skeleton shell
// ABOUTME: Verifies the loading view renders a Skeletonizer instead of text

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/widgets/profile/profile_loading_view.dart';
import 'package:skeletonizer/skeletonizer.dart';

void main() {
  group('ProfileLoadingView', () {
    testWidgets(
      'renders a skeleton shell instead of "Loading profile" text '
      '(#4183 review feedback)',
      (tester) async {
        await tester.pumpWidget(
          const MaterialApp(home: Scaffold(body: ProfileLoadingView())),
        );

        // No bare loading text — the reviewer asked us to drop it and
        // show only the skeleton page.
        expect(find.text('Loading profile...'), findsNothing);
        expect(find.text('This may take a few moments'), findsNothing);
        expect(find.byType(CircularProgressIndicator), findsNothing);

        // The shell is wrapped in a single Skeletonizer so the package
        // handles shimmer for the whole subtree.
        expect(find.bySubtype<Skeletonizer>(), findsOneWidget);
      },
    );
  });
}
