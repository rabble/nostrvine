// ABOUTME: Sounds browser screen for discovering and selecting sounds for recordings
// ABOUTME: Features bundled sounds, trending Nostr sounds, search, and sound selection

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/models/audio_event.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/sound_library_service_provider.dart';
import 'package:openvine/providers/sounds_providers.dart';
import 'package:openvine/services/audio_playback_service.dart';
import 'package:openvine/theme/vine_theme.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:openvine/widgets/branded_loading_indicator.dart';
import 'package:openvine/widgets/sound_tile.dart';

/// A screen for browsing and selecting sounds for use in recordings.
///
/// Displays:
/// - Featured sounds (bundled meme sounds from app assets)
/// - Trending sounds from Nostr (Kind 1063 events)
/// - Search input for filtering all sounds
/// - Combined sounds in a vertical list
///
/// Usage:
/// ```dart
/// Navigator.push(
///   context,
///   MaterialPageRoute(
///     builder: (_) => SoundsScreen(
///       onSoundSelected: (sound) {
///         // Handle sound selection
///       },
///     ),
///   ),
/// );
/// ```
class SoundsScreen extends ConsumerStatefulWidget {
  /// Creates a SoundsScreen.
  ///
  /// [onSoundSelected] is called when the user selects a sound.
  /// If not provided, the screen will use the selectedSoundProvider
  /// and pop the navigation stack.
  const SoundsScreen({this.onSoundSelected, super.key});

  /// Callback when a sound is selected.
  final void Function(AudioEvent sound)? onSoundSelected;

  @override
  ConsumerState<SoundsScreen> createState() => _SoundsScreenState();
}

class _SoundsScreenState extends ConsumerState<SoundsScreen> {
  final TextEditingController _searchController = TextEditingController();
  String _searchQuery = '';
  String? _previewingSoundId;
  bool _isLoadingPreview = false;

  /// Cached reference to the audio service for use in dispose
  AudioPlaybackService? _audioService;

  @override
  void dispose() {
    // Stop any playing preview using cached reference (safe in dispose)
    if (_previewingSoundId != null && _audioService != null) {
      _audioService!.stop();
    }
    _searchController.dispose();
    super.dispose();
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

  void _onSearchChanged(String query) {
    setState(() {
      _searchQuery = query.toLowerCase();
    });
  }

  void _onSoundTap(AudioEvent sound) {
    Log.info(
      'Sound selected: ${sound.title} (${sound.id})',
      name: 'SoundsScreen',
      category: LogCategory.ui,
    );

    if (widget.onSoundSelected != null) {
      widget.onSoundSelected!(sound);
    } else {
      // Use the provider and navigate back
      ref.read(selectedSoundProvider.notifier).select(sound);
      context.pop();
    }
  }

  Future<void> _onPreviewTap(AudioEvent sound) async {
    // If already loading, ignore taps
    if (_isLoadingPreview) return;

    // Cache the audio service reference for dispose safety
    _audioService ??= ref.read(audioPlaybackServiceProvider);
    final audioService = _audioService!;

    // If tapping the same sound, toggle play/stop
    if (_previewingSoundId == sound.id) {
      Log.info(
        'Stopping preview: ${sound.title} (${sound.id})',
        name: 'SoundsScreen',
        category: LogCategory.ui,
      );
      await _stopPreview();
      return;
    }

    // Stop any currently playing preview
    if (_previewingSoundId != null) {
      await audioService.stop();
    }

    // Check if sound has a URL to play
    if (sound.url == null || sound.url!.isEmpty) {
      Log.warning(
        'Cannot preview sound: no URL available (${sound.id})',
        name: 'SoundsScreen',
        category: LogCategory.ui,
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Unable to preview sound - no audio available'),
            duration: Duration(seconds: 2),
          ),
        );
      }
      return;
    }

    Log.info(
      'Starting preview: ${sound.title} (${sound.id})',
      name: 'SoundsScreen',
      category: LogCategory.ui,
    );

    setState(() {
      _isLoadingPreview = true;
    });

    try {
      // Load and play the audio
      await audioService.loadAudio(sound.url!);
      await audioService.play();

      if (mounted) {
        setState(() {
          _previewingSoundId = sound.id;
          _isLoadingPreview = false;
        });
      }
    } catch (e) {
      Log.error(
        'Failed to preview sound: $e',
        name: 'SoundsScreen',
        category: LogCategory.ui,
      );
      if (mounted) {
        setState(() {
          _previewingSoundId = null;
          _isLoadingPreview = false;
        });
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to play preview: ${e.toString()}'),
            duration: const Duration(seconds: 2),
          ),
        );
      }
    }
  }

  Future<void> _onDetailTap(AudioEvent sound) async {
    // Bundled sounds don't have detail pages
    if (sound.isBundled) {
      return;
    }

    Log.info(
      'Navigate to sound detail: ${sound.title} (${sound.id})',
      name: 'SoundsScreen',
      category: LogCategory.ui,
    );

    // Stop any playing preview before navigating - must await to ensure it stops
    await _stopPreview();

    if (!mounted) return;

    context.push('/sound/${sound.id}', extra: sound);
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

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Sounds screen',
      container: true,
      child: Scaffold(
        backgroundColor: Colors.black,
        appBar: AppBar(
          backgroundColor: VineTheme.cardBackground,
          leading: IconButton(
            icon: const Icon(Icons.arrow_back, color: Colors.white),
            onPressed: context.pop,
          ),
          title: const Text(
            'Sounds',
            style: TextStyle(
              color: Colors.white,
              fontSize: 18,
              fontWeight: FontWeight.w600,
            ),
          ),
          centerTitle: true,
        ),
        body: Column(
          children: [
            // Search input
            _buildSearchInput(),

            // Content
            Expanded(child: _buildContent()),
          ],
        ),
      ),
    );
  }

  Widget _buildSearchInput() {
    return Container(
      padding: const EdgeInsets.all(16),
      color: VineTheme.cardBackground,
      child: TextField(
        controller: _searchController,
        onChanged: _onSearchChanged,
        style: const TextStyle(color: Colors.white),
        decoration: InputDecoration(
          hintText: 'Search sounds...',
          hintStyle: TextStyle(color: Colors.grey[500]),
          prefixIcon: Icon(Icons.search, color: Colors.grey[500]),
          filled: true,
          fillColor: Colors.black,
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

  Widget _buildContent() {
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
      color: VineTheme.vineGreen,
      onRefresh: () async {
        await ref.read(trendingSoundsProvider.notifier).refresh();
      },
      child: ListView(
        children: [
          // Featured sounds section (bundled meme sounds) - show when not searching
          if (_searchQuery.isEmpty && bundledSounds.isNotEmpty) ...[
            _buildFeaturedSoundsSection(bundledSounds),
            const SizedBox(height: 16),
          ],

          // Trending Nostr sounds section (only show when not searching)
          if (_searchQuery.isEmpty && nostrSounds.isNotEmpty) ...[
            _buildTrendingSoundsSection(nostrSounds),
            const SizedBox(height: 16),
          ],

          // All sounds section (search results or combined list)
          _buildAllSoundsSection(
            _searchQuery.isNotEmpty ? filteredAll : allSounds,
          ),
        ],
      ),
    );
  }

  Widget _buildFeaturedSoundsSection(List<AudioEvent> sounds) {
    // Take first 10 bundled sounds as featured
    final featuredSounds = sounds.take(10).toList();

    if (featuredSounds.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(Icons.star, color: VineTheme.vineGreen, size: 20),
              const SizedBox(width: 8),
              const Text(
                'Featured Sounds',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),

        // Horizontal list
        SizedBox(
          height: 100,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: featuredSounds.length,
            itemBuilder: (context, index) {
              final sound = featuredSounds[index];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: SoundTile(
                  sound: sound,
                  compact: true,
                  isPlaying: _previewingSoundId == sound.id,
                  onTap: () => _onSoundTap(sound),
                  onPlayPreview: () => _onPreviewTap(sound),
                  // No detail tap for bundled sounds (they don't have Nostr pages)
                  onDetailTap: null,
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildTrendingSoundsSection(List<AudioEvent> sounds) {
    // Take first 10 sounds as trending
    final trendingSounds = sounds.take(10).toList();

    if (trendingSounds.isEmpty) {
      return const SizedBox.shrink();
    }

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Header
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              Icon(
                Icons.local_fire_department,
                color: VineTheme.vineGreen,
                size: 20,
              ),
              const SizedBox(width: 8),
              const Text(
                'Trending Sounds',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),

        // Horizontal list
        SizedBox(
          height: 100,
          child: ListView.builder(
            scrollDirection: Axis.horizontal,
            padding: const EdgeInsets.symmetric(horizontal: 12),
            itemCount: trendingSounds.length,
            itemBuilder: (context, index) {
              final sound = trendingSounds[index];
              return Padding(
                padding: const EdgeInsets.symmetric(horizontal: 4),
                child: SoundTile(
                  sound: sound,
                  compact: true,
                  isPlaying: _previewingSoundId == sound.id,
                  onTap: () => _onSoundTap(sound),
                  onPlayPreview: () => _onPreviewTap(sound),
                  onDetailTap: () => _onDetailTap(sound),
                ),
              );
            },
          ),
        ),
      ],
    );
  }

  Widget _buildAllSoundsSection(List<AudioEvent> sounds) {
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
                '(${sounds.length})',
                style: TextStyle(color: Colors.grey[500], fontSize: 14),
              ),
            ],
          ),
        ),

        // Sound tiles
        ListView.builder(
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 16),
          itemCount: sounds.length,
          itemBuilder: (context, index) {
            final sound = sounds[index];
            return SoundTile(
              sound: sound,
              isPlaying: _previewingSoundId == sound.id,
              onTap: () => _onSoundTap(sound),
              onPlayPreview: () => _onPreviewTap(sound),
              // Only show detail tap for Nostr sounds (not bundled)
              onDetailTap: sound.isBundled ? null : () => _onDetailTap(sound),
            );
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
