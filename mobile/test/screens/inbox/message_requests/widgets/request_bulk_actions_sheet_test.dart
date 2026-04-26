// ABOUTME: Widget tests for RequestBulkActionsSheet.
// ABOUTME: Verifies that both action tiles render and return the correct
// ABOUTME: RequestBulkAction when tapped.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/router/app_router.dart';
import 'package:openvine/screens/inbox/message_requests/widgets/request_bulk_actions_sheet.dart';

import '../../../../helpers/go_router.dart';
import '../../../../helpers/test_provider_overrides.dart';

void main() {
  group(RequestBulkActionsSheet, () {
    late MockGoRouter mockGoRouter;

    setUp(() {
      mockGoRouter = MockGoRouter();
    });

    Widget buildSubject({required ValueChanged<RequestBulkAction?> onResult}) {
      return testMaterialApp(
        additionalOverrides: [goRouterProvider.overrideWithValue(mockGoRouter)],
        home: MockGoRouterProvider(
          goRouter: mockGoRouter,
          child: Builder(
            builder: (context) {
              return Scaffold(
                body: ElevatedButton(
                  onPressed: () async {
                    final result = await RequestBulkActionsSheet.show(context);
                    onResult(result);
                  },
                  child: const Text('Show sheet'),
                ),
              );
            },
          ),
        ),
      );
    }

    testWidgets('renders both action tiles when shown', (tester) async {
      await tester.pumpWidget(buildSubject(onResult: (_) {}));

      await tester.tap(find.text('Show sheet'));
      await tester.pumpAndSettle();

      expect(find.text('Mark all requests as read'), findsOneWidget);
      expect(find.text('Remove all requests'), findsOneWidget);
    });

    testWidgets('returns markAllRead when first tile tapped', (tester) async {
      // Stub pop to use Navigator.pop with the value argument
      when(() => mockGoRouter.pop(any())).thenAnswer((invocation) async {
        // The value is passed as positional arg to GoRouter.pop
      });

      await tester.pumpWidget(buildSubject(onResult: (_) {}));

      await tester.tap(find.text('Show sheet'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Mark all requests as read'));
      await tester.pumpAndSettle();

      verify(() => mockGoRouter.pop(RequestBulkAction.markAllRead)).called(1);
    });

    testWidgets('returns removeAll when second tile tapped', (tester) async {
      when(() => mockGoRouter.pop(any())).thenAnswer((invocation) async {});

      await tester.pumpWidget(buildSubject(onResult: (_) {}));

      await tester.tap(find.text('Show sheet'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Remove all requests'));
      await tester.pumpAndSettle();

      verify(() => mockGoRouter.pop(RequestBulkAction.removeAll)).called(1);
    });
  });
}
