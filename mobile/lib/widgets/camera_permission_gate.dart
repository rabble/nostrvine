// ABOUTME: Declarative permission gate that wraps camera screen
// ABOUTME: Renders permission UI or camera based on CameraPermissionBloc state

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/blocs/camera_permission/camera_permission_bloc.dart';
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/screens/feed/video_feed_page.dart';
import 'package:openvine/widgets/video_recorder/video_recorder_bottom_bar.dart';
import 'package:tv_static_effect/tv_static_effect.dart';
import 'package:unified_logger/unified_logger.dart';

/// A declarative gate widget that handles camera/microphone permissions.
///
/// Renders appropriate UI based on permission state:
/// - Loading: Shows camera placeholder with loading indicator
/// - canRequest: Shows bottom sheet style UI with Continue/Not now buttons
/// - requiresSettings: Shows bottom sheet style UI with Go to Settings/Not now
/// - authorized: Renders the [child] (camera screen)
///
/// Handles app lifecycle to refresh permissions when returning from background.
class CameraPermissionGate extends StatefulWidget {
  const CameraPermissionGate({required this.child, super.key});

  /// The widget to render when permissions are authorized (typically camera screen)
  final Widget child;

  @override
  State<CameraPermissionGate> createState() => _CameraPermissionGateState();
}

class _CameraPermissionGateState extends State<CameraPermissionGate>
    with WidgetsBindingObserver {
  bool _wasInBackground = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);

    Log.info(
      '🔐 CameraPermissionGate initState',
      name: 'CameraPermissionGate',
      category: LogCategory.video,
    );

    // Always refresh permission check when screen opens
    // This handles cases where user denied previously and is returning
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final bloc = context.read<CameraPermissionBloc>();
      Log.info(
        '🔐 Current permission state: ${bloc.state.runtimeType}',
        name: 'CameraPermissionGate',
        category: LogCategory.video,
      );
      if (bloc.state is! CameraPermissionLoaded) {
        Log.info(
          '🔐 Triggering permission refresh',
          name: 'CameraPermissionGate',
          category: LogCategory.video,
        );
        bloc.add(const CameraPermissionRefresh());
      }
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    super.didChangeAppLifecycleState(state);

    switch (state) {
      case AppLifecycleState.resumed:
        // Refresh permissions when returning from real background (e.g., Settings app)
        if (_wasInBackground) {
          _wasInBackground = false;
          context.read<CameraPermissionBloc>().add(
            const CameraPermissionRefresh(),
          );
        }
      case AppLifecycleState.paused:
      case AppLifecycleState.hidden:
        _wasInBackground = true;
      case AppLifecycleState.inactive:
      case AppLifecycleState.detached:
        break;
    }
  }

  void _popBack() {
    if (!mounted) return;
    final router = GoRouter.of(context);
    if (router.canPop()) {
      router.pop();
    } else {
      context.go(VideoFeedPage.pathForIndex(0));
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<CameraPermissionBloc, CameraPermissionState>(
      listener: (context, state) {
        Log.info(
          '🔐 Permission state changed: ${state.runtimeType}',
          name: 'CameraPermissionGate',
          category: LogCategory.video,
        );
        // When user denies native permission dialog, pop back to home
        if (state is CameraPermissionDenied) {
          _popBack();
        }
      },
      builder: (context, state) {
        Log.debug(
          '🔐 Building with state: ${state.runtimeType}',
          name: 'CameraPermissionGate',
          category: LogCategory.video,
        );

        if (kIsWeb) {
          return _PermissionScreen(
            title: context.l10n.cameraPermissionWebUnsupportedTitle,
            description: context.l10n.cameraPermissionWebUnsupportedDescription,
            buttonLabel: context.l10n.cameraPermissionBackToFeed,
            onAction: _popBack,
            onClose: _popBack,
          );
        }

        return switch (state) {
          CameraPermissionInitial() => const _LoadingIndicator(),
          CameraPermissionLoading() => const _LoadingIndicator(),
          CameraPermissionError() => _PermissionScreen(
            title: context.l10n.cameraPermissionErrorTitle,
            description: context.l10n.cameraPermissionErrorDescription,
            buttonLabel: context.l10n.cameraPermissionRetry,
            onAction: () {
              context.read<CameraPermissionBloc>().add(
                const CameraPermissionRefresh(),
              );
            },
            onClose: _popBack,
          ),
          CameraPermissionDenied() => const _LoadingIndicator(),
          CameraPermissionLoaded(:final status) => switch (status) {
            CameraPermissionStatus.authorized => widget.child,
            CameraPermissionStatus.canRequest => _PermissionScreen(
              title: context.l10n.cameraPermissionAllowAccessTitle,
              description: context.l10n.cameraPermissionAllowAccessDescription,
              buttonLabel: context.l10n.cameraPermissionContinue,
              onAction: () {
                context.read<CameraPermissionBloc>().add(
                  const CameraPermissionRequest(),
                );
              },
              onClose: _popBack,
            ),
            CameraPermissionStatus.requiresSettings => _PermissionScreen(
              title: context.l10n.cameraPermissionAllowAccessTitle,
              description: context.l10n.cameraPermissionAllowAccessDescription,
              buttonLabel: context.l10n.cameraPermissionGoToSettings,
              onAction: () {
                context.read<CameraPermissionBloc>().add(
                  const CameraPermissionOpenSettings(),
                );
              },
              onClose: _popBack,
            ),
          },
        };
      },
    );
  }
}

/// Loading indicator centered on screen
class _LoadingIndicator extends StatelessWidget {
  const _LoadingIndicator();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: CircularProgressIndicator(color: VineTheme.vineGreen),
    );
  }
}

/// Permission screen with TV static background, sticker, title, description,
/// and a primary action button. Used for all permission states.
class _PermissionScreen extends StatelessWidget {
  const _PermissionScreen({
    required this.title,
    required this.description,
    required this.buttonLabel,
    required this.onAction,
    required this.onClose,
  });

  final String title;
  final String description;
  final String buttonLabel;
  final VoidCallback onAction;
  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return AnnotatedRegion<SystemUiOverlayStyle>(
      value: VideoEditorConstants.uiOverlayStyle.copyWith(
        systemNavigationBarColor: VineTheme.surfaceContainerHigh,
      ),
      child: Scaffold(
        backgroundColor: VineTheme.backgroundColor,
        body: Stack(
          fit: StackFit.expand,
          children: [
            const TvStaticNoise(),
            Column(
              children: [
                Align(
                  alignment: .centerLeft,
                  child: SafeArea(
                    bottom: false,
                    child: Padding(
                      padding: const .fromLTRB(16, 16, 0, 8),
                      child: DivineIconButton(
                        icon: .x,
                        onPressed: onClose,
                        size: .small,
                        type: .ghost,
                      ),
                    ),
                  ),
                ),

                Expanded(
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const .symmetric(horizontal: 48),
                      child: Column(
                        mainAxisAlignment: .center,
                        children: [
                          const DivineSticker(
                            sticker: .alert,
                            size: 154,
                          ),
                          const SizedBox(height: 19),
                          Text(
                            title,
                            style: VineTheme.titleMediumFont(
                              color: VineTheme.onSurfaceMuted,
                            ),
                            textAlign: .center,
                          ),
                          const SizedBox(height: 8),
                          Text(
                            description,
                            style: VineTheme.bodyMediumFont(
                              color: VineTheme.onSurfaceMuted,
                            ),
                            textAlign: .center,
                          ),
                          const SizedBox(height: 32),
                          DivineButton(
                            label: buttonLabel,
                            onPressed: onAction,
                          ),
                        ],
                      ),
                    ),
                  ),
                ),

                IgnorePointer(
                  child: Container(
                    padding: const .only(top: 8),
                    color: VineTheme.surfaceContainerHigh,
                    child: const Opacity(
                      opacity: 0.25,
                      child: VideoRecorderBottomBar(),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
