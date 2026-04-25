// ABOUTME: Widget tests for ConversationActionsSheet.
// ABOUTME: Verifies that all action tiles render and return the correct
// ABOUTME: ConversationAction when tapped.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/screens/inbox/widgets/conversation_actions_sheet.dart';

import '../../../helpers/test_provider_overrides.dart';

void main() {
  group(ConversationActionsSheet, () {
    Widget buildSubject({
      required ValueChanged<ConversationAction?> onResult,
      bool isMuted = false,
      bool isBlocked = false,
    }) {
      return testMaterialApp(
        home: Builder(
          builder: (context) {
            return Scaffold(
              body: ElevatedButton(
                onPressed: () async {
                  final result = await ConversationActionsSheet.show(
                    context,
                    displayName: 'Alice',
                    isMuted: isMuted,
                    isBlocked: isBlocked,
                  );
                  onResult(result);
                },
                child: const Text('Show sheet'),
              ),
            );
          },
        ),
      );
    }

    group('renders', () {
      testWidgets('renders all four action tiles', (tester) async {
        await tester.pumpWidget(buildSubject(onResult: (_) {}));

        await tester.tap(find.text('Show sheet'));
        await tester.pumpAndSettle();

        expect(find.text('Mute conversation'), findsOneWidget);
        expect(find.text('Report Alice'), findsOneWidget);
        expect(find.text('Block Alice'), findsOneWidget);
        expect(find.text('Remove conversation'), findsOneWidget);
      });

      testWidgets('renders Unblock label when user is blocked', (tester) async {
        await tester.pumpWidget(
          buildSubject(onResult: (_) {}, isBlocked: true),
        );

        await tester.tap(find.text('Show sheet'));
        await tester.pumpAndSettle();

        expect(find.text('Unblock Alice'), findsOneWidget);
        expect(find.text('Block Alice'), findsNothing);
      });

      testWidgets('renders $SwitchListTile for mute toggle', (tester) async {
        await tester.pumpWidget(buildSubject(onResult: (_) {}));

        await tester.tap(find.text('Show sheet'));
        await tester.pumpAndSettle();

        expect(find.byType(SwitchListTile), findsOneWidget);
      });
    });

    group('interactions', () {
      testWidgets('returns toggleMute when mute tile tapped', (tester) async {
        ConversationAction? result;
        await tester.pumpWidget(
          buildSubject(onResult: (action) => result = action),
        );

        await tester.tap(find.text('Show sheet'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Mute conversation'));
        await tester.pumpAndSettle();

        expect(result, equals(ConversationAction.toggleMute));
      });

      testWidgets('returns report when report tile tapped', (tester) async {
        ConversationAction? result;
        await tester.pumpWidget(
          buildSubject(onResult: (action) => result = action),
        );

        await tester.tap(find.text('Show sheet'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Report Alice'));
        await tester.pumpAndSettle();

        expect(result, equals(ConversationAction.report));
      });

      testWidgets('returns block when block tile tapped', (tester) async {
        ConversationAction? result;
        await tester.pumpWidget(
          buildSubject(onResult: (action) => result = action),
        );

        await tester.tap(find.text('Show sheet'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Block Alice'));
        await tester.pumpAndSettle();

        expect(result, equals(ConversationAction.block));
      });

      testWidgets('returns remove when remove tile tapped', (tester) async {
        ConversationAction? result;
        await tester.pumpWidget(
          buildSubject(onResult: (action) => result = action),
        );

        await tester.tap(find.text('Show sheet'));
        await tester.pumpAndSettle();

        await tester.tap(find.text('Remove conversation'));
        await tester.pumpAndSettle();

        expect(result, equals(ConversationAction.remove));
      });

      testWidgets('returns null when dismissed by tapping scrim', (
        tester,
      ) async {
        ConversationAction? result;
        var callbackCalled = false;
        await tester.pumpWidget(
          buildSubject(
            onResult: (action) {
              callbackCalled = true;
              result = action;
            },
          ),
        );

        await tester.tap(find.text('Show sheet'));
        await tester.pumpAndSettle();

        // Tap the scrim (top-left corner, outside the bottom sheet)
        await tester.tapAt(Offset.zero);
        await tester.pumpAndSettle();

        expect(callbackCalled, isTrue);
        expect(result, isNull);
      });
    });
  });
}
