// ABOUTME: Screen for browsing and managing saved video clips
// ABOUTME: Shows grid of clip thumbnails with preview, delete, and import options

import 'dart:async';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/models/saved_clip.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/providers/clip_manager_provider.dart';
import 'package:openvine/router/nav_extensions.dart';
import 'package:openvine/theme/vine_theme.dart';
import 'package:video_player/video_player.dart';

class ClipLibraryScreen extends ConsumerStatefulWidget {
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
  bool _isLoading = true;
  // Always show selection checkboxes when not in single-selection mode
  // This makes multi-select the default behavior for better UX
  Set<String> _selectedClipIds = {};

  @override
  void initState() {
    super.initState();
    _loadClips();
  }

  Future<void> _loadClips() async {
    setState(() {
      _isLoading = true;
    });

    try {
      final clipService = ref.read(clipLibraryServiceProvider);
      final clips = await clipService.getAllClips();

      if (mounted) {
        setState(() {
          _clips = clips;
          _isLoading = false;
        });
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isLoading = false;
        });
      }
    }
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
    setState(() {
      _selectedClipIds.clear();
    });
  }

  void _toggleClipSelection(String clipId) {
    setState(() {
      if (_selectedClipIds.contains(clipId)) {
        _selectedClipIds.remove(clipId);
      } else {
        _selectedClipIds.add(clipId);
      }
    });
  }

  Future<void> _createVideoFromSelected() async {
    final selectedClips = _clips
        .where((clip) => _selectedClipIds.contains(clip.id))
        .toList();
    if (selectedClips.isEmpty) return;

    // Add selected clips to ClipManager
    final clipManagerNotifier = ref.read(clipManagerProvider.notifier);

    // Clear existing clips first
    clipManagerNotifier.clearAll();

    // Add each selected clip
    for (final clip in selectedClips) {
      clipManagerNotifier.addClip(
        filePath: clip.filePath,
        duration: clip.duration,
        thumbnailPath: clip.thumbnailPath,
      );
    }

    // Navigate to ClipManager screen (push to preserve back navigation)
    context.push('/clip-manager');

    // Clear selection
    _clearSelection();
  }

  @override
  Widget build(BuildContext context) => Scaffold(
    backgroundColor: Colors.black,
    appBar: AppBar(
      backgroundColor: VineTheme.vineGreen,
      foregroundColor: VineTheme.whiteText,
      title: Text(_buildAppBarTitle()),
      actions: [
        // Clear selection button when clips are selected
        if (_selectedClipIds.isNotEmpty && !widget.selectionMode)
          TextButton(
            onPressed: _clearSelection,
            child: const Text(
              'Clear',
              style: TextStyle(color: VineTheme.whiteText),
            ),
          ),
        if (_selectedClipIds.isEmpty &&
            _clips.isNotEmpty &&
            !widget.selectionMode)
          PopupMenuButton<String>(
            icon: const Icon(Icons.more_vert, color: VineTheme.whiteText),
            onSelected: (value) {
              if (value == 'clear_all') {
                _showClearAllConfirmation();
              }
            },
            itemBuilder: (context) => [
              const PopupMenuItem(
                value: 'clear_all',
                child: Row(
                  children: [
                    Icon(Icons.delete_sweep, color: Colors.red),
                    SizedBox(width: 8),
                    Text('Clear All Clips'),
                  ],
                ),
              ),
            ],
          ),
      ],
    ),
    body: _isLoading
        ? const Center(
            child: CircularProgressIndicator(color: VineTheme.vineGreen),
          )
        : _clips.isEmpty
        ? _buildEmptyState()
        : _buildClipsGrid(),
    floatingActionButton: _selectedClipIds.isNotEmpty
        ? FloatingActionButton.extended(
            onPressed: _createVideoFromSelected,
            icon: const Icon(Icons.movie_creation),
            label: const Text('Create Video'),
            backgroundColor: VineTheme.vineGreen,
          )
        : null,
  );

  Widget _buildEmptyState() => Center(
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
          'No Clips Yet',
          style: TextStyle(
            color: VineTheme.whiteText,
            fontSize: 24,
            fontWeight: FontWeight.bold,
          ),
        ),
        const SizedBox(height: 8),
        Text(
          'Your recorded video clips will appear here',
          style: TextStyle(color: Colors.grey[400], fontSize: 16),
        ),
        const SizedBox(height: 32),
        ElevatedButton.icon(
          onPressed: () {
            context.pushCamera();
          },
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

  Widget _buildClipsGrid() => GridView.builder(
    padding: const EdgeInsets.all(8),
    gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
      crossAxisCount: 3,
      crossAxisSpacing: 4,
      mainAxisSpacing: 4,
      childAspectRatio: 1.0,
    ),
    itemCount: _clips.length,
    itemBuilder: (context, index) {
      final clip = _clips[index];
      return ClipThumbnailCard(
        clip: clip,
        isSelected: _selectedClipIds.contains(clip.id),
        // Show checkboxes when not in single-selection mode
        showCheckbox: !widget.selectionMode,
        onTap: () => _handleClipTap(clip),
        onLongPress: () => _showClipPreview(clip),
      );
    },
  );

  void _handleClipTap(SavedClip clip) {
    if (widget.selectionMode) {
      // Single selection mode from ClipManager - select and close
      widget.onClipSelected?.call(clip);
      context.pop();
    } else {
      // Default behavior: toggle selection for multi-select
      _toggleClipSelection(clip.id);
    }
  }

  void _showClipPreview(SavedClip clip) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) => ClipPreviewSheet(
        clip: clip,
        onDelete: () {
          sheetContext.pop();
          _confirmDeleteClip(clip);
        },
      ),
    );
  }

  void _confirmDeleteClip(SavedClip clip) {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text(
          'Delete Clip?',
          style: TextStyle(color: VineTheme.whiteText),
        ),
        content: Text(
          'This will permanently delete this ${clip.durationInSeconds.toStringAsFixed(1)}s clip.',
          style: const TextStyle(color: VineTheme.whiteText),
        ),
        actions: [
          TextButton(onPressed: dialogContext.pop, child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              dialogContext.pop();
              _deleteClip(clip);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _deleteClip(SavedClip clip) async {
    try {
      final clipService = ref.read(clipLibraryServiceProvider);
      await clipService.deleteClip(clip.id);

      // Delete video file
      final videoFile = File(clip.filePath);
      if (await videoFile.exists()) {
        await videoFile.delete();
      }

      // Delete thumbnail if exists
      if (clip.thumbnailPath != null) {
        final thumbFile = File(clip.thumbnailPath!);
        if (await thumbFile.exists()) {
          await thumbFile.delete();
        }
      }

      setState(() {
        _clips.removeWhere((c) => c.id == clip.id);
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Clip deleted'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete clip: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }

  void _showClearAllConfirmation() {
    showDialog(
      context: context,
      builder: (dialogContext) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text(
          'Clear All Clips?',
          style: TextStyle(color: VineTheme.whiteText),
        ),
        content: Text(
          'This will permanently delete all ${_clips.length} clip(s). This action cannot be undone.',
          style: const TextStyle(color: VineTheme.whiteText),
        ),
        actions: [
          TextButton(onPressed: dialogContext.pop, child: const Text('Cancel')),
          TextButton(
            onPressed: () {
              dialogContext.pop();
              _clearAllClips();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );
  }

  Future<void> _clearAllClips() async {
    try {
      final clipService = ref.read(clipLibraryServiceProvider);

      // Delete all video and thumbnail files
      for (final clip in _clips) {
        try {
          final videoFile = File(clip.filePath);
          if (await videoFile.exists()) {
            await videoFile.delete();
          }
          if (clip.thumbnailPath != null) {
            final thumbFile = File(clip.thumbnailPath!);
            if (await thumbFile.exists()) {
              await thumbFile.delete();
            }
          }
        } catch (_) {
          // Continue even if individual file deletion fails
        }
      }

      await clipService.clearAllClips();

      setState(() {
        _clips.clear();
      });

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('All clips cleared'),
            duration: Duration(seconds: 2),
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to clear clips: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

/// Thumbnail card for a single clip in the grid
class ClipThumbnailCard extends StatelessWidget {
  const ClipThumbnailCard({
    super.key,
    required this.clip,
    required this.onTap,
    required this.onLongPress,
    this.isSelected = false,
    this.showCheckbox = true,
  });

  final SavedClip clip;
  final VoidCallback onTap;
  final VoidCallback onLongPress;
  final bool isSelected;
  final bool showCheckbox;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      onLongPress: onLongPress,
      child: Container(
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(8),
          border: Border.all(
            color: isSelected ? VineTheme.vineGreen : Colors.transparent,
            width: 2,
          ),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(6),
          child: Stack(
            fit: StackFit.expand,
            children: [
              // Thumbnail or placeholder
              if (clip.thumbnailPath != null &&
                  File(clip.thumbnailPath!).existsSync())
                Image.file(File(clip.thumbnailPath!), fit: BoxFit.cover)
              else
                Container(
                  color: Colors.grey[800],
                  child: const Icon(
                    Icons.videocam,
                    color: Colors.grey,
                    size: 32,
                  ),
                ),
              // Duration badge
              Positioned(
                left: 4,
                bottom: 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 6,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.7),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Text(
                    '${clip.durationInSeconds.toStringAsFixed(1)}s',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ),
              ),
              // Aspect ratio indicator
              Positioned(
                right: 4,
                top: 4,
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 2,
                  ),
                  decoration: BoxDecoration(
                    color: Colors.black.withValues(alpha: 0.5),
                    borderRadius: BorderRadius.circular(4),
                  ),
                  child: Icon(
                    clip.aspectRatio == 'vertical'
                        ? Icons.crop_portrait
                        : Icons.crop_square,
                    color: Colors.white,
                    size: 12,
                  ),
                ),
              ),
              // Selection checkbox (always visible when showCheckbox is true)
              if (showCheckbox)
                Positioned(
                  left: 4,
                  top: 4,
                  child: Container(
                    width: 24,
                    height: 24,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: isSelected
                          ? VineTheme.vineGreen
                          : Colors.black.withValues(alpha: 0.7),
                      border: Border.all(color: Colors.white, width: 2),
                    ),
                    child: isSelected
                        ? const Icon(Icons.check, color: Colors.white, size: 16)
                        : null,
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

/// Preview sheet for playing a clip
class ClipPreviewSheet extends StatefulWidget {
  const ClipPreviewSheet({
    super.key,
    required this.clip,
    required this.onDelete,
  });

  final SavedClip clip;
  final VoidCallback onDelete;

  @override
  State<ClipPreviewSheet> createState() => _ClipPreviewSheetState();
}

class _ClipPreviewSheetState extends State<ClipPreviewSheet> {
  VideoPlayerController? _controller;
  bool _isInitialized = false;

  @override
  void initState() {
    super.initState();
    _initializePlayer();
  }

  Future<void> _initializePlayer() async {
    final file = File(widget.clip.filePath);
    if (!await file.exists()) {
      return;
    }

    _controller = VideoPlayerController.file(file);
    await _controller!.initialize();
    await _controller!.setLooping(true);
    await _controller!.play();

    if (mounted) {
      setState(() {
        _isInitialized = true;
      });
    }
  }

  @override
  void dispose() {
    _controller?.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      height: MediaQuery.of(context).size.height * 0.7,
      decoration: const BoxDecoration(
        color: Colors.black,
        borderRadius: BorderRadius.vertical(top: Radius.circular(16)),
      ),
      child: Column(
        children: [
          // Handle bar
          Container(
            width: 40,
            height: 4,
            margin: const EdgeInsets.symmetric(vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey[600],
              borderRadius: BorderRadius.circular(2),
            ),
          ),
          // Video preview
          Expanded(
            child: _isInitialized && _controller != null
                ? Center(
                    child: AspectRatio(
                      aspectRatio: _controller!.value.aspectRatio,
                      child: VideoPlayer(_controller!),
                    ),
                  )
                : const Center(
                    child: CircularProgressIndicator(
                      color: VineTheme.vineGreen,
                    ),
                  ),
          ),
          // Info and actions
          Container(
            padding: const EdgeInsets.all(16),
            child: Row(
              children: [
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '${widget.clip.durationInSeconds.toStringAsFixed(1)}s clip',
                        style: const TextStyle(
                          color: VineTheme.whiteText,
                          fontSize: 16,
                          fontWeight: FontWeight.bold,
                        ),
                      ),
                      Text(
                        widget.clip.displayDuration,
                        style: TextStyle(color: Colors.grey[400], fontSize: 12),
                      ),
                    ],
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete, color: Colors.red),
                  onPressed: widget.onDelete,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
