import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/models/audio_event.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/sound_library_service_provider.dart';
import 'package:openvine/providers/sounds_providers.dart';
import 'package:openvine/services/audio_playback_service.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:openvine/widgets/branded_loading_indicator.dart';
import 'package:openvine/widgets/video_editor/audio_editor/audio_list_tile.dart';
import 'package:openvine/widgets/video_editor/audio_editor/audio_sort_dropdown.dart';

class AudioSelectionBottomSheet extends ConsumerStatefulWidget {
  const AudioSelectionBottomSheet({required this.scrollController, super.key});

  final ScrollController scrollController;

  @override
  ConsumerState<AudioSelectionBottomSheet> createState() =>
      _AudioSelectionBottomSheetState();
}

class _AudioSelectionBottomSheetState
    extends ConsumerState<AudioSelectionBottomSheet> {
  final String _searchQuery = '';
  AudioSortOption _sortOption = AudioSortOption.newest;
  String? _playingSoundId;
  AudioPlaybackService? _audioService;

  @override
  void dispose() {
    _stopPlayback();
    super.dispose();
  }

  Future<void> _stopPlayback() async {
    if (_playingSoundId != null && _audioService != null) {
      await _audioService!.stop();
      _playingSoundId = null;
    }
  }

  Future<void> _togglePlayPause(AudioEvent sound) async {
    _audioService ??= ref.read(audioPlaybackServiceProvider);
    final audioService = _audioService!;

    // If tapping the same sound, toggle play/stop
    if (_playingSoundId == sound.id) {
      if (audioService.isPlaying) {
        await audioService.stop();

        if (mounted) setState(() => _playingSoundId = null);

        Log.debug(
          'Stopped preview: ${sound.title ?? sound.id}',
          name: 'AudioSelectionBottomSheet',
          category: LogCategory.ui,
        );
      }
      return;
    }

    // Stop any currently playing audio
    await audioService.stop();

    if (sound.url == null || sound.url!.isEmpty) {
      Log.warning(
        'Cannot preview sound: no URL available (${sound.id})',
        name: 'AudioSelectionBottomSheet',
        category: LogCategory.ui,
      );
      return;
    }

    Log.debug(
      'Starting preview: ${sound.title ?? sound.id}',
      name: 'AudioSelectionBottomSheet',
      category: LogCategory.ui,
    );

    try {
      await audioService.loadAudio(sound.url!);
      if (mounted) {
        setState(() => _playingSoundId = sound.id);
      }
      await audioService.play();
    } catch (e) {
      Log.error(
        'Failed to preview sound: $e',
        name: 'AudioSelectionBottomSheet',
        category: LogCategory.ui,
      );
    } finally {
      if (mounted) {
        setState(() => _playingSoundId = null);
      }
    }
  }

  void _selectSound(AudioEvent sound) {
    Log.info(
      'Sound selected: ${sound.title ?? 'Untitled'} (${sound.id})',
      name: 'AudioSelectionBottomSheet',
      category: LogCategory.ui,
    );
    _stopPlayback();
    context.pop(sound);
  }

  List<AudioEvent> _filterSounds(List<AudioEvent> sounds) {
    if (_searchQuery.isEmpty) {
      return sounds;
    }

    return sounds.where((sound) {
      final title = sound.title?.toLowerCase() ?? '';
      return title.contains(_searchQuery);
    }).toList();
  }

  List<AudioEvent> _sortSounds(List<AudioEvent> sounds) {
    final sorted = List<AudioEvent>.from(sounds);
    switch (_sortOption) {
      case AudioSortOption.newest:
        sorted.sort((a, b) => b.createdAt.compareTo(a.createdAt));
      case AudioSortOption.longest:
        sorted.sort((a, b) {
          final aDuration = a.duration ?? 0;
          final bDuration = b.duration ?? 0;
          return bDuration.compareTo(aDuration);
        });
      case AudioSortOption.shortest:
        sorted.sort((a, b) {
          final aDuration = a.duration ?? 0;
          final bDuration = b.duration ?? 0;
          return aDuration.compareTo(bDuration);
        });
    }
    return sorted;
  }

  @override
  Widget build(BuildContext context) {
    final bundledSoundsAsync = ref.watch(soundLibraryServiceProvider);
    final nostrSoundsAsync = ref.watch(trendingSoundsProvider);

    // Convert bundled VineSounds to AudioEvents
    final bundledSounds =
        bundledSoundsAsync.whenOrNull(
          data: (service) =>
              service.sounds.map(AudioEvent.fromBundledSound).toList(),
        ) ??
        <AudioEvent>[];

    return nostrSoundsAsync.when(
      data: (nostrSounds) {
        final allSounds = [...bundledSounds, ...nostrSounds];
        final filteredBundled = _filterSounds(bundledSounds);
        final filteredNostr = _filterSounds(nostrSounds);
        final filteredAll = [...filteredBundled, ...filteredNostr];

        final soundsToShow = _searchQuery.isNotEmpty ? filteredAll : allSounds;
        final sortedSounds = _sortSounds(soundsToShow);

        return _SoundsContent(
          scrollController: widget.scrollController,
          allSounds: allSounds,
          filteredSounds: sortedSounds,
          searchQuery: _searchQuery,
          hasSearchResults: filteredAll.isNotEmpty,
          sortOption: _sortOption,
          onSortChanged: (option) => setState(() => _sortOption = option),
          playingSoundId: _playingSoundId,
          onPlayPause: _togglePlayPause,
          onSelect: _selectSound,
        );
      },
      loading: () => bundledSounds.isNotEmpty
          ? _SoundsContent(
              scrollController: widget.scrollController,
              allSounds: bundledSounds,
              filteredSounds: _sortSounds(bundledSounds),
              searchQuery: _searchQuery,
              hasSearchResults: true,
              sortOption: _sortOption,
              onSortChanged: (option) => setState(() => _sortOption = option),
              playingSoundId: _playingSoundId,
              onPlayPause: _togglePlayPause,
              onSelect: _selectSound,
            )
          : const Center(child: BrandedLoadingIndicator()),
      error: (error, stack) => bundledSounds.isNotEmpty
          ? _SoundsContent(
              scrollController: widget.scrollController,
              allSounds: bundledSounds,
              filteredSounds: _sortSounds(bundledSounds),
              searchQuery: _searchQuery,
              hasSearchResults: true,
              sortOption: _sortOption,
              onSortChanged: (option) => setState(() => _sortOption = option),
              playingSoundId: _playingSoundId,
              onPlayPause: _togglePlayPause,
              onSelect: _selectSound,
            )
          : _ErrorState(error: error),
    );
  }
}

class _SoundsContent extends StatelessWidget {
  const _SoundsContent({
    required this.scrollController,
    required this.allSounds,
    required this.filteredSounds,
    required this.searchQuery,
    required this.hasSearchResults,
    required this.sortOption,
    required this.onSortChanged,
    required this.playingSoundId,
    required this.onPlayPause,
    required this.onSelect,
  });

  final ScrollController scrollController;
  final List<AudioEvent> allSounds;
  final List<AudioEvent> filteredSounds;
  final String searchQuery;
  final bool hasSearchResults;
  final AudioSortOption sortOption;
  final ValueChanged<AudioSortOption> onSortChanged;
  final String? playingSoundId;
  final ValueChanged<AudioEvent> onPlayPause;
  final ValueChanged<AudioEvent> onSelect;

  @override
  Widget build(BuildContext context) {
    if (allSounds.isEmpty) {
      return const _EmptyState();
    }

    if (searchQuery.isNotEmpty && !hasSearchResults) {
      return const _NoResultsState();
    }

    return CustomScrollView(
      controller: scrollController,
      slivers: [
        SliverToBoxAdapter(
          child: Padding(
            padding: const .symmetric(vertical: 12),
            child: AudioSortDropdown(
              value: sortOption,
              onChanged: onSortChanged,
            ),
          ),
        ),
        const SliverToBoxAdapter(
          child: Divider(height: 1, color: VineTheme.outlineDisabled),
        ),
        SliverList.separated(
          itemCount: filteredSounds.length,
          separatorBuilder: (context, index) =>
              const Divider(height: 1, color: VineTheme.outlineDisabled),
          itemBuilder: (context, index) {
            final audio = filteredSounds[index];
            return AudioListTile(
              audio: audio,
              isPlaying: audio.id == playingSoundId,
              onPlayPause: () => onPlayPause(audio),
              onSelect: () => onSelect(audio),
            );
          },
        ),
      ],
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.music_off, size: 64, color: VineTheme.secondaryText),
          SizedBox(height: 16),
          Text(
            // TODO(l10n): Replace with context.l10n when localization is added.
            'No sounds available',
            style: TextStyle(
              color: VineTheme.whiteText,
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 8),
          Text(
            // TODO(l10n): Replace with context.l10n when localization is added.
            'Sounds will appear here when creators share audio',
            style: TextStyle(color: VineTheme.secondaryText, fontSize: 14),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }
}

class _NoResultsState extends StatelessWidget {
  const _NoResultsState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 64, color: VineTheme.secondaryText),
          SizedBox(height: 16),
          Text(
            // TODO(l10n): Replace with context.l10n when localization is added.
            'No sounds found',
            style: TextStyle(
              color: VineTheme.whiteText,
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 8),
          Text(
            // TODO(l10n): Replace with context.l10n when localization is added.
            'Try a different search term',
            style: TextStyle(color: VineTheme.secondaryText, fontSize: 14),
          ),
        ],
      ),
    );
  }
}

class _ErrorState extends ConsumerWidget {
  const _ErrorState({required this.error});

  final Object error;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(Icons.error_outline, size: 64, color: VineTheme.likeRed),
            const SizedBox(height: 16),
            const Text(
              // TODO(l10n): Replace with context.l10n when localization is added.
              'Failed to load sounds',
              style: TextStyle(
                color: VineTheme.whiteText,
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error.toString(),
              style: const TextStyle(
                color: VineTheme.secondaryText,
                fontSize: 12,
              ),
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
              // TODO(l10n): Replace with context.l10n when localization is added.
              label: const Text('Retry'),
              style: ElevatedButton.styleFrom(
                backgroundColor: VineTheme.vineGreen,
                foregroundColor: VineTheme.backgroundColor,
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
