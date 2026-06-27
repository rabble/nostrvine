// ABOUTME: Tests for the recorder-exit auth gate in video_recorder_navigation.
// ABOUTME: Covers the authenticated (proceed) and restore-then-terminal
// ABOUTME: (draft + route to Welcome) paths for both recorder-exit entries.

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/video_recorder/video_recorder_bloc.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/models/clip_manager_state.dart';
import 'package:openvine/models/video_editor/video_editor_provider_state.dart';
import 'package:openvine/models/video_recorder/video_recorder_mode.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/clip_manager_provider.dart';
import 'package:openvine/providers/video_editor_provider.dart';
import 'package:openvine/screens/auth/welcome_screen.dart';
import 'package:openvine/screens/library_screen.dart';
import 'package:openvine/screens/video_editor/video_editor_screen.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/widgets/video_recorder/video_recorder_navigation.dart';

class _MockAuthService extends Mock implements AuthService {}

class _MockVideoRecorderBloc
    extends MockBloc<VideoRecorderEvent, VideoRecorderBlocState>
    implements VideoRecorderBloc {}

class _FakeVideoEditorNotifier extends VideoEditorNotifier {
  bool saveAsDraftCalled = false;
  bool startRenderVideoCalled = false;
  DraftSaveOutcome saveResult = DraftSaveOutcome.saved;

  @override
  VideoEditorProviderState build() => VideoEditorProviderState();

  @override
  Future<DraftSaveOutcome> saveAsDraft({
    bool enforceCreateNewDraft = false,
  }) async {
    saveAsDraftCalled = true;
    return saveResult;
  }

  @override
  Future<void> startRenderVideo() async {
    startRenderVideoCalled = true;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  late _MockAuthService mockAuthService;
  late _MockVideoRecorderBloc recorderBloc;
  late _FakeVideoEditorNotifier fakeEditor;
  late _FakeClipManagerNotifier fakeClipManager;

  setUp(() {
    mockAuthService = _MockAuthService();
    recorderBloc = _MockVideoRecorderBloc();
    fakeEditor = _FakeVideoEditorNotifier();
    fakeClipManager = _FakeClipManagerNotifier();

    when(() => recorderBloc.state).thenReturn(const VideoRecorderBlocState());
    when(
      () => mockAuthService.authStateStream,
    ).thenAnswer((_) => const Stream<AuthState>.empty());
  });

  Widget buildHarness() {
    final router = GoRouter(
      initialLocation: '/recorder',
      routes: [
        GoRoute(
          path: '/recorder',
          builder: (context, state) => BlocProvider<VideoRecorderBloc>.value(
            value: recorderBloc,
            child: const _RecorderHarness(),
          ),
        ),
        GoRoute(
          path: VideoEditorScreen.path,
          builder: (_, _) => const _StubScreen(label: 'editor'),
        ),
        GoRoute(
          path: '/library-clips',
          name: LibraryScreen.clipsOnlyRouteName,
          builder: (_, _) => const _StubScreen(label: 'library'),
        ),
        GoRoute(
          path: WelcomeScreen.path,
          builder: (_, _) => const _StubScreen(label: 'welcome'),
        ),
      ],
    );

    return ProviderScope(
      overrides: [
        authServiceProvider.overrideWithValue(mockAuthService),
        videoEditorProvider.overrideWith(() => fakeEditor),
        clipManagerProvider.overrideWith(() => fakeClipManager),
      ],
      child: MaterialApp.router(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        routerConfig: router,
      ),
    );
  }

  group('recorder-exit auth gate', () {
    group('when already authenticated', () {
      setUp(() {
        when(
          () => mockAuthService.authState,
        ).thenReturn(AuthState.authenticated);
      });

      testWidgets('openVideoEditorFromRecorder proceeds to the editor '
          'without saving a draft', (tester) async {
        await tester.pumpWidget(buildHarness());
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('open-editor')));
        await tester.pumpAndSettle();

        expect(find.text('editor'), findsOneWidget);
        expect(fakeEditor.saveAsDraftCalled, isFalse);
      });

      testWidgets('openRecorderLibrary proceeds to the library '
          'without saving a draft', (tester) async {
        await tester.pumpWidget(buildHarness());
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('open-library')));
        await tester.pumpAndSettle();

        expect(find.text('library'), findsOneWidget);
        expect(fakeEditor.saveAsDraftCalled, isFalse);
      });

      testWidgets('openVideoEditorFromRecorder mutes clips in lip-sync mode', (
        tester,
      ) async {
        when(() => recorderBloc.state).thenReturn(
          const VideoRecorderBlocState(recorderMode: VideoRecorderMode.lipSync),
        );

        await tester.pumpWidget(buildHarness());
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('open-editor')));
        await tester.pumpAndSettle();

        expect(fakeClipManager.muteAllClipsCalled, isTrue);
        expect(find.text('editor'), findsOneWidget);
      });

      testWidgets('openVideoEditorFromRecorder does not mute clips in '
          'capture mode', (tester) async {
        await tester.pumpWidget(buildHarness());
        await tester.pumpAndSettle();

        await tester.tap(find.byKey(const Key('open-editor')));
        await tester.pumpAndSettle();

        expect(fakeClipManager.muteAllClipsCalled, isFalse);
        expect(find.text('editor'), findsOneWidget);
      });
    });

    group('when restore resolves to terminal unauthenticated', () {
      setUp(() {
        when(() => mockAuthService.authState).thenReturn(AuthState.checking);
        when(
          () => mockAuthService.authStateStream,
        ).thenAnswer((_) => Stream<AuthState>.value(AuthState.unauthenticated));
      });

      testWidgets('openVideoEditorFromRecorder saves a draft, shows the '
          'snackbar, and routes to Welcome', (tester) async {
        await tester.pumpWidget(buildHarness());
        await tester.pumpAndSettle();
        final l10n = lookupAppLocalizations(const Locale('en'));

        await tester.tap(find.byKey(const Key('open-editor')));
        await tester.pumpAndSettle();

        expect(fakeEditor.saveAsDraftCalled, isTrue);
        expect(
          find.text(l10n.uploadFailureSheetSavedToDraftsSnackbar),
          findsOneWidget,
        );
        expect(find.text('welcome'), findsOneWidget);
        expect(find.text('editor'), findsNothing);

        await tester.pumpAndSettle(const Duration(seconds: 5));
      });

      testWidgets('openRecorderLibrary saves a draft, shows the snackbar, '
          'and routes to Welcome', (tester) async {
        await tester.pumpWidget(buildHarness());
        await tester.pumpAndSettle();
        final l10n = lookupAppLocalizations(const Locale('en'));

        await tester.tap(find.byKey(const Key('open-library')));
        await tester.pumpAndSettle();

        expect(fakeEditor.saveAsDraftCalled, isTrue);
        expect(
          find.text(l10n.uploadFailureSheetSavedToDraftsSnackbar),
          findsOneWidget,
        );
        expect(find.text('welcome'), findsOneWidget);
        expect(find.text('library'), findsNothing);

        await tester.pumpAndSettle(const Duration(seconds: 5));
      });

      testWidgets('openVideoEditorFromRecorder with a save already in flight '
          'shows no snackbar and stays on the recorder', (tester) async {
        fakeEditor.saveResult = DraftSaveOutcome.alreadyInProgress;

        await tester.pumpWidget(buildHarness());
        await tester.pumpAndSettle();
        final l10n = lookupAppLocalizations(const Locale('en'));

        await tester.tap(find.byKey(const Key('open-editor')));
        await tester.pumpAndSettle();

        expect(fakeEditor.saveAsDraftCalled, isTrue);
        expect(
          find.text(l10n.uploadFailureSheetSavedToDraftsSnackbar),
          findsNothing,
        );
        expect(find.text(l10n.videoMetadataFailedToSaveSnackbar), findsNothing);
        expect(find.text('welcome'), findsNothing);
        expect(find.text('editor'), findsNothing);
        expect(find.byKey(const Key('open-editor')), findsOneWidget);
      });
    });
  });
}

class _FakeClipManagerNotifier extends ClipManagerNotifier {
  bool muteAllClipsCalled = false;

  @override
  ClipManagerState build() => ClipManagerState();

  @override
  void muteAllClips() {
    muteAllClipsCalled = true;
  }
}

class _RecorderHarness extends ConsumerWidget {
  const _RecorderHarness();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Scaffold(
      body: Column(
        children: [
          ElevatedButton(
            key: const Key('open-editor'),
            onPressed: () =>
                unawaited(openVideoEditorFromRecorder(context, ref)),
            child: const Text('open editor'),
          ),
          ElevatedButton(
            key: const Key('open-library'),
            onPressed: () => unawaited(openRecorderLibrary(context, ref)),
            child: const Text('open library'),
          ),
        ],
      ),
    );
  }
}

class _StubScreen extends StatelessWidget {
  const _StubScreen({required this.label});

  final String label;

  @override
  Widget build(BuildContext context) {
    return Scaffold(body: Center(child: Text(label)));
  }
}
