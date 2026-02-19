import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/models/audio_event.dart';
import 'package:openvine/providers/sound_library_service_provider.dart';
import 'package:openvine/providers/sounds_providers.dart';
import 'package:openvine/widgets/branded_loading_indicator.dart';
import 'package:openvine/widgets/video_editor/audio_editor/audio_list_tile.dart';

class AudioSelectionBottomSheet extends ConsumerStatefulWidget {
  const AudioSelectionBottomSheet({super.key, required this.scrollController});

  final ScrollController scrollController;

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
      data: (nostrSounds) {
        final allSounds = [...bundledSounds, ...nostrSounds];
        final filteredBundled = _filterSounds(bundledSounds);
        final filteredNostr = _filterSounds(nostrSounds);
        final filteredAll = [...filteredBundled, ...filteredNostr];

        return _SoundsContent(
          scrollController: widget.scrollController,
          allSounds: allSounds,
          filteredSounds: _searchQuery.isNotEmpty ? filteredAll : allSounds,
          searchQuery: _searchQuery,
          hasSearchResults: filteredAll.isNotEmpty,
        );
      },
      loading: () => bundledSounds.isNotEmpty
          ? _SoundsContent(
              scrollController: widget.scrollController,
              allSounds: bundledSounds,
              filteredSounds: bundledSounds,
              searchQuery: _searchQuery,
              hasSearchResults: true,
            )
          : const Center(child: BrandedLoadingIndicator(size: 80)),
      error: (error, stack) => bundledSounds.isNotEmpty
          ? _SoundsContent(
              scrollController: widget.scrollController,
              allSounds: bundledSounds,
              filteredSounds: bundledSounds,
              searchQuery: _searchQuery,
              hasSearchResults: true,
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
  });

  final ScrollController scrollController;
  final List<AudioEvent> allSounds;
  final List<AudioEvent> filteredSounds;
  final String searchQuery;
  final bool hasSearchResults;

  @override
  Widget build(BuildContext context) {
    if (allSounds.isEmpty) {
      return const _EmptyState();
    }

    if (searchQuery.isNotEmpty && !hasSearchResults) {
      return const _NoResultsState();
    }

    return ListView.separated(
      controller: scrollController,
      itemCount: filteredSounds.length,
      separatorBuilder: (context, index) =>
          const Divider(height: 1, color: VineTheme.outlineDisabled),
      itemBuilder: (context, index) {
        final audio = filteredSounds[index];
        return AudioListTile(audio: audio, isPlaying: false);
      },
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.music_off, size: 64, color: VineTheme.secondaryText),
          const SizedBox(height: 16),
          const Text(
            'No sounds available',
            style: TextStyle(
              color: VineTheme.whiteText,
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
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
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.search_off, size: 64, color: VineTheme.secondaryText),
          const SizedBox(height: 16),
          const Text(
            'No sounds found',
            style: TextStyle(
              color: VineTheme.whiteText,
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
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
            Icon(Icons.error_outline, size: 64, color: VineTheme.likeRed),
            const SizedBox(height: 16),
            const Text(
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
              style: TextStyle(color: VineTheme.secondaryText, fontSize: 12),
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
