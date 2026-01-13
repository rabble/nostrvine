// ABOUTME: Declarative permission gate that wraps camera screen
// ABOUTME: Renders permission UI or camera based on CameraPermissionBloc state

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/blocs/camera_permission/camera_permission_bloc.dart';
import 'package:openvine/router/nav_extensions.dart';
import 'package:openvine/theme/vine_theme.dart';

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

    // Always refresh permission check when screen opens
    // This handles cases where user denied previously and is returning
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final bloc = context.read<CameraPermissionBloc>();
      if (bloc.state is! CameraPermissionLoaded) {
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
      context.goHome();
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<CameraPermissionBloc, CameraPermissionState>(
      listener: (context, state) {
        // When user denies native permission dialog, pop back to home
        if (state is CameraPermissionDenied) {
          _popBack();
        }
      },
      builder: (context, state) {
        return switch (state) {
          CameraPermissionInitial() => _CameraPlaceholderScaffold(
            onClose: _popBack,
            child: const _LoadingIndicator(),
          ),
          CameraPermissionLoading() => _CameraPlaceholderScaffold(
            onClose: _popBack,
            child: const _LoadingIndicator(),
          ),
          CameraPermissionError() => _CameraPlaceholderScaffold(
            onClose: _popBack,
            child: _PermissionErrorSheet(
              onRetry: () {
                context.read<CameraPermissionBloc>().add(
                  const CameraPermissionRefresh(),
                );
              },
              onGoBack: _popBack,
            ),
          ),
          CameraPermissionDenied() => _CameraPlaceholderScaffold(
            onClose: _popBack,
            child: const _LoadingIndicator(),
          ),
          CameraPermissionLoaded(:final status) => switch (status) {
            CameraPermissionStatus.authorized => widget.child,
            CameraPermissionStatus.canRequest => _CameraPlaceholderScaffold(
              onClose: _popBack,
              child: _PrePermissionSheet(
                onContinue: () {
                  context.read<CameraPermissionBloc>().add(
                    const CameraPermissionRequest(),
                  );
                },
                onNotNow: _popBack,
              ),
            ),
            CameraPermissionStatus.requiresSettings =>
              _CameraPlaceholderScaffold(
                onClose: _popBack,
                child: _SettingsRequiredSheet(
                  onGoToSettings: () {
                    context.read<CameraPermissionBloc>().add(
                      const CameraPermissionOpenSettings(),
                    );
                  },
                  onNotNow: _popBack,
                ),
              ),
          },
        };
      },
    );
  }
}

/// Scaffold with camera placeholder background (progress bar + black preview area)
class _CameraPlaceholderScaffold extends StatelessWidget {
  const _CameraPlaceholderScaffold({
    required this.onClose,
    required this.child,
  });

  final VoidCallback onClose;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: Stack(
        children: [
          _CameraPlaceholder(onClose: onClose),
          child,
        ],
      ),
    );
  }
}

/// Camera placeholder with top progress bar
class _CameraPlaceholder extends StatelessWidget {
  const _CameraPlaceholder({required this.onClose});

  final VoidCallback onClose;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        // Top progress bar - matches camera screen style
        Container(
          height: 44,
          margin: EdgeInsets.only(top: MediaQuery.of(context).padding.top),
          color: VineTheme.vineGreen,
          child: Row(
            children: [
              // X button
              GestureDetector(
                behavior: HitTestBehavior.opaque,
                onTap: onClose,
                child: Container(
                  width: 44,
                  height: 44,
                  alignment: Alignment.center,
                  child: const Icon(Icons.close, color: Colors.white, size: 28),
                ),
              ),
              // Empty progress bar
              Expanded(
                child: Container(
                  height: 24,
                  margin: const EdgeInsets.symmetric(horizontal: 8),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(4),
                  ),
                ),
              ),
              // Disabled > button
              Container(
                width: 44,
                height: 44,
                alignment: Alignment.center,
                child: Icon(
                  Icons.chevron_right,
                  color: Colors.white.withValues(alpha: 0.3),
                  size: 32,
                ),
              ),
            ],
          ),
        ),
        // Black camera preview placeholder
        const Expanded(child: SizedBox.expand()),
      ],
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

/// Bottom sheet for permission errors
class _PermissionErrorSheet extends StatelessWidget {
  const _PermissionErrorSheet({required this.onRetry, required this.onGoBack});

  final VoidCallback onRetry;
  final VoidCallback onGoBack;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: _PermissionBottomSheet(
        icon: Icons.error_outline,
        iconColor: Colors.red,
        title: 'Permission Error',
        subtitle: 'Something went wrong while checking permissions.',
        primaryButtonText: 'Retry',
        onPrimaryPressed: onRetry,
        secondaryButtonText: 'Go back',
        onSecondaryPressed: onGoBack,
      ),
    );
  }
}

/// Bottom sheet for pre-permission request
class _PrePermissionSheet extends StatelessWidget {
  const _PrePermissionSheet({required this.onContinue, required this.onNotNow});

  final VoidCallback onContinue;
  final VoidCallback onNotNow;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: _PermissionBottomSheet(
        icon: Icons.videocam,
        iconColor: VineTheme.vineGreen,
        title: 'Allow camera and microphone access',
        subtitle:
            'This allows you to capture and edit videos right here in the app, nothing more.',
        primaryButtonText: 'Continue',
        onPrimaryPressed: onContinue,
        secondaryButtonText: 'Not now',
        onSecondaryPressed: onNotNow,
      ),
    );
  }
}

/// Bottom sheet for settings-required state
class _SettingsRequiredSheet extends StatelessWidget {
  const _SettingsRequiredSheet({
    required this.onGoToSettings,
    required this.onNotNow,
  });

  final VoidCallback onGoToSettings;
  final VoidCallback onNotNow;

  @override
  Widget build(BuildContext context) {
    return Align(
      alignment: Alignment.bottomCenter,
      child: _PermissionBottomSheet(
        icon: Icons.videocam_off,
        iconColor: VineTheme.vineGreen,
        title: 'Allow camera & microphone access',
        subtitle:
            'This allows you to capture and edit videos right here in the app, nothing more.',
        additionalText: 'Please enable permissions in Settings to continue.',
        primaryButtonText: 'Go to Settings',
        onPrimaryPressed: onGoToSettings,
        secondaryButtonText: 'Not now',
        onSecondaryPressed: onNotNow,
      ),
    );
  }
}

/// Reusable bottom sheet container with consistent styling
class _PermissionBottomSheet extends StatelessWidget {
  const _PermissionBottomSheet({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    this.additionalText,
    required this.primaryButtonText,
    required this.onPrimaryPressed,
    required this.secondaryButtonText,
    required this.onSecondaryPressed,
  });

  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String? additionalText;
  final String primaryButtonText;
  final VoidCallback onPrimaryPressed;
  final String secondaryButtonText;
  final VoidCallback onSecondaryPressed;

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;

    return Container(
      width: double.infinity,
      decoration: const BoxDecoration(
        color: Color(0xFF151616),
        borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
      ),
      child: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                width: 40,
                height: 4,
                margin: const EdgeInsets.only(bottom: 20),
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.3),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
              Icon(icon, color: iconColor, size: 64, semanticLabel: title),
              const SizedBox(height: 16),
              Text(
                title,
                style: textTheme.headlineSmall?.copyWith(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              Text(
                subtitle,
                style: textTheme.bodyLarge?.copyWith(color: Colors.white70),
                textAlign: TextAlign.center,
              ),
              if (additionalText != null) ...[
                const SizedBox(height: 8),
                Text(
                  additionalText!,
                  style: textTheme.bodyMedium?.copyWith(color: Colors.white54),
                  textAlign: TextAlign.center,
                ),
              ],
              const SizedBox(height: 24),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: onPrimaryPressed,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: VineTheme.vineGreen,
                    foregroundColor: Colors.white,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 16,
                    ),
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(24),
                    ),
                  ),
                  child: Text(
                    primaryButtonText,
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: TextButton(
                  onPressed: onSecondaryPressed,
                  style: TextButton.styleFrom(
                    foregroundColor: Colors.white70,
                    padding: const EdgeInsets.symmetric(
                      horizontal: 24,
                      vertical: 16,
                    ),
                  ),
                  child: Text(
                    secondaryButtonText,
                    style: const TextStyle(fontSize: 16),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
