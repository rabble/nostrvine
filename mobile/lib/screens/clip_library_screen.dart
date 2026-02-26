// ABOUTME: Screen for browsing and managing saved video clips and drafts
// ABOUTME: Shows tabs for clips and drafts with preview, delete, and import options

import 'dart:async';
import 'dart:io';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:models/models.dart' as model show AspectRatio;
import 'package:openvine/constants/video_editor_constants.dart';
import 'package:openvine/models/saved_clip.dart';
import 'package:openvine/models/vine_draft.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/clip_manager_provider.dart';
import 'package:openvine/providers/video_publish_provider.dart';
import 'package:openvine/screens/feed/video_feed_page.dart';
import 'package:openvine/screens/video_editor/video_clip_editor_screen.dart';
import 'package:openvine/screens/video_recorder_screen.dart';
import 'package:openvine/services/draft_storage_service.dart';
import 'package:openvine/services/gallery_save_service.dart';
import 'package:openvine/utils/unified_logger.dart';
import 'package:openvine/utils/video_editor_utils.dart';
import 'package:openvine/widgets/masonary_grid.dart';
import 'package:openvine/widgets/video_clip/video_clip_preview_sheet.dart';
import 'package:openvine/widgets/video_clip/video_clip_thumbnail_card.dart';
import 'package:pro_video_editor/pro_video_editor.dart';

class ClipLibraryScreen extends ConsumerStatefulWidget {
  /// Route name for drafts path.
  static const draftsRouteName = 'drafts';

  /// Path for drafts route.
  static const draftsPath = '/drafts';

  /// Route name for clips path.
  static const clipsRouteName = 'clips';

  /// Path for clips route.
  static const clipsPath = '/clips';

  const ClipLibraryScreen({
    super.key,
    this.selectionMode = false,
    this.onClipSelected,
  });

  /// When true, tapping a clip calls onClipSelected instead of previewing
  final bool selectionMode;

  /// Called when a clip is selected in selection mode
  final void Function(SavedClip clip)? onClipSelected;

  @override
  ConsumerState<ClipLibraryScreen> createState() => _ClipLibraryScreenState();
}

class _ClipLibraryScreenState extends ConsumerState<ClipLibraryScreen> {
  List<SavedClip> _clips = [];
  List<VineDraft> _drafts = [];
  bool _isLoading = true;
  bool _isDeleting = false;
  // Always show selection checkboxes when not in single-selection mode
  // This makes multi-select the default behavior for better UX
  final Set<String> _selectedClipIds = {};

  Duration _selectedDuration = Duration.zero;

  @override
  void initState() {
    super.initState();
    Log.info(
      '📚 ClipLibrary opened (selectionMode: ${widget.selectionMode})',
      name: 'ClipLibraryScreen',
      category: LogCategory.video,
    );
    unawaited(_loadClips());
    unawaited(_loadDrafts());
  }

  Future<void> _loadClips() async {
    try {
      final clipService = ref.read(clipLibraryServiceProvider);
      final clips = await clipService.getAllClips();

      Log.debug(
        '📚 Loaded ${clips.length} clips from library',
        name: 'ClipLibraryScreen',
        category: LogCategory.video,
      );

      if (mounted) {
        setState(() {
          _clips = clips;
          _isLoading = false;
        });
      }
    } catch (e) {
      Log.error(
        '📚 Failed to load clips: $e',
        name: 'ClipLibraryScreen',
        category: LogCategory.video,
      );
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
  }

  Future<void> _loadDrafts() async {
    try {
      final draftService = DraftStorageService();
      final drafts = await draftService.getAllDrafts();

      // Filter out autosave and already published drafts, sort by newest first
      final filteredDrafts =
          drafts
              .where(
                (d) =>
                    d.id != VideoEditorConstants.autoSaveId &&
                    d.publishStatus != PublishStatus.published,
              )
              .toList()
            ..sort((a, b) => b.lastModified.compareTo(a.lastModified));

      Log.debug(
        '📚 Loaded ${filteredDrafts.length} drafts',
        name: 'ClipLibraryScreen',
        category: LogCategory.video,
      );

      if (mounted) {
        setState(() {
          _drafts = filteredDrafts;
        });
      }
    } catch (e) {
      Log.error(
        '📚 Failed to load drafts: $e',
        name: 'ClipLibraryScreen',
        category: LogCategory.video,
      );
      // Silently fail - drafts will just be empty
    }
  }

  Duration get _remainingDuration {
    final remainingDuration = widget.selectionMode
        ? ref.watch(clipManagerProvider.select((s) => s.remainingDuration))
        : VideoEditorConstants.maxDuration;
    return remainingDuration - _selectedDuration;
  }

  String _buildAppBarTitle() {
    if (widget.selectionMode) {
      return 'Select Clip';
    } else if (_selectedClipIds.isNotEmpty) {
      return '${_selectedClipIds.length} selected';
    } else {
      return 'Clips';
    }
  }

  void _clearSelection() {
    setState(_selectedClipIds.clear);
    _selectedDuration = .zero;
  }

  void _showDeleteConfirmationDialog() {
    final clipCount = _selectedClipIds.length;

    showDialog<void>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: VineTheme.cardBackground,
        title: const Text(
          'Delete Clips',
          style: TextStyle(color: VineTheme.whiteText),
        ),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              'Are you sure you want to delete $clipCount '
              'selected clip${clipCount == 1 ? '' : 's'}?',
              style: const TextStyle(color: VineTheme.whiteText),
            ),
            const SizedBox(height: 12),
            const Text(
              'This action cannot be undone. The video files will be '
              'permanently removed from your device.',
              style: TextStyle(color: VineTheme.secondaryText, fontSize: 12),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () {
              Navigator.of(dialogContext).pop();
              _deleteSelectedClips();
            },
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteSelectedClips() async {
    if (_selectedClipIds.isEmpty) return;

    setState(() => _isDeleting = true);

    try {
      final clipService = ref.read(clipLibraryServiceProvider);
      final deletedCount = _selectedClipIds.length;

      Log.info(
        '📚 Deleting $deletedCount clips',
        name: 'ClipLibraryScreen',
        category: LogCategory.video,
      );

      for (final clipId in _selectedClipIds.toList()) {
        await clipService.deleteClip(clipId);
      }

      _clearSelection();
      await _loadClips();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            behavior: SnackBarBehavior.floating,
            content: DivineSnackbarContainer(
              label:
                  '$deletedCount clip${deletedCount == 1 ? '' : 's'} deleted',
            ),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            behavior: SnackBarBehavior.floating,
            content: DivineSnackbarContainer(
              label: 'Failed to delete clips: $e',
              error: true,
            ),
          ),
        );
      }
    } finally {
      if (mounted) {
        setState(() => _isDeleting = false);
      }
    }
  }

  void _toggleClipSelection(SavedClip clip) {
    setState(() {
      if (_selectedClipIds.contains(clip.id)) {
        _selectedClipIds.remove(clip.id);
        _selectedDuration -= clip.duration;
      } else {
        _selectedClipIds.add(clip.id);
        _selectedDuration += clip.duration;
      }
    });
  }

  Future<void> _createVideoFromSelected() async {
    final selectedClips = _clips
        .where((clip) => _selectedClipIds.contains(clip.id))
        .toList();
    if (selectedClips.isEmpty) return;

    Log.info(
      '📚 Creating video from ${selectedClips.length} selected clips',
      name: 'ClipLibraryScreen',
      category: LogCategory.video,
    );

    // Add selected clips to ClipManager
    final clipManagerNotifier = ref.read(clipManagerProvider.notifier);
    final videoPublishNotifier = ref.read(videoPublishProvider.notifier);

    if (!widget.selectionMode) {
      // Clear cached/autosaved values.
      await videoPublishNotifier.clearAll();
    }

    // Add each selected clip
    for (final clip in selectedClips) {
      clipManagerNotifier.addClip(
        video: EditorVideo.file(clip.filePath),
        duration: clip.duration,
        thumbnailPath: clip.thumbnailPath,
        targetAspectRatio: model.AspectRatio.values.firstWhere(
          (el) => el.name == clip.aspectRatio,
          orElse: () => .vertical,
        ),
        originalAspectRatio: 9 / 16,
      );
    }

    if (widget.selectionMode) {
      context.pop();
    } else {
      // Navigate to editor with fromLibrary flag so back goes to recorder
      await context.push(
        VideoClipEditorScreen.path,
        extra: {'fromLibrary': true},
      );

      // Clear selection
      _clearSelection();
    }
  }

  Future<void> _saveSelectedClipsToGallery() async {
    final selectedClips = _clips
        .where((clip) => _selectedClipIds.contains(clip.id))
        .toList();
    if (selectedClips.isEmpty) return;

    final clipCount = selectedClips.length;

    Log.info(
      '📚 Saving $clipCount clips to gallery',
      name: 'ClipLibraryScreen',
      category: LogCategory.video,
    );

    final gallerySaveService = ref.read(gallerySaveServiceProvider);
    var successCount = 0;
    var failureCount = 0;

    for (final clip in selectedClips) {
      final result = await gallerySaveService.saveVideoToGallery(
        EditorVideo.file(clip.filePath),
      );
      switch (result) {
        case GallerySaveSuccess():
          successCount++;
        case GallerySavePermissionDenied():
          // Stop immediately on permission denied
          if (mounted) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                behavior: SnackBarBehavior.floating,
                content: DivineSnackbarContainer(
                  label:
                      '${GallerySaveService.destinationName}'
                      ' permission denied',
                  error: true,
                ),
              ),
            );
          }
          return;
        case GallerySaveFailure():
          failureCount++;
      }
    }

    if (!mounted) return;

    final label = failureCount == 0
        ? '$successCount clip${successCount == 1 ? '' : 's'} '
              'saved to ${GallerySaveService.destinationName}'
        : '$successCount saved, $failureCount failed';

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        behavior: SnackBarBehavior.floating,
        content: DivineSnackbarContainer(label: label, error: failureCount > 0),
      ),
    );

    _clearSelection();
  }

  Future<void> _showClipPreview(SavedClip clip) async {
    Navigator.push(
      context,
      PageRouteBuilder(
        opaque: false,
        maintainState: true,
        pageBuilder: (_, _, _) => VideoClipPreviewSheet(clip: clip),
        transitionsBuilder: (_, animation, __, child) {
          return FadeTransition(opacity: animation, child: child);
        },
        transitionDuration: const Duration(milliseconds: 200),
        reverseTransitionDuration: const Duration(milliseconds: 200),
      ),
    );
  }

  Future<void> _openDraft(VineDraft draft) async {
    Log.info(
      '📚 Opening draft: ${draft.id}',
      name: 'ClipLibraryScreen',
      category: LogCategory.video,
    );
    final videoPublishNotifier = ref.read(videoPublishProvider.notifier);
    await videoPublishNotifier.clearAll();

    if (!mounted) return;

    // Navigate to editor with draftId as path parameter
    await context.push(
      '${VideoClipEditorScreen.path}/${draft.id}',
      extra: {'fromLibrary': true},
    );

    // Reload drafts after returning
    await _loadDrafts();
  }

  Future<void> _deleteDraft(VineDraft draft) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: VineTheme.cardBackground,
        title: const Text(
          'Delete Draft',
          style: TextStyle(color: VineTheme.whiteText),
        ),
        content: Text(
          'Are you sure you want to delete "${draft.title.isEmpty ? "Untitled" : draft.title}"?',
          style: const TextStyle(color: VineTheme.whiteText),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(dialogContext).pop(false),
            child: const Text('Cancel', style: TextStyle(color: Colors.grey)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.of(dialogContext).pop(true),
            style: ElevatedButton.styleFrom(
              backgroundColor: Colors.red,
              foregroundColor: Colors.white,
            ),
            child: const Text('Delete'),
          ),
        ],
      ),
    );

    if (confirmed == true) {
      Log.info(
        '📚 Deleting draft: ${draft.id}',
        name: 'ClipLibraryScreen',
        category: LogCategory.video,
      );
      final draftService = DraftStorageService();
      await draftService.deleteDraft(draft.id);
      await _loadDrafts();

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            behavior: SnackBarBehavior.floating,
            content: DivineSnackbarContainer(label: 'Draft deleted'),
          ),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final clips = ref.watch(clipManagerProvider).clips;

    final targetAspectRatio = clips.isNotEmpty
        ? clips.first.targetAspectRatio.value
        : _selectedClipIds.isNotEmpty
        ? _clips
              .firstWhere((el) => el.id == _selectedClipIds.first)
              .aspectRatioValue
        : null;

    return Stack(
      children: [
        AnnotatedRegion<SystemUiOverlayStyle>(
          value: const SystemUiOverlayStyle(
            statusBarColor: Colors.black,
            statusBarIconBrightness: Brightness.light,
            statusBarBrightness: Brightness.dark,
          ),
          child: Scaffold(
            backgroundColor: widget.selectionMode
                ? VineTheme.surfaceBackground
                : const Color(0xFF101111),
            appBar: widget.selectionMode
                ? null
                : AppBar(
                    backgroundColor: const Color(0xFF101111),
                    foregroundColor: VineTheme.whiteText,
                    leading: IconButton(
                      icon: const Icon(Icons.arrow_back),
                      onPressed: () {
                        if (context.canPop()) {
                          context.pop();
                        } else {
                          context.go(VideoFeedPage.pathForIndex(0));
                        }
                      },
                    ),
                    title: Text(_buildAppBarTitle()),
                    actions:
                        _selectedClipIds.isNotEmpty && !widget.selectionMode
                        ? [
                            // Save to gallery button
                            IconButton(
                              icon: DivineIcon(
                                icon: .downloadSimple,
                                size: 24,
                                color: VineTheme.whiteText,
                              ),
                              onPressed: _saveSelectedClipsToGallery,
                              tooltip: 'Save to camera roll',
                            ),
                            // Delete button
                            IconButton(
                              icon: DivineIcon(
                                icon: .trash,
                                size: 24,
                                color: VineTheme.error,
                              ),
                              onPressed: _showDeleteConfirmationDialog,
                              tooltip: 'Delete selected clips',
                            ),
                          ]
                        : null,
                  ),
            body: Column(
              children: [
                if (widget.selectionMode)
                  _SelectionHeader(
                    isSelectionMode: widget.selectionMode,
                    selectedClipIds: _selectedClipIds,
                    remainingDuration: _remainingDuration,
                    onCreate: _createVideoFromSelected,
                  )
                else
                  const SizedBox(height: 4),
                Expanded(child: _buildUnifiedContent(targetAspectRatio)),
              ],
            ),
            floatingActionButton:
                !widget.selectionMode && _selectedClipIds.isNotEmpty
                ? FloatingActionButton.extended(
                    onPressed: _createVideoFromSelected,
                    icon: const Icon(Icons.movie_creation),
                    label: const Text('Create Video'),
                    backgroundColor: VineTheme.vineGreen,
                  )
                : null,
          ),
        ),
        if (_isDeleting)
          Container(
            color: Colors.black54,
            child: const Center(
              child: CircularProgressIndicator(color: VineTheme.vineGreen),
            ),
          ),
      ],
    );
  }

  Widget _buildUnifiedContent(double? targetAspectRatio) {
    if (_isLoading) {
      return const Center(
        child: CircularProgressIndicator(color: VineTheme.vineGreen),
      );
    }

    // In selection mode, only show clips
    if (widget.selectionMode) {
      if (_clips.isEmpty) {
        return _EmptyClips(isSelectionMode: widget.selectionMode);
      }
      return _MasonryLayout(
        clips: _clips,
        selectedClipIds: _selectedClipIds,
        remainingDuration: _remainingDuration,
        targetAspectRatio: targetAspectRatio,
        onTapClip: _toggleClipSelection,
        onLongPressClip: _showClipPreview,
      );
    }

    // Show unified view: drafts at top, then clips
    if (_drafts.isEmpty && _clips.isEmpty) {
      return const _EmptyLibrary();
    }

    // If only clips (no drafts), show the masonry layout directly
    if (_drafts.isEmpty) {
      return _MasonryLayout(
        clips: _clips,
        selectedClipIds: _selectedClipIds,
        remainingDuration: _remainingDuration,
        targetAspectRatio: targetAspectRatio,
        onTapClip: _toggleClipSelection,
        onLongPressClip: _showClipPreview,
      );
    }

    // If only drafts (no clips), show drafts list
    if (_clips.isEmpty) {
      return ListView.builder(
        padding: const EdgeInsets.all(16),
        itemCount: _drafts.length + 1, // +1 for header
        itemBuilder: (context, index) {
          if (index == 0) {
            return Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: Text(
                'Ready to Post (${_drafts.length})',
                style: const TextStyle(
                  color: VineTheme.whiteText,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
            );
          }
          final draft = _drafts[index - 1];
          return _DraftListTile(
            draft: draft,
            onTap: () => _openDraft(draft),
            onDelete: () => _deleteDraft(draft),
          );
        },
      );
    }

    // Both drafts and clips - show first draft as banner, clips below
    return Column(
      children: [
        // Show first draft as a prominent banner
        Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 0),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Ready to Post (${_drafts.length})',
                style: const TextStyle(
                  color: VineTheme.whiteText,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              // Show first draft only to avoid layout issues
              _DraftListTile(
                draft: _drafts.first,
                onTap: () => _openDraft(_drafts.first),
                onDelete: () => _deleteDraft(_drafts.first),
              ),
              if (_drafts.length > 1)
                Padding(
                  padding: const EdgeInsets.only(top: 4),
                  child: Text(
                    '+${_drafts.length - 1} more draft${_drafts.length > 2 ? 's' : ''}',
                    style: TextStyle(color: Colors.grey[400], fontSize: 12),
                  ),
                ),
              const Divider(color: Colors.grey, height: 24),
              Text(
                'Clips (${_clips.length})',
                style: const TextStyle(
                  color: VineTheme.whiteText,
                  fontSize: 16,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        // Clips masonry grid
        Expanded(
          child: _MasonryLayout(
            clips: _clips,
            selectedClipIds: _selectedClipIds,
            remainingDuration: _remainingDuration,
            targetAspectRatio: targetAspectRatio,
            onTapClip: _toggleClipSelection,
            onLongPressClip: _showClipPreview,
          ),
        ),
      ],
    );
  }
}

class _SelectionHeader extends ConsumerWidget {
  _SelectionHeader({
    required this.isSelectionMode,
    required this.selectedClipIds,
    required this.onCreate,
    required this.remainingDuration,
  });

  final bool isSelectionMode;
  final Set<String> selectedClipIds;
  final VoidCallback onCreate;
  final Duration remainingDuration;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return Column(
      children: [
        Padding(
          padding: const .only(bottom: 16.0),
          child: Row(
            mainAxisSize: .min,
            spacing: 4,
            children: [
              const Spacer(),
              Column(
                mainAxisSize: .min,
                mainAxisAlignment: .center,
                children: [
                  Text(
                    // TODO(l10n): Replace with context.l10n when localization is added.
                    'Clips',
                    style: VineTheme.titleFont(
                      color: VineTheme.onSurface,
                      fontSize: 18,
                      height: 1.33,
                      letterSpacing: 0.15,
                    ),
                  ),
                  Text(
                    '${remainingDuration.toFormattedSeconds()}s remaining',
                    style: VineTheme.bodyFont(
                      color: const Color(0xBEFFFFFF),
                      fontSize: 12,
                      height: 1.33,
                      letterSpacing: 0.40,
                    ).copyWith(fontFeatures: [const .tabularFigures()]),
                  ),
                ],
              ),
              Expanded(
                child: Align(
                  alignment: .centerRight,
                  child: _AddClipButton(
                    onTap: selectedClipIds.isNotEmpty ? onCreate : context.pop,
                    enable: selectedClipIds.isNotEmpty,
                  ),
                ),
              ),
            ],
          ),
        ),
        const Divider(
          height: 2,
          thickness: 2,
          color: VineTheme.outlinedDisabled,
        ),
      ],
    );
  }
}

class _MasonryLayout extends StatelessWidget {
  const _MasonryLayout({
    required this.clips,
    required this.selectedClipIds,
    required this.remainingDuration,
    required this.onTapClip,
    required this.onLongPressClip,
    this.targetAspectRatio,
  });

  final List<SavedClip> clips;
  final Set<String> selectedClipIds;
  final Duration remainingDuration;
  final ValueChanged<SavedClip> onTapClip;
  final ValueChanged<SavedClip> onLongPressClip;
  final double? targetAspectRatio;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const .symmetric(horizontal: 8),
      child: MasonryGrid(
        columnCount: 2,
        rowGap: 4,
        columnGap: 4,
        itemAspectRatios: clips.map((clip) => clip.aspectRatioValue).toList(),
        children: clips.map((clip) {
          final isSelected = selectedClipIds.contains(clip.id);
          return VideoClipThumbnailCard(
            clip: clip,
            isSelected: isSelected,
            disabled:
                (targetAspectRatio != null &&
                    targetAspectRatio != clip.aspectRatioValue) ||
                (!isSelected && clip.duration > remainingDuration),
            onTap: () => onTapClip(clip),
            onLongPress: () => onLongPressClip(clip),
          );
        }).toList(),
      ),
    );
  }
}

class _EmptyClips extends StatelessWidget {
  const _EmptyClips({required this.isSelectionMode});

  final bool isSelectionMode;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.grey[800],
              border: .all(color: Colors.grey[600]!, width: 2),
            ),
            child: const Icon(
              Icons.video_library_outlined,
              size: 60,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'No Clips Yet',
            style: TextStyle(
              color: VineTheme.whiteText,
              fontSize: 24,
              fontWeight: .bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your recorded video clips will appear here',
            style: TextStyle(color: Colors.grey[400], fontSize: 16),
          ),
          if (!isSelectionMode) ...[
            const SizedBox(height: 32),
            ElevatedButton.icon(
              onPressed: () => context.push(VideoRecorderScreen.path),
              icon: const Icon(Icons.videocam),
              label: const Text('Record a Video'),
              style: ElevatedButton.styleFrom(
                backgroundColor: VineTheme.vineGreen,
                foregroundColor: VineTheme.whiteText,
                padding: const EdgeInsets.symmetric(
                  horizontal: 24,
                  vertical: 12,
                ),
                shape: RoundedRectangleBorder(borderRadius: .circular(12)),
              ),
            ),
          ],
        ],
      ),
    );
  }
}

class _AddClipButton extends StatelessWidget {
  const _AddClipButton({required this.onTap, this.enable = true});

  final VoidCallback? onTap;
  final bool enable;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      button: true,
      // TODO(l10n): Replace with context.l10n when localization is added.
      label: 'Add',
      child: GestureDetector(
        onTap: onTap,
        child: Opacity(
          opacity: enable ? 1 : 0.32,
          child: Container(
            margin: const .only(right: 16),
            padding: const .symmetric(horizontal: 16, vertical: 8),
            decoration: ShapeDecoration(
              color: VineTheme.tabIndicatorGreen,
              shape: RoundedRectangleBorder(borderRadius: .circular(16)),
            ),
            child: const Text(
              // TODO(l10n): Replace with context.l10n when localization is added.
              'Add',
              textAlign: TextAlign.center,
              style: TextStyle(
                color: Color(0xFF002C1C),
                fontSize: 18,
                fontFamily: VineTheme.fontFamilyBricolage,
                fontWeight: FontWeight.w800,
                height: 1.33,
                letterSpacing: 0.15,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _EmptyLibrary extends StatelessWidget {
  const _EmptyLibrary();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 120,
            height: 120,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.grey[800],
              border: Border.all(color: Colors.grey[600]!, width: 2),
            ),
            child: const Icon(
              Icons.video_library_outlined,
              size: 60,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'Library Empty',
            style: TextStyle(
              color: VineTheme.whiteText,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your saved videos and drafts will appear here',
            style: TextStyle(color: Colors.grey[400], fontSize: 16),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () => context.push(VideoRecorderScreen.path),
            icon: const Icon(Icons.videocam),
            label: const Text('Record a Video'),
            style: ElevatedButton.styleFrom(
              backgroundColor: VineTheme.vineGreen,
              foregroundColor: VineTheme.whiteText,
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _DraftListTile extends StatelessWidget {
  const _DraftListTile({
    required this.draft,
    required this.onTap,
    required this.onDelete,
  });

  final VineDraft draft;
  final VoidCallback onTap;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Card(
      color: VineTheme.cardBackground,
      margin: const EdgeInsets.only(bottom: 12),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(12),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Thumbnail
              Container(
                width: 80,
                height: 80,
                decoration: BoxDecoration(
                  color: Colors.grey[800],
                  borderRadius: BorderRadius.circular(8),
                ),
                child:
                    draft.clips.isNotEmpty &&
                        draft.clips.first.thumbnailPath != null
                    ? ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: Image.file(
                          File(draft.clips.first.thumbnailPath!),
                          fit: BoxFit.cover,
                          errorBuilder: (_, __, ___) => const Icon(
                            Icons.video_file,
                            color: Colors.grey,
                            size: 40,
                          ),
                        ),
                      )
                    : const Icon(
                        Icons.video_file,
                        color: Colors.grey,
                        size: 40,
                      ),
              ),
              const SizedBox(width: 16),
              // Content
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      draft.title.isEmpty ? 'Untitled' : draft.title,
                      style: const TextStyle(
                        color: VineTheme.whiteText,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      draft.displayDuration,
                      style: TextStyle(color: Colors.grey[400], fontSize: 14),
                    ),
                    if (draft.hashtags.isNotEmpty) ...[
                      const SizedBox(height: 4),
                      Text(
                        draft.hashtags.map((t) => '#$t').join(' '),
                        style: TextStyle(
                          color: VineTheme.vineGreen.withValues(alpha: 0.8),
                          fontSize: 12,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                    ],
                  ],
                ),
              ),
              // Delete button
              IconButton(
                icon: const Icon(Icons.delete_outline, color: Colors.red),
                onPressed: onDelete,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
