import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/models/video_editor/video_editor_provider_state.dart';
import 'package:openvine/providers/video_editor_provider.dart';
import 'package:openvine/widgets/video_metadata/video_metadata_tags_input.dart';

void main() {
  group('VideoMetadataTagsInput', () {
    testWidgets('displays empty state initially', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(home: Scaffold(body: VideoMetadataTagsInput())),
        ),
      );

      // Should show Tags label in text field
      expect(find.text('Tags'), findsOneWidget);
      // Should not show tag count when empty
      expect(
        find.textContaining('/${VideoEditorConstants.tagLimit}'),
        findsNothing,
      );
    });

    testWidgets('displays existing tags as chips', (tester) async {
      final state = VideoEditorProviderState(
        tags: {'flutter', 'dart', 'mobile'},
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            videoEditorProvider.overrideWith(
              () => _MockVideoEditorNotifier(state),
            ),
          ],
          child: const MaterialApp(
            home: Scaffold(body: VideoMetadataTagsInput()),
          ),
        ),
      );

      // Should display all tags
      expect(find.text('#'), findsNWidgets(3));
      expect(find.text('flutter'), findsOneWidget);
      expect(find.text('dart'), findsOneWidget);
      expect(find.text('mobile'), findsOneWidget);

      // Should show tag count
      if (VideoEditorConstants.enableTagLimit) {
        expect(find.text('3/${VideoEditorConstants.tagLimit}'), findsOneWidget);
      }
    });

    testWidgets('adds tag when space is entered', (tester) async {
      final addedTags = <String>{};
      final mockNotifier = _MockVideoEditorNotifier(
        VideoEditorProviderState(),
        onUpdateMetadata: (tags) => addedTags.addAll(tags ?? {}),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [videoEditorProvider.overrideWith(() => mockNotifier)],
          child: const MaterialApp(
            home: Scaffold(body: VideoMetadataTagsInput()),
          ),
        ),
      );

      // Enter text and space
      await tester.enterText(find.byType(TextField), 'flutter ');
      await tester.pump();

      expect(addedTags, contains('flutter'));
    });

    testWidgets('adds tag when submitted', (tester) async {
      final addedTags = <String>{};
      final mockNotifier = _MockVideoEditorNotifier(
        VideoEditorProviderState(),
        onUpdateMetadata: (tags) => addedTags.addAll(tags ?? {}),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [videoEditorProvider.overrideWith(() => mockNotifier)],
          child: const MaterialApp(
            home: Scaffold(body: VideoMetadataTagsInput()),
          ),
        ),
      );

      await tester.enterText(find.byType(TextField), 'flutter');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();

      expect(addedTags, contains('flutter'));
    });

    testWidgets('adds multiple tags from pasted text', (tester) async {
      final addedTags = <String>{};
      final mockNotifier = _MockVideoEditorNotifier(
        VideoEditorProviderState(),
        onUpdateMetadata: (tags) => addedTags.addAll(tags ?? {}),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [videoEditorProvider.overrideWith(() => mockNotifier)],
          child: const MaterialApp(
            home: Scaffold(body: VideoMetadataTagsInput()),
          ),
        ),
      );

      // Simulate pasting multiple tags
      await tester.enterText(find.byType(TextField), 'flutter dart mobile ');
      await tester.pump();

      expect(addedTags, containsAll(['flutter', 'dart', 'mobile']));
    });

    testWidgets('filters out invalid characters', (tester) async {
      final addedTags = <String>{};
      final mockNotifier = _MockVideoEditorNotifier(
        VideoEditorProviderState(),
        onUpdateMetadata: (tags) => addedTags.addAll(tags ?? {}),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [videoEditorProvider.overrideWith(() => mockNotifier)],
          child: const MaterialApp(
            home: Scaffold(body: VideoMetadataTagsInput()),
          ),
        ),
      );

      await tester.enterText(find.byType(TextField), '#flutter! ');
      await tester.pump();

      // Should only contain alphanumeric characters
      expect(addedTags, contains('flutter'));
      expect(addedTags.first, equals('flutter'));
    });

    testWidgets('removes tag when delete button is tapped', (tester) async {
      Set<String>? updatedTags;
      final mockNotifier = _MockVideoEditorNotifier(
        VideoEditorProviderState(tags: {'flutter', 'dart'}),
        onUpdateMetadata: (tags) => updatedTags = tags,
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [videoEditorProvider.overrideWith(() => mockNotifier)],
          child: const MaterialApp(
            home: Scaffold(body: VideoMetadataTagsInput()),
          ),
        ),
      );

      // Find and tap a delete button on one of the tag chips.
      // The delete button uses Semantics(label: 'Delete'), so we
      // find it by its semantic label to avoid fragile GestureDetector
      // ordering that can break when child widgets add their own.
      final deleteButton = find.bySemanticsLabel('Delete').first;

      await tester.tap(deleteButton);
      await tester.pump();

      // Should have removed one of the tags (updatedTags should have 1 tag)
      expect(updatedTags, isNotNull);
      expect(updatedTags!.length, equals(1));
      expect(updatedTags, anyOf(equals({'flutter'}), equals({'dart'})));
    });

    testWidgets(
      'hides input field when tag limit is reached',
      (tester) async {
        final state = VideoEditorProviderState(
          tags: {
            for (var i = 0; i < VideoEditorConstants.tagLimit; i++) 'tag$i',
          },
        );

        await tester.pumpWidget(
          ProviderScope(
            overrides: [
              videoEditorProvider.overrideWith(
                () => _MockVideoEditorNotifier(state),
              ),
            ],
            child: const MaterialApp(
              home: Scaffold(body: VideoMetadataTagsInput()),
            ),
          ),
        );

        // Should show 10 tags
        expect(find.text('#'), findsNWidgets(10));
        expect(
          find.text(
            '${VideoEditorConstants.tagLimit}/${VideoEditorConstants.tagLimit}',
          ),
          findsOneWidget,
        );

        // Input field should not be present
        expect(find.byType(TextField), findsNothing);
      },
      skip: !VideoEditorConstants.enableTagLimit,
    );

    testWidgets('clears input after adding tag', (tester) async {
      final mockNotifier = _MockVideoEditorNotifier(VideoEditorProviderState());

      await tester.pumpWidget(
        ProviderScope(
          overrides: [videoEditorProvider.overrideWith(() => mockNotifier)],
          child: const MaterialApp(
            home: Scaffold(body: VideoMetadataTagsInput()),
          ),
        ),
      );

      await tester.enterText(find.byType(TextField), 'flutter ');
      await tester.pump();

      // Input should be cleared
      final textField = tester.widget<TextField>(find.byType(TextField));
      expect(textField.controller?.text, isEmpty);
    });

    testWidgets('focuses input when tapped outside', (tester) async {
      await tester.pumpWidget(
        const ProviderScope(
          child: MaterialApp(home: Scaffold(body: VideoMetadataTagsInput())),
        ),
      );

      // Initially unfocused
      expect(tester.testTextInput.isVisible, isFalse);

      // Tap the gesture detector area to focus
      await tester.tap(find.byType(GestureDetector).first);
      await tester.pump();

      // Keyboard should appear (text input now visible)
      expect(tester.testTextInput.isVisible, isTrue);
    });

    testWidgets('ignores empty whitespace input', (tester) async {
      final addedTags = <String>{};
      final mockNotifier = _MockVideoEditorNotifier(
        VideoEditorProviderState(),
        onUpdateMetadata: (tags) => addedTags.addAll(tags ?? {}),
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [videoEditorProvider.overrideWith(() => mockNotifier)],
          child: const MaterialApp(
            home: Scaffold(body: VideoMetadataTagsInput()),
          ),
        ),
      );

      await tester.enterText(find.byType(TextField), '   ');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();

      expect(addedTags, isEmpty);
    });
  });
}

/// Mock notifier for testing
class _MockVideoEditorNotifier extends VideoEditorNotifier {
  _MockVideoEditorNotifier(this._state, {this.onUpdateMetadata});

  final VideoEditorProviderState _state;
  final void Function(Set<String>? tags)? onUpdateMetadata;

  @override
  VideoEditorProviderState build() => _state;

  @override
  void updateMetadata({String? title, String? description, Set<String>? tags}) {
    if (tags != null) {
      onUpdateMetadata?.call(tags);
      state = state.copyWith(tags: tags);
    }
  }
}
