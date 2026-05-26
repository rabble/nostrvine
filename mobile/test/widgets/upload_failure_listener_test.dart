// ABOUTME: Widget tests for the UploadFailureListener success-tracking state machine.
// ABOUTME: Covers: success while authenticated, success buffered during re-auth then
// ABOUTME: flushed on restore, and a vanished failed upload not miscounted as success.

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

/// Builds a minimal harness that wraps [UploadFailureListener] inside a
/// [ProviderScope] (with [authServiceProvider] overridden) and a
/// [BlocProvider] for [BackgroundPublishBloc].
///
/// The [MaterialApp] is keyed to [NavigatorKeys.root] so that
/// [_showPublishSuccessSnackbar] can resolve its [ScaffoldMessenger] via
/// the same key the production code uses.
Widget _buildHarness({
  required _MockBackgroundPublishBloc publishBloc,
  required _MockAuthService authService,
}) {
  return ProviderScope(
    overrides: [authServiceProvider.overrideWithValue(authService)],
    child: MaterialApp(
      // Wire the real NavigatorKeys.root so the snackbar helper can find the
      // ScaffoldMessenger ancestor from NavigatorKeys.root.currentContext.
      navigatorKey: NavigatorKeys.root,
      localizationsDelegates: AppLocalizations.localizationsDelegates,
      supportedLocales: AppLocalizations.supportedLocales,
      home: BlocProvider<BackgroundPublishBloc>.value(
        value: publishBloc,
        child: const app.UploadFailureListener(
          child: Scaffold(body: SizedBox.shrink()),
        ),
      ),
    ),
  );
}

/// Creates a [BackgroundUpload] with result == null (in-progress).
BackgroundUpload _inProgress(String id) => BackgroundUpload(
  draft: _FakeDraft(id),
  result: null,
  progress: 0.5,
);

/// Creates a [BackgroundUpload] with a [PublishError] result.
BackgroundUpload _failed(String id) => BackgroundUpload(
  draft: _FakeDraft(id),
  result: const PublishError('Upload failed'),
  progress: 1.0,
);

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
        // Start with an empty state (no uploads), then add an in-progress
        // upload, then mark it as complete — mirroring the real app lifecycle.
        stubPublishBloc(const BackgroundPublishState());

        when(() => authService.isAuthenticated).thenReturn(true);

        await tester.pumpWidget(
          _buildHarness(publishBloc: publishBloc, authService: authService),
        );

        // Step 1: Upload starts (in-progress) — listener records the ID.
        publishStream.add(
          BackgroundPublishState(uploads: [_inProgress('draft-1')]),
        );
        await tester.pump();

        // Step 2: Upload completes — draft-1 disappears from state entirely
        // (neither in-progress nor failed).
        publishStream.add(const BackgroundPublishState());
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        // A success snackbar must be visible.
        final l10n = lookupAppLocalizations(const Locale('en'));
        expect(
          find.text(l10n.uploadPublishedCountMessage(1)),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'buffers success while unauthenticated then flushes on re-auth',
      (tester) async {
        // Start empty, then add in-progress upload.
        stubPublishBloc(const BackgroundPublishState());

        when(() => authService.isAuthenticated).thenReturn(false);

        await tester.pumpWidget(
          _buildHarness(publishBloc: publishBloc, authService: authService),
        );

        // Upload starts while user is NOT authenticated.
        publishStream.add(
          BackgroundPublishState(uploads: [_inProgress('draft-2')]),
        );
        await tester.pump();

        // Upload succeeds while still unauthenticated: draft-2 disappears.
        publishStream.add(const BackgroundPublishState());
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        // No snackbar yet — auth is not restored.
        final l10n = lookupAppLocalizations(const Locale('en'));
        expect(find.text(l10n.uploadPublishedCountMessage(1)), findsNothing);

        // Auth is now restored. Emit a new state to trigger the listener
        // again, this time with isAuthenticated == true.
        when(() => authService.isAuthenticated).thenReturn(true);
        publishStream.add(const BackgroundPublishState());
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        // Buffered success must now be flushed.
        expect(
          find.text(l10n.uploadPublishedCountMessage(1)),
          findsOneWidget,
        );
      },
    );

    testWidgets(
      'does not count a vanished failed upload as a success',
      (tester) async {
        // Start empty, user is NOT authenticated yet (prevents failure sheets
        // from showing, keeping the test focused on success counting).
        stubPublishBloc(const BackgroundPublishState());
        when(() => authService.isAuthenticated).thenReturn(false);

        await tester.pumpWidget(
          _buildHarness(publishBloc: publishBloc, authService: authService),
        );

        // Both the in-progress and the pre-existing failed upload appear
        // together. With auth=false the failure sheet is suppressed, and the
        // listener records draft-3 as in-progress and draft-fail as failed.
        publishStream.add(
          BackgroundPublishState(
            uploads: [_inProgress('draft-3'), _failed('draft-fail')],
          ),
        );
        await tester.pump();

        // Now auth is restored. The failed upload is dismissed (removed from
        // state) and the in-progress upload also disappears (succeeds). Only
        // draft-3 was ever in-progress, so success count must be 1, not 2.
        when(() => authService.isAuthenticated).thenReturn(true);
        publishStream.add(const BackgroundPublishState());
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 50));

        final l10n = lookupAppLocalizations(const Locale('en'));
        // Must show exactly 1 success.
        expect(
          find.text(l10n.uploadPublishedCountMessage(1)),
          findsOneWidget,
        );
        // The plural "2 videos …" form must not appear.
        expect(
          find.text(l10n.uploadPublishedCountMessage(2)),
          findsNothing,
        );
      },
    );
  });
}
