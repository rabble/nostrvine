// ABOUTME: Sounds tab for the Library screen.
// ABOUTME: Browse bundled and trending Nostr sounds with search and preview.

import 'dart:developer' as developer;

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:models/models.dart' show AudioEvent;
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/sound_library_service_provider.dart';
import 'package:openvine/providers/sounds_providers.dart';
import 'package:openvine/screens/sound_detail_screen.dart';
import 'package:openvine/widgets/branded_loading_indicator.dart';
import 'package:openvine/widgets/sound_tile.dart';
import 'package:sound_service/sound_service.dart';

/// Sounds browsing tab for the Library screen.
///
/// Shows bundled and trending Nostr sounds with search, preview
/// playback, and navigation to [SoundDetailScreen].
class SoundsTab extends ConsumerStatefulWidget {
  const SoundsTab({super.key});

  @override
  ConsumerState<SoundsTab> createState() => _SoundsTabState();
}

class _SoundsTabState extends ConsumerState<SoundsTab> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String? _previewingSoundId;

  /// Cached reference to audio service for safe disposal.
  AudioPlaybackService? _audioService;

  @override
  void dispose() {
    if (_previewingSoundId != null && _audioService != null) {
      _audioService!.stop();
    }
    _searchController.dispose();
    super.dispose();
  }

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query.toLowerCase().trim();
    });
  }

  Future<void> _stopPreview() async {
    if (_previewingSoundId != null) {
      _audioService ??= ref.read(audioPlaybackServiceProvider);
      await _audioService!.stop();
      if (mounted) {
        setState(() {
          _previewingSoundId = null;
        });
      }
    }
  }

  Future<void> _onPreviewTap(AudioEvent sound) async {
    _audioService ??= ref.read(audioPlaybackServiceProvider);
    final audioService = _audioService!;

    // Toggle off if already playing this sound
    if (_previewingSoundId == sound.id) {
      await _stopPreview();
      return;
    }

    if (sound.url == null || sound.url!.isEmpty) return;

    try {
      await audioService.stop();
      await audioService.loadAudio(sound.url!);
      if (mounted) {
        setState(() => _previewingSoundId = sound.id);
      }
      await audioService.play();
    } catch (e) {
      developer.log(
        'Failed to preview sound: $e',
        name: 'SoundsTab',
        level: 1000,
      );
    } finally {
      if (mounted) {
        setState(() => _previewingSoundId = null);
      }
    }
  }

  Future<void> _onSoundTap(AudioEvent sound) async {
    await _stopPreview();
    if (!mounted) return;
    context.push(SoundDetailScreen.pathForId(sound.id), extra: sound);
  }

  Future<void> _onDetailTap(AudioEvent sound) async {
    if (sound.isBundled) return;
    await _stopPreview();
    if (!mounted) return;
    context.push(SoundDetailScreen.pathForId(sound.id), extra: sound);
  }

  List<AudioEvent> _filterSounds(List<AudioEvent> sounds) {
    if (_searchQuery.isEmpty) return sounds;
    return sounds.where((sound) {
      final title = sound.title?.toLowerCase() ?? '';
      return title.contains(_searchQuery);
    }).toList();
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _SearchInput(
          controller: _searchController,
          onChanged: _onSearchChanged,
        ),
        Expanded(child: _buildContent()),
      ],
    );
  }

  Widget _buildContent() {
    final bundledSoundsAsync = ref.watch(soundLibraryServiceProvider);
    final nostrSoundsAsync = ref.watch(trendingSoundsProvider);

    final bundledSounds =
        bundledSoundsAsync.whenOrNull(
          data: (service) {
            return service.sounds.indexed
                .map(
                  (e) => AudioEvent.fromBundledSound(e.$2, index: e.$1),
                )
                .toList();
          },
        ) ??
        <AudioEvent>[];

    return nostrSoundsAsync.when(
      data: (nostrSounds) => _buildSoundsContent(
        bundledSounds: bundledSounds,
        nostrSounds: nostrSounds,
      ),
      loading: () => bundledSounds.isNotEmpty
          ? _buildSoundsContent(
              bundledSounds: bundledSounds,
              nostrSounds: [],
            )
          : const Center(child: BrandedLoadingIndicator()),
      error: (error, stack) => bundledSounds.isNotEmpty
          ? _buildSoundsContent(
              bundledSounds: bundledSounds,
              nostrSounds: [],
            )
          : _buildEmptyState(),
    );
  }

  Widget _buildSoundsContent({
    required List<AudioEvent> bundledSounds,
    required List<AudioEvent> nostrSounds,
  }) {
    final allSounds = [...bundledSounds, ...nostrSounds];

    if (allSounds.isEmpty) return _buildEmptyState();

    final filteredBundled = _filterSounds(bundledSounds);
    final filteredNostr = _filterSounds(nostrSounds);
    final filteredAll = [...filteredBundled, ...filteredNostr];

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
          if (_searchQuery.isEmpty && bundledSounds.isNotEmpty) ...[
            _FeaturedSoundsSection(
              sounds: bundledSounds,
              previewingSoundId: _previewingSoundId,
              onTap: _onSoundTap,
              onPreview: _onPreviewTap,
            ),
            const SizedBox(height: 16),
          ],
          if (_searchQuery.isEmpty && nostrSounds.isNotEmpty) ...[
            _TrendingSoundsSection(
              sounds: nostrSounds,
              previewingSoundId: _previewingSoundId,
              onTap: _onSoundTap,
              onPreview: _onPreviewTap,
              onDetail: _onDetailTap,
            ),
            const SizedBox(height: 16),
          ],
          _AllSoundsSection(
            sounds: _searchQuery.isNotEmpty ? filteredAll : allSounds,
            searchQuery: _searchQuery,
            previewingSoundId: _previewingSoundId,
            onTap: _onSoundTap,
            onPreview: _onPreviewTap,
            onDetail: _onDetailTap,
          ),
        ],
      ),
    );
  }

  Widget _buildEmptyState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.music_off, size: 64, color: VineTheme.lightText),
          SizedBox(height: 16),
          Text(
            'No sounds available',
            style: TextStyle(
              color: VineTheme.whiteText,
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 8),
          Text(
            'Sounds will appear here when creators share audio',
            style: TextStyle(
              color: VineTheme.onSurfaceMuted,
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
        ],
      ),
    );
  }

  Widget _buildNoResultsState() {
    return const Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(
            Icons.search_off,
            size: 64,
            color: VineTheme.lightText,
          ),
          SizedBox(height: 16),
          Text(
            'No sounds found',
            style: TextStyle(
              color: VineTheme.whiteText,
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _SearchInput extends StatelessWidget {
  const _SearchInput({
    required this.controller,
    required this.onChanged,
  });

  final TextEditingController controller;
  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      color: VineTheme.onPrimary,
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        style: const TextStyle(color: VineTheme.whiteText),
        decoration: InputDecoration(
          hintText: 'Search sounds...',
          hintStyle: const TextStyle(
            color: VineTheme.onSurfaceMuted,
          ),
          prefixIcon: const Icon(
            Icons.search,
            color: VineTheme.onSurfaceMuted,
          ),
          filled: true,
          fillColor: VineTheme.backgroundColor,
          border: OutlineInputBorder(
            borderRadius: BorderRadius.circular(12),
            borderSide: BorderSide.none,
          ),
          contentPadding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
        ),
      ),
    );
  }
}

class _FeaturedSoundsSection extends StatelessWidget {
  const _FeaturedSoundsSection({
    required this.sounds,
    required this.previewingSoundId,
    required this.onTap,
    required this.onPreview,
  });

  final List<AudioEvent> sounds;
  final String? previewingSoundId;
  final ValueChanged<AudioEvent> onTap;
  final ValueChanged<AudioEvent> onPreview;

  @override
  Widget build(BuildContext context) {
    final featured = sounds.take(10).toList();
    if (featured.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(Icons.star, color: VineTheme.vineGreen, size: 20),
              SizedBox(width: 8),
              Text(
                'Featured Sounds',
                style: TextStyle(
                  color: VineTheme.whiteText,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 100,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: featured.length,
            itemBuilder: (context, index) {
              final sound = featured[index];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: SoundTile(
                  sound: sound,
                  compact: true,
                  isPlaying: previewingSoundId == sound.id,
                  onTap: () => onTap(sound),
                  onPlayPreview: () => onPreview(sound),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _TrendingSoundsSection extends StatelessWidget {
  const _TrendingSoundsSection({
    required this.sounds,
    required this.previewingSoundId,
    required this.onTap,
    required this.onPreview,
    required this.onDetail,
  });

  final List<AudioEvent> sounds;
  final String? previewingSoundId;
  final ValueChanged<AudioEvent> onTap;
  final ValueChanged<AudioEvent> onPreview;
  final ValueChanged<AudioEvent> onDetail;

  @override
  Widget build(BuildContext context) {
    final trending = sounds.take(10).toList();
    if (trending.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Padding(
          padding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(
                Icons.local_fire_department,
                color: VineTheme.vineGreen,
                size: 20,
              ),
              SizedBox(width: 8),
              Text(
                'Trending Sounds',
                style: TextStyle(
                  color: VineTheme.whiteText,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
        SizedBox(
          height: 100,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: trending.length,
            itemBuilder: (context, index) {
              final sound = trending[index];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: SoundTile(
                  sound: sound,
                  compact: true,
                  isPlaying: previewingSoundId == sound.id,
                  onTap: () => onTap(sound),
                  onPlayPreview: () => onPreview(sound),
                  onDetailTap: () => onDetail(sound),
                ),
              );
            },
          ),
        ),
      ],
    );
  }
}

class _AllSoundsSection extends StatelessWidget {
  const _AllSoundsSection({
    required this.sounds,
    required this.searchQuery,
    required this.previewingSoundId,
    required this.onTap,
    required this.onPreview,
    required this.onDetail,
  });

  final List<AudioEvent> sounds;
  final String searchQuery;
  final String? previewingSoundId;
  final ValueChanged<AudioEvent> onTap;
  final ValueChanged<AudioEvent> onPreview;
  final ValueChanged<AudioEvent> onDetail;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: 16,
            vertical: 12,
          ),
          child: Row(
            children: [
              const Icon(
                Icons.music_note,
                color: VineTheme.vineGreen,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                searchQuery.isEmpty ? 'All Sounds' : 'Search Results',
                style: const TextStyle(
                  color: VineTheme.whiteText,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '(${sounds.length})',
                style: const TextStyle(
                  color: VineTheme.onSurfaceMuted,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: sounds.length,
          itemBuilder: (context, index) {
            final sound = sounds[index];
            return SoundTile(
              sound: sound,
              isPlaying: previewingSoundId == sound.id,
              onTap: () => onTap(sound),
              onPlayPreview: () => onPreview(sound),
              onDetailTap: sound.isBundled ? null : () => onDetail(sound),
            );
          },
        ),
      ],
    );
  }
}
