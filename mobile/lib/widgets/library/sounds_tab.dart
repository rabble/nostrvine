// ABOUTME: Sounds tab for the Library screen.
// ABOUTME: Shows reusable sounds the user has explicitly saved.

import 'dart:developer' as developer;

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:models/models.dart' show AudioEvent;
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/saved_sounds_provider.dart';
import 'package:openvine/screens/sound_detail_screen.dart';
import 'package:openvine/widgets/sound_tile.dart';
import 'package:sound_service/sound_service.dart';

/// User-saved sounds tab for the Library screen.
///
/// Shows sounds saved through the out-of-flow "Use Sound" actions. Editor
/// selection remains inside the recording/editor flow.
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
    final savedSounds = ref.watch(savedSoundsProvider);
    return _buildSoundsContent(savedSounds);
  }

  Widget _buildSoundsContent(List<AudioEvent> sounds) {
    if (sounds.isEmpty) return _buildEmptyState();

    final filteredSounds = _filterSounds(sounds);
    if (_searchQuery.isNotEmpty && filteredSounds.isEmpty) {
      return _buildNoResultsState();
    }

    return ListView(
      children: [
        _SavedSoundsSection(
          sounds: filteredSounds,
          previewingSoundId: _previewingSoundId,
          onTap: _onSoundTap,
          onPreview: _onPreviewTap,
          onDetail: _onDetailTap,
        ),
      ],
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
            'No saved sounds yet',
            style: TextStyle(
              color: VineTheme.whiteText,
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
          SizedBox(height: 8),
          Padding(
            padding: EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              'Tap Use Sound on a video to save it here.',
              style: TextStyle(
                color: VineTheme.onSurfaceMuted,
                fontSize: 14,
              ),
              textAlign: TextAlign.center,
            ),
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
          const Icon(Icons.search_off, size: 64, color: VineTheme.lightText),
          const SizedBox(height: 16),
          Text(
            context.l10n.soundsNoSoundsFound,
            style: const TextStyle(
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
  const _SearchInput({required this.controller, required this.onChanged});

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
          hintText: context.l10n.soundsSearchHint,
          hintStyle: const TextStyle(color: VineTheme.onSurfaceMuted),
          prefixIcon: const Icon(Icons.search, color: VineTheme.onSurfaceMuted),
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

class _SavedSoundsSection extends StatelessWidget {
  const _SavedSoundsSection({
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
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              const Icon(
                Icons.music_note,
                color: VineTheme.vineGreen,
                size: 20,
              ),
              const SizedBox(width: 8),
              const Text(
                'My Sounds',
                style: TextStyle(
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
