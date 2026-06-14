import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/video_recorder/video_recorder_bloc.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/widgets/video_recorder/video_recorder_zoom_indicator.dart';

class _MockVideoRecorderBloc
    extends MockBloc<VideoRecorderEvent, VideoRecorderBlocState>
    implements VideoRecorderBloc {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  group(VideoRecorderZoomIndicator, () {
    late _MockVideoRecorderBloc bloc;

    setUp(() {
      bloc = _MockVideoRecorderBloc();
    });

    Widget buildWidget({
      double zoomLevel = 1.0,
      double minZoomLevel = 0.5,
      double maxZoomLevel = 5.0,
      bool showZoomIndicator = true,
    }) {
      when(() => bloc.state).thenReturn(
        VideoRecorderBlocState(
          zoomLevel: zoomLevel,
          minZoomLevel: minZoomLevel,
          maxZoomLevel: maxZoomLevel,
          showZoomIndicator: showZoomIndicator,
          isCameraInitialized: true,
        ),
      );

      return BlocProvider<VideoRecorderBloc>.value(
        value: bloc,
        child: const MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(
            body: Center(child: VideoRecorderZoomIndicator()),
          ),
        ),
      );
    }

    group('renders', () {
      testWidgets('shows the live zoom value while zooming', (tester) async {
        await tester.pumpWidget(buildWidget(zoomLevel: 2.4));
        await tester.pumpAndSettle();

        expect(find.text('2.4×'), findsOneWidget);
        expect(find.byType(CustomPaint), findsWidgets);
      });

      testWidgets('drops the trailing .0 on clean zoom factors', (
        tester,
      ) async {
        await tester.pumpWidget(buildWidget());
        await tester.pumpAndSettle();

        expect(find.text('1×'), findsOneWidget);
      });
    });

    group('visibility', () {
      testWidgets('is visible while the user is zooming', (tester) async {
        await tester.pumpWidget(buildWidget());
        await tester.pumpAndSettle();

        final opacity = tester.widget<AnimatedOpacity>(
          find.byType(AnimatedOpacity),
        );
        expect(opacity.opacity, equals(1));
      });

      testWidgets('is hidden when not zooming', (tester) async {
        await tester.pumpWidget(buildWidget(showZoomIndicator: false));
        await tester.pumpAndSettle();

        final opacity = tester.widget<AnimatedOpacity>(
          find.byType(AnimatedOpacity),
        );
        expect(opacity.opacity, equals(0));
      });

      testWidgets('excludes the zoom semantics label when hidden', (
        tester,
      ) async {
        final semantics = tester.ensureSemantics();
        try {
          await tester.pumpWidget(buildWidget(showZoomIndicator: false));
          await tester.pumpAndSettle();

          expect(find.bySemanticsLabel('Zoom to 1×'), findsNothing);
        } finally {
          semantics.dispose();
        }
      });

      testWidgets('renders nothing when the camera has a single zoom stop', (
        tester,
      ) async {
        await tester.pumpWidget(
          buildWidget(minZoomLevel: 1, maxZoomLevel: 1),
        );
        await tester.pumpAndSettle();

        expect(find.byType(AnimatedOpacity), findsNothing);
        expect(find.text('1×'), findsNothing);
      });
    });
  });
}
