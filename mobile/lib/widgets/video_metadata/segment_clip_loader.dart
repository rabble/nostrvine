// ABOUTME: Resolves the clip a preview/cover action targets (segment or full).
// ABOUTME: Renders the active 60s-series segment on demand behind a spinner.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/models/divine_video_clip.dart';
import 'package:openvine/providers/segment_clip_provider.dart';
import 'package:openvine/providers/series_metadata_provider.dart';
import 'package:openvine/providers/video_editor_provider.dart';
import 'package:openvine/widgets/branded_loading_indicator.dart';

/// Resolves the clip that a full-screen preview or cover picker should operate
/// on for the currently active tab.
///
/// For a single video it returns the shared rendered clip immediately. For a
/// multi-segment series it renders the active segment into its own file (via
/// [segmentClipProvider]), showing a blocking spinner while the first render
/// runs; cached segments resolve without a spinner. Returns null when nothing
/// is ready or the render fails.
Future<DivineVideoClip?> resolveActiveSegmentClip(
  BuildContext context,
  WidgetRef ref,
) async {
  final series = ref.read(seriesMetadataProvider);
  if (!series.isSeries) {
    return ref.read(videoEditorProvider).finalRenderedClip;
  }

  final index = series.activeIndex;
  final cached = ref.read(segmentClipProvider(index));
  if (cached.hasValue) return cached.value;

  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const Center(child: BrandedLoadingIndicator()),
  );
  try {
    return await ref.read(segmentClipProvider(index).future);
  } catch (_) {
    return null;
  } finally {
    if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
  }
}
