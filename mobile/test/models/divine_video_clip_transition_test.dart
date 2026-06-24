import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart' as model;
import 'package:openvine/models/divine_video_clip.dart';
import 'package:pro_video_editor/pro_video_editor.dart' as editor;

void main() {
  DivineVideoClip clip({editor.ClipTransition? transition}) => DivineVideoClip(
    id: 'c1',
    video: editor.EditorVideo.file(File('/docs/clip.mp4')),
    duration: const Duration(seconds: 5),
    recordedAt: DateTime(2024),
    targetAspectRatio: model.AspectRatio.square,
    originalAspectRatio: 1,
    transition: transition,
  );

  group('DivineVideoClip transition', () {
    test('omits transition from JSON for a hard cut', () {
      expect(clip().toJson().containsKey('transition'), isFalse);
    });

    test('round-trips a transition through JSON', () {
      final source = clip(
        transition: const editor.ClipTransition(
          type: editor.ClipTransitionType.wipe,
          duration: Duration(milliseconds: 600),
          direction: editor.ClipTransitionDirection.right,
        ),
      );

      final json = source.toJson();
      expect((json['transition'] as Map)['type'], equals('wipe'));

      final restored = DivineVideoClip.fromJson(
        json,
        '/docs',
        useOriginalPath: true,
      );
      expect(restored.transition?.type, equals(editor.ClipTransitionType.wipe));
      expect(
        restored.transition?.direction,
        equals(editor.ClipTransitionDirection.right),
      );
      expect(
        restored.transition?.duration,
        equals(const Duration(milliseconds: 600)),
      );
    });

    test('copyWith clears the transition with clearTransition', () {
      final withTransition = clip(
        transition: const editor.ClipTransition(
          type: editor.ClipTransitionType.dissolve,
        ),
      );

      expect(withTransition.copyWith().transition, isNotNull);
      expect(withTransition.copyWith(clearTransition: true).transition, isNull);
    });

    test('copyWith sets a new transition', () {
      const dissolve = editor.ClipTransition(
        type: editor.ClipTransitionType.dissolve,
      );
      expect(
        clip().copyWith(transition: dissolve).transition,
        equals(dissolve),
      );
    });

    test('drops an unparseable transition instead of aborting the load', () {
      final json = clip(
        transition: const editor.ClipTransition(
          type: editor.ClipTransitionType.dissolve,
        ),
      ).toJson();
      // Simulate a forward-incompatible / corrupt draft: an enum name this
      // build can't resolve. fromMap resolves via `byName`, which throws —
      // the load must degrade to a hard cut, not blow up the whole draft.
      json['transition'] = <String, dynamic>{
        ...(json['transition'] as Map).cast<String, dynamic>(),
        'type': 'someFutureTransitionType',
      };

      late DivineVideoClip restored;
      expect(
        () => restored = DivineVideoClip.fromJson(
          json,
          '/docs',
          useOriginalPath: true,
        ),
        returnsNormally,
      );
      expect(restored.transition, isNull);
    });
  });
}
