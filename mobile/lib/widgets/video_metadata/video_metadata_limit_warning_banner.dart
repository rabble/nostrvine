import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/video_editor_provider.dart';

/// Warning banner displayed when metadata size exceeds the 64KB limit.
class VideoMetadataLimitWarningBanner extends ConsumerWidget {
  /// Creates a metadata limit warning widget.
  const VideoMetadataLimitWarningBanner({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final limitReached = ref.watch(
      videoEditorProvider.select((s) => s.metadataLimitReached),
    );
    if (!limitReached) return const SizedBox.shrink();

    return Container(
      margin: const .all(16),
      padding: const .all(14),
      decoration: BoxDecoration(
        color: VineTheme.contentWarningBackground,
        border: Border.all(
          color: VineTheme.contentWarningAmber.withValues(alpha: 0.6),
        ),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        spacing: 12,
        children: [
          const DivineIcon(
            icon: .warning,
            color: VineTheme.contentWarningAmber,
            size: 20,
          ),
          Expanded(
            child: Text(
              context.l10n.videoMetadataLimitReachedWarning,
              style: VineTheme.labelLargeFont(
                color: VineTheme.contentWarningAmber,
              ),
            ),
          ),
        ],
      ),
    );
  }
}
