import 'package:divine_video_player/src/divine_video_player_controller.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

/// Renders the native video surface for a [DivineVideoPlayerController].
///
/// The controller must be [DivineVideoPlayerController.isInitialized]
/// before this widget is inserted into the tree.
///
/// When [placeholder] is provided it is shown on top of the native
/// surface until the first video frame has been rendered. This
/// prevents black-frame flashes on Android where the platform view
/// composites before ExoPlayer has decoded the initial frame.
class DivineVideoPlayer extends StatelessWidget {
  /// Creates a video player widget bound to [controller].
  ///
  /// If [placeholder] is non-null it covers the video surface and
  /// fades out once [DivineVideoPlayerController.firstFrameRendered]
  /// completes.
  const DivineVideoPlayer({
    required this.controller,
    this.placeholder,
    super.key,
  }) : assert(
         controller != null || placeholder != null,
         'Either controller or placeholder must be provided.',
       );

  /// The controller whose native player this widget renders.
  final DivineVideoPlayerController? controller;

  /// Optional widget displayed over the video surface until the
  /// first frame has been rendered.
  final Widget? placeholder;

  @override
  Widget build(BuildContext context) {
    if (controller == null && placeholder != null) return placeholder!;
    final ctrl = controller!;

    final Widget surface;
    if (ctrl.useTexture && ctrl.textureId != null) {
      surface = Texture(textureId: ctrl.textureId!);
    } else {
      final creationParams = <String, dynamic>{'playerId': ctrl.playerId};
      surface = switch (defaultTargetPlatform) {
        TargetPlatform.android => _AndroidPlayerView(
          viewType: ctrl.viewType,
          creationParams: creationParams,
        ),
        TargetPlatform.iOS => UiKitView(
          viewType: ctrl.viewType,
          creationParams: creationParams,
          creationParamsCodec: const StandardMessageCodec(),
        ),
        TargetPlatform.macOS => AppKitView(
          viewType: ctrl.viewType,
          creationParams: creationParams,
          creationParamsCodec: const StandardMessageCodec(),
        ),
        _ => const Center(
          child: Text('Platform not supported'),
        ),
      };
    }

    if (placeholder == null || ctrl.state.isFirstFrameRendered) {
      return surface;
    }

    return Stack(
      fit: .expand,
      children: [
        surface,
        _PlaceholderOverlay(
          controller: ctrl,
          placeholder: placeholder!,
        ),
      ],
    );
  }
}

/// Android uses [PlatformViewLink] for Hybrid Composition which provides
/// better performance than Virtual Display for video surfaces.
class _AndroidPlayerView extends StatelessWidget {
  const _AndroidPlayerView({
    required this.viewType,
    required this.creationParams,
  });

  final String viewType;
  final Map<String, dynamic> creationParams;

  @override
  // coverage:ignore-start
  Widget build(BuildContext context) {
    return PlatformViewLink(
      viewType: viewType,
      surfaceFactory: (context, controller) {
        return AndroidViewSurface(
          controller: controller as AndroidViewController,
          hitTestBehavior: PlatformViewHitTestBehavior.opaque,
          gestureRecognizers: const <Factory<OneSequenceGestureRecognizer>>{},
        );
      },
      onCreatePlatformView: (params) {
        return PlatformViewsService.initSurfaceAndroidView(
            id: params.id,
            viewType: viewType,
            layoutDirection: TextDirection.ltr,
            creationParams: creationParams,
            creationParamsCodec: const StandardMessageCodec(),
            onFocus: () => params.onFocusChanged(true),
          )
          ..addOnPlatformViewCreatedListener(params.onPlatformViewCreated)
          // Flutter platform view API – fire-and-forget by design.
          // ignore: discarded_futures
          ..create();
      },
    );
  }

  // coverage:ignore-end
}

/// Shows the [placeholder] over the video surface and hides it once
/// [DivineVideoPlayerController.firstFrameRendered] completes.
class _PlaceholderOverlay extends StatelessWidget {
  const _PlaceholderOverlay({
    required this.controller,
    required this.placeholder,
  });

  final DivineVideoPlayerController controller;
  final Widget placeholder;

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<bool>(
      future: controller.firstFrameRendered,
      builder: (context, snapshot) {
        if (snapshot.data == true) return const SizedBox.shrink();
        return placeholder;
      },
    );
  }
}
