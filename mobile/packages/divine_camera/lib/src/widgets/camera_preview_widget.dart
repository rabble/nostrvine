// ABOUTME: Camera preview widget for Flutter
// ABOUTME: Provides a ready-to-use camera preview with gesture support

import 'dart:io' show Platform;

import 'package:divine_camera/divine_camera.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

/// A widget that displays the camera preview with built-in gesture support.
///
/// This widget handles:
/// - Pinch-to-zoom gestures
/// - Tap-to-focus functionality
/// - Proper aspect ratio handling
class CameraPreviewWidget extends StatefulWidget {
  /// Creates a camera preview widget.
  const CameraPreviewWidget({
    this.fit = BoxFit.contain,
    this.onTap,
    this.onScaleStart,
    this.onScaleUpdate,
    this.loadingWidget,
    this.focusIndicatorBuilder,
    super.key,
  });

  /// How the preview should be fitted.
  final BoxFit fit;

  /// Optional callback when the preview is tapped.
  /// Receives local position and normalized position (0.0 - 1.0).
  final void Function(Offset localPosition, Offset normalizedPosition)? onTap;

  /// Widget to show while loading.
  final Widget? loadingWidget;

  /// Optional builder for the focus indicator widget.
  /// Receives the tap position (local coordinates) and returns a widget.
  final Widget Function(Offset position)? focusIndicatorBuilder;

  /// Optional callback when a scale gesture starts (pinch-to-zoom).
  /// Used to handle zoom gestures on the camera preview.
  final ValueChanged<ScaleStartDetails>? onScaleStart;

  /// Optional callback when a scale gesture updates (pinch-to-zoom).
  /// Used to handle zoom level changes during the gesture.
  final ValueChanged<ScaleUpdateDetails>? onScaleUpdate;

  @override
  State<CameraPreviewWidget> createState() => _CameraPreviewWidgetState();
}

class _CameraPreviewWidgetState extends State<CameraPreviewWidget> {
  final ValueNotifier<Offset?> _focusPoint = ValueNotifier(null);
  TapDownDetails? _tapDownDetails;
  final DivineCamera _camera = DivineCamera.instance;

  /// Stores the last valid texture ID to show during camera switch
  int? _lastTextureId;

  /// Whether the preview is currently being mirrored in Flutter.
  /// Used to adjust tap coordinates for focus.
  bool get _isPreviewMirrored {
    if (kIsWeb) return false;
    final isFront = _camera.lens == DivineCameraLens.front;
    if (!isFront) return false;

    // On iOS, mirror preview only when native isn't mirroring
    // coverage:ignore-start
    if (Platform.isIOS) {
      return !_camera.mirrorFrontCameraOutput;
    }
    // coverage:ignore-end
    return false;
  }

  @override
  void dispose() {
    _focusPoint.dispose();
    super.dispose();
  }

  void _handleTap(TapDownDetails details, Size previewSize) {
    final localPosition = details.localPosition;

    // Calculate normalized coordinates (0.0 - 1.0) based on actual preview size
    var normalizedX = (localPosition.dx / previewSize.width).clamp(0.0, 1.0);
    final normalizedY = (localPosition.dy / previewSize.height).clamp(0.0, 1.0);

    // If preview is mirrored in Flutter, flip the X coordinate for the camera
    // The visual focus indicator stays where the user tapped,
    // but the camera needs the un-mirrored coordinate
    // coverage:ignore-start
    if (_isPreviewMirrored) {
      normalizedX = 1.0 - normalizedX;
    }
    // coverage:ignore-end

    final normalizedPosition = Offset(normalizedX, normalizedY);

    // Update focus point for indicator
    if (widget.focusIndicatorBuilder != null) {
      _focusPoint.value = localPosition;
    }

    // Call external callback - user decides what to do with the position
    widget.onTap?.call(localPosition, normalizedPosition);
  }

  /// Calculate the actual preview size based on constraints and aspect ratio
  Size _calculatePreviewSize(BoxConstraints constraints, double aspectRatio) {
    final availableWidth = constraints.maxWidth;
    final availableHeight = constraints.maxHeight;

    // For portrait mode, aspectRatio is inverted (e.g., 3/4 instead of 4/3)
    final previewAspectRatio = aspectRatio;

    double previewWidth;
    double previewHeight;

    if (widget.fit == BoxFit.cover) {
      // Cover: fill the entire space
      previewWidth = availableWidth;
      previewHeight = availableHeight;
    } else {
      // Contain: fit within the space while maintaining aspect ratio
      final availableAspectRatio = availableWidth / availableHeight;

      if (previewAspectRatio > availableAspectRatio) {
        // Preview is wider than available space - constrain by width
        previewWidth = availableWidth;
        previewHeight = availableWidth / previewAspectRatio;
      } else {
        // Preview is taller than available space - constrain by height
        previewHeight = availableHeight;
        previewWidth = availableHeight * previewAspectRatio;
      }
    }

    return Size(previewWidth, previewHeight);
  }

  @override
  Widget build(BuildContext context) {
    // Update last known texture ID when available
    if (_camera.textureId != null) {
      _lastTextureId = _camera.textureId;
    }

    // During camera switch, show the last frame (frozen texture)
    final isSwitching = _camera.state.isSwitchingCamera;
    final textureToShow = isSwitching ? _lastTextureId : _camera.textureId;

    if (!_camera.isInitialized || textureToShow == null) {
      return widget.loadingWidget ??
          const ColoredBox(
            color: Colors.black,
            child: Center(
              child: CircularProgressIndicator(color: Colors.white),
            ),
          );
    }

    return LayoutBuilder(
      builder: (context, constraints) {
        final aspectRatio = _camera.cameraAspectRatio;
        final previewSize = _calculatePreviewSize(constraints, aspectRatio);

        return Stack(
          children: [
            GestureDetector(
              onTapDown: (details) => _tapDownDetails = details,
              onTap: () {
                if (_tapDownDetails != null) {
                  _handleTap(_tapDownDetails!, previewSize);
                }
              },
              onScaleStart: widget.onScaleStart,
              onScaleUpdate: widget.onScaleUpdate,
              child: _CameraPreview(
                constraints: constraints,
                textureId: textureToShow,
                aspectRatio: aspectRatio,
                fit: widget.fit,
                shouldMirror: _isPreviewMirrored,
              ),
            ),
            ValueListenableBuilder<Offset?>(
              valueListenable: _focusPoint,
              builder: (context, focusPoint, _) {
                if (focusPoint != null &&
                    widget.focusIndicatorBuilder != null) {
                  return widget.focusIndicatorBuilder!(focusPoint);
                }
                return const SizedBox.shrink();
              },
            ),
          ],
        );
      },
    );
  }
}

/// Private widget that renders the camera preview texture with proper
/// aspect ratio.
class _CameraPreview extends StatelessWidget {
  const _CameraPreview({
    required this.constraints,
    required this.textureId,
    required this.aspectRatio,
    required this.fit,
    required this.shouldMirror,
  });

  final BoxConstraints constraints;
  final int textureId;
  final double aspectRatio;
  final BoxFit fit;

  /// Whether to apply a horizontal flip transform to the preview.
  /// This is determined by the parent widget based on platform and settings.
  final bool shouldMirror;

  @override
  Widget build(BuildContext context) {
    Widget preview = Texture(textureId: textureId);

    // Mirror front camera preview (selfie mode)
    // This is a visual-only transform, the actual pixels remain "real-world"
    // coverage:ignore-start
    if (shouldMirror) {
      preview = Transform(
        alignment: .center,
        transform: .diagonal3Values(-1, 1, 1),
        child: preview,
      );
    }
    // coverage:ignore-end

    // Apply aspect ratio and fit
    if (fit == BoxFit.cover) {
      preview = SizedBox(
        width: constraints.maxWidth,
        height: constraints.maxHeight,
        child: FittedBox(
          fit: BoxFit.cover,
          clipBehavior: Clip.hardEdge,
          child: SizedBox(
            width: constraints.maxWidth,
            height: constraints.maxWidth / aspectRatio,
            child: preview,
          ),
        ),
      );
    } else {
      preview = AspectRatio(aspectRatio: aspectRatio, child: preview);
    }

    return preview;
  }
}
