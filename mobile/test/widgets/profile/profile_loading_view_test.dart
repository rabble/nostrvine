// ABOUTME: Tests for ProfileLoadingView widget
// ABOUTME: Verifies loading indicator and messaging display correctly

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/widgets/profile/profile_loading_view.dart';

void main() {
  group('ProfileLoadingView', () {
    testWidgets('displays loading indicator and text', (tester) async {
      await tester.pumpWidget(
        const MaterialApp(home: Scaffold(body: ProfileLoadingView())),
      );

      expect(find.byType(CircularProgressIndicator), findsOneWidget);
      expect(find.text('Loading profile...'), findsOneWidget);
      expect(find.text('This may take a few moments'), findsOneWidget);
    });
  });
}
