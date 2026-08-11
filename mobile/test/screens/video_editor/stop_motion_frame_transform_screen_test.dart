// ABOUTME: Widget tests for the stop-motion still crop/rotate/flip screen.
// ABOUTME: Covers the chrome it renders and the cancel (no-result) close.

import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:models/models.dart' as model show AspectRatio;
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/screens/video_editor/stop_motion_frame_transform_screen.dart';

Future<Uint8List> _pngBytes(int width, int height) async {
  final recorder = ui.PictureRecorder();
  Canvas(recorder).drawRect(
    Rect.fromLTWH(0, 0, width.toDouble(), height.toDouble()),
    Paint()..color = const Color(0xFF3355FF),
  );
  final image = await recorder.endRecording().toImage(width, height);
  final data = await image.toByteData(format: ui.ImageByteFormat.png);
  return data!.buffer.asUint8List();
}

/// Advances the clock without waiting for a settled tree: the branded loading
/// indicator animates continuously, so `pumpAndSettle` never returns here.
Future<void> _pumpFrames(WidgetTester tester, {int frames = 40}) async {
  for (var i = 0; i < frames; i++) {
    await tester.pump(const Duration(milliseconds: 50));
  }
}

void main() {
  late Directory tempDir;
  late String framePath;

  setUp(() async {
    tempDir = Directory.systemTemp.createTempSync('frame_transform_screen');
    framePath = '${tempDir.path}/frame.png';
    await File(framePath).writeAsBytes(await _pngBytes(120, 213));
  });

  tearDown(() {
    if (tempDir.existsSync()) tempDir.deleteSync(recursive: true);
  });

  group(StopMotionFrameTransformScreen, () {
    final l10n = lookupAppLocalizations(const Locale('en'));

    late Object? pushResult;
    late bool popped;

    Future<void> open(WidgetTester tester) async {
      pushResult = 'not-popped';
      popped = false;

      await tester.pumpWidget(
        MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          theme: VineTheme.theme,
          home: Builder(
            builder: (context) => Scaffold(
              body: Center(
                child: GestureDetector(
                  onTap: () async {
                    // Mirrors `transformStopMotionFrame`: a non-opaque route,
                    // so the editor underneath keeps building.
                    pushResult = await Navigator.of(context).push<Uint8List>(
                      PageRouteBuilder<Uint8List>(
                        opaque: false,
                        barrierColor: VineTheme.surfaceBackground,
                        pageBuilder: (_, _, _) =>
                            StopMotionFrameTransformScreen(
                              framePath: framePath,
                              targetAspectRatio: model.AspectRatio.vertical,
                            ),
                        transitionsBuilder: (_, animation, _, child) =>
                            FadeTransition(opacity: animation, child: child),
                      ),
                    );
                    popped = true;
                  },
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ),
      );

      await tester.tap(find.text('open'));
      await _pumpFrames(tester);
    }

    /// Closes the editor and lets pro_image_editor's own transition loop run
    /// out — it keeps a `Timer` alive that the test binding otherwise flags at
    /// teardown.
    Future<void> settleEditor(WidgetTester tester) async {
      if (find.text('open').evaluate().isEmpty) {
        await tester.tap(
          find.byWidgetPredicate(
            (widget) =>
                widget is DivineIconButton &&
                widget.icon == DivineIconName.arrowLeft,
          ),
        );
      }
      // pro_image_editor's fit-to-screen loop drives itself off wall-clock
      // `DateTime.now()` while awaiting `Future.delayed`, so pumping fake time
      // never ends it. Let real time pass instead, or the binding reports a
      // pending timer at teardown.
      for (var round = 0; round < 2; round++) {
        await tester.runAsync(
          () => Future<void>.delayed(const Duration(milliseconds: 700)),
        );
        await _pumpFrames(tester, frames: 10);
      }
    }

    Finder iconButton(DivineIconName icon) => find.byWidgetPredicate(
      (widget) => widget is DivineIconButton && widget.icon == icon,
    );

    testWidgets('renders the transform chrome over the still', (tester) async {
      await open(tester);

      expect(find.text(l10n.videoEditorTransformRotateLabel), findsOneWidget);
      expect(find.text(l10n.videoEditorTransformFlipLabel), findsOneWidget);
      expect(find.text(l10n.videoEditorTransformResetLabel), findsOneWidget);
      // A still has nothing to play, unlike the clip transform's bar.
      expect(find.text(l10n.videoEditorTransformPlayLabel), findsNothing);
      expect(tester.takeException(), isNull);

      await settleEditor(tester);
    });

    testWidgets('system back closes without an error', (tester) async {
      await open(tester);

      // The Android back gesture pops through the editor's own PopScope
      // instead of the app-bar button.
      await tester.binding.handlePopRoute();
      await settleEditor(tester);

      expect(tester.takeException(), isNull);
      expect(popped, isTrue);
      expect(pushResult, isNull);
      expect(find.text('open'), findsOneWidget);
    });

    testWidgets('back pops once with no result and no error', (tester) async {
      await open(tester);

      await tester.tap(iconButton(DivineIconName.arrowLeft));
      await settleEditor(tester);

      expect(tester.takeException(), isNull);
      expect(popped, isTrue);
      expect(pushResult, isNull);
      // The caller's screen is back, not a blank route.
      expect(find.text('open'), findsOneWidget);
    });
  });
}
