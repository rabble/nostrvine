// ABOUTME: Widget tests for the captions editor screen.
// ABOUTME: Covers generation states, cue editing, and the confirm result.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/video_editor/captions_editor/captions_editor_cubit.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/models/video_editor/caption_track.dart';
import 'package:openvine/screens/video_editor/video_captions_editor_screen.dart';
import 'package:openvine/services/video_editor/caption_generation_service.dart';

class _MockCaptionGenerationService extends Mock
    implements CaptionGenerationService {}

void main() {
  final l10n = lookupAppLocalizations(const Locale('en'));

  late _MockCaptionGenerationService service;

  setUp(() {
    service = _MockCaptionGenerationService();
  });

  void stubOutcome(CaptionGenerationOutcome outcome) {
    when(
      () => service.generateForClips(
        clips: any(named: 'clips'),
        localeIdentifier: any(named: 'localeIdentifier'),
      ),
    ).thenAnswer((_) async => outcome);
  }

  Widget buildScreen({
    CaptionRenderMode mode = CaptionRenderMode.overlay,
    List<CaptionCue>? initialCues,
    void Function(CaptionsEditorResult?)? onResult,
  }) {
    // A real GoRouter hosts the flow because the screen pops via the
    // go_router `context.pop` extension, mirroring production (the editor
    // pushes it with Navigator.push inside a GoRouter app).
    return MaterialApp.router(
      routerConfig: GoRouter(
        routes: [
          GoRoute(
            path: '/',
            builder: (_, _) => Builder(
              builder: (context) => Center(
                child: ElevatedButton(
                  onPressed: () async {
                    final result =
                        await Navigator.of(
                          context,
                        ).push<CaptionsEditorResult>(
                          MaterialPageRoute(
                            builder: (_) => VideoCaptionsEditorScreen(
                              mode: mode,
                              presetId: 'classic',
                              languageTag: 'en-US',
                              clips: const [],
                              totalDuration: const Duration(seconds: 6),
                              initialCues: initialCues,
                              cubit: CaptionsEditorCubit(
                                clips: const [],
                                totalDuration: const Duration(seconds: 6),
                                mode: mode,
                                presetId: 'classic',
                                languageTag: 'en-US',
                                initialCues: initialCues,
                                generationService: service,
                              ),
                            ),
                          ),
                        );
                    onResult?.call(result);
                  },
                  child: const Text('open'),
                ),
              ),
            ),
          ),
        ],
      ),
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
    );
  }

  Future<void> open(WidgetTester tester) async {
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  group(VideoCaptionsEditorScreen, () {
    testWidgets('shows generated cues after transcription', (tester) async {
      stubOutcome(
        const CaptionsGenerated([
          CaptionCue(
            id: 'cue-0',
            text: 'Hello world.',
            start: Duration.zero,
            end: Duration(seconds: 1),
          ),
        ]),
      );

      await tester.pumpWidget(buildScreen());
      await open(tester);

      expect(find.text('Hello world.'), findsOneWidget);
    });

    testWidgets(
      'failure state offers writing captions manually',
      (tester) async {
        stubOutcome(
          const CaptionsFailed(CaptionGenerationFailure.recognizerUnavailable),
        );

        await tester.pumpWidget(buildScreen());
        await open(tester);

        expect(
          find.text(l10n.videoEditorCaptionsUnavailableMessage),
          findsOneWidget,
        );

        await tester.tap(find.text(l10n.videoEditorCaptionsStartEmptyButton));
        await tester.pumpAndSettle();

        expect(find.text(l10n.videoEditorCaptionsAddCue), findsOneWidget);
      },
    );

    testWidgets(
      'confirm pops the edited cues and drops cleared ones',
      (tester) async {
        CaptionsEditorResult? result;
        await tester.pumpWidget(
          buildScreen(
            initialCues: const [
              CaptionCue(
                id: 'cue-0',
                text: 'Keep me.',
                start: Duration.zero,
                end: Duration(seconds: 1),
              ),
              CaptionCue(
                id: 'cue-1',
                text: 'Clear me.',
                start: Duration(seconds: 2),
                end: Duration(seconds: 3),
              ),
            ],
            onResult: (r) => result = r,
          ),
        );
        await open(tester);

        await tester.enterText(
          find.widgetWithText(TextFormField, 'Clear me.'),
          '   ',
        );
        await tester.tap(
          find.bySemanticsLabel(l10n.videoEditorCaptionsDoneSemanticLabel),
        );
        await tester.pumpAndSettle();

        final confirmed = result! as CaptionsConfirmed;
        expect(confirmed.cues.map((c) => c.text), equals(['Keep me.']));
        expect(confirmed.track.mode, equals(CaptionRenderMode.overlay));
        expect(confirmed.track.cues.map((c) => c.id), equals(['cue-0']));
      },
    );

    testWidgets('existing session skips generation', (tester) async {
      await tester.pumpWidget(
        buildScreen(
          initialCues: const [
            CaptionCue(
              id: 'cue-0',
              text: 'Existing.',
              start: Duration.zero,
              end: Duration(seconds: 1),
            ),
          ],
        ),
      );
      await open(tester);

      expect(find.text('Existing.'), findsOneWidget);
      verifyNever(
        () => service.generateForClips(
          clips: any(named: 'clips'),
          localeIdentifier: any(named: 'localeIdentifier'),
        ),
      );
    });
  });
}
