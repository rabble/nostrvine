import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

class VideoEditorScreen extends ConsumerStatefulWidget {
  const VideoEditorScreen({super.key});

  /// Route name for this screen.
  static const routeName = 'video-editor';

  /// Path for this route.
  static const path = '/video-editor';

  @override
  ConsumerState<VideoEditorScreen> createState() => _VideoEditorScreenState();
}

class _VideoEditorScreenState extends ConsumerState<VideoEditorScreen> {
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(),
      body: ErrorWidget(
        'The video editor screen has not yet been implemented.',
      ),
    );
  }
}
