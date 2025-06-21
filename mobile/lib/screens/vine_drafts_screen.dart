// ABOUTME: Screen for managing saved Vine drafts before publishing
// ABOUTME: Shows list of saved drafts with preview, edit, and delete options

import 'package:flutter/material.dart';
import '../models/vine_draft.dart';
import '../theme/vine_theme.dart';
import 'vine_preview_screen.dart';

class VineDraftsScreen extends StatefulWidget {
  const VineDraftsScreen({super.key});

  @override
  State<VineDraftsScreen> createState() => _VineDraftsScreenState();
}

class _VineDraftsScreenState extends State<VineDraftsScreen> {
  List<VineDraft> _drafts = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadDrafts();
  }

  Future<void> _loadDrafts() async {
    setState(() {
      _isLoading = true;
    });

    try {
      // TODO: Load drafts from storage
      // For now, using empty list
      await Future.delayed(const Duration(milliseconds: 500));
      setState(() {
        _drafts = [];
        _isLoading = false;
      });
    } catch (e) {
      setState(() {
        _isLoading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: const Text(
          'Drafts',
          style: TextStyle(
            color: VineTheme.whiteText,
            fontWeight: FontWeight.bold,
          ),
        ),
        leading: IconButton(
          icon: const Icon(Icons.arrow_back, color: VineTheme.whiteText),
          onPressed: () => Navigator.of(context).pop(),
        ),
        actions: [
          if (_drafts.isNotEmpty)
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
                      Text('Clear All Drafts'),
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
          : _drafts.isEmpty
              ? _buildEmptyState()
              : _buildDraftsList(),
    );
  }

  Widget _buildEmptyState() {
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
              border: Border.all(
                color: Colors.grey[600]!,
                width: 2,
              ),
            ),
            child: const Icon(
              Icons.video_library_outlined,
              size: 60,
              color: Colors.grey,
            ),
          ),
          const SizedBox(height: 24),
          const Text(
            'No Drafts Yet',
            style: TextStyle(
              color: VineTheme.whiteText,
              fontSize: 24,
              fontWeight: FontWeight.bold,
            ),
          ),
          const SizedBox(height: 8),
          Text(
            'Your saved Vine drafts will appear here',
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 16,
            ),
          ),
          const SizedBox(height: 32),
          ElevatedButton.icon(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.videocam),
            label: const Text('Record a Vine'),
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

  Widget _buildDraftsList() {
    return ListView.builder(
      padding: const EdgeInsets.all(16),
      itemCount: _drafts.length,
      itemBuilder: (context, index) {
        final draft = _drafts[index];
        return _buildDraftCard(draft);
      },
    );
  }

  Widget _buildDraftCard(VineDraft draft) {
    return Container(
      margin: const EdgeInsets.only(bottom: 16),
      decoration: BoxDecoration(
        color: Colors.grey[900],
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: Colors.grey[700]!,
          width: 1,
        ),
      ),
      child: InkWell(
        borderRadius: BorderRadius.circular(12),
        onTap: () => _editDraft(draft),
        child: Padding(
          padding: const EdgeInsets.all(16),
          child: Row(
            children: [
              // Video thumbnail
              Container(
                width: 60,
                height: 60,
                decoration: BoxDecoration(
                  color: Colors.grey[800],
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Icon(
                  Icons.play_circle_filled,
                  color: VineTheme.vineGreen,
                  size: 30,
                ),
              ),
              const SizedBox(width: 16),
              
              // Draft info
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      draft.hasTitle ? draft.title : 'Untitled Vine',
                      style: const TextStyle(
                        color: VineTheme.whiteText,
                        fontSize: 16,
                        fontWeight: FontWeight.bold,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      '${draft.frameCount} frames • ${draft.selectedApproach}',
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 12,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Text(
                      draft.displayDuration,
                      style: TextStyle(
                        color: Colors.grey[500],
                        fontSize: 11,
                      ),
                    ),
                  ],
                ),
              ),
              
              // Action menu
              PopupMenuButton<String>(
                icon: Icon(Icons.more_vert, color: Colors.grey[400]),
                onSelected: (value) {
                  switch (value) {
                    case 'edit':
                      _editDraft(draft);
                      break;
                    case 'delete':
                      _deleteDraft(draft);
                      break;
                  }
                },
                itemBuilder: (context) => [
                  const PopupMenuItem(
                    value: 'edit',
                    child: Row(
                      children: [
                        Icon(Icons.edit, size: 20),
                        SizedBox(width: 8),
                        Text('Edit'),
                      ],
                    ),
                  ),
                  const PopupMenuItem(
                    value: 'delete',
                    child: Row(
                      children: [
                        Icon(Icons.delete, color: Colors.red, size: 20),
                        SizedBox(width: 8),
                        Text('Delete', style: TextStyle(color: Colors.red)),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  void _editDraft(VineDraft draft) {
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (context) => VinePreviewScreen(
          videoFile: draft.videoFile,
          frameCount: draft.frameCount,
          selectedApproach: draft.selectedApproach,
        ),
      ),
    );
  }

  void _deleteDraft(VineDraft draft) {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text(
          'Delete Draft?',
          style: TextStyle(color: VineTheme.whiteText),
        ),
        content: Text(
          'This will permanently delete "${draft.hasTitle ? draft.title : 'Untitled Vine'}" from your drafts.',
          style: const TextStyle(color: VineTheme.whiteText),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _confirmDeleteDraft(draft);
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
  }

  Future<void> _confirmDeleteDraft(VineDraft draft) async {
    try {
      // TODO: Delete draft from storage
      setState(() {
        _drafts.remove(draft);
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Draft deleted'),
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to delete draft: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }

  void _showClearAllConfirmation() {
    showDialog(
      context: context,
      builder: (context) => AlertDialog(
        backgroundColor: Colors.grey[900],
        title: const Text(
          'Clear All Drafts?',
          style: TextStyle(color: VineTheme.whiteText),
        ),
        content: Text(
          'This will permanently delete all ${_drafts.length} draft(s). This action cannot be undone.',
          style: const TextStyle(color: VineTheme.whiteText),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('Cancel'),
          ),
          TextButton(
            onPressed: () {
              Navigator.of(context).pop();
              _clearAllDrafts();
            },
            style: TextButton.styleFrom(foregroundColor: Colors.red),
            child: const Text('Clear All'),
          ),
        ],
      ),
    );
  }

  Future<void> _clearAllDrafts() async {
    try {
      // TODO: Clear all drafts from storage
      setState(() {
        _drafts.clear();
      });
      
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('All drafts cleared'),
          duration: Duration(seconds: 2),
        ),
      );
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Failed to clear drafts: $e'),
          backgroundColor: Colors.red,
        ),
      );
    }
  }
}