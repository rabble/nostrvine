// ABOUTME: Bottom sheet UI for browsing and selecting stickers from curated packs.
// ABOUTME: Displays a searchable grid of sticker images with BLoC-driven state.

import 'package:cached_network_image/cached_network_image.dart';
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/blocs/sticker_picker/sticker_picker_bloc.dart';
import 'package:sticker_pack_repository/sticker_pack_repository.dart';

/// Bottom sheet for browsing and selecting stickers.
///
/// Renders a searchable grid of sticker images from curated packs.
/// Returns the selected [Sticker] via `context.pop(sticker)`.
class StickerPickerSheet extends StatelessWidget {
  const StickerPickerSheet({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<StickerPickerBloc, StickerPickerState>(
      builder: (context, state) {
        return switch (state) {
          StickerPickerInitial() ||
          StickerPickerLoading() => const _LoadingState(),
          StickerPickerLoaded(:final filteredStickers) => _StickerContent(
            stickers: filteredStickers,
          ),
          StickerPickerError(:final message) => _ErrorState(message: message),
        };
      },
    );
  }
}

class _LoadingState extends StatelessWidget {
  const _LoadingState();

  @override
  Widget build(BuildContext context) {
    return const Center(
      child: Padding(
        padding: EdgeInsets.all(48),
        child: CircularProgressIndicator(color: VineTheme.vineGreen),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message});

  final String message;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.error_outline, color: VineTheme.error, size: 48),
            const SizedBox(height: 16),
            Text(
              message,
              style: VineTheme.bodyFont(color: VineTheme.secondaryText),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}

class _StickerContent extends StatelessWidget {
  const _StickerContent({required this.stickers});

  final List<Sticker> stickers;

  @override
  Widget build(BuildContext context) {
    return CustomScrollView(
      slivers: [
        SliverAppBar(
          floating: true,
          snap: true,
          automaticallyImplyLeading: false,
          backgroundColor: VineTheme.surfaceBackground,
          toolbarHeight: 56,
          title: _SearchBar(
            onChanged: (query) {
              context.read<StickerPickerBloc>().add(
                StickerSearchChanged(query),
              );
            },
          ),
        ),
        if (stickers.isEmpty)
          const SliverFillRemaining(child: _EmptyState())
        else
          SliverPadding(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            sliver: SliverGrid(
              gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                maxCrossAxisExtent: 100,
                mainAxisSpacing: 8,
                crossAxisSpacing: 8,
              ),
              delegate: SliverChildBuilderDelegate(
                (context, index) {
                  final sticker = stickers[index];
                  return _StickerTile(sticker: sticker);
                },
                childCount: stickers.length,
              ),
            ),
          ),
      ],
    );
  }
}

class _SearchBar extends StatelessWidget {
  const _SearchBar({required this.onChanged});

  final ValueChanged<String> onChanged;

  @override
  Widget build(BuildContext context) {
    return TextField(
      onChanged: onChanged,
      style: VineTheme.bodyFont(color: VineTheme.onSurface),
      cursorColor: VineTheme.tabIndicatorGreen,
      decoration: InputDecoration(
        hintText: 'Search stickers...',
        hintStyle: VineTheme.bodyFont(color: VineTheme.onSurfaceMuted),
        prefixIcon: const Icon(
          Icons.search,
          color: VineTheme.onSurfaceMuted,
          size: 20,
        ),
        filled: true,
        fillColor: VineTheme.containerLow,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        contentPadding: const EdgeInsets.symmetric(vertical: 8),
        isDense: true,
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Text(
        'No stickers found',
        style: VineTheme.bodyFont(color: VineTheme.onSurfaceMuted),
      ),
    );
  }
}

class _StickerTile extends StatelessWidget {
  const _StickerTile({required this.sticker});

  final Sticker sticker;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      identifier: 'sticker_${sticker.shortcode}',
      button: true,
      label: sticker.shortcode,
      child: InkWell(
        onTap: () => context.pop(sticker),
        borderRadius: BorderRadius.circular(12),
        child: Container(
          decoration: BoxDecoration(
            color: VineTheme.containerLow,
            borderRadius: BorderRadius.circular(12),
          ),
          padding: const EdgeInsets.all(8),
          child: CachedNetworkImage(
            imageUrl: sticker.imageUrl,
            fit: BoxFit.contain,
            placeholder: (_, _) => const SizedBox.shrink(),
            errorWidget: (_, _, _) => const Icon(
              Icons.broken_image_outlined,
              color: VineTheme.onSurfaceMuted,
              size: 24,
            ),
          ),
        ),
      ),
    );
  }
}
