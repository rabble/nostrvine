// ABOUTME: Riverpod provider for reactive clip count updates
// ABOUTME: Used by profile screen to display clip library count

import 'dart:io';

import 'package:openvine/providers/app_providers.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

part 'clip_count_provider.g.dart';

/// Provider that returns the current number of clips in the library.
/// Only counts clips where the video file still exists on disk.
@riverpod
Future<int> clipCount(Ref ref) async {
  final clipService = ref.watch(clipLibraryServiceProvider);
  final clips = await clipService.getAllClips();
  return clips.where((c) => File(c.filePath).existsSync()).length;
}
