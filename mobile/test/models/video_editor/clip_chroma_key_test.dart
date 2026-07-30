import 'dart:ui';

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/models/video_editor/clip_chroma_key.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

void main() {
  group(ClipChromaKey, () {
    group('backgroundType', () {
      test('is transparent when nothing fills the keyed area', () {
        const key = ClipChromaKey(key: ChromaKey.greenScreen());
        expect(key.backgroundType, ClipChromaKeyBackgroundType.transparent);
        expect(key.needsComposition, isTrue);
      });

      test('is color when the key carries a fill colour', () {
        const key = ClipChromaKey(
          key: ChromaKey.greenScreen(backgroundColor: Color(0xFF102030)),
        );
        expect(key.backgroundType, ClipChromaKeyBackgroundType.color);
        expect(key.needsComposition, isFalse);
      });

      test('is image when the key carries a background image', () {
        final key = ClipChromaKey(
          key: ChromaKey(backgroundImage: EditorLayerImage.file('/a/bg.png')),
        );
        expect(key.backgroundType, ClipChromaKeyBackgroundType.image);
        expect(key.needsComposition, isFalse);
      });

      test('is video when a backdrop clip is set, and needs a composition', () {
        const key = ClipChromaKey(
          key: ChromaKey.greenScreen(),
          backgroundVideoPath: '/a/backdrop.mp4',
        );
        expect(key.backgroundType, ClipChromaKeyBackgroundType.video);
        // The single-track segment path cannot put a video behind the subject,
        // so this background must be pre-rendered.
        expect(key.needsComposition, isTrue);
      });
    });

    group('withVideoBackground', () {
      test('drops a colour fill so the layer below can show through', () {
        const key = ClipChromaKey(
          key: ChromaKey.greenScreen(backgroundColor: Color(0xFF102030)),
        );

        final swapped = key.withVideoBackground('/a/backdrop.mp4');

        expect(swapped.backgroundType, ClipChromaKeyBackgroundType.video);
        // A colour fill left in place would paint over the backdrop and the
        // composition would render a solid rectangle instead of the video.
        expect(swapped.key.backgroundColor, isNull);
        expect(swapped.key.isTransparent, isTrue);
      });

      test('keeps the tuning the user dialled in', () {
        const key = ClipChromaKey(
          key: ChromaKey(
            color: Color(0xFF00FF00),
            similarity: 0.31,
            smoothness: 0.13,
            spill: 0.7,
          ),
        );

        final swapped = key.withVideoBackground('/a/backdrop.mp4');

        expect(swapped.key.color, const Color(0xFF00FF00));
        expect(swapped.key.similarity, 0.31);
        expect(swapped.key.smoothness, 0.13);
        expect(swapped.key.spill, 0.7);
      });
    });

    test('withKey drops a video backdrop', () {
      const key = ClipChromaKey(
        key: ChromaKey.greenScreen(),
        backgroundVideoPath: '/a/backdrop.mp4',
      );

      final swapped = key.withKey(
        const ChromaKey.greenScreen(backgroundColor: Color(0xFF000000)),
      );

      expect(swapped.backgroundType, ClipChromaKeyBackgroundType.color);
      expect(swapped.backgroundVideoPath, isNull);
    });

    group('serialization', () {
      const documentsPath = '/documents';

      test('round-trips the tuning', () {
        // Deliberately not the default key colour: a colour that round-trips
        // only because `fromMap` fell back to the default would prove nothing.
        const key = ClipChromaKey(
          key: ChromaKey(
            color: Color(0xFF12B4A0),
            similarity: 0.27,
            smoothness: 0.11,
            spill: 0.35,
            backgroundColor: Color(0xFF123456),
          ),
        );

        final restored = ClipChromaKey.fromJson(key.toJson(), documentsPath);

        expect(restored, key);
      });

      test('re-anchors file paths under the documents directory', () {
        // iOS rewrites the container path on every app update, so a persisted
        // absolute path goes stale — only the basename survives.
        final key = ClipChromaKey(
          key: ChromaKey(
            backgroundImage: EditorLayerImage.file('/old/container/bg.png'),
          ),
          backgroundVideoPath: '/old/container/backdrop.mp4',
        );

        final json = key.toJson();
        expect(json['backgroundImage'], 'bg.png');
        expect(json['backgroundVideo'], 'backdrop.mp4');

        final restored = ClipChromaKey.fromJson(json, documentsPath);
        expect(restored.backgroundImagePath, '$documentsPath/bg.png');
        expect(restored.backgroundVideoPath, '$documentsPath/backdrop.mp4');
      });

      test('restores a transparent key with no background at all', () {
        const key = ClipChromaKey(key: ChromaKey.blueScreen());

        final restored = ClipChromaKey.fromJson(key.toJson(), documentsPath);

        expect(
          restored.backgroundType,
          ClipChromaKeyBackgroundType.transparent,
        );
        expect(restored.backgroundVideoPath, isNull);
      });
    });

    group('equality', () {
      test('compares the background image by path, not by identity', () {
        // `ChromaKey` compares its `EditorLayerImage` by identity — that class
        // has no value equality. The cubit's state is Equatable over this
        // type, so an identity compare would emit a "changed" state for an
        // unchanged key and rebuild the preview shader on every emit.
        final a = ClipChromaKey(
          key: ChromaKey(backgroundImage: EditorLayerImage.file('/bg.png')),
        );
        final b = ClipChromaKey(
          key: ChromaKey(backgroundImage: EditorLayerImage.file('/bg.png')),
        );

        expect(a, b);
        expect(a.hashCode, b.hashCode);
      });

      test('separates keys that differ only in tuning', () {
        const a = ClipChromaKey(key: ChromaKey(similarity: 0.15));
        const b = ClipChromaKey(key: ChromaKey(similarity: 0.4));

        expect(a, isNot(b));
      });

      test('separates keys that differ only in backdrop clip', () {
        const a = ClipChromaKey(
          key: ChromaKey.greenScreen(),
          backgroundVideoPath: '/a.mp4',
        );
        const b = ClipChromaKey(
          key: ChromaKey.greenScreen(),
          backgroundVideoPath: '/b.mp4',
        );

        expect(a, isNot(b));
      });
    });
  });
}
