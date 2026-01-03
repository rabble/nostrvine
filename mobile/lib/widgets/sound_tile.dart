// ABOUTME: Reusable tile widget for displaying AudioEvent sounds in lists
// ABOUTME: Supports normal mode for list display and compact mode for horizontal scroll

import 'package:flutter/material.dart';
import 'package:openvine/models/audio_event.dart';
import 'package:openvine/theme/vine_theme.dart';

/// A tile widget for displaying a sound (AudioEvent) in various list contexts.
///
/// Used in:
/// - Trending sounds horizontal scroll (compact mode)
/// - Sound search results
/// - Sound detail page "videos using this sound"
///
/// Normal mode displays:
/// ```
/// ┌─────────────────────────────────────────┐
/// │  ▶️ Original sound - @user1           > │
/// │    6s · 142 videos                      │
/// └─────────────────────────────────────────┘
/// ```
/// - Tap play button (left) = preview sound
/// - Tap tile body = select sound
/// - Tap chevron (right) = navigate to sound detail
///
/// Compact mode (for horizontal scroll):
/// ```
/// ┌─────┐
/// │thumb│
/// │ ♪6s │
/// └─────┘
/// ```
class SoundTile extends StatelessWidget {
  /// Creates a SoundTile widget.
  const SoundTile({
    required this.sound,
    this.onTap,
    this.onPlayPreview,
    this.onDetailTap,
    this.isPlaying = false,
    this.compact = false,
    this.videoCount,
    super.key,
  });

  /// The audio event to display.
  final AudioEvent sound;

  /// Callback when the tile body is tapped (select sound).
  final VoidCallback? onTap;

  /// Callback when the preview play button is tapped.
  final VoidCallback? onPlayPreview;

  /// Callback when the chevron/detail button is tapped (navigate to detail).
  final VoidCallback? onDetailTap;

  /// Whether this sound is currently playing a preview.
  final bool isPlaying;

  /// Whether to display in compact mode for horizontal scrolling.
  /// Defaults to false.
  final bool compact;

  /// Optional video usage count to display (e.g., "142 videos").
  final int? videoCount;

  /// Format the duration for display.
  ///
  /// Returns a short format like "6s" for durations under a minute.
  /// Returns "0s" for null or zero duration.
  String _formatDuration() {
    if (sound.duration == null || sound.duration! <= 0) {
      return '0s';
    }
    final totalSeconds = sound.duration!.round();
    if (totalSeconds < 60) {
      return '${totalSeconds}s';
    }
    final minutes = totalSeconds ~/ 60;
    final seconds = totalSeconds % 60;
    return '$minutes:${seconds.toString().padLeft(2, '0')}';
  }

  /// Get the display title, falling back gracefully.
  String get _displayTitle => sound.title ?? 'Untitled sound';

  @override
  Widget build(BuildContext context) {
    if (compact) {
      return _buildCompactTile();
    }
    return _buildNormalTile();
  }

  /// Build the compact version for horizontal scroll.
  ///
  /// Shows the sound title (truncated) so users can identify the sound.
  /// Tapping selects the sound for use in recording.
  Widget _buildCompactTile() {
    return Semantics(
      identifier: 'sound_tile_compact_${sound.id}',
      label: _displayTitle,
      button: true,
      child: GestureDetector(
        onTap: onTap,
        child: Container(
          width: 80,
          height: 80,
          decoration: BoxDecoration(
            color: VineTheme.cardBackground,
            borderRadius: BorderRadius.circular(8),
          ),
          child: Padding(
            padding: const EdgeInsets.all(6),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(
                  Icons.music_note,
                  color: VineTheme.vineGreen,
                  size: 24,
                ),
                const SizedBox(height: 4),
                Text(
                  _displayTitle,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 10,
                    fontWeight: FontWeight.w500,
                  ),
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  textAlign: TextAlign.center,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Build the normal list tile version.
  Widget _buildNormalTile() {
    return Semantics(
      identifier: 'sound_tile_${sound.id}',
      label: _displayTitle,
      container: true,
      child: Container(
        margin: const EdgeInsets.only(bottom: 8),
        decoration: BoxDecoration(
          color: VineTheme.cardBackground,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(12),
            child: Padding(
              padding: const EdgeInsets.all(12),
              child: Row(
                children: [
                  // Music note icon with play preview
                  _buildPlayPreviewButton(),
                  const SizedBox(width: 12),

                  // Title and metadata
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Row(
                          children: [
                            const Icon(
                              Icons.music_note,
                              color: VineTheme.vineGreen,
                              size: 16,
                            ),
                            const SizedBox(width: 4),
                            Expanded(
                              child: Text(
                                _displayTitle,
                                style: const TextStyle(
                                  color: Colors.white,
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                                maxLines: 1,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                          ],
                        ),
                        const SizedBox(height: 4),
                        _buildMetadataRow(),
                      ],
                    ),
                  ),

                  // Chevron indicator - tappable for detail navigation
                  GestureDetector(
                    onTap: onDetailTap,
                    behavior: HitTestBehavior.opaque,
                    child: Semantics(
                      identifier: 'sound_tile_detail_${sound.id}',
                      label: 'View details for $_displayTitle',
                      button: true,
                      child: const Padding(
                        padding: EdgeInsets.all(8),
                        child: Icon(
                          Icons.chevron_right,
                          color: Colors.grey,
                          size: 24,
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  /// Build the play preview button.
  Widget _buildPlayPreviewButton() {
    return Semantics(
      identifier: 'sound_tile_preview_${sound.id}',
      label: isPlaying ? 'Stop preview' : 'Preview $_displayTitle',
      button: true,
      child: GestureDetector(
        onTap: onPlayPreview,
        child: Container(
          width: 44,
          height: 44,
          decoration: BoxDecoration(
            color: VineTheme.vineGreen.withValues(alpha: isPlaying ? 0.4 : 0.2),
            borderRadius: BorderRadius.circular(22),
          ),
          child: Icon(
            isPlaying ? Icons.stop : Icons.play_arrow,
            color: VineTheme.vineGreen,
            size: 28,
          ),
        ),
      ),
    );
  }

  /// Build the metadata row (duration and video count).
  Widget _buildMetadataRow() {
    final parts = <String>[_formatDuration()];

    if (videoCount != null && videoCount! > 0) {
      final videoText = videoCount == 1 ? '1 video' : '$videoCount videos';
      parts.add(videoText);
    }

    return Text(
      parts.join(' · '),
      style: TextStyle(color: Colors.grey[400], fontSize: 13),
    );
  }
}
