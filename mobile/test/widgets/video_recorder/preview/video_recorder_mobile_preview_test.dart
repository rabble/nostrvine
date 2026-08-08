import 'dart:ui' show SemanticsAction;

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/video_recorder/video_recorder_bloc.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/widgets/video_recorder/preview/video_recorder_mobile_preview.dart';

class _MockVideoRecorderBloc
    extends MockBloc<VideoRecorderEvent, VideoRecorderBlocState>
    implements VideoRecorderBloc {}

void main() {
  group(VideoRecorderMobilePreview, () {
    final l10n = lookupAppLocalizations(const Locale('en'));

    late _MockVideoRecorderBloc recorderBloc;

    setUp(() {
      recorderBloc = _MockVideoRecorderBloc();
      when(() => recorderBloc.state).thenReturn(
        const VideoRecorderBlocState(),
      );
    });

    Widget buildSubject({required bool enableTapToFocus}) {
      return BlocProvider<VideoRecorderBloc>.value(
        value: recorderBloc,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: VideoRecorderMobilePreview(
              enableTapToFocus: enableTapToFocus,
            ),
          ),
        ),
      );
    }

    testWidgets('describes the camera preview and tap-to-focus action', (
      tester,
    ) async {
      final semanticsHandle = tester.ensureSemantics();
      try {
        await tester.pumpWidget(buildSubject(enableTapToFocus: true));

        final finder = find.bySemanticsLabel(
          l10n.videoRecorderCameraPreviewLabel,
        );
        final node = tester.getSemantics(finder);
        final data = node.getSemanticsData();
        final semantics = tester.widget<Semantics>(
          find.descendant(
            of: find.byType(VideoRecorderMobilePreview),
            matching: find.byType(Semantics),
          ),
        );

        expect(data.label, l10n.videoRecorderCameraPreviewLabel);
        expect(data.hasAction(SemanticsAction.tap), isTrue);
        expect(semantics.properties.button, isTrue);
        expect(
          semantics.properties.hintOverrides?.onTapHint,
          l10n.videoRecorderCameraPreviewFocusHint,
        );

        semantics.properties.onTap!();
        verify(
          () => recorderBloc.add(
            const VideoRecorderFocusPointSet(Offset(0.5, 0.5)),
          ),
        ).called(1);
      } finally {
        semanticsHandle.dispose();
      }
    });

    testWidgets('does not expose a button when tap-to-focus is disabled', (
      tester,
    ) async {
      final semanticsHandle = tester.ensureSemantics();
      try {
        await tester.pumpWidget(buildSubject(enableTapToFocus: false));

        expect(
          find.bySemanticsLabel(l10n.videoRecorderCameraPreviewLabel),
          findsNothing,
        );
      } finally {
        semanticsHandle.dispose();
      }
    });
  });
}
