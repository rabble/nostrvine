// ABOUTME: Widget tests for ChromaKeyBackdrop's background-type dispatch.
// ABOUTME: The video branch is left out: it builds a real native player.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/models/video_editor/clip_chroma_key.dart';
import 'package:openvine/widgets/video_editor/chroma_key/chroma_key_backdrop.dart';
import 'package:pro_video_editor/pro_video_editor.dart'
    show ChromaKey, EditorLayerImage;

void main() {
  group(ChromaKeyBackdrop, () {
    Future<void> pump(WidgetTester tester, ClipChromaKey chromaKey) {
      return tester.pumpWidget(
        Directionality(
          textDirection: TextDirection.ltr,
          child: ChromaKeyBackdrop(chromaKey: chromaKey),
        ),
      );
    }

    testWidgets('shows the checkerboard when nothing replaces the screen', (
      tester,
    ) async {
      await pump(
        tester,
        const ClipChromaKey(key: ChromaKey.greenScreen()),
      );

      expect(find.byType(ChromaKeyTransparencyCheckerboard), findsOneWidget);
    });

    testWidgets('fills with the chosen colour', (tester) async {
      await pump(
        tester,
        const ClipChromaKey(
          key: ChromaKey(backgroundColor: Color(0xFF123456)),
        ),
      );

      final box = tester.widget<ColoredBox>(find.byType(ColoredBox));
      expect(box.color, const Color(0xFF123456));
      expect(find.byType(ChromaKeyTransparencyCheckerboard), findsNothing);
    });

    testWidgets('shows the picked image stretched to the frame', (
      tester,
    ) async {
      await pump(
        tester,
        ClipChromaKey(
          key: ChromaKey(backgroundImage: EditorLayerImage.file('/tmp/bg.png')),
        ),
      );

      // `fit: fill` rather than `cover`: the renderer stretches a background
      // image to the frame, and the preview has to show the same distortion.
      final image = tester.widget<Image>(find.byType(Image));
      expect(image.fit, BoxFit.fill);
      expect(find.byType(ChromaKeyTransparencyCheckerboard), findsNothing);
    });
  });
}
