// ABOUTME: Sounds tab for the Library screen.
// ABOUTME: Shows reusable sounds the user has explicitly saved.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:models/models.dart' show AudioEvent;
import 'package:openvine/blocs/saved_sounds/saved_sounds_bloc.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/models/saved_sound.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/services/saved_sounds_service.dart';
import 'package:openvine/widgets/library/saved_sound_card.dart';
import 'package:openvine/widgets/library/saved_sound_details_editor.dart';
import 'package:openvine/widgets/video_editor/audio_editor/audio_selection_bottom_sheet.dart';
import 'package:sound_service/sound_service.dart';
import 'package:unified_logger/unified_logger.dart';

/// User-saved sounds tab for the Library screen.
///
/// Shows sounds saved through the out-of-flow "Use Sound" actions. Editor
/// selection remains inside the recording/editor flow.
class SoundsTab extends ConsumerStatefulWidget {
  const SoundsTab({this.showAudioPicker, super.key});

  final Future<AudioEvent?> Function(BuildContext context)? showAudioPicker;

  @override
  ConsumerState<SoundsTab> createState() => _SoundsTabState();
}

class _SoundsTabState extends ConsumerState<SoundsTab> {
  final TextEditingController _searchController = TextEditingController();
  String? _previewingSoundId;
  String? _editingSoundId;

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
    context.read<SavedSoundsBloc>().add(SavedSoundsQueryChanged(query));
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
      Log.error(
        'Failed to preview sound: $e',
        name: 'SoundsTab',
        category: LogCategory.video,
      );
    } finally {
      if (mounted) {
        setState(() => _previewingSoundId = null);
      }
    }
  }

  Future<void> _onRemoveTap(SavedSound sound) async {
    await _stopPreview();
    if (!mounted) return;
    context.read<SavedSoundsBloc>().add(SavedSoundRemoveRequested(sound.id));
    if (_editingSoundId == sound.id) {
      setState(() => _editingSoundId = null);
    }

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(context.l10n.soundsRemovedFromLibrary),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  Future<void> _onAddAudioTap() async {
    await _stopPreview();
    if (!mounted) return;

    final selectedSound =
        await (widget.showAudioPicker?.call(context) ??
            AudioSelectionBottomSheet.show(context));
    if (selectedSound == null || !mounted) return;

    final result = await context.read<SavedSoundsBloc>().saveSound(
      selectedSound,
    );
    if (!mounted) return;
    setState(() => _editingSoundId = selectedSound.id);

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          result == SavedSoundSaveResult.saved
              ? context.l10n.soundsSavedToLibrary
              : context.l10n.soundsAlreadySavedToLibrary,
        ),
        duration: const Duration(seconds: 2),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _SearchInput(
          controller: _searchController,
          onChanged: _onSearchChanged,
        ),
        if (kDebugMode && !kIsWeb)
          _DebugAudioPickerLauncher(onTap: _onAddAudioTap),
        Expanded(child: _buildContent()),
      ],
    );
  }

  Widget _buildContent() {
    return BlocBuilder<SavedSoundsBloc, SavedSoundsState>(
      builder: (context, state) {
        if (state.sounds.isEmpty) return _buildEmptyState();
        if (state.visibleSounds.isEmpty) return _buildNoResultsState();

        return _SavedSoundsSection(
          state: state,
          editingSoundId: _editingSoundId,
          onPreview: (sound) => _onPreviewTap(sound.audio),
          onEdit: (sound) {
            setState(() {
              _editingSoundId = _editingSoundId == sound.id ? null : sound.id;
            });
          },
          onRemove: _onRemoveTap,
        );
      },
    );
  }

  Widget _buildEmptyState() {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Icon(Icons.music_off, size: 64, color: context.vineColors.mutedText),
          const SizedBox(height: 16),
          Text(
            context.l10n.soundsSavedEmptyTitle,
            style: TextStyle(
              color: context.vineColors.primaryText,
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 32),
            child: Text(
              context.l10n.soundsSavedEmptyDescription,
              style: TextStyle(
                color: context.vineColors.onSurfaceMuted,
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
          Icon(Icons.search_off, size: 64, color: context.vineColors.mutedText),
          const SizedBox(height: 16),
          Text(
            context.l10n.soundsNoSoundsFound,
            style: TextStyle(
              color: context.vineColors.primaryText,
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
        ],
      ),
    );
  }
}

class _DebugAudioPickerLauncher extends StatelessWidget {
  const _DebugAudioPickerLauncher({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
      child: DivineButton(
        label: context.l10n.videoEditorAudioAddAudio,
        type: DivineButtonType.secondary,
        onPressed: onTap,
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
      color: context.vineColors.surfaceContainerHigh,
      child: TextField(
        controller: controller,
        onChanged: onChanged,
        style: TextStyle(color: context.vineColors.primaryText),
        decoration: InputDecoration(
          hintText: context.l10n.soundsSearchHint,
          hintStyle: TextStyle(color: context.vineColors.onSurfaceMuted),
          prefixIconConstraints: const BoxConstraints(),
          prefixIcon: Padding(
            padding: const EdgeInsetsDirectional.only(start: 12, end: 8),
            child: DivineIcon(
              icon: DivineIconName.search,
              color: context.vineColors.onSurfaceMuted,
            ),
          ),
          filled: true,
          fillColor: context.vineColors.surfaceContainer,
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
    required this.state,
    required this.editingSoundId,
    required this.onPreview,
    required this.onEdit,
    required this.onRemove,
  });

  final SavedSoundsState state;
  final String? editingSoundId;
  final ValueChanged<SavedSound> onPreview;
  final ValueChanged<SavedSound> onEdit;
  final ValueChanged<SavedSound> onRemove;

  @override
  Widget build(BuildContext context) {
    final sounds = state.visibleSounds;
    final hashtags =
        state.sounds.expand((sound) => sound.personalHashtags).toSet().toList()
          ..sort();
    return ListView(
      children: [
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          child: Row(
            children: [
              const DivineIcon(
                icon: DivineIconName.musicNote,
                color: VineTheme.vineGreen,
                size: 20,
              ),
              const SizedBox(width: 8),
              Text(
                context.l10n.soundsSavedLibraryTitle,
                style: TextStyle(
                  color: context.vineColors.primaryText,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(width: 8),
              Text(
                '(${state.sounds.length})',
                style: TextStyle(
                  color: context.vineColors.onSurfaceMuted,
                  fontSize: 14,
                ),
              ),
            ],
          ),
        ),
        if (hashtags.isNotEmpty)
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Wrap(
              spacing: 8,
              runSpacing: 8,
              children: [
                for (final hashtag in hashtags)
                  Semantics(
                    label: state.selectedHashtag == hashtag
                        ? context.l10n.savedSoundClearHashtagFilter
                        : '#$hashtag',
                    child: FilterChip(
                      key: Key('saved_sound_filter_$hashtag'),
                      label: Text('#$hashtag'),
                      selected: state.selectedHashtag == hashtag,
                      onSelected: (selected) {
                        context.read<SavedSoundsBloc>().add(
                          SavedSoundsHashtagSelected(
                            selected ? hashtag : null,
                          ),
                        );
                      },
                    ),
                  ),
              ],
            ),
          ),
        for (final sound in sounds)
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: Padding(
              padding: const EdgeInsets.only(bottom: 12),
              child: Column(
                children: [
                  SavedSoundCard(
                    sound: sound,
                    onPreview: () => onPreview(sound),
                    onEdit: () => onEdit(sound),
                    onRemove: () => onRemove(sound),
                  ),
                  if (editingSoundId == sound.id)
                    SavedSoundDetailsEditor(sound: sound),
                ],
              ),
            ),
          ),
      ],
    );
  }
}
