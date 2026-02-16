// ABOUTME: Bottom sheet widget for subtitle generation progress.
// ABOUTME: Shows pipeline stages, success/error states with retry.
//
// NOTE: This file is temporarily disabled due to Android build issues
// with whisper_ggml_plus v1.3.1. See: https://github.com/divinevideo/divine-mobile/issues/1568

// import 'package:flutter/material.dart';
// import 'package:flutter_riverpod/flutter_riverpod.dart';
// import 'package:models/models.dart';
// import 'package:openvine/providers/subtitle_providers.dart';
// import 'package:openvine/services/subtitle_generation_service.dart';

// /// Bottom sheet that shows subtitle generation progress.
// ///
// /// Usage:
// /// ```dart
// /// showModalBottomSheet(
// ///   context: context,
// ///   builder: (_) => SubtitleGenerationSheet(
// ///     video: videoEvent,
// ///     videoFilePath: '/path/to/video.mp4',
// ///   ),
// /// );
// /// ```
// class SubtitleGenerationSheet extends ConsumerStatefulWidget {
//   const SubtitleGenerationSheet({
//     required this.video,
//     required this.videoFilePath,
//     super.key,
//   });

//   final VideoEvent video;
//   final String videoFilePath;

//   @override
//   ConsumerState<SubtitleGenerationSheet> createState() =>
//       _SubtitleGenerationSheetState();
// }

// class _SubtitleGenerationSheetState
//     extends ConsumerState<SubtitleGenerationSheet> {
//   SubtitleGenerationStage? _currentStage;
//   bool _isComplete = false;
//   String? _error;

//   @override
//   void initState() {
//     super.initState();
//     _startGeneration();
//   }

//   Future<void> _startGeneration() async {
//     setState(() {
//       _currentStage = null;
//       _isComplete = false;
//       _error = null;
//     });

//     try {
//       final service = ref.read(subtitleGenerationServiceProvider);
//       await service.generateAndPublish(
//         video: widget.video,
//         videoFilePath: widget.videoFilePath,
//         onStage: (stage) {
//           if (mounted) {
//             setState(() => _currentStage = stage);
//           }
//         },
//       );
//       if (mounted) {
//         setState(() => _isComplete = true);
//       }
//     } on SubtitleGenerationException catch (e) {
//       if (mounted) {
//         setState(() => _error = e.message);
//       }
//     } catch (e) {
//       if (mounted) {
//         setState(() => _error = 'Something went wrong');
//       }
//     }
//   }

//   String _stageText(SubtitleGenerationStage stage) {
//     return switch (stage) {
//       SubtitleGenerationStage.downloadingModel => 'Downloading speech model...',
//       SubtitleGenerationStage.extractingAudio => 'Preparing audio...',
//       SubtitleGenerationStage.transcribing => 'Transcribing speech...',
//       SubtitleGenerationStage.publishingSubtitles => 'Publishing subtitles...',
//       SubtitleGenerationStage.publishingEvent => 'Updating video...',
//       SubtitleGenerationStage.done => 'Subtitles generated!',
//     };
//   }

//   @override
//   Widget build(BuildContext context) {
//     return Padding(
//       padding: const EdgeInsets.all(24),
//       child: Column(
//         mainAxisSize: MainAxisSize.min,
//         children: [
//           if (_error != null) ...[
//             const Icon(Icons.error_outline, size: 48),
//             const SizedBox(height: 16),
//             Text(
//               _error!,
//               style: const TextStyle(fontSize: 16),
//               textAlign: TextAlign.center,
//             ),
//             const SizedBox(height: 24),
//             ElevatedButton(
//               onPressed: _startGeneration,
//               child: const Text('Retry'),
//             ),
//           ] else if (_isComplete) ...[
//             const Icon(Icons.check_circle, size: 48),
//             const SizedBox(height: 16),
//             const Text(
//               'Subtitles generated!',
//               style: TextStyle(fontSize: 16),
//             ),
//             const SizedBox(height: 24),
//             ElevatedButton(
//               onPressed: () => Navigator.of(context).pop(),
//               child: const Text('Done'),
//             ),
//           ] else ...[
//             const CircularProgressIndicator(),
//             const SizedBox(height: 16),
//             Text(
//               _currentStage != null
//                   ? _stageText(_currentStage!)
//                   : 'Starting...',
//               style: const TextStyle(fontSize: 16),
//             ),
//           ],
//         ],
//       ),
//     );
//   }
// }
