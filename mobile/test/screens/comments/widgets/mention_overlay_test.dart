// ABOUTME: Tests for comment mention autocomplete overlay rendering
// ABOUTME: Verifies server suggestion data renders before profile cache catches up

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/blocs/comments/comments_bloc.dart';
import 'package:openvine/screens/comments/widgets/mention_overlay.dart';

void main() {
  testWidgets('renders suggestion display name before profile cache resolves', (
    tester,
  ) async {
    await tester.pumpWidget(
      ProviderScope(
        child: MaterialApp(
          home: Scaffold(
            body: MentionOverlay(
              suggestions: const [
                MentionSuggestion(
                  pubkey:
                      'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa',
                  displayName: 'GaryVee',
                ),
              ],
              onSelect: (_, _) {},
            ),
          ),
        ),
      ),
    );

    expect(find.text('GaryVee'), findsOneWidget);
  });
}
