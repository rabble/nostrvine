// ABOUTME: Widget tests for comment options modal tap targets.
// ABOUTME: Verifies option rows respond across transparent icon/text gaps.

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/screens/comments/widgets/comment_options_modal.dart';

void main() {
  group(CommentOptionsModal, () {
    testWidgets('delete option responds when tapping the icon-label gap', (
      tester,
    ) async {
      CommentOptionResult? result;

      final router = GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (context, state) => Scaffold(
              body: Builder(
                builder: (context) {
                  return TextButton(
                    onPressed: () async {
                      result = await CommentOptionsModal.showForOwnComment(
                        context,
                        commentId:
                            'comment0123456789abcdef0123456789abcdef01234567',
                        commentContent: 'test comment',
                      );
                    },
                    child: const Text('Open options'),
                  );
                },
              ),
            ),
          ),
        ],
      );

      await tester.pumpWidget(
        MaterialApp.router(routerConfig: router),
      );

      await tester.tap(find.text('Open options'));
      await tester.pumpAndSettle();

      final deleteText = find.text('Delete');
      final deleteIcon = find.byType(SvgPicture).last;
      expect(deleteText, findsOneWidget);
      expect(deleteIcon, findsOneWidget);

      final textRect = tester.getRect(deleteText);
      final iconRect = tester.getRect(deleteIcon);

      await tester.tapAt(
        Offset(
          (iconRect.right + textRect.left) / 2,
          textRect.center.dy,
        ),
      );
      await tester.pumpAndSettle();

      expect(result, isA<CommentDeleteResult>());
    });
  });
}
