import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
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

  setUpAll(() {
    registerFallbackValue(const VideoRecorderZoomLevelSet(1));
  });

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

    group('interaction', () {
      List<VideoRecorderZoomLevelSet> capturedZoomEvents() {
        return verify(
          () => bloc.add(captureAny()),
        ).captured.whereType<VideoRecorderZoomLevelSet>().toList();
      }

      testWidgets('dragging left zooms in', (tester) async {
        await tester.pumpWidget(buildWidget(zoomLevel: 2));
        await tester.pumpAndSettle();

        await tester.drag(
          find.byType(VideoRecorderZoomIndicator),
          const Offset(-110, 0),
        );
        await tester.pumpAndSettle();

        final events = capturedZoomEvents();
        expect(events, isNotEmpty);
        expect(events.last.value, greaterThan(2));
      });

      testWidgets('dragging right zooms out', (tester) async {
        await tester.pumpWidget(buildWidget(zoomLevel: 3));
        await tester.pumpAndSettle();

        await tester.drag(
          find.byType(VideoRecorderZoomIndicator),
          const Offset(110, 0),
        );
        await tester.pumpAndSettle();

        final events = capturedZoomEvents();
        expect(events, isNotEmpty);
        expect(events.last.value, lessThan(3));
      });

      testWidgets('never dispatches beyond the camera max', (tester) async {
        await tester.pumpWidget(
          buildWidget(zoomLevel: 4.8),
        );
        await tester.pumpAndSettle();

        await tester.drag(
          find.byType(VideoRecorderZoomIndicator),
          const Offset(-1000, 0),
        );
        await tester.pumpAndSettle();

        for (final event in capturedZoomEvents()) {
          expect(event.value, lessThanOrEqualTo(5));
        }
      });

      testWidgets('eases onto a major mark when released nearby', (
        tester,
      ) async {
        await tester.pumpWidget(buildWidget());
        await tester.pumpAndSettle();

        // 1× dragged ~0.95 lands at a raw 1.95×, inside the 2× detent radius,
        // so the emitted value is pulled snug to 2× rather than left at 1.95×.
        await tester.drag(
          find.byType(VideoRecorderZoomIndicator),
          const Offset(-104.5, 0),
        );
        await tester.pumpAndSettle();

        final events = capturedZoomEvents();
        expect(events, isNotEmpty);
        expect(events.last.value, closeTo(2, 0.02));
      });

      testWidgets('reaches a non-integer camera max next to a detent', (
        tester,
      ) async {
        // maxZoom 2.1 sits inside the 2× detent radius; the bound must stay
        // reachable rather than being pulled back toward 2×.
        await tester.pumpWidget(buildWidget(maxZoomLevel: 2.1));
        await tester.pumpAndSettle();

        await tester.drag(
          find.byType(VideoRecorderZoomIndicator),
          const Offset(-1000, 0),
        );
        await tester.pumpAndSettle();

        final events = capturedZoomEvents();
        expect(events, isNotEmpty);
        expect(events.last.value, closeTo(2.1, 1e-9));
      });

      testWidgets('reaches a non-integer camera min next to a detent', (
        tester,
      ) async {
        // minZoom 0.95 sits inside the 1× detent radius.
        await tester.pumpWidget(buildWidget(minZoomLevel: 0.95));
        await tester.pumpAndSettle();

        await tester.drag(
          find.byType(VideoRecorderZoomIndicator),
          const Offset(1000, 0),
        );
        await tester.pumpAndSettle();

        final events = capturedZoomEvents();
        expect(events, isNotEmpty);
        expect(events.last.value, closeTo(0.95, 1e-9));
      });

      testWidgets('ticks haptics when crossing a major mark', (tester) async {
        final calls = <MethodCall>[];
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
            .setMockMethodCallHandler(SystemChannels.platform, (call) async {
              calls.add(call);
              return null;
            });
        addTearDown(() {
          TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
              .setMockMethodCallHandler(SystemChannels.platform, null);
        });

        await tester.pumpWidget(buildWidget());
        await tester.pumpAndSettle();

        // 1× → ~2× crosses the 2× whole-factor mark.
        await tester.drag(
          find.byType(VideoRecorderZoomIndicator),
          const Offset(-110, 0),
        );
        await tester.pumpAndSettle();

        expect(
          calls.where((c) => c.method == 'HapticFeedback.vibrate'),
          isNotEmpty,
        );
      });

      testWidgets('does not capture drags while hidden', (tester) async {
        await tester.pumpWidget(buildWidget(showZoomIndicator: false));
        await tester.pumpAndSettle();

        await tester.drag(
          find.byType(VideoRecorderZoomIndicator),
          const Offset(-110, 0),
          warnIfMissed: false,
        );
        await tester.pumpAndSettle();

        verifyNever(
          () => bloc.add(any(that: isA<VideoRecorderZoomLevelSet>())),
        );
      });
    });
  });
}
