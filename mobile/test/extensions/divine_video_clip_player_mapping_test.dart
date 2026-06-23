import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart' as model;
import 'package:openvine/extensions/divine_video_clip_player_mapping.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:pro_video_editor/pro_video_editor.dart' as editor;

void main() {
  DivineVideoClip clip({editor.ClipTransition? transition}) => DivineVideoClip(
    id: 'c1',
    video: editor.EditorVideo.file(File('/tmp/clip.mp4')),
    duration: const Duration(seconds: 5),
    recordedAt: DateTime(2024),
    targetAspectRatio: model.AspectRatio.square,
    originalAspectRatio: 1,
    trimStart: const Duration(seconds: 1),
    trimEnd: const Duration(milliseconds: 500),
    volume: 0.5,
    playbackSpeed: 2,
    transition: transition,
  );

  group('DivineVideoClipPlayerMapping', () {
    test('maps trim, volume and speed onto the player clip', () {
      final vc = clip().toPlayerVideoClip()!;

      expect(vc.uri, equals('/tmp/clip.mp4'));
      expect(vc.start, equals(const Duration(seconds: 1)));
      expect(vc.end, equals(const Duration(milliseconds: 4500)));
      expect(vc.volume, equals(0.5));
      expect(vc.playbackSpeed, equals(2));
    });

    test('start and end overrides take precedence over the clip trim', () {
      final vc = clip().toPlayerVideoClip(
        start: const Duration(seconds: 2),
        end: const Duration(seconds: 3),
      )!;

      expect(vc.start, equals(const Duration(seconds: 2)));
      expect(vc.end, equals(const Duration(seconds: 3)));
    });

    test('does not carry the transition to the player (seam preview)', () {
      // The preview composites transitions by playing a pre-rendered seam clip
      // between neighbours, so the player clip itself is identical whether or
      // not the source clip carries a transition.
      final withoutTransition = clip().toPlayerVideoClip()!;
      final withTransition = clip(
        transition: const editor.ClipTransition(
          type: editor.ClipTransitionType.dissolve,
        ),
      ).toPlayerVideoClip()!;

      expect(withTransition.uri, equals(withoutTransition.uri));
      expect(withTransition.start, equals(withoutTransition.start));
      expect(withTransition.end, equals(withoutTransition.end));
      expect(withTransition.volume, equals(withoutTransition.volume));
      expect(
        withTransition.playbackSpeed,
        equals(withoutTransition.playbackSpeed),
      );
    });
  });
}
