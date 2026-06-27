// ABOUTME: View-layer navigation helpers for the video recorder. Navigation is
// ABOUTME: a UI concern, so it lives here rather than on VideoRecorderBloc; the
// ABOUTME: bloc only exposes VideoRecorderCameraPausedForNavigation so the
// ABOUTME: camera can be released cleanly during a push transition.

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/blocs/video_recorder/video_recorder_bloc.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/video_recorder/video_recorder_mode.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/clip_manager_provider.dart';
import 'package:openvine/providers/video_editor_provider.dart';
import 'package:openvine/screens/auth/welcome_screen.dart';
import 'package:openvine/screens/feed/video_feed_page.dart';
import 'package:openvine/screens/library_screen.dart';
import 'package:openvine/screens/video_editor/video_editor_screen.dart';
import 'package:openvine/screens/video_metadata/video_metadata_screen.dart';
import 'package:openvine/utils/await_push_transition.dart';

/// Closes the video recorder.
///
/// Pops if there is a route to pop to, otherwise navigates home (the recorder
/// was reached via `go`, so there is nothing on the stack).
void closeVideoRecorder(BuildContext context) {
  if (context.canPop()) {
    context.pop();
  } else {
    context.go(VideoFeedPage.pathForIndex(0));
  }
}

/// Navigates to the video editor (or the metadata screen, depending on mode),
/// releasing the camera during the transition and re-initializing it on return.
///
/// Mirrors the legacy `VideoRecorderNotifier.openVideoEditor`: the camera is
/// disposed only after the push animation is past the visible frame (disposing
/// immediately would flash the camera-init screen behind the transition), and
/// re-initialized once the pushed route pops.
Future<void> openVideoEditorFromRecorder(
  BuildContext context,
  WidgetRef ref,
) async {
  if (!await _ensureAuthenticatedForRecorderExit(context, ref)) return;
  if (!context.mounted) return;

  final bloc = context.read<VideoRecorderBloc>();
  final recorderMode = bloc.state.recorderMode;

  // Lip-sync records against a selected sound, so silence the clips before the
  // editor: only the chosen audio should be heard, with the clips muted and
  // the sound carried in as its own track (seeded on editor init).
  if (recorderMode == VideoRecorderMode.lipSync) {
    ref.read(clipManagerProvider.notifier).muteAllClips();
  }

  if (!recorderMode.hasVideoEditor) {
    ref.read(videoEditorProvider.notifier).startRenderVideo();
  }

  final navigation = recorderMode.hasVideoEditor
      ? context.push(VideoEditorScreen.path)
      : context.push(VideoMetadataScreen.path);

  await awaitPushTransition(context);
  bloc.add(const VideoRecorderCameraPausedForNavigation());

  await navigation;
  if (!context.mounted) return;
  bloc.add(const VideoRecorderInitializeRequested());
}

/// Navigates to the clips-only library, releasing the camera during the
/// transition and re-initializing it on return.
Future<void> openRecorderLibrary(BuildContext context, WidgetRef ref) async {
  if (!await _ensureAuthenticatedForRecorderExit(context, ref)) return;
  if (!context.mounted) return;

  final bloc = context.read<VideoRecorderBloc>();

  final navigation = context.pushNamed(LibraryScreen.clipsOnlyRouteName);

  await awaitPushTransition(context);
  bloc.add(const VideoRecorderCameraPausedForNavigation());

  await navigation;
  if (!context.mounted) return;
  bloc.add(const VideoRecorderInitializeRequested());
}

Future<bool> _ensureAuthenticatedForRecorderExit(
  BuildContext context,
  WidgetRef ref,
) async {
  final authGate = ref.read(recorderExitAuthGateProvider);
  final showedRestoreSnackbar = authGate.isRestoring;
  if (showedRestoreSnackbar && context.mounted) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.l10n.authSigningYouIn),
        duration: authGate.restoreTimeout,
      ),
    );
  }

  final authenticated = await authGate.waitForAuthenticatedOrTerminal();
  if (showedRestoreSnackbar) {
    if (context.mounted) {
      ScaffoldMessenger.of(context).hideCurrentSnackBar();
    }
  }

  if (authenticated) return true;

  final outcome = await ref
      .read(videoEditorProvider.notifier)
      .saveAsDraft(enforceCreateNewDraft: true);

  // A save was already in flight; don't double-report or navigate.
  if (outcome == DraftSaveOutcome.alreadyInProgress) return false;
  if (!context.mounted) return false;

  final saved = outcome == DraftSaveOutcome.saved;
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      content: Text(
        saved
            ? context.l10n.uploadFailureSheetSavedToDraftsSnackbar
            : context.l10n.videoMetadataFailedToSaveSnackbar,
      ),
    ),
  );

  if (saved) {
    context.go(WelcomeScreen.path);
  }
  return false;
}
