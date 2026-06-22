import 'dart:async';

import 'package:flutter/material.dart';
import 'package:models/models.dart';
import 'package:openvine/widgets/video_feed_item/subtitle_overlay.dart';
import 'package:video_player/video_player.dart';

/// Renders subtitles for a [VideoPlayerController]-backed video.
class VideoPlayerSubtitleLayer extends StatefulWidget {
  const VideoPlayerSubtitleLayer({
    required this.video,
    required this.controller,
    super.key,
  });

  final VideoEvent video;
  final VideoPlayerController controller;

  @override
  State<VideoPlayerSubtitleLayer> createState() =>
      _VideoPlayerSubtitleLayerState();
}

class _VideoPlayerSubtitleLayerState extends State<VideoPlayerSubtitleLayer> {
  final _positionController = StreamController<Duration>.broadcast();
  late bool _isInitialized = widget.controller.value.isInitialized;

  @override
  void initState() {
    super.initState();
    widget.controller.addListener(_handleControllerValue);
  }

  @override
  void didUpdateWidget(covariant VideoPlayerSubtitleLayer oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.controller == widget.controller) return;

    oldWidget.controller.removeListener(_handleControllerValue);
    _isInitialized = widget.controller.value.isInitialized;
    widget.controller.addListener(_handleControllerValue);
    _emitPositionIfReady(widget.controller.value);
  }

  @override
  void dispose() {
    widget.controller.removeListener(_handleControllerValue);
    _positionController.close();
    super.dispose();
  }

  void _handleControllerValue() {
    final value = widget.controller.value;
    if (_isInitialized != value.isInitialized) {
      setState(() {
        _isInitialized = value.isInitialized;
      });
    }
    _emitPositionIfReady(value);
  }

  void _emitPositionIfReady(VideoPlayerValue value) {
    if (!value.isInitialized || _positionController.isClosed) return;
    _positionController.add(value.position);
  }

  @override
  Widget build(BuildContext context) {
    if (!_isInitialized) return const SizedBox.shrink();

    return SubtitleCueStreamPill(
      video: widget.video,
      positionStream: _positionController.stream,
      initialPosition: widget.controller.value.position,
    );
  }
}
