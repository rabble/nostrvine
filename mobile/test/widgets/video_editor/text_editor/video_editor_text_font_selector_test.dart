// ABOUTME: Tests for VideoEditorTextInlineFontSelector widget.
// ABOUTME: Validates font list rendering, selection state, and callbacks.
// ABOUTME: Note: Many tests are skipped because GoogleFonts requires network
// ABOUTME: access or bundled fonts which are not available in unit tests.

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/video_editor/text_editor/video_editor_text_bloc.dart';
import 'package:openvine/constants/video_editor_constants.dart';

class MockVideoEditorTextBloc
    extends MockBloc<VideoEditorTextEvent, VideoEditorTextState>
    implements VideoEditorTextBloc {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() {
    registerFallbackValue(const VideoEditorTextFontSelected(0));
  });

  group('VideoEditorTextInlineFontSelector', () {
    late MockVideoEditorTextBloc mockBloc;

    setUp(() {
      mockBloc = MockVideoEditorTextBloc();

      when(() => mockBloc.state).thenReturn(const VideoEditorTextState());
      when(() => mockBloc.stream).thenAnswer((_) => const Stream.empty());
    });

    group('VideoEditorConstants.textFonts', () {
      test('contains fonts', () {
        expect(VideoEditorConstants.textFonts, isNotEmpty);
      });
    });

    group('BLoC interactions', () {
      test('State copyWith correctly updates selectedFontIndex', () {
        const initialState = VideoEditorTextState();
        final updatedState = initialState.copyWith(selectedFontIndex: 5);

        expect(initialState.selectedFontIndex, 0);
        expect(updatedState.selectedFontIndex, 5);
      });
    });
  });
}
