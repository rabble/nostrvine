// ABOUTME: Widget tests for the UploadFailureListener success-tracking state machine.
// ABOUTME: Covers: success while authenticated, success buffered during re-auth then
// ABOUTME: flushed on restore, BackgroundPublishVanished not miscounted as success,
// ABOUTME: and BackgroundPublishBloc state-test coverage for recentlySucceededIds.

import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/background_publish/background_publish_bloc.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/main.dart' as app;
import 'package:openvine/models/divine_video_draft.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/router/navigator_keys.dart';
import 'package:openvine/services/auth_service.dart';
import 'package:openvine/services/video_publish/video_publish_service.dart';

// ---------------------------------------------------------------------------
// Test doubles
// ---------------------------------------------------------------------------

class _MockBackgroundPublishBloc
    extends MockBloc<BackgroundPublishEvent, BackgroundPublishState>
    implements BackgroundPublishBloc {}

class _MockAuthService extends Mock implements AuthService {}

class _FakeDraft extends Fake implements DivineVideoDraft {
  _FakeDraft(this._id);

  final String _id;

  @override
  String get id => _id;
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

/// Builds a minimal harness matching production topology: [UploadFailureListener]
/// wraps [MaterialApp], while [ProviderScope] and [BlocProvider] remain above
/// the listener.
///
/// The [MaterialApp] is keyed to [NavigatorKeys.root] so that
/// [_showPublishSuccessSnackbar] can resolve its [ScaffoldMessenger] via
/// the same key the production code uses.
Widget _buildHarness({
  required _MockBackgroundPublishBloc publishBloc,
  required _MockAuthService authService,
  bool wireRootNavigatorKey = true,
}) {
  return ProviderScope(
    overrides: [authServiceProvider.overrideWithValue(authService)],
    child: BlocProvider<BackgroundPublishBloc>.value(
      value: publishBloc,
      child: app.UploadFailureListener(
        child: MaterialApp(
          // Wire the real NavigatorKeys.root so the snackbar helper can find
          // the ScaffoldMessenger and Localizations ancestors from
          // NavigatorKeys.root.currentContext.
          navigatorKey: wireRootNavigatorKey ? NavigatorKeys.root : null,
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: const Scaffold(body: SizedBox.shrink()),
        ),
      ),
    ),
  );
}

/// Creates a [BackgroundUpload] with result == null (in-progress).
BackgroundUpload _inProgress(String id) =>
    BackgroundUpload(draft: _FakeDraft(id), result: null, progress: 0.5);

/// A [BackgroundPublishState] that carries success signals, with no remaining
/// uploads — mirrors what the bloc emits on [PublishSuccess].
BackgroundPublishState _succeededState(String id, [String? secondId]) =>
    BackgroundPublishState(
      recentlySucceededIds: {id, ?secondId},
    );

/// A [BackgroundPublishState] where upload [id] disappeared without a success
/// signal — mirrors what the bloc emits on [BackgroundPublishVanished].
BackgroundPublishState _vanishedState() => const BackgroundPublishState();

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  late _MockBackgroundPublishBloc publishBloc;
  late _MockAuthService authService;
  late StreamController<BackgroundPublishState> publishStream;

  setUp(() {
    publishBloc = _MockBackgroundPublishBloc();
    authService = _MockAuthService();
    publishStream = StreamController<BackgroundPublishState>.broadcast();
  });

  tearDown(() {
    publishStream.close();
  });

  /// Stubs [publishBloc] with the given initial state and stream.
  void stubPublishBloc(BackgroundPublishState initial) {
    when(() => publishBloc.state).thenReturn(initial);
    whenListen(publishBloc, publishStream.stream, initialState: initial);
  }

  group('UploadFailureListener success tracking', () {
    testWidgets(
      'shows snackbar immediately when upload succeeds while authenticated',
      (tester) async {
        stubPublishBloc(const BackgroundPublishState());
        when(() => authService.isAuthenticated).thenReturn(true);

        await tester.pumpWidget(
          _buildHarness(publishBloc: publishBloc, authService: authService),
        );

        // Bloc emits a state with recentlySucceededIds populated (true success).
        publishStream.add(_succeededState('draft-1'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        expect(tester.takeException(), isNull);
        final l10n = lookupAppLocalizations(const Locale('en'));
        expect(find.text(l10n.uploadPublishedCountMessage(1)), findsOneWidget);
      },
    );

    testWidgets('shows plural snackbar when multiple uploads succeed', (
      tester,
    ) async {
      stubPublishBloc(const BackgroundPublishState());
      when(() => authService.isAuthenticated).thenReturn(true);

      await tester.pumpWidget(
        _buildHarness(publishBloc: publishBloc, authService: authService),
      );

      publishStream.add(_succeededState('draft-1', 'draft-2'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(tester.takeException(), isNull);
      final l10n = lookupAppLocalizations(const Locale('en'));
      expect(find.text(l10n.uploadPublishedCountMessage(2)), findsOneWidget);
    });

    testWidgets(
      'buffers success while unauthenticated then flushes on re-auth',
      (tester) async {
        stubPublishBloc(const BackgroundPublishState());
        when(() => authService.isAuthenticated).thenReturn(false);

        await tester.pumpWidget(
          _buildHarness(publishBloc: publishBloc, authService: authService),
        );

        // Upload succeeds while user is NOT authenticated.
        publishStream.add(_succeededState('draft-2'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        final l10n = lookupAppLocalizations(const Locale('en'));
        // No snackbar yet — auth is not restored.
        expect(find.text(l10n.uploadPublishedCountMessage(1)), findsNothing);

        // Auth is now restored. Emit another state to trigger the listener.
        when(() => authService.isAuthenticated).thenReturn(true);
        publishStream.add(const BackgroundPublishState());
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        expect(tester.takeException(), isNull);
        // Buffered success must now be flushed.
        expect(find.text(l10n.uploadPublishedCountMessage(1)), findsOneWidget);
      },
    );

    testWidgets('keeps buffered success when root navigator is unavailable', (
      tester,
    ) async {
      stubPublishBloc(const BackgroundPublishState());
      when(() => authService.isAuthenticated).thenReturn(false);

      await tester.pumpWidget(
        _buildHarness(
          publishBloc: publishBloc,
          authService: authService,
          wireRootNavigatorKey: false,
        ),
      );

      publishStream.add(_succeededState('draft-buffered'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      final l10n = lookupAppLocalizations(const Locale('en'));
      expect(find.text(l10n.uploadPublishedCountMessage(1)), findsNothing);

      when(() => authService.isAuthenticated).thenReturn(true);
      publishStream.add(const BackgroundPublishState());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(tester.takeException(), isNull);
      expect(find.text(l10n.uploadPublishedCountMessage(1)), findsNothing);

      await tester.pumpWidget(
        _buildHarness(publishBloc: publishBloc, authService: authService),
      );
      publishStream.add(const BackgroundPublishState());
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(tester.takeException(), isNull);
      expect(find.text(l10n.uploadPublishedCountMessage(1)), findsOneWidget);
    });

    testWidgets(
      'does not throw or show snackbar when root navigator is unavailable',
      (tester) async {
        stubPublishBloc(const BackgroundPublishState());
        when(() => authService.isAuthenticated).thenReturn(true);

        await tester.pumpWidget(
          _buildHarness(
            publishBloc: publishBloc,
            authService: authService,
            wireRootNavigatorKey: false,
          ),
        );

        publishStream.add(_succeededState('draft-no-root'));
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        final l10n = lookupAppLocalizations(const Locale('en'));
        expect(tester.takeException(), isNull);
        expect(find.text(l10n.uploadPublishedCountMessage(1)), findsNothing);
      },
    );

    testWidgets('does not duplicate snackbar for replayed success state', (
      tester,
    ) async {
      stubPublishBloc(const BackgroundPublishState());
      when(() => authService.isAuthenticated).thenReturn(true);

      await tester.pumpWidget(
        _buildHarness(publishBloc: publishBloc, authService: authService),
      );

      final succeeded = _succeededState('draft-replayed');
      publishStream.add(succeeded);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));
      publishStream.add(succeeded);
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 50));

      expect(tester.takeException(), isNull);
      final l10n = lookupAppLocalizations(const Locale('en'));
      expect(find.text(l10n.uploadPublishedCountMessage(1)), findsOneWidget);
    });

    testWidgets(
      'does not show snackbar when upload vanishes via BackgroundPublishVanished',
      (tester) async {
        // BackgroundPublishVanished emits a state with an empty
        // recentlySucceededIds — no success signal should be shown.
        stubPublishBloc(
          BackgroundPublishState(uploads: [_inProgress('draft-vanish')]),
        );
        when(() => authService.isAuthenticated).thenReturn(true);

        await tester.pumpWidget(
          _buildHarness(publishBloc: publishBloc, authService: authService),
        );

        // Upload vanishes — draft removed from state but no success signal.
        publishStream.add(_vanishedState());
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        // No snackbar must appear for a vanished upload.
        final l10n = lookupAppLocalizations(const Locale('en'));
        expect(tester.takeException(), isNull);
        expect(find.text(l10n.uploadPublishedCountMessage(1)), findsNothing);
        expect(find.text(l10n.uploadPublishedCountMessage(2)), findsNothing);
      },
    );
  });
}
