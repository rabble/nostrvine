// ABOUTME: Sounds browser screen for discovering and selecting sounds for recordings
// ABOUTME: Features bundled sounds, trending Nostr sounds, search, and sound selection

import 'dart:async';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:models/models.dart' show AudioEvent;
import 'package:openvine/blocs/sounds/sounds_cubit.dart';
import 'package:openvine/blocs/sounds/sounds_state.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/saved_sounds_provider.dart';
import 'package:openvine/providers/sound_library_service_provider.dart';
import 'package:openvine/providers/sounds_providers.dart';
import 'package:openvine/screens/sound_detail_screen.dart';
import 'package:openvine/services/saved_sounds_service.dart';
import 'package:openvine/widgets/branded_loading_indicator.dart';
import 'package:openvine/widgets/sound_tile.dart';
import 'package:unified_logger/unified_logger.dart';

/// Page: bridges `AudioPlaybackService` and `SavedSoundsNotifier.saveSound`
/// into [SoundsCubit].
class SoundsScreen extends ConsumerWidget {
  /// Creates a SoundsScreen.
  ///
  /// [onSoundSelected] is called when the user selects a sound.
  /// If not provided, the screen saves the sound to the user's library.
  const SoundsScreen({this.onSoundSelected, super.key});

  /// Callback when a sound is selected.
  final void Function(AudioEvent sound)? onSoundSelected;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    // Both providers are app-scoped and never invalidated, so their identities
    // are stable for the Cubit's lifetime — ref.read is safe here
    // (state_management.md bridging-rule exception #1).
    final audioService = ref.read(audioPlaybackServiceProvider);
    final savedSoundsNotifier = ref.read(savedSoundsProvider.notifier);
    return BlocProvider(
      create: (_) => SoundsCubit(
        audioPlaybackService: audioService,
        saveSound: savedSoundsNotifier.saveSound,
      ),
      child: SoundsView(onSoundSelected: onSoundSelected),
    );
  }
}

/// View: renders the sounds browser from Cubit state + Riverpod-provided
/// sound lists. Owns the search `TextEditingController` (controllers stay
/// in the View — the hybrid pattern established by #4744 WS-1 #5).
class SoundsView extends ConsumerStatefulWidget {
  @visibleForTesting
  const SoundsView({this.onSoundSelected, super.key});

  final void Function(AudioEvent sound)? onSoundSelected;

  @override
  ConsumerState<SoundsView> createState() => _SoundsViewState();
}

class _SoundsViewState extends ConsumerState<SoundsView> {
  final TextEditingController _searchController = TextEditingController();

  @override
  void dispose() {
    _searchController.dispose();
    super.dispose();
  }

  void _onSoundTap(AudioEvent sound) {
    Log.info(
      'Sound selected: ${sound.title} (${sound.id})',
      name: 'SoundsScreen',
      category: LogCategory.ui,
    );

    final onSoundSelected = widget.onSoundSelected;
    if (onSoundSelected != null) {
      onSoundSelected(sound);
    } else {
      unawaited(_saveSoundToLibrary(sound));
    }
  }

  Future<void> _saveSoundToLibrary(AudioEvent sound) async {
    final cubit = context.read<SoundsCubit>();
    final result = await cubit.saveSound(sound);
    if (!mounted) return;

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

  Future<void> _onPreviewTap(AudioEvent sound) async {
    final cubit = context.read<SoundsCubit>();
    final outcome = await cubit.previewSound(sound);
    if (!mounted) return;
    switch (outcome) {
      case PreviewSoundOutcome.ignored:
      case PreviewSoundOutcome.stopped:
      case PreviewSoundOutcome.completed:
        return;
      case PreviewSoundOutcome.unavailable:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.soundsPreviewUnavailable),
            duration: const Duration(seconds: 2),
          ),
        );
      case PreviewSoundOutcome.failed:
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(context.l10n.soundsPreviewFailedGeneric),
            duration: const Duration(seconds: 2),
          ),
        );
    }
  }

  Future<void> _onDetailTap(AudioEvent sound) async {
    // Bundled sounds don't have detail pages.
    if (sound.isBundled) return;

    Log.info(
      'Navigate to sound detail: ${sound.title} (${sound.id})',
      name: 'SoundsScreen',
      category: LogCategory.ui,
    );

    // Stop any playing preview before navigating.
    await context.read<SoundsCubit>().stopPreview();
    if (!mounted) return;
    context.push(SoundDetailScreen.pathForId(sound.id), extra: sound);
  }

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: context.l10n.soundsScreenLabel,
      container: true,
      child: Scaffold(
        backgroundColor: VineTheme.backgroundColor,
        appBar: DiVineAppBar(
          title: context.l10n.soundsTitle,
          showBackButton: true,
          onBackPressed: context.pop,
          backgroundColor: VineTheme.cardBackground,
        ),
        body: Column(
          children: [
            _SearchInput(controller: _searchController),
            Expanded(
              child: _SoundsContent(
                onSoundTap: _onSoundTap,
                onPreviewTap: _onPreviewTap,
                onDetailTap: _onDetailTap,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _SearchInput extends StatelessWidget {
  const _SearchInput({required this.controller});

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      color: VineTheme.cardBackground,
      child: TextField(
        controller: controller,
        onChanged: (query) => context.read<SoundsCubit>().setSearchQuery(query),
        style: const TextStyle(color: VineTheme.whiteText),
        decoration: InputDecoration(
          hintText: context.l10n.soundsSearchHint,
          hintStyle: const TextStyle(color: VineTheme.onSurfaceMuted),
          prefixIcon: const DivineIcon(
            icon: DivineIconName.search,
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

class _SoundsContent extends ConsumerWidget {
  const _SoundsContent({
    required this.onSoundTap,
    required this.onPreviewTap,
    required this.onDetailTap,
  });

  final void Function(AudioEvent) onSoundTap;
  final void Function(AudioEvent) onPreviewTap;
  final void Function(AudioEvent) onDetailTap;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final bundledSoundsAsync = ref.watch(soundLibraryServiceProvider);
    final nostrSoundsAsync = ref.watch(trendingSoundsProvider);

    final bundledSounds =
        bundledSoundsAsync.whenOrNull(
          data: (service) {
            return service.sounds.indexed
                .map((e) => AudioEvent.fromBundledSound(e.$2, index: e.$1))
                .toList();
          },
        ) ??
        <AudioEvent>[];

    return nostrSoundsAsync.when(
      data: (nostrSounds) => _SoundsBody(
        bundledSounds: bundledSounds,
        nostrSounds: nostrSounds,
        onSoundTap: onSoundTap,
        onPreviewTap: onPreviewTap,
        onDetailTap: onDetailTap,
      ),
      loading: () => bundledSounds.isNotEmpty
          ? _SoundsBody(
              bundledSounds: bundledSounds,
              nostrSounds: const [],
              onSoundTap: onSoundTap,
              onPreviewTap: onPreviewTap,
              onDetailTap: onDetailTap,
            )
          : const Center(child: BrandedLoadingIndicator()),
      error: (error, stack) => bundledSounds.isNotEmpty
          ? _SoundsBody(
              bundledSounds: bundledSounds,
              nostrSounds: const [],
              onSoundTap: onSoundTap,
              onPreviewTap: onPreviewTap,
              onDetailTap: onDetailTap,
            )
          : _ErrorState(error: error),
    );
  }
}

class _SoundsBody extends StatelessWidget {
  const _SoundsBody({
    required this.bundledSounds,
    required this.nostrSounds,
    required this.onSoundTap,
    required this.onPreviewTap,
    required this.onDetailTap,
  });

  final List<AudioEvent> bundledSounds;
  final List<AudioEvent> nostrSounds;
  final void Function(AudioEvent) onSoundTap;
  final void Function(AudioEvent) onPreviewTap;
  final void Function(AudioEvent) onDetailTap;

  @override
  Widget build(BuildContext context) {
    final allSounds = [...bundledSounds, ...nostrSounds];
    if (allSounds.isEmpty) return const _EmptyState();

    final cubit = context.read<SoundsCubit>();
    final searchQuery = context.select((SoundsCubit c) => c.state.searchQuery);

    final filteredBundled = cubit.filterSounds(bundledSounds);
    final filteredNostr = cubit.filterSounds(nostrSounds);
    final filteredAll = [...filteredBundled, ...filteredNostr];

    if (searchQuery.isNotEmpty && filteredAll.isEmpty) {
      return const _NoResultsState();
    }

    return _SoundsRefreshable(
      child: ListView(
        children: [
          if (searchQuery.isEmpty && bundledSounds.isNotEmpty) ...[
            _FeaturedSoundsSection(
              sounds: bundledSounds,
              onSoundTap: onSoundTap,
              onPreviewTap: onPreviewTap,
            ),
            const SizedBox(height: 16),
          ],
          if (searchQuery.isEmpty && nostrSounds.isNotEmpty) ...[
            _TrendingSoundsSection(
              sounds: nostrSounds,
              onSoundTap: onSoundTap,
              onPreviewTap: onPreviewTap,
              onDetailTap: onDetailTap,
            ),
            const SizedBox(height: 16),
          ],
          _AllSoundsSection(
            sounds: searchQuery.isNotEmpty ? filteredAll : allSounds,
            isSearching: searchQuery.isNotEmpty,
            onSoundTap: onSoundTap,
            onPreviewTap: onPreviewTap,
            onDetailTap: onDetailTap,
          ),
        ],
      ),
    );
  }
}

class _SoundsRefreshable extends ConsumerWidget {
  const _SoundsRefreshable({required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return RefreshIndicator(
      color: VineTheme.onPrimary,
      backgroundColor: VineTheme.vineGreen,
      onRefresh: () => ref.read(trendingSoundsProvider.notifier).refresh(),
      child: child,
    );
  }
}

class _FeaturedSoundsSection extends StatelessWidget {
  const _FeaturedSoundsSection({
    required this.sounds,
    required this.onSoundTap,
    required this.onPreviewTap,
  });

  final List<AudioEvent> sounds;
  final void Function(AudioEvent) onSoundTap;
  final void Function(AudioEvent) onPreviewTap;

  @override
  Widget build(BuildContext context) {
    final featuredSounds = sounds.take(10).toList();
    if (featuredSounds.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          icon: Icons.star,
          label: context.l10n.soundsFeaturedSounds,
        ),
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
                child: _SoundTileSelector(
                  sound: sound,
                  compact: true,
                  onSoundTap: onSoundTap,
                  onPreviewTap: onPreviewTap,
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
    required this.onSoundTap,
    required this.onPreviewTap,
    required this.onDetailTap,
  });

  final List<AudioEvent> sounds;
  final void Function(AudioEvent) onSoundTap;
  final void Function(AudioEvent) onPreviewTap;
  final void Function(AudioEvent) onDetailTap;

  @override
  Widget build(BuildContext context) {
    final trendingSounds = sounds.take(10).toList();
    if (trendingSounds.isEmpty) return const SizedBox.shrink();

    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _SectionHeader(
          icon: Icons.local_fire_department,
          label: context.l10n.soundsTrendingSounds,
        ),
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
                child: _SoundTileSelector(
                  sound: sound,
                  compact: true,
                  onSoundTap: onSoundTap,
                  onPreviewTap: onPreviewTap,
                  onDetailTap: onDetailTap,
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
    required this.isSearching,
    required this.onSoundTap,
    required this.onPreviewTap,
    required this.onDetailTap,
  });

  final List<AudioEvent> sounds;
  final bool isSearching;
  final void Function(AudioEvent) onSoundTap;
  final void Function(AudioEvent) onPreviewTap;
  final void Function(AudioEvent) onDetailTap;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
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
                isSearching
                    ? context.l10n.soundsSearchResults
                    : context.l10n.soundsAllSounds,
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
            return _SoundTileSelector(
              sound: sound,
              onSoundTap: onSoundTap,
              onPreviewTap: onPreviewTap,
              // Bundled sounds don't get a detail-tap affordance.
              onDetailTap: sound.isBundled ? null : onDetailTap,
            );
          },
        ),
      ],
    );
  }
}

class _SoundTileSelector extends StatelessWidget {
  const _SoundTileSelector({
    required this.sound,
    required this.onSoundTap,
    required this.onPreviewTap,
    this.onDetailTap,
    this.compact = false,
  });

  final AudioEvent sound;
  final bool compact;
  final void Function(AudioEvent) onSoundTap;
  final void Function(AudioEvent) onPreviewTap;
  final void Function(AudioEvent)? onDetailTap;

  @override
  Widget build(BuildContext context) {
    final isPlaying = context.select(
      (SoundsCubit cubit) => cubit.state.previewingSoundId == sound.id,
    );
    return SoundTile(
      sound: sound,
      compact: compact,
      isPlaying: isPlaying,
      onTap: () => onSoundTap(sound),
      onPlayPreview: () => onPreviewTap(sound),
      onDetailTap: onDetailTap == null ? null : () => onDetailTap!(sound),
    );
  }
}

class _SectionHeader extends StatelessWidget {
  const _SectionHeader({required this.icon, required this.label});

  final IconData icon;
  final String label;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Icon(icon, color: VineTheme.vineGreen, size: 20),
          const SizedBox(width: 8),
          Text(
            label,
            style: const TextStyle(
              color: VineTheme.whiteText,
              fontSize: 16,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
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
          const Icon(Icons.music_off, size: 64, color: VineTheme.lightText),
          const SizedBox(height: 16),
          Text(
            context.l10n.soundsNoSoundsAvailable,
            style: const TextStyle(
              color: VineTheme.whiteText,
              fontSize: 18,
              fontWeight: FontWeight.w500,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            context.l10n.soundsNoSoundsDescription,
            style: const TextStyle(
              color: VineTheme.onSurfaceMuted,
              fontSize: 14,
            ),
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
          const SizedBox(height: 8),
          Text(
            context.l10n.soundsNoSoundsFoundDescription,
            style: const TextStyle(
              color: VineTheme.onSurfaceMuted,
              fontSize: 14,
            ),
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
            const DivineIcon(
              icon: DivineIconName.warningCircle,
              size: 64,
              color: VineTheme.likeRed,
            ),
            const SizedBox(height: 16),
            Text(
              context.l10n.soundsFailedToLoad,
              style: const TextStyle(
                color: VineTheme.whiteText,
                fontSize: 18,
                fontWeight: FontWeight.w500,
              ),
            ),
            const SizedBox(height: 8),
            Text(
              error.toString(),
              style: const TextStyle(
                color: VineTheme.onSurfaceMuted,
                fontSize: 12,
              ),
              textAlign: TextAlign.center,
              maxLines: 3,
              overflow: TextOverflow.ellipsis,
            ),
            const SizedBox(height: 24),
            ElevatedButton.icon(
              onPressed: () => ref.invalidate(trendingSoundsProvider),
              icon: const DivineIcon(icon: DivineIconName.arrowClockwise),
              label: Text(context.l10n.soundsRetry),
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
