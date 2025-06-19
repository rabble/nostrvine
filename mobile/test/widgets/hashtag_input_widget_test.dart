// ABOUTME: Test file for HashtagInputWidget UI and functionality
// ABOUTME: Verifies hashtag input, suggestions, and validation

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import '../../lib/widgets/hashtag_input_widget.dart';

void main() {
  group('HashtagInputWidget', () {
    testWidgets('displays empty state correctly', (WidgetTester tester) async {
      List<String> hashtags = [];
      
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HashtagInputWidget(
              hashtags: hashtags,
              onHashtagsChanged: (newHashtags) {
                hashtags = newHashtags;
              },
            ),
          ),
        ),
      );

      // Should show input field and counter
      expect(find.text('Add hashtags to help people find your video...'), findsOneWidget);
      expect(find.text('0/10 hashtags'), findsOneWidget);
    });

    testWidgets('shows popular suggestions when focused', (WidgetTester tester) async {
      List<String> hashtags = [];
      
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HashtagInputWidget(
              hashtags: hashtags,
              onHashtagsChanged: (newHashtags) {
                hashtags = newHashtags;
              },
            ),
          ),
        ),
      );

      // Tap the input field to focus
      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();

      // Should show popular suggestions
      expect(find.text('Popular hashtags:'), findsOneWidget);
      expect(find.text('#nostrvine'), findsOneWidget);
      expect(find.text('#vine'), findsOneWidget);
      expect(find.text('#nostr'), findsOneWidget);
    });

    testWidgets('adds hashtag when suggestion is tapped', (WidgetTester tester) async {
      List<String> hashtags = [];
      
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HashtagInputWidget(
              hashtags: hashtags,
              onHashtagsChanged: (newHashtags) {
                hashtags = newHashtags;
              },
            ),
          ),
        ),
      );

      // Focus the input to show suggestions
      await tester.tap(find.byType(TextField));
      await tester.pumpAndSettle();

      // Tap a suggestion
      await tester.tap(find.text('#nostrvine'));
      await tester.pumpAndSettle();

      // Should have added the hashtag
      expect(hashtags, contains('nostrvine'));
      expect(find.text('#nostrvine'), findsWidgets); // Both in chip and suggestions
    });

    testWidgets('adds hashtag when typing and pressing enter', (WidgetTester tester) async {
      List<String> hashtags = [];
      
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HashtagInputWidget(
              hashtags: hashtags,
              onHashtagsChanged: (newHashtags) {
                hashtags = newHashtags;
              },
            ),
          ),
        ),
      );

      // Type in the input field
      await tester.enterText(find.byType(TextField), 'test');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      // Should have added the hashtag
      expect(hashtags, contains('test'));
    });

    testWidgets('removes hashtag when chip close is tapped', (WidgetTester tester) async {
      List<String> hashtags = ['test', 'example'];
      
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => HashtagInputWidget(
                hashtags: hashtags,
                onHashtagsChanged: (newHashtags) {
                  setState(() {
                    hashtags = newHashtags;
                  });
                },
              ),
            ),
          ),
        ),
      );

      // Should show hashtag chips
      expect(find.text('#test'), findsOneWidget);
      expect(find.text('#example'), findsOneWidget);

      // Tap the close button on the first hashtag
      final closeIcons = find.byIcon(Icons.close);
      expect(closeIcons, findsNWidgets(2));
      
      await tester.tap(closeIcons.first);
      await tester.pumpAndSettle();

      // Should have removed one hashtag
      expect(hashtags.length, equals(1));
    });

    testWidgets('enforces maximum hashtag limit', (WidgetTester tester) async {
      List<String> hashtags = [];
      
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: StatefulBuilder(
              builder: (context, setState) => HashtagInputWidget(
                hashtags: hashtags,
                maxHashtags: 2,
                onHashtagsChanged: (newHashtags) {
                  setState(() {
                    hashtags = newHashtags;
                  });
                },
              ),
            ),
          ),
        ),
      );

      // Should show correct counter
      expect(find.text('0/2 hashtags'), findsOneWidget);

      // Add two hashtags
      await tester.enterText(find.byType(TextField), 'first');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      await tester.enterText(find.byType(TextField), 'second');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      // Should show maximum reached
      expect(find.text('2/2 hashtags'), findsOneWidget);
      expect(find.text('Maximum reached'), findsOneWidget);

      // Try to add a third hashtag
      await tester.enterText(find.byType(TextField), 'third');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      // Should still only have 2 hashtags
      expect(hashtags.length, equals(2));
    });

    testWidgets('filters suggestions based on input', (WidgetTester tester) async {
      List<String> hashtags = [];
      
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HashtagInputWidget(
              hashtags: hashtags,
              onHashtagsChanged: (newHashtags) {
                hashtags = newHashtags;
              },
            ),
          ),
        ),
      );

      // Focus and type partial text
      await tester.tap(find.byType(TextField));
      await tester.enterText(find.byType(TextField), 'nost');
      await tester.pumpAndSettle();

      // Should show filtered suggestions
      expect(find.text('Suggestions:'), findsOneWidget);
      expect(find.text('#nostrvine'), findsOneWidget);
      expect(find.text('#nostr'), findsOneWidget);
      // Should not show unrelated suggestions
      expect(find.text('#bitcoin'), findsNothing);
    });

    testWidgets('validates hashtag format', (WidgetTester tester) async {
      List<String> hashtags = [];
      
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HashtagInputWidget(
              hashtags: hashtags,
              onHashtagsChanged: (newHashtags) {
                hashtags = newHashtags;
              },
            ),
          ),
        ),
      );

      // Try to add invalid hashtag with special characters
      await tester.enterText(find.byType(TextField), 'test@#\$');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      // Should not have added invalid hashtag
      expect(hashtags, isEmpty);

      // Try to add valid hashtag
      await tester.enterText(find.byType(TextField), 'valid_tag123');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      // Should have added valid hashtag
      expect(hashtags, contains('valid_tag123'));
    });

    testWidgets('prevents duplicate hashtags', (WidgetTester tester) async {
      List<String> hashtags = ['existing'];
      
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: HashtagInputWidget(
              hashtags: hashtags,
              onHashtagsChanged: (newHashtags) {
                hashtags = newHashtags;
              },
            ),
          ),
        ),
      );

      // Try to add duplicate hashtag
      await tester.enterText(find.byType(TextField), 'existing');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pumpAndSettle();

      // Should still only have one instance
      expect(hashtags.length, equals(1));
      expect(hashtags, contains('existing'));
    });
  });
}