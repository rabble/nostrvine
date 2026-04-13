// ABOUTME: Tests for ClipGalleryInstructionText widget
// ABOUTME: Verifies visibility based on editing and reordering states

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/blocs/video_editor/clip_editor/clip_editor_bloc.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/widgets/video_editor/clip_editor/gallery/video_editor_gallery_instruction_text.dart';

void main() {
  group('ClipGalleryInstructionText', () {
    late ClipEditorBloc bloc;

    tearDown(() async {
      await bloc.close();
    });

    testWidgets('should show instruction text in normal state', (tester) async {
      bloc = _TestClipEditorBloc();

      await tester.pumpWidget(
        BlocProvider<ClipEditorBloc>.value(
          value: bloc,
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: ClipGalleryInstructionText()),
          ),
        ),
      );

      expect(
        find.text('Tap to edit. Hold and drag to reorder.'),
        findsOneWidget,
      );
    });

    testWidgets('should hide text when editing', (tester) async {
      bloc = _TestClipEditorBloc(
        initialState: const ClipEditorState(isEditing: true),
      );

      await tester.pumpWidget(
        BlocProvider<ClipEditorBloc>.value(
          value: bloc,
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: ClipGalleryInstructionText()),
          ),
        ),
      );

      // When editing, AnimatedSwitcher shows SizedBox.shrink
      expect(
        find.text('Tap to edit. Hold and drag to reorder.'),
        findsNothing,
      );
    });

    testWidgets('should have zero opacity when reordering', (tester) async {
      bloc = _TestClipEditorBloc(
        initialState: const ClipEditorState(isReordering: true),
      );

      await tester.pumpWidget(
        BlocProvider<ClipEditorBloc>.value(
          value: bloc,
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: ClipGalleryInstructionText()),
          ),
        ),
      );

      await tester.pump();

      // Find AnimatedOpacity and check opacity is 0
      final animatedOpacity = tester.widget<AnimatedOpacity>(
        find.byType(AnimatedOpacity),
      );
      expect(animatedOpacity.opacity, 0);
    });

    testWidgets('should have full opacity when not reordering', (tester) async {
      bloc = _TestClipEditorBloc();

      await tester.pumpWidget(
        BlocProvider<ClipEditorBloc>.value(
          value: bloc,
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: Scaffold(body: ClipGalleryInstructionText()),
          ),
        ),
      );

      // Not reordering - should have full opacity
      final animatedOpacity = tester.widget<AnimatedOpacity>(
        find.byType(AnimatedOpacity),
      );
      expect(animatedOpacity.opacity, 1);
    });
  });
}

class _TestClipEditorBloc extends ClipEditorBloc {
  _TestClipEditorBloc({
    ClipEditorState initialState = const ClipEditorState(),
  }) {
    emit(initialState);
  }
}
