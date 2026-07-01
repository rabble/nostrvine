import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/providers/series_metadata_provider.dart';
import 'package:openvine/widgets/video_metadata/modes/capture/video_metadata_capture_app_bar.dart';
import 'package:openvine/widgets/video_metadata/modes/capture/video_metadata_capture_bottom_bar.dart';
import 'package:openvine/widgets/video_metadata/modes/capture/video_metadata_capture_clip_preview.dart';
import 'package:openvine/widgets/video_metadata/video_metadata_form_fields.dart';

class VideoMetadataCaptureStack extends ConsumerWidget {
  const VideoMetadataCaptureStack({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // A rendered clip longer than the per-video limit exposes one tab per
    // segment; each tab customises that segment's text and thumbnail before the
    // series is published. The count is derived in seriesMetadataProvider.
    final segmentCount = ref.watch(
      seriesMetadataProvider.select((s) => s.count),
    );

    return Scaffold(
      backgroundColor: VineTheme.surfaceContainerHigh,
      appBar: const VideoMetadataCaptureAppBar(),
      body: Column(
        spacing: 12,
        children: [
          if (segmentCount > 1) const _SeriesMetadataTabs(),
          const Expanded(
            child: SingleChildScrollView(
              child: Column(
                mainAxisSize: .min,
                crossAxisAlignment: .stretch,
                children: [
                  Padding(
                    padding: EdgeInsets.only(top: 8, bottom: 16),
                    child: VideoMetadataCaptureClipPreview(),
                  ),
                  VideoMetadataFormFields(),
                ],
              ),
            ),
          ),
          const SafeArea(top: false, child: VideoMetadataCaptureBottomBar()),
        ],
      ),
    );
  }
}

/// Horizontal pill row acting as tabs, one per series segment. Tapping a tab
/// switches which segment the form and preview edit.
class _SeriesMetadataTabs extends ConsumerWidget {
  const _SeriesMetadataTabs();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (:count, :activeIndex) = ref.watch(
      seriesMetadataProvider.select(
        (s) => (count: s.count, activeIndex: s.activeIndex),
      ),
    );
    return SizedBox(
      height: 40,
      child: ListView.separated(
        scrollDirection: Axis.horizontal,
        padding: const EdgeInsets.symmetric(horizontal: 16),
        itemCount: count,
        separatorBuilder: (_, _) => const SizedBox(width: 8),
        itemBuilder: (context, index) => _SegmentTab(
          index: index,
          selected: index == activeIndex,
          onTap: () =>
              ref.read(seriesMetadataProvider.notifier).setActiveIndex(index),
        ),
      ),
    );
  }
}

class _SegmentTab extends StatelessWidget {
  const _SegmentTab({
    required this.index,
    required this.selected,
    required this.onTap,
  });

  final int index;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: DecoratedBox(
        decoration: BoxDecoration(
          color: selected ? VineTheme.primary : VineTheme.surfaceContainer,
          borderRadius: BorderRadius.circular(20),
        ),
        child: Center(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Text(
              '${index + 1}',
              style: VineTheme.labelLargeFont(
                color: selected
                    ? VineTheme.surfaceContainerHigh
                    : VineTheme.onSurface,
              ),
            ),
          ),
        ),
      ),
    );
  }
}
