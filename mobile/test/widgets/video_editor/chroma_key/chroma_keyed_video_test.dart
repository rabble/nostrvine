import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/models/video_editor/clip_chroma_key.dart';
import 'package:openvine/widgets/video_editor/chroma_key/chroma_key_backdrop.dart';
import 'package:openvine/widgets/video_editor/chroma_key/chroma_keyed_video.dart';
import 'package:pro_video_editor/pro_video_editor.dart' show ChromaKey;

void main() {
  group(ChromaKeyedVideo, () {
    const child = Text('video', textDirection: TextDirection.ltr);

    testWidgets('renders the plain video when no key is set', (tester) async {
      await tester.pumpWidget(const ChromaKeyedVideo(child: child));

      expect(find.text('video'), findsOneWidget);
      // No key means nothing to composite behind the subject, so the preview
      // must not pay for a backdrop or a filter layer.
      expect(find.byType(ChromaKeyBackdrop), findsNothing);
      expect(find.byType(ImageFiltered), findsNothing);
    });

    testWidgets('keeps showing the video when shaders are unavailable', (
      tester,
    ) async {
      // `flutter_test` runs without Impeller, which is exactly the fallback
      // this has to survive: a backend that cannot run `ImageFilter.shader`
      // shows the unkeyed video rather than throwing, and the key still
      // applies to the exported file.
      await tester.pumpWidget(
        const ChromaKeyedVideo(
          chromaKey: ClipChromaKey(key: ChromaKey.greenScreen()),
          child: child,
        ),
      );
      await tester.pump();

      expect(ui.ImageFilter.isShaderFilterSupported, isFalse);
      expect(find.text('video'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });

    testWidgets('survives a key change without leaking the old shader', (
      tester,
    ) async {
      await tester.pumpWidget(
        const ChromaKeyedVideo(
          chromaKey: ClipChromaKey(key: ChromaKey.greenScreen()),
          child: child,
        ),
      );
      await tester.pumpWidget(
        const ChromaKeyedVideo(
          chromaKey: ClipChromaKey(key: ChromaKey.blueScreen()),
          child: child,
        ),
      );
      await tester.pumpWidget(const ChromaKeyedVideo(child: child));

      expect(find.text('video'), findsOneWidget);
      expect(tester.takeException(), isNull);
    });
  });
}
