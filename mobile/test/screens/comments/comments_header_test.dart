import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/screens/comments/comments.dart';

void main() {
  group('CommentsHeader', () {
    Widget buildSubject({VoidCallback? onClose}) => MaterialApp(
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: Scaffold(body: CommentsHeader(onClose: onClose ?? () {})),
    );

    testWidgets('displays localized title', (tester) async {
      await tester.pumpWidget(buildSubject());

      final l10n = lookupAppLocalizations(const Locale('en'));
      expect(find.text(l10n.commentsHeaderTitle), findsOneWidget);
    });

    testWidgets('displays close button', (tester) async {
      await tester.pumpWidget(buildSubject());

      expect(find.byIcon(Icons.close), findsOneWidget);
    });

    testWidgets('calls onClose when close button is tapped', (tester) async {
      var closeCallCount = 0;
      await tester.pumpWidget(
        buildSubject(onClose: () => closeCallCount++),
      );

      await tester.tap(find.byIcon(Icons.close));
      await tester.pump();

      expect(closeCallCount, equals(1));
    });

    testWidgets('has correct layout structure', (tester) async {
      await tester.pumpWidget(buildSubject());

      expect(find.byType(Row), findsOneWidget);
      expect(find.byType(IconButton), findsOneWidget);
      expect(find.byType(Spacer), findsOneWidget);
    });
  });
}
