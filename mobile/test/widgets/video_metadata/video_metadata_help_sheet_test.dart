import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/widgets/video_metadata/video_metadata_help_sheet.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  /// Creates a test app with GoRouter for navigation tests.
  Widget createTestApp({
    required String title,
    required String message,
    required String assetPath,
    VoidCallback? onPop,
  }) {
    final router = GoRouter(
      routes: [
        GoRoute(
          path: '/',
          builder: (context, state) => Scaffold(
            body: Builder(
              builder: (context) => ElevatedButton(
                onPressed: () {
                  showModalBottomSheet<void>(
                    context: context,
                    builder: (_) => Material(
                      child: VideoMetadataHelpSheet(
                        title: title,
                        message: message,
                        assetPath: assetPath,
                      ),
                    ),
                  );
                },
                child: const Text('Show Sheet'),
              ),
            ),
          ),
        ),
      ],
    );
    return ProviderScope(child: MaterialApp.router(routerConfig: router));
  }

  group(VideoMetadataHelpSheet, () {
    testWidgets('renders title text', (tester) async {
      const testTitle = 'Test Help Title';
      const testMessage = 'Test help message content';

      await tester.pumpWidget(
        createTestApp(
          title: testTitle,
          message: testMessage,
          assetPath: 'assets/stickers/stars.png',
        ),
      );

      // Open the bottom sheet
      await tester.tap(find.text('Show Sheet'));
      await tester.pumpAndSettle();

      expect(find.text(testTitle), findsOneWidget);
    });

    testWidgets('renders message text', (tester) async {
      const testTitle = 'Test Title';
      const testMessage = 'This is a helpful message about the feature';

      await tester.pumpWidget(
        createTestApp(
          title: testTitle,
          message: testMessage,
          assetPath: 'assets/stickers/stars.png',
        ),
      );

      // Open the bottom sheet
      await tester.tap(find.text('Show Sheet'));
      await tester.pumpAndSettle();

      expect(find.text(testMessage), findsOneWidget);
    });

    testWidgets('renders "Got it!" dismiss button', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          title: 'Title',
          message: 'Message',
          assetPath: 'assets/stickers/stars.png',
        ),
      );

      // Open the bottom sheet
      await tester.tap(find.text('Show Sheet'));
      await tester.pumpAndSettle();

      expect(find.text('Got it!'), findsOneWidget);
    });

    testWidgets('has correct dismiss button semantics', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          title: 'Title',
          message: 'Message',
          assetPath: 'assets/stickers/stars.png',
        ),
      );

      // Open the bottom sheet
      await tester.tap(find.text('Show Sheet'));
      await tester.pumpAndSettle();

      // Find the Semantics widget wrapping the dismiss button
      final semanticsWidgets = find.byType(Semantics);
      expect(semanticsWidgets, findsWidgets);

      // Look for a Semantics widget with button=true and the dismiss label
      var foundButtonSemantics = false;
      for (final element in semanticsWidgets.evaluate()) {
        final widget = element.widget as Semantics;
        if (widget.properties.button == true &&
            widget.properties.label == 'Dismiss help dialog') {
          foundButtonSemantics = true;
          break;
        }
      }
      expect(foundButtonSemantics, isTrue);
    });

    testWidgets('renders image with provided asset path', (tester) async {
      const testAssetPath = 'assets/stickers/stars.png';

      await tester.pumpWidget(
        createTestApp(
          title: 'Title',
          message: 'Message',
          assetPath: testAssetPath,
        ),
      );

      // Open the bottom sheet
      await tester.tap(find.text('Show Sheet'));
      await tester.pumpAndSettle();

      // Image widget should be present
      expect(find.byType(Image), findsOneWidget);
    });

    testWidgets('dismiss button closes the sheet', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          title: 'Title',
          message: 'Message',
          assetPath: 'assets/stickers/stars.png',
        ),
      );

      // Open the bottom sheet
      await tester.tap(find.text('Show Sheet'));
      await tester.pumpAndSettle();

      // Verify sheet is open
      expect(find.text('Got it!'), findsOneWidget);

      // Tap the dismiss button
      await tester.tap(find.text('Got it!'));
      await tester.pumpAndSettle();

      // Sheet should be closed/dismissed
      expect(find.text('Got it!'), findsNothing);
    });

    testWidgets('content is scrollable', (tester) async {
      await tester.pumpWidget(
        createTestApp(
          title: 'Title',
          message: 'Message',
          assetPath: 'assets/stickers/stars.png',
        ),
      );

      // Open the bottom sheet
      await tester.tap(find.text('Show Sheet'));
      await tester.pumpAndSettle();

      // SingleChildScrollView should be present for scrollable content
      expect(find.byType(SingleChildScrollView), findsOneWidget);
    });
  });
}
