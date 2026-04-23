// ABOUTME: Tests for ClipGalleryInstructionText widget
// ABOUTME: Verifies visibility based on editing and reordering states

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/blocs/video_editor/clip_editor/clip_editor_bloc.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/widgets/video_editor/clip_editor/gallery/video_editor_gallery_instruction_text.dart';

class _MockClipEditorBloc extends MockBloc<ClipEditorEvent, ClipEditorState>
    implements ClipEditorBloc {}

void main() {
  group('ClipGalleryInstructionText', () {
    late _MockClipEditorBloc bloc;

    setUp(() {
      bloc = _MockClipEditorBloc();
    });

    tearDown(() async {
      await bloc.close();
    });

    Widget buildSubject() {
      return BlocProvider<ClipEditorBloc>.value(
        value: bloc,
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: ClipGalleryInstructionText()),
        ),
      );
    }

    testWidgets('should show instruction text in normal state', (tester) async {
      whenListen(
        bloc,
        const Stream<ClipEditorState>.empty(),
        initialState: const ClipEditorState(),
      );

      await tester.pumpWidget(buildSubject());

      expect(
        find.text('Tap to edit. Hold and drag to reorder.'),
        findsOneWidget,
      );
    });

    testWidgets('should hide text when editing', (tester) async {
      whenListen(
        bloc,
        const Stream<ClipEditorState>.empty(),
        initialState: const ClipEditorState(isEditing: true),
      );

      await tester.pumpWidget(buildSubject());

      // When editing, AnimatedSwitcher shows SizedBox.shrink
      expect(
        find.text('Tap to edit. Hold and drag to reorder.'),
        findsNothing,
      );
    });

    testWidgets('should have zero opacity when reordering', (tester) async {
      whenListen(
        bloc,
        const Stream<ClipEditorState>.empty(),
        initialState: const ClipEditorState(isReordering: true),
      );

      await tester.pumpWidget(buildSubject());
      await tester.pump();

      // Find AnimatedOpacity and check opacity is 0
      final animatedOpacity = tester.widget<AnimatedOpacity>(
        find.byType(AnimatedOpacity),
      );
      expect(animatedOpacity.opacity, 0);
    });

    testWidgets('should have full opacity when not reordering', (tester) async {
      whenListen(
        bloc,
        const Stream<ClipEditorState>.empty(),
        initialState: const ClipEditorState(),
      );

      await tester.pumpWidget(buildSubject());

      // Not reordering - should have full opacity
      final animatedOpacity = tester.widget<AnimatedOpacity>(
        find.byType(AnimatedOpacity),
      );
      expect(animatedOpacity.opacity, 1);
    });
  });
}
