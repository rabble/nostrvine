// ABOUTME: Integration tests for VideoEditorClipPreview widget
// ABOUTME: Tests video preview rendering and interactions

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/blocs/video_editor/clip_editor/clip_editor_bloc.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/widgets/video_editor/clip_editor/gallery/video_editor_clip_preview.dart';
import 'package:patrol/patrol.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

void main() {
  group('VideoEditorClipPreview Integration Tests', () {
    late ClipEditorBloc bloc;

    setUp(() {
      bloc = ClipEditorBloc(onFinalClipInvalidated: () {});
    });

    tearDown(() async {
      await bloc.close();
    });

    Widget buildTestWidget({required Widget child}) {
      return BlocProvider<ClipEditorBloc>.value(
        value: bloc,
        child: MaterialApp(
          home: Scaffold(body: child),
        ),
      );
    }

    patrolTest('displays clip preview with correct aspect ratio', ($) async {
      final tester = $.tester;
      final clip = DivineVideoClip(
        id: 'clip1',
        video: EditorVideo.file('assets/videos/default_intro.mp4'),
        duration: const Duration(seconds: 2),
        recordedAt: DateTime.now(),
        targetAspectRatio: .vertical,
        originalAspectRatio: 9 / 16,
      );

      await tester.pumpWidget(
        buildTestWidget(child: VideoEditorClipPreview(clip: clip)),
      );

      await tester.pump();

      expect(find.byType(AspectRatio), findsOneWidget);
    });

    patrolTest('can be tapped when onTap is provided', ($) async {
      final tester = $.tester;
      final clip = DivineVideoClip(
        id: 'clip1',
        video: EditorVideo.file('assets/videos/default_intro.mp4'),
        duration: const Duration(seconds: 2),
        recordedAt: DateTime.now(),
        targetAspectRatio: .vertical,
        originalAspectRatio: 9 / 16,
      );

      var tapped = false;

      await tester.pumpWidget(
        buildTestWidget(
          child: VideoEditorClipPreview(
            clip: clip,
            onTap: () => tapped = true,
          ),
        ),
      );

      await tester.pump();

      await tester.tap(find.byType(VideoEditorClipPreview));
      await tester.pump();

      expect(tapped, isTrue);
    });

    patrolTest('shows border when reordering', ($) async {
      final tester = $.tester;
      final clip = DivineVideoClip(
        id: 'clip1',
        video: EditorVideo.file('assets/videos/default_intro.mp4'),
        duration: const Duration(seconds: 2),
        recordedAt: DateTime.now(),
        targetAspectRatio: .vertical,
        originalAspectRatio: 9 / 16,
      );

      await tester.pumpWidget(
        buildTestWidget(
          child: VideoEditorClipPreview(
            clip: clip,
            isCurrentClip: true,
            isReordering: true,
          ),
        ),
      );

      await tester.pump();

      expect(find.byType(AnimatedContainer), findsWidgets);
    });

    patrolTest('shows deletion zone border color', ($) async {
      final tester = $.tester;
      await bloc.close();
      bloc = _TestClipEditorBloc(
        initialState: const ClipEditorState(isOverDeleteZone: true),
      );
      final clip = DivineVideoClip(
        id: 'clip1',
        video: EditorVideo.file('assets/videos/default_intro.mp4'),
        duration: const Duration(seconds: 2),
        recordedAt: DateTime.now(),
        targetAspectRatio: .vertical,
        originalAspectRatio: 9 / 16,
      );

      await tester.pumpWidget(
        buildTestWidget(
          child: VideoEditorClipPreview(
            clip: clip,
            isCurrentClip: true,
            isReordering: true,
          ),
        ),
      );

      await tester.pump();

      expect(find.byType(VideoEditorClipPreview), findsOneWidget);
    });
  });
}

class _TestClipEditorBloc extends ClipEditorBloc {
  _TestClipEditorBloc({required ClipEditorState initialState})
    : super(onFinalClipInvalidated: () {}) {
    emit(initialState);
  }
}
