// ABOUTME: View-layer navigation helpers for the video recorder. Navigation is
// ABOUTME: a UI concern, so it lives here rather than on VideoRecorderBloc; the
// ABOUTME: bloc only exposes VideoRecorderCameraPausedForNavigation so the
// ABOUTME: camera can be released cleanly during a push transition.

import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/blocs/video_recorder/video_recorder_bloc.dart';
import 'package:openvine/providers/video_editor_provider.dart';
import 'package:openvine/screens/feed/video_feed_page.dart';
import 'package:openvine/screens/library_screen.dart';
import 'package:openvine/screens/video_editor/video_editor_screen.dart';
import 'package:openvine/screens/video_metadata/video_metadata_screen.dart';

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
  final bloc = context.read<VideoRecorderBloc>();
  final recorderMode = bloc.state.recorderMode;

  if (!recorderMode.hasVideoEditor) {
    ref.read(videoEditorProvider.notifier).startRenderVideo();
  }

  final navigation = recorderMode.hasVideoEditor
      ? context.push(VideoEditorScreen.path)
      : context.push(VideoMetadataScreen.path);

  await _awaitPushTransition(context);
  bloc.add(const VideoRecorderCameraPausedForNavigation());

  await navigation;
  if (!context.mounted) return;
  bloc.add(const VideoRecorderInitializeRequested());
}

/// Navigates to the clips-only library, releasing the camera during the
/// transition and re-initializing it on return.
Future<void> openRecorderLibrary(BuildContext context) async {
  final bloc = context.read<VideoRecorderBloc>();

  final navigation = context.pushNamed(LibraryScreen.clipsOnlyRouteName);

  await _awaitPushTransition(context);
  bloc.add(const VideoRecorderCameraPausedForNavigation());

  await navigation;
  if (!context.mounted) return;
  bloc.add(const VideoRecorderInitializeRequested());
}

/// Waits for the current route's push transition to finish before returning.
///
/// Disposing the camera while the new route is still animating in would reveal
/// the camera-init screen behind it; this defers until the secondary animation
/// completes.
Future<void> _awaitPushTransition(BuildContext context) async {
  await WidgetsBinding.instance.endOfFrame;

  if (!context.mounted) return;

  final route = ModalRoute.of(context);
  if (route == null) return;

  final secondary = route.secondaryAnimation;
  if (secondary == null || secondary.status == AnimationStatus.completed) {
    return;
  }

  final completer = Completer<void>();
  void onStatus(AnimationStatus status) {
    if (status == AnimationStatus.completed && !completer.isCompleted) {
      secondary.removeStatusListener(onStatus);
      completer.complete();
    }
  }

  secondary.addStatusListener(onStatus);
  await completer.future;
}
