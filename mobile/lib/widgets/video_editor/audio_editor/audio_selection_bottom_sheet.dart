import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:openvine/models/audio_event.dart';
import 'package:openvine/providers/sound_library_service_provider.dart';
import 'package:openvine/providers/sounds_providers.dart';
import 'package:openvine/utils/video_editor_utils.dart';
import 'package:openvine/widgets/branded_loading_indicator.dart';

class AudioSelectionBottomSheet extends ConsumerStatefulWidget {
  const AudioSelectionBottomSheet({super.key});

  @override
  ConsumerState<AudioSelectionBottomSheet> createState() =>
      _AudioSelectionBottomSheetState();
}

class _AudioSelectionBottomSheetState
    extends ConsumerState<AudioSelectionBottomSheet> {
  String _searchQuery = '';

  List<AudioEvent> _filterSounds(List<AudioEvent> sounds) {
    if (_searchQuery.isEmpty) {
      return sounds;
    }

    return sounds.where((sound) {
      final title = sound.title?.toLowerCase() ?? '';
      return title.contains(_searchQuery);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    final bundledSoundsAsync = ref.watch(soundLibraryServiceProvider);
    final nostrSoundsAsync = ref.watch(trendingSoundsProvider);

    // Convert bundled VineSounds to AudioEvents
    final bundledSounds =
        bundledSoundsAsync.whenOrNull(
          data: (service) => service.sounds
              .map((s) => AudioEvent.fromBundledSound(s))
              .toList(),
        ) ??
        <AudioEvent>[];

    return nostrSoundsAsync.when(
      data: (nostrSounds) => _buildSoundsContent(
        bundledSounds: bundledSounds,
        nostrSounds: nostrSounds,
      ),
      loading: () => bundledSounds.isNotEmpty
          ? _buildSoundsContent(bundledSounds: bundledSounds, nostrSounds: [])
          : const Center(child: BrandedLoadingIndicator(size: 80)),
      error: (error, stack) => bundledSounds.isNotEmpty
          ? _buildSoundsContent(bundledSounds: bundledSounds, nostrSounds: [])
          : _buildErrorState(error),
    );
  }

  // TODO(@hm21): refactor old build widgets below...
  Widget _buildSoundsContent({
    required List<AudioEvent> bundledSounds,
    required List<AudioEvent> nostrSounds,
  }) {
    final allSounds = [...bundledSounds, ...nostrSounds];

    if (allSounds.isEmpty) {
      return _buildEmptyState();
    }

    final filteredBundled = _filterSounds(bundledSounds);
    final filteredNostr = _filterSounds(nostrSounds);
    final filteredAll = [...filteredBundled, ...filteredNostr];

    // If search is active but no results
    if (_searchQuery.isNotEmpty && filteredAll.isEmpty) {
      return _buildNoResultsState();
    }

    return RefreshIndicator(
      color: VineTheme.onPrimary,
      backgroundColor: VineTheme.vineGreen,
      onRefresh: () async {
        await ref.read(trendingSoundsProvider.notifier).refresh();
      },
      child: ListView(
        children: [
          // All sounds section (search results or combined list)
          _buildAllSoundsSection(
            _searchQuery.isNotEmpty ? filteredAll : allSounds,
          ),
        ],
      ),
    );
  }

  Widget _buildAllSoundsSection(List<AudioEvent> audioList) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(Icons.music_note, color: VineTheme.vineGreen, size: 20),
              const SizedBox(width: 8),
              Text(
                _searchQuery.isEmpty ? 'All Sounds' : 'Search Results',
                style: const TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '(${audioList.length})',
                style: TextStyle(color: Colors.grey[500], fontSize: 14),
              ),
            ],
          ),
        ),

        // Sound tiles
        ListView.separated(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          itemCount: audioList.length,
          separatorBuilder: (context, index) =>
              const Divider(height: 40, color: VineTheme.outlineDisabled),
          itemBuilder: (context, index) {
            final audio = audioList[index];
            return _AudioTile(audio: audio, isPlaying: false);
          },
        ),
      ],
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.music_off, size: 64, color: Colors.grey[600]),
          const SizedBox(height: 16),
          const Text(
            'No sounds available',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Sounds will appear here when creators share audio',
            style: TextStyle(color: Colors.grey[500], fontSize: 14),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildNoResultsState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 64, color: Colors.grey[600]),
          const SizedBox(height: 16),
          const Text(
            'No sounds found',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Try a different search term',
            style: TextStyle(color: Colors.grey[500], fontSize: 14),
          ),
        ],
      ),
    );
  }

  Widget _buildErrorState(Object error) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.error_outline, size: 64, color: VineTheme.likeRed),
            const SizedBox(height: 16),
            const Text(
              'Failed to load sounds',
              style: TextStyle(
                color: Colors.white,
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error.toString(),
              style: TextStyle(color: Colors.grey[500], fontSize: 12),
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () {
                ref.invalidate(trendingSoundsProvider);
              },
              icon: const Icon(Icons.refresh),
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: VineTheme.vineGreen,
                foregroundColor: Colors.black,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _FilterButton extends StatelessWidget {
  const _FilterButton({super.key});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: ShapeDecoration(
        shape: RoundedRectangleBorder(
          side: BorderSide(
            width: 1,
            color: const Color(0xFF001A12) /* outline-outline-disabled */,
          ),
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        mainAxisAlignment: MainAxisAlignment.start,
        crossAxisAlignment: CrossAxisAlignment.center,
        spacing: 8,
        children: [
          Container(
            height: 48,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              mainAxisAlignment: MainAxisAlignment.start,
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: 4,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(vertical: 12),
                  decoration: ShapeDecoration(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    mainAxisAlignment: MainAxisAlignment.center,
                    crossAxisAlignment: CrossAxisAlignment.center,
                    spacing: 8,
                    children: [
                      Container(
                        width: 24,
                        height: 24,
                        clipBehavior: Clip.antiAlias,
                        decoration: BoxDecoration(),
                        child: Stack(),
                      ),
                      Text(
                        'Trending',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          color: Colors.white.withValues(
                            alpha: 0.95,
                          ) /* fg-on-surface */,
                          fontSize: 16,
                          fontFamily: 'Bricolage Grotesque',
                          fontWeight: FontWeight.w800,
                          height: 1.50,
                          letterSpacing: 0.15,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _AudioTile extends StatelessWidget {
  const _AudioTile({required this.audio, required this.isPlaying});

  final AudioEvent audio;
  final bool isPlaying;

  String _formatDuration(double? seconds) {
    if (seconds == null) return '--:--';
    final totalSeconds = seconds.round();
    final mins = (totalSeconds ~/ 60).toString().padLeft(2, '0');
    final secs = (totalSeconds % 60).toString().padLeft(2, '0');
    return '$mins:$secs';
  }

  @override
  Widget build(BuildContext context) {
    return ListTile(
      minTileHeight: 48,
      leading: Container(
        padding: const .all(12),
        decoration: ShapeDecoration(
          color: VineTheme.surfaceContainer,
          shape: RoundedRectangleBorder(borderRadius: .circular(12)),
        ),
        child: SvgPicture.asset(
          isPlaying
              ? 'assets/icon/pause_fill.svg'
              : 'assets/icon/play_fill.svg',
          width: 16,
          height: 16,
          colorFilter: .mode(VineTheme.onSurface, .srcIn),
        ),
      ),
      title: Text(
        audio.title ?? 'Untitled sound',
        style: VineTheme.titleMediumFont(fontSize: 16, height: 1.5),
      ),
      subtitle: Text.rich(
        TextSpan(
          style: VineTheme.bodyMediumFont(),
          children: [
            TextSpan(
              text: _formatDuration(audio.duration),
              style: TextStyle(fontFeatures: [.tabularFigures()]),
            ),
            TextSpan(text: ' ∙ '),
            TextSpan(text: 'Source'),
          ],
        ),
      ),
    );
  }
}
