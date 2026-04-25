import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:models/models.dart' show AudioEvent;
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/sound_library_service_provider.dart';
import 'package:openvine/providers/sounds_providers.dart';
import 'package:openvine/screens/video_editor/video_audio_editor_timing_screen.dart';
import 'package:openvine/widgets/branded_loading_indicator.dart';
import 'package:openvine/widgets/video_editor/audio_editor/audio_category_bar.dart';
import 'package:openvine/widgets/video_editor/audio_editor/audio_editor_selection_overlay.dart';
import 'package:openvine/widgets/video_editor/audio_editor/audio_list_tile.dart';
import 'package:sound_service/sound_service.dart';
import 'package:unified_logger/unified_logger.dart';

class AudioSelectionBottomSheet extends ConsumerStatefulWidget {
  const AudioSelectionBottomSheet({required this.scrollController, super.key});

  final ScrollController scrollController;

  static Future<AudioEvent?> show(BuildContext context) {
    return VineBottomSheet.show<AudioEvent>(
      context: context,
      maxChildSize: 1,
      initialChildSize: 1,
      minChildSize: 0.8,
      headerPadding: const EdgeInsetsDirectional.only(
        start: 12,
        end: 12,
        top: 8,
      ),
      title: Row(
        mainAxisAlignment: .spaceBetween,
        spacing: 8,
        children: [
          DivineIconButton(
            icon: .x,
            onPressed: context.pop,
            type: .secondary,
            size: .small,
          ),

          Flexible(child: Text(context.l10n.videoEditorAudioAddAudio)),

          const IgnorePointer(
            child: ExcludeSemantics(
              child: Opacity(
                opacity: 0,
                child: DivineIconButton(
                  icon: .x,
                  onPressed: null,
                  size: .small,
                ),
              ),
            ),
          ),
        ],
      ),
      buildScrollBody: (scrollController) =>
          AudioSelectionBottomSheet(scrollController: scrollController),
    );
  }

  @override
  ConsumerState<AudioSelectionBottomSheet> createState() =>
      _AudioSelectionBottomSheetState();
}

class _AudioSelectionBottomSheetState
    extends ConsumerState<AudioSelectionBottomSheet>
    with SingleTickerProviderStateMixin {
  final _audioService = AudioPlaybackService();
  String? _loadedSoundId;
  AudioEvent? _selectedItem;
  AudioCategory _category = .diVine;

  late final _tabController = TabController(
    length: AudioCategory.values.length,
    vsync: this,
  );

  @override
  void initState() {
    super.initState();
    _tabController.addListener(_onTabChanged);
  }

  @override
  void dispose() {
    _audioService.dispose();
    _tabController.dispose();
    super.dispose();
  }

  void _onTabChanged() {
    if (_tabController.indexIsChanging) return;
    final newCategory = AudioCategory.values[_tabController.index];
    if (_category != newCategory) {
      setState(() => _category = newCategory);
    }
  }

  void _selectCategory(AudioCategory category) {
    setState(() {
      _category = category;
      _tabController.animateTo(
        AudioCategory.values.indexWhere((el) => el == category),
      );
    });
  }

  Future<void> _togglePlayPause({bool enforcePlay = false}) async {
    if (_selectedItem == null) {
      return;
    }

    if (_audioService.isPlaying && !enforcePlay) {
      await _audioService.pause();
      await _audioService.seek(.zero);
      return;
    }

    final sound = _selectedItem!;

    if (sound.url == null || sound.url!.isEmpty) {
      Log.warning(
        'Cannot preview sound: no URL available (${sound.id})',
        name: 'AudioSelectionBottomSheet',
        category: LogCategory.ui,
      );
      return;
    }

    final shouldReload = _loadedSoundId != sound.id;

    Log.debug(
      'Starting preview: ${sound.title ?? sound.id}',
      name: 'AudioSelectionBottomSheet',
      category: LogCategory.ui,
    );

    try {
      await _audioService.seek(.zero);
      if (shouldReload) {
        await _audioService.stop();
        await _audioService.loadAudio(sound.url!);
        _loadedSoundId = sound.id;
      }

      if (mounted) {
        setState(() {
          _selectedItem = sound;
        });
      }
      // Blocks here for the entire duration of playback — only
      // releases once the song finishes playing to the end or was paused.
      await _audioService.play();
    } catch (e) {
      Log.error(
        'Failed to preview sound: $e',
        name: 'AudioSelectionBottomSheet',
        category: LogCategory.ui,
      );
    } finally {
      if (_selectedItem == sound) {
        await _audioService.pause();
        setState(() {});
      }
    }
  }

  Future<void> _selectSound(AudioEvent sound) async {
    if (_selectedItem?.id == sound.id) return;
    Log.info(
      'Sound selected: ${sound.title ?? 'Untitled'} (${sound.id})',
      name: 'AudioSelectionBottomSheet',
      category: LogCategory.ui,
    );
    setState(() {
      _selectedItem = sound;
    });
    await _togglePlayPause(enforcePlay: true);
  }

  Future<void> _handleDoneSelection() async {
    await _audioService.stop();
    if (!mounted) return;

    if (_selectedItem == null) {
      context.pop();
      return;
    }

    if (_selectedItem!.duration == null ||
        _selectedItem!.duration! >
            (VideoEditorConstants.maxDuration.inMilliseconds / 1000)) {
      final timingResult = await Navigator.of(context).push<AudioTimingResult>(
        PageRouteBuilder(
          opaque: false,
          barrierColor: VineTheme.transparent,
          transitionsBuilder: (_, animation, _, child) =>
              FadeTransition(opacity: animation, child: child),
          pageBuilder: (_, _, _) => VideoAudioEditorTimingScreen(
            sound: _selectedItem!,
            enableDeleteButton: false,
          ),
        ),
      );

      if (timingResult != null && mounted) {
        switch (timingResult) {
          case AudioTimingConfirmed(:final sound):
            context.pop(sound);
          case AudioTimingDeleted():
            break;
        }
      }
    } else {
      context.pop(_selectedItem);
    }
  }

  @override
  Widget build(BuildContext context) {
    final bundledSoundsAsync = ref.watch(soundLibraryServiceProvider);
    final nostrSoundsAsync = ref.watch(trendingSoundsProvider);

    // Convert bundled VineSounds to AudioEvents
    final bundledSounds =
        bundledSoundsAsync.whenOrNull(
          data: (service) {
            return service.sounds.indexed
                .map((e) => AudioEvent.fromBundledSound(e.$2, index: e.$1))
                .toList();
          },
        ) ??
        <AudioEvent>[];

    return Stack(
      children: [
        Column(
          crossAxisAlignment: .stretch,
          children: [
            AudioCategoryBar(category: _category, onSelect: _selectCategory),
            Expanded(
              child: TabBarView(
                controller: _tabController,
                children: [
                  _SoundsContent(
                    scrollController: widget.scrollController,
                    sounds: bundledSounds,
                    selectedSound: _selectedItem,
                    audioService: _audioService,
                    onSelect: _selectSound,
                  ),

                  nostrSoundsAsync.when(
                    data: (nostrSounds) {
                      return _SoundsContent(
                        scrollController: widget.scrollController,
                        sounds: nostrSounds,
                        selectedSound: _selectedItem,
                        audioService: _audioService,
                        onSelect: _selectSound,
                      );
                    },
                    loading: () =>
                        const Center(child: BrandedLoadingIndicator()),
                    error: (error, stack) => _ErrorState(error: error),
                  ),
                ],
              ),
            ),
          ],
        ),

        Align(
          alignment: .bottomCenter,
          child: AnimatedSwitcher(
            duration: const Duration(milliseconds: 220),
            child: _selectedItem != null
                ? AudioEditorSelectionOverlay(
                    audio: _selectedItem!,
                    audioService: _audioService,
                    onTapDone: _handleDoneSelection,
                    onTogglePlayState: _togglePlayPause,
                  )
                : const SizedBox.shrink(),
          ),
        ),
      ],
    );
  }
}

class _SoundsContent extends StatelessWidget {
  const _SoundsContent({
    required this.scrollController,
    required this.sounds,
    required this.selectedSound,
    required this.audioService,
    required this.onSelect,
  });

  final ScrollController scrollController;
  final List<AudioEvent> sounds;
  final AudioEvent? selectedSound;
  final AudioPlaybackService audioService;
  final ValueChanged<AudioEvent> onSelect;

  static const _bottomSpace = 120.0;

  @override
  Widget build(BuildContext context) {
    if (sounds.isEmpty) {
      return const _EmptyState();
    }

    return CustomScrollView(
      controller: scrollController,
      slivers: [
        const SliverToBoxAdapter(
          child: Divider(height: 1, color: VineTheme.outlineDisabled),
        ),

        SliverList.separated(
          itemCount: sounds.length,
          separatorBuilder: (context, index) =>
              const Divider(height: 1, color: VineTheme.outlineDisabled),
          itemBuilder: (context, index) {
            final audio = sounds[index];
            final isSelected = audio.id == selectedSound?.id;
            if (!isSelected) {
              return AudioListTile(
                audio: audio,
                isSelected: false,
                onTap: () => onSelect(audio),
              );
            }
            return StreamBuilder<bool>(
              stream: audioService.playingStream,
              initialData: audioService.isPlaying,
              builder: (context, snapshot) {
                return AudioListTile(
                  audio: audio,
                  isSelected: true,
                  isPlaying: snapshot.data ?? false,
                  onTap: () => onSelect(audio),
                );
              },
            );
          },
        ),
        const SliverToBoxAdapter(child: SizedBox(height: _bottomSpace)),
        const SliverBottomSafeArea(),
      ],
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
          const Icon(Icons.music_off, size: 64, color: VineTheme.secondaryText),
          const SizedBox(height: 16),
          Text(
            context.l10n.videoEditorAudioNoSoundsAvailableTitle,
            style: VineTheme.bodyLargeFont(),
          ),
          const SizedBox(height: 8),
          Text(
            context.l10n.videoEditorAudioNoSoundsAvailableSubtitle,
            style: VineTheme.bodyMediumFont(color: VineTheme.secondaryText),
            textAlign: TextAlign.center,
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
            Text(
              context.l10n.videoEditorAudioFailedToLoadTitle,
              style: VineTheme.bodyLargeFont(),
            ),
            const SizedBox(height: 8),
            Text(
              error.toString(),
              style: VineTheme.bodySmallFont(color: VineTheme.secondaryText),
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
              label: Text(context.l10n.commonRetry),
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
