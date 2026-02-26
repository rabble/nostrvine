// ABOUTME: Bottom sheet for sticker selection in the video editor.
// ABOUTME: Features search functionality and a responsive grid of stickers.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:models/models.dart' show StickerData;
import 'package:openvine/blocs/video_editor/sticker/video_editor_sticker_bloc.dart';
import 'package:openvine/widgets/video_editor/sticker_editor/video_editor_sticker.dart';

/// A bottom sheet that displays a searchable grid of stickers.
///
/// Returns the selected [StickerData] via [context.pop] when a sticker is
/// tapped.
class VideoEditorStickerSheet extends StatelessWidget {
  const VideoEditorStickerSheet({super.key});

  @override
  Widget build(BuildContext context) {
    final bottomInset = MediaQuery.viewInsetsOf(context).bottom;

    return GestureDetector(
      onTap: () => FocusManager.instance.primaryFocus?.unfocus(),
      child: CustomScrollView(
        slivers: [
          // Floating Search Bar Header
          const _SearchBar(),
          // Grid with Sticker Icons
          SliverPadding(
            padding: EdgeInsets.fromLTRB(16, 16, 16, 16 + bottomInset),
            sliver: BlocBuilder<VideoEditorStickerBloc, VideoEditorStickerState>(
              builder: (context, state) {
                return switch (state) {
                  VideoEditorStickerInitial() ||
                  VideoEditorStickerLoading() => const SliverToBoxAdapter(
                    child: Center(child: CircularProgressIndicator()),
                  ),
                  VideoEditorStickerLoaded(:final stickers)
                      when stickers.isNotEmpty =>
                    _StickerGrid(stickers: stickers),
                  VideoEditorStickerLoaded(:final hasSearchQuery) => _EmptyState(
                    // TODO(l10n): Replace with context.l10n when localization is added.
                    message: hasSearchQuery
                        ? 'No stickers found'
                        : 'No stickers available',
                  ),
                  VideoEditorStickerError() => const _EmptyState(
                    // TODO(l10n): Replace with context.l10n when localization is added.
                    message: 'Failed to load stickers',
                  ),
                };
              },
            ),
          ),
        ],
      ),
    );
  }
}

/// A responsive grid displaying stickers with tap-to-select functionality.
class _StickerGrid extends StatelessWidget {
  const _StickerGrid({required this.stickers});

  /// The list of stickers to display in the grid.
  final List<StickerData> stickers;

  @override
  Widget build(BuildContext context) {
    return SliverGrid(
      gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
        maxCrossAxisExtent: 120,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
      ),
      delegate: SliverChildBuilderDelegate((context, index) {
        final sticker = stickers[index];
        return Semantics(
          label: sticker.description,
          button: true,
          child: GestureDetector(
            onTap: () => context.pop(sticker),
            child: VideoEditorSticker(sticker: sticker),
          ),
        );
      }, childCount: stickers.length),
    );
  }
}

/// Empty state widget shown when no stickers are available or found.
class _EmptyState extends StatelessWidget {
  const _EmptyState({required this.message});

  /// The message to display (e.g., "No stickers found").
  final String message;

  @override
  Widget build(BuildContext context) {
    return SliverToBoxAdapter(
      child: Text(
        message,
        style: VineTheme.bodyFont(color: Colors.white54),
        textAlign: .center,
      ),
    );
  }
}

/// A floating search bar for filtering stickers by name or tags.
class _SearchBar extends StatefulWidget {
  const _SearchBar();

  @override
  State<_SearchBar> createState() => _SearchBarState();
}

class _SearchBarState extends State<_SearchBar> {
  final _searchController = TextEditingController();
  final _focusNode = FocusNode();

  static const _iconColor = Color(0xFF818E8A);

  @override
  void dispose() {
    _searchController.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _clearSearch() {
    _searchController.clear();
    _focusNode.requestFocus();
    _setQuery('');
  }

  void _setQuery(String value) {
    context.read<VideoEditorStickerBloc>().add(VideoEditorStickerSearch(value));
  }

  @override
  Widget build(BuildContext context) {
    return SliverAppBar(
      floating: true,
      snap: true,
      automaticallyImplyLeading: false,
      backgroundColor: VineTheme.surfaceBackground,
      surfaceTintColor: Colors.transparent,
      toolbarHeight: 64,
      flexibleSpace: Padding(
        padding: const .symmetric(horizontal: 16, vertical: 8),
        child: TextField(
          controller: _searchController,
          focusNode: _focusNode,
          keyboardType: .text,
          textInputAction: .search,
          style: VineTheme.bodyFont(height: 1.5, letterSpacing: 0.15),
          onChanged: _setQuery,
          onSubmitted: (_) => _focusNode.unfocus(),
          decoration: InputDecoration(
            // TODO(l10n): Replace with context.l10n when localization is added.
            hintText: 'Search stickers...',
            hintStyle: VineTheme.bodyFont(
              height: 1.5,
              letterSpacing: 0.15,
              color: const Color(0x80FFFFFF),
            ),
            filled: true,
            fillColor: VineTheme.surfaceContainer,
            border: OutlineInputBorder(
              borderRadius: .circular(20),
              borderSide: .none,
            ),
            contentPadding: const .symmetric(horizontal: 16, vertical: 12),
            prefixIcon: const Padding(
              padding: .only(left: 16, right: 12),
              child: DivineIcon(icon: .search, color: _iconColor),
            ),
            prefixIconConstraints: const BoxConstraints(
              minWidth: 24,
              minHeight: 24,
            ),
            suffixIcon:
                BlocSelector<
                  VideoEditorStickerBloc,
                  VideoEditorStickerState,
                  bool
                >(
                  selector: (state) =>
                      state is VideoEditorStickerLoaded && state.hasSearchQuery,
                  builder: (context, hasSearchQuery) {
                    return hasSearchQuery
                        ? IconButton(
                            icon: const Icon(
                              Icons.close_rounded,
                              color: _iconColor,
                            ),
                            onPressed: _clearSearch,
                          )
                        : const SizedBox.shrink();
                  },
                ),
          ),
        ),
      ),
    );
  }
}
