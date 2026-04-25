// ABOUTME: Tests for VideoClipThumbnailCard widget
// ABOUTME: Verifies selection overlay, duration badge, and disabled state

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/widgets/video_clip/video_clip_thumbnail_card.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

void main() {
  group(VideoClipThumbnailCard, () {
    DivineVideoClip createClip({
      String id = 'clip-1',
      Duration duration = const Duration(seconds: 5),
    }) {
      return DivineVideoClip(
        id: id,
        video: EditorVideo.file('/path/to/clip.mp4'),
        duration: duration,
        recordedAt: DateTime(2026),
        targetAspectRatio: .vertical,
        originalAspectRatio: 9 / 16,
      );
    }

    Widget buildWidget({
      DivineVideoClip? clip,
      int selectionIndex = -1,
      bool disabled = false,
      VoidCallback? onTap,
      VoidCallback? onLongPress,
    }) {
      return MaterialApp(
        theme: VineTheme.theme,
        home: Scaffold(
          body: VideoClipThumbnailCard(
            clip: clip ?? createClip(),
            selectionIndex: selectionIndex,
            disabled: disabled,
            onTap: onTap ?? () {},
            onLongPress: onLongPress ?? () {},
          ),
        ),
      );
    }

    group('renders', () {
      testWidgets('duration badge', (tester) async {
        await tester.pumpWidget(
          buildWidget(clip: createClip(duration: const Duration(seconds: 3))),
        );

        expect(find.text('3.00'), findsOneWidget);
      });

      testWidgets('selection index when selected', (tester) async {
        await tester.pumpWidget(buildWidget(selectionIndex: 2));

        expect(find.text('2'), findsOneWidget);
      });

      testWidgets('no selection index text when not selected', (tester) async {
        await tester.pumpWidget(buildWidget());

        // Selection overlay exists but without the number
        expect(find.text('1'), findsNothing);
      });

      testWidgets('reduced opacity when disabled', (tester) async {
        await tester.pumpWidget(buildWidget(disabled: true));

        final animatedOpacity = tester.widget<AnimatedOpacity>(
          find.byType(AnimatedOpacity),
        );
        expect(animatedOpacity.opacity, equals(0.4));
      });

      testWidgets('full opacity when enabled', (tester) async {
        await tester.pumpWidget(buildWidget());

        final animatedOpacity = tester.widget<AnimatedOpacity>(
          find.byType(AnimatedOpacity),
        );
        expect(animatedOpacity.opacity, equals(1.0));
      });
    });

    group('interactions', () {
      testWidgets('calls onTap when tapped', (tester) async {
        var tapped = false;
        await tester.pumpWidget(buildWidget(onTap: () => tapped = true));

        await tester.tap(find.byType(VideoClipThumbnailCard));
        expect(tapped, isTrue);
      });

      testWidgets('calls onLongPress when long-pressed', (tester) async {
        var longPressed = false;
        await tester.pumpWidget(
          buildWidget(onLongPress: () => longPressed = true),
        );

        await tester.longPress(find.byType(VideoClipThumbnailCard));
        expect(longPressed, isTrue);
      });

      testWidgets('does not call onTap when disabled', (tester) async {
        var tapped = false;
        await tester.pumpWidget(
          buildWidget(disabled: true, onTap: () => tapped = true),
        );

        await tester.tap(find.byType(VideoClipThumbnailCard));
        expect(tapped, isFalse);
      });

      testWidgets('does not call onLongPress when disabled', (tester) async {
        var longPressed = false;
        await tester.pumpWidget(
          buildWidget(disabled: true, onLongPress: () => longPressed = true),
        );

        await tester.longPress(find.byType(VideoClipThumbnailCard));
        expect(longPressed, isFalse);
      });
    });

    group('accessibility', () {
      testWidgets('has correct semantics when not selected', (tester) async {
        await tester.pumpWidget(buildWidget());

        expect(
          find.bySemanticsLabel(RegExp('Video clip.*seconds')),
          findsOneWidget,
        );
      });

      testWidgets('has correct semantics value when selected', (tester) async {
        await tester.pumpWidget(buildWidget(selectionIndex: 1));

        final semantics = tester.getSemantics(
          find.byType(VideoClipThumbnailCard),
        );
        expect(semantics.value, equals('Selected'));
      });
    });
  });
}
