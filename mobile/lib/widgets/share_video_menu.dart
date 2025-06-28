// ABOUTME: Comprehensive share menu for videos with content reporting, user sharing, and list management
// ABOUTME: Provides Apple-compliant reporting, NIP-51 list management, and social sharing features

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import 'package:share_plus/share_plus.dart';
import '../models/video_event.dart';
import '../services/content_reporting_service.dart';
import '../services/curated_list_service.dart';
import '../services/video_sharing_service.dart';
import '../services/content_deletion_service.dart';
import '../services/content_moderation_service.dart';
import '../services/nostr_service_interface.dart';
import '../services/social_service.dart';
import '../services/user_profile_service.dart';
import '../theme/vine_theme.dart';

/// Comprehensive share menu for videos
class ShareVideoMenu extends StatefulWidget {
  final VideoEvent video;
  final VoidCallback? onDismiss;

  const ShareVideoMenu({
    super.key,
    required this.video,
    this.onDismiss,
  });

  @override
  State<ShareVideoMenu> createState() => _ShareVideoMenuState();
}

class _ShareVideoMenuState extends State<ShareVideoMenu> {

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        color: VineTheme.backgroundColor,
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      child: SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            // Header
            _buildHeader(),
            
            // Share options
            Flexible(
              child: SingleChildScrollView(
                padding: const EdgeInsets.symmetric(horizontal: 16),
                child: Column(
                  children: [
                    _buildShareSection(),
                    const SizedBox(height: 24),
                    _buildListSection(),
                    if (_isUserOwnContent()) ...[
                      const SizedBox(height: 24),
                      _buildDeleteSection(),
                    ],
                    const SizedBox(height: 24),
                    _buildReportSection(),
                    const SizedBox(height: 16),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        border: Border(
          bottom: BorderSide(color: Colors.grey.shade800, width: 1),
        ),
      ),
      child: Row(
        children: [
          const Icon(Icons.share, color: VineTheme.whiteText),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  'Share Video',
                  style: TextStyle(
                    color: VineTheme.whiteText,
                    fontSize: 18,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                if (widget.video.title != null)
                  Text(
                    widget.video.title!,
                    style: const TextStyle(
                      color: VineTheme.secondaryText,
                      fontSize: 14,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
              ],
            ),
          ),
          IconButton(
            onPressed: () => Navigator.of(context).pop(),
            icon: const Icon(Icons.close, color: VineTheme.secondaryText),
          ),
        ],
      ),
    );
  }

  Widget _buildShareSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Share With',
          style: TextStyle(
            color: VineTheme.whiteText,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        
        // Send to user
        _buildActionTile(
          icon: Icons.person_add,
          title: 'Send to Viner',
          subtitle: 'Share privately with another user',
          onTap: _showSendToUserDialog,
        ),
        
        const SizedBox(height: 8),
        
        // External share options
        _buildActionTile(
          icon: Icons.copy,
          title: 'Copy Link',
          subtitle: 'Copy shareable URL',
          onTap: _copyVideoLink,
        ),
        
        const SizedBox(height: 8),
        
        _buildActionTile(
          icon: Icons.share,
          title: 'Share Externally',
          subtitle: 'Share via other apps',
          onTap: _shareExternally,
        ),
      ],
    );
  }

  Widget _buildListSection() {
    return Consumer<CuratedListService>(
      builder: (context, listService, child) {
        final defaultList = listService.getDefaultList();
        final isInDefaultList = defaultList != null && 
            listService.isVideoInDefaultList(widget.video.id);

        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Add to List',
              style: TextStyle(
                color: VineTheme.whiteText,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            
            // Add to My List (default list)
            _buildActionTile(
              icon: isInDefaultList ? Icons.playlist_add_check : Icons.playlist_add,
              title: isInDefaultList ? 'Remove from My List' : 'Add to My List',
              subtitle: 'Your public curated list',
              iconColor: isInDefaultList ? VineTheme.vineGreen : null,
              onTap: () => _toggleDefaultList(isInDefaultList),
            ),
            
            const SizedBox(height: 8),
            
            // Create new list or add to existing
            _buildActionTile(
              icon: Icons.create_new_folder,
              title: 'Create New List',
              subtitle: 'Start a new curated collection',
              onTap: _showCreateListDialog,
            ),
            
            // Show existing lists if any
            if (listService.lists.length > 1) ...[
              const SizedBox(height: 8),
              _buildActionTile(
                icon: Icons.folder,
                title: 'Add to Other List',
                subtitle: '${listService.lists.length - 1} other lists',
                onTap: _showSelectListDialog,
              ),
            ],
          ],
        );
      },
    );
  }

  Widget _buildReportSection() {
    return Consumer<ContentReportingService>(
      builder: (context, reportService, child) {
        final hasReported = reportService.hasBeenReported(widget.video.id);
        
        return Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              'Content Actions',
              style: TextStyle(
                color: VineTheme.whiteText,
                fontSize: 16,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 12),
            
            _buildActionTile(
              icon: hasReported ? Icons.flag : Icons.flag_outlined,
              title: hasReported ? 'Already Reported' : 'Report Content',
              subtitle: hasReported 
                  ? 'You have reported this content'
                  : 'Report for policy violations',
              iconColor: hasReported ? Colors.red : Colors.orange,
              onTap: hasReported ? null : _showReportDialog,
            ),
          ],
        );
      },
    );
  }

  Widget _buildActionTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback? onTap,
    Color? iconColor,
  }) {
    return ListTile(
      leading: Container(
        width: 40,
        height: 40,
        decoration: BoxDecoration(
          color: VineTheme.cardBackground,
          borderRadius: BorderRadius.circular(8),
        ),
        child: Icon(
          icon,
          color: iconColor ?? VineTheme.whiteText,
          size: 20,
        ),
      ),
      title: Text(
        title,
        style: const TextStyle(
          color: VineTheme.whiteText,
          fontWeight: FontWeight.w500,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: const TextStyle(
          color: VineTheme.secondaryText,
          fontSize: 12,
        ),
      ),
      onTap: onTap,
      enabled: onTap != null,
      contentPadding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
    );
  }

  void _showSendToUserDialog() {
    showDialog(
      context: context,
      builder: (context) => _SendToUserDialog(video: widget.video),
    );
  }

  void _copyVideoLink() async {
    try {
      final sharingService = context.read<VideoSharingService>();
      final url = sharingService.generateShareUrl(widget.video);
      
      await Clipboard.setData(ClipboardData(text: url));
      
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('Link copied to clipboard'),
            duration: Duration(seconds: 2),
          ),
        );
        Navigator.of(context).pop();
      }
    } catch (e) {
      debugPrint('❌ Failed to copy link: $e');
    }
  }

  void _shareExternally() async {
    try {
      final sharingService = context.read<VideoSharingService>();
      final shareText = sharingService.generateShareText(widget.video);
      
      await Share.share(shareText);
      
      if (mounted) {
        Navigator.of(context).pop();
      }
    } catch (e) {
      debugPrint('❌ Failed to share externally: $e');
    }
  }

  void _toggleDefaultList(bool isCurrentlyInList) async {
    try {
      final listService = context.read<CuratedListService>();
      
      bool success;
      if (isCurrentlyInList) {
        success = await listService.removeVideoFromList(
          CuratedListService.defaultListId,
          widget.video.id,
        );
      } else {
        success = await listService.addVideoToList(
          CuratedListService.defaultListId,
          widget.video.id,
        );
      }
      
      if (mounted && success) {
        final message = isCurrentlyInList 
            ? 'Removed from My List'
            : 'Added to My List';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), duration: const Duration(seconds: 2)),
        );
      }
    } catch (e) {
      debugPrint('❌ Failed to toggle list: $e');
    }
  }

  void _showCreateListDialog() {
    showDialog(
      context: context,
      builder: (context) => _CreateListDialog(video: widget.video),
    );
  }

  void _showSelectListDialog() {
    showDialog(
      context: context,
      builder: (context) => _SelectListDialog(video: widget.video),
    );
  }

  void _showReportDialog() {
    showDialog(
      context: context,
      builder: (context) => _ReportContentDialog(video: widget.video),
    );
  }

  /// Check if this is the user's own content
  bool _isUserOwnContent() {
    try {
      final nostrService = Provider.of<INostrService>(context, listen: false);
      final userPubkey = nostrService.publicKey;
      if (userPubkey == null) return false;
      
      return widget.video.pubkey == userPubkey;
    } catch (e) {
      debugPrint('⚠️ Error checking content ownership: $e');
      return false;
    }
  }

  /// Build delete section for user's own content
  Widget _buildDeleteSection() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'Manage Content',
          style: TextStyle(
            color: VineTheme.whiteText,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
        ),
        const SizedBox(height: 12),
        
        // Delete content option
        _buildActionTile(
          icon: Icons.delete_outline,
          iconColor: Colors.red,
          title: 'Delete Video',
          subtitle: 'Permanently remove this content',
          onTap: _showDeleteDialog,
        ),
      ],
    );
  }

  /// Show delete confirmation dialog
  void _showDeleteDialog() {
    showDialog(
      context: context,
      builder: (context) => _buildDeleteDialog(),
    );
  }

  /// Build delete confirmation dialog
  Widget _buildDeleteDialog() {
    return AlertDialog(
      backgroundColor: VineTheme.cardBackground,
      title: const Text('Delete Video', style: TextStyle(color: VineTheme.whiteText)),
      content: const Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Are you sure you want to delete this video?',
            style: TextStyle(color: VineTheme.whiteText),
          ),
          SizedBox(height: 12),
          Text(
            'This will send a delete request (NIP-09) to all relays. Some relays may still retain the content.',
            style: TextStyle(
              color: VineTheme.secondaryText,
              fontSize: 12,
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: () {
            Navigator.of(context).pop();
            _deleteContent();
          },
          style: TextButton.styleFrom(foregroundColor: Colors.red),
          child: const Text('Delete'),
        ),
      ],
    );
  }

  /// Delete the user's content using NIP-09
  void _deleteContent() async {
    try {
      final deletionService = Provider.of<ContentDeletionService>(context, listen: false);
      
      // Show loading snackbar
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Row(
              children: [
                SizedBox(
                  width: 16,
                  height: 16,
                  child: CircularProgressIndicator(
                    strokeWidth: 2,
                    color: Colors.white,
                  ),
                ),
                SizedBox(width: 12),
                Text('Deleting content...'),
              ],
            ),
            backgroundColor: Colors.orange,
            duration: Duration(seconds: 2),
          ),
        );
      }

      final result = await deletionService.quickDelete(
        video: widget.video,
        reason: DeleteReason.personalChoice,
      );

      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Row(
              children: [
                Icon(
                  result.success ? Icons.check_circle : Icons.error,
                  color: Colors.white,
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: Text(
                    result.success
                        ? 'Delete request sent successfully'
                        : 'Failed to delete content: ${result.error}',
                  ),
                ),
              ],
            ),
            backgroundColor: result.success ? Colors.green : Colors.red,
          ),
        );

        // Close the share menu if deletion was successful
        if (result.success && widget.onDismiss != null) {
          widget.onDismiss!();
        }
      }
    } catch (e) {
      debugPrint('❌ Failed to delete content: $e');
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text('Failed to delete content: $e'),
            backgroundColor: Colors.red,
          ),
        );
      }
    }
  }
}

/// Dialog for sending video to specific user
class _SendToUserDialog extends StatefulWidget {
  final VideoEvent video;

  const _SendToUserDialog({required this.video});

  @override
  State<_SendToUserDialog> createState() => _SendToUserDialogState();
}

class _SendToUserDialogState extends State<_SendToUserDialog> {
  final TextEditingController _searchController = TextEditingController();
  final TextEditingController _messageController = TextEditingController();
  bool _isSearching = false;
  List<ShareableUser> _searchResults = [];
  List<ShareableUser> _contacts = [];
  bool _contactsLoaded = false;

  @override
  void initState() {
    super.initState();
    _loadUserContacts();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: VineTheme.cardBackground,
      title: const Text('Send to Viner', style: TextStyle(color: VineTheme.whiteText)),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _searchController,
              enableInteractiveSelection: true,
              style: const TextStyle(color: VineTheme.whiteText),
              decoration: const InputDecoration(
                hintText: 'Search by name, npub, or pubkey...',
                hintStyle: TextStyle(color: VineTheme.secondaryText),
                prefixIcon: Icon(Icons.search, color: VineTheme.secondaryText),
              ),
              onChanged: _searchUsers,
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _messageController,
              enableInteractiveSelection: true,
              style: const TextStyle(color: VineTheme.whiteText),
              decoration: const InputDecoration(
                hintText: 'Add a personal message (optional)',
                hintStyle: TextStyle(color: VineTheme.secondaryText),
              ),
              maxLines: 2,
            ),
            const SizedBox(height: 16),
            // Show contacts or search results
            if (!_contactsLoaded) ...[
              const Center(
                child: CircularProgressIndicator(color: VineTheme.vineGreen),
              ),
            ] else if (_searchController.text.isEmpty && _contacts.isNotEmpty) ...[
              // Show user's contacts when not searching
              const Text(
                'Your Contacts',
                style: TextStyle(
                  color: VineTheme.whiteText,
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                height: 200,
                child: ListView.builder(
                  itemCount: _contacts.length,
                  itemBuilder: (context, index) => _buildUserTile(_contacts[index]),
                ),
              ),
            ] else if (_searchController.text.isEmpty && _contacts.isEmpty) ...[
              // No contacts found
              const Center(
                child: Text(
                  'No contacts found. Start following people to see them here.',
                  style: TextStyle(color: VineTheme.secondaryText),
                  textAlign: TextAlign.center,
                ),
              ),
            ] else if (_searchController.text.isNotEmpty) ...[
              // Show search results
              if (_isSearching) ...[
                const Center(
                  child: CircularProgressIndicator(color: VineTheme.vineGreen),
                ),
              ] else if (_searchResults.isNotEmpty) ...[
                const Text(
                  'Search Results',
                  style: TextStyle(
                    color: VineTheme.whiteText,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                  ),
                ),
                const SizedBox(height: 8),
                SizedBox(
                  height: 200,
                  child: ListView.builder(
                    itemCount: _searchResults.length,
                    itemBuilder: (context, index) => _buildUserTile(_searchResults[index]),
                  ),
                ),
              ] else ...[
                const Center(
                  child: Text(
                    'No users found. Try searching by name or public key.',
                    style: TextStyle(color: VineTheme.secondaryText),
                    textAlign: TextAlign.center,
                  ),
                ),
              ],
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
      ],
    );
  }

  /// Load user's contacts from their follow list (NIP-02)
  void _loadUserContacts() async {
    try {
      final socialService = Provider.of<SocialService>(context, listen: false);
      final userProfileService = Provider.of<UserProfileService>(context, listen: false);
      
      // Get the user's follow list
      final followList = socialService.followingPubkeys;
      final contacts = <ShareableUser>[];
      
      // Convert follows to ShareableUser objects with profile data
      for (final pubkey in followList) {
        try {
          // Fetch profile if not cached
          if (!userProfileService.hasProfile(pubkey)) {
            userProfileService.fetchProfile(pubkey);
          }
          
          final profile = userProfileService.getCachedProfile(pubkey);
          contacts.add(ShareableUser(
            pubkey: pubkey,
            displayName: profile?.displayName ?? profile?.name,
            picture: profile?.picture,
          ));
        } catch (e) {
          debugPrint('⚠️ Error loading contact profile $pubkey: $e');
          // Still add the contact without profile data
          contacts.add(ShareableUser(
            pubkey: pubkey,
            displayName: null,
            picture: null,
          ));
        }
      }
      
      if (mounted) {
        setState(() {
          _contacts = contacts;
          _contactsLoaded = true;
        });
      }
    } catch (e) {
      debugPrint('⚠️ Error loading user contacts: $e');
      if (mounted) {
        setState(() {
          _contacts = [];
          _contactsLoaded = true;
        });
      }
    }
  }

  /// Build a user tile for contacts or search results
  Widget _buildUserTile(ShareableUser user) {
    return ListTile(
      leading: CircleAvatar(
        backgroundImage: user.picture != null 
            ? NetworkImage(user.picture!)
            : null,
        backgroundColor: VineTheme.cardBackground,
        child: user.picture == null 
            ? const Icon(Icons.person, color: VineTheme.secondaryText)
            : null,
      ),
      title: Text(
        user.displayName ?? 'Anonymous',
        style: const TextStyle(color: VineTheme.whiteText),
      ),
      subtitle: Text(
        '${user.pubkey.substring(0, 16)}...',
        style: const TextStyle(color: VineTheme.secondaryText),
      ),
      onTap: () => _sendToUser(user),
      dense: true,
    );
  }

  void _searchUsers(String query) async {
    if (query.trim().isEmpty) {
      setState(() => _searchResults = []);
      return;
    }

    setState(() => _isSearching = true);
    
    try {
      final userProfileService = Provider.of<UserProfileService>(context, listen: false);
      final searchResults = <ShareableUser>[];
      
      String? pubkeyToSearch;
      
      // Handle different search formats
      if (query.startsWith('npub1')) {
        // TODO: Convert npub to hex pubkey using bech32 decoding
        // For now, just use the query as-is and let the service handle it
        pubkeyToSearch = query;
      } else if (query.length == 64 && RegExp(r'^[0-9a-fA-F]+$').hasMatch(query)) {
        // Looks like a hex pubkey
        pubkeyToSearch = query.toLowerCase();
      } else {
        // Search by display name - check contacts first
        for (final contact in _contacts) {
          if (contact.displayName != null && 
              contact.displayName!.toLowerCase().contains(query.toLowerCase())) {
            searchResults.add(contact);
          }
        }
      }
      
      // If we have a specific pubkey to search for
      if (pubkeyToSearch != null) {
        try {
          // Fetch profile if not cached
          if (!userProfileService.hasProfile(pubkeyToSearch)) {
            userProfileService.fetchProfile(pubkeyToSearch);
          }
          
          // Give it a moment to fetch
          await Future.delayed(const Duration(milliseconds: 500));
          
          final profile = userProfileService.getCachedProfile(pubkeyToSearch);
          searchResults.add(ShareableUser(
            pubkey: pubkeyToSearch,
            displayName: profile?.displayName ?? profile?.name,
            picture: profile?.picture,
          ));
        } catch (e) {
          debugPrint('⚠️ Error searching for user $pubkeyToSearch: $e');
          // Still add the user without profile data
          searchResults.add(ShareableUser(
            pubkey: pubkeyToSearch,
            displayName: null,
            picture: null,
          ));
        }
      }
      
      if (mounted) {
        setState(() {
          _searchResults = searchResults;
          _isSearching = false;
        });
      }
    } catch (e) {
      debugPrint('⚠️ Error searching users: $e');
      if (mounted) {
        setState(() => _isSearching = false);
      }
    }
  }

  void _sendToUser(ShareableUser user) async {
    try {
      final sharingService = context.read<VideoSharingService>();
      final result = await sharingService.shareVideoWithUser(
        video: widget.video,
        recipientPubkey: user.pubkey,
        personalMessage: _messageController.text.trim().isEmpty 
            ? null 
            : _messageController.text.trim(),
      );

      if (mounted) {
        Navigator.of(context).pop(); // Close dialog
        Navigator.of(context).pop(); // Close share menu
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result.success 
                  ? 'Video sent to ${user.displayName ?? 'user'}'
                  : 'Failed to send video: ${result.error}',
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Failed to send video: $e');
    }
  }

  @override
  void dispose() {
    _searchController.dispose();
    _messageController.dispose();
    super.dispose();
  }
}

/// Dialog for creating new curated list
class _CreateListDialog extends StatefulWidget {
  final VideoEvent video;

  const _CreateListDialog({required this.video});

  @override
  State<_CreateListDialog> createState() => _CreateListDialogState();
}

class _CreateListDialogState extends State<_CreateListDialog> {
  final TextEditingController _nameController = TextEditingController();
  final TextEditingController _descriptionController = TextEditingController();
  bool _isPublic = true;

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: VineTheme.cardBackground,
      title: const Text('Create New List', style: TextStyle(color: VineTheme.whiteText)),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _nameController,
            enableInteractiveSelection: true,
            style: const TextStyle(color: VineTheme.whiteText),
            decoration: const InputDecoration(
              labelText: 'List Name',
              labelStyle: TextStyle(color: VineTheme.secondaryText),
            ),
          ),
          const SizedBox(height: 16),
          TextField(
            controller: _descriptionController,
            enableInteractiveSelection: true,
            style: const TextStyle(color: VineTheme.whiteText),
            decoration: const InputDecoration(
              labelText: 'Description (optional)',
              labelStyle: TextStyle(color: VineTheme.secondaryText),
            ),
            maxLines: 2,
          ),
          const SizedBox(height: 16),
          SwitchListTile(
            title: const Text('Public List', style: TextStyle(color: VineTheme.whiteText)),
            subtitle: const Text(
              'Others can follow and see this list',
              style: TextStyle(color: VineTheme.secondaryText),
            ),
            value: _isPublic,
            onChanged: (value) => setState(() => _isPublic = value),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: _createList,
          child: const Text('Create'),
        ),
      ],
    );
  }

  void _createList() async {
    final name = _nameController.text.trim();
    if (name.isEmpty) return;

    try {
      final listService = context.read<CuratedListService>();
      final newList = await listService.createList(
        name: name,
        description: _descriptionController.text.trim().isEmpty 
            ? null 
            : _descriptionController.text.trim(),
        isPublic: _isPublic,
      );

      if (newList != null && mounted) {
        // Add the video to the new list
        await listService.addVideoToList(newList.id, widget.video.id);
        
        Navigator.of(context).pop(); // Close dialog
        Navigator.of(context).pop(); // Close share menu
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Created list "$name" and added video')),
        );
      }
    } catch (e) {
      debugPrint('❌ Failed to create list: $e');
    }
  }

  @override
  void dispose() {
    _nameController.dispose();
    _descriptionController.dispose();
    super.dispose();
  }
}

/// Dialog for selecting existing list
class _SelectListDialog extends StatelessWidget {
  final VideoEvent video;

  const _SelectListDialog({required this.video});

  @override
  Widget build(BuildContext context) {
    return Consumer<CuratedListService>(
      builder: (context, listService, child) {
        final availableLists = listService.lists
            .where((list) => list.id != CuratedListService.defaultListId)
            .toList();

        return AlertDialog(
          backgroundColor: VineTheme.cardBackground,
          title: const Text('Add to List', style: TextStyle(color: VineTheme.whiteText)),
          content: SizedBox(
            width: double.maxFinite,
            height: 300,
            child: ListView.builder(
              itemCount: availableLists.length,
              itemBuilder: (context, index) {
                final list = availableLists[index];
                final isInList = listService.isVideoInList(list.id, video.id);
                
                return ListTile(
                  leading: Icon(
                    isInList ? Icons.check_circle : Icons.playlist_play,
                    color: isInList ? VineTheme.vineGreen : VineTheme.whiteText,
                  ),
                  title: Text(
                    list.name,
                    style: const TextStyle(color: VineTheme.whiteText),
                  ),
                  subtitle: Text(
                    '${list.videoEventIds.length} videos',
                    style: const TextStyle(color: VineTheme.secondaryText),
                  ),
                  onTap: () => _toggleVideoInList(context, listService, list, isInList),
                );
              },
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Done'),
            ),
          ],
        );
      },
    );
  }

  void _toggleVideoInList(
    BuildContext context,
    CuratedListService listService,
    CuratedList list,
    bool isCurrentlyInList,
  ) async {
    try {
      bool success;
      if (isCurrentlyInList) {
        success = await listService.removeVideoFromList(list.id, video.id);
      } else {
        success = await listService.addVideoToList(list.id, video.id);
      }

      if (success) {
        final message = isCurrentlyInList 
            ? 'Removed from ${list.name}'
            : 'Added to ${list.name}';
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(message), duration: const Duration(seconds: 1)),
        );
      }
    } catch (e) {
      debugPrint('❌ Failed to toggle video in list: $e');
    }
  }
}

/// Dialog for reporting content
class _ReportContentDialog extends StatefulWidget {
  final VideoEvent video;

  const _ReportContentDialog({required this.video});

  @override
  State<_ReportContentDialog> createState() => _ReportContentDialogState();
}

class _ReportContentDialogState extends State<_ReportContentDialog> {
  ContentFilterReason? _selectedReason;
  final TextEditingController _detailsController = TextEditingController();

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: VineTheme.cardBackground,
      title: const Text('Report Content', style: TextStyle(color: VineTheme.whiteText)),
      content: SizedBox(
        width: double.maxFinite,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Text(
              'Why are you reporting this content?',
              style: TextStyle(color: VineTheme.whiteText),
            ),
            const SizedBox(height: 16),
            SizedBox(
              height: 200,
              child: SingleChildScrollView(
                child: Column(
                  children: ContentFilterReason.values.map((reason) {
                    return RadioListTile<ContentFilterReason>(
                      title: Text(
                        _getReasonDisplayName(reason),
                        style: const TextStyle(color: VineTheme.whiteText),
                      ),
                      value: reason,
                      groupValue: _selectedReason,
                      onChanged: (value) => setState(() => _selectedReason = value),
                    );
                  }).toList(),
                ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _detailsController,
              enableInteractiveSelection: true,
              style: const TextStyle(color: VineTheme.whiteText),
              decoration: const InputDecoration(
                labelText: 'Additional details (optional)',
                labelStyle: TextStyle(color: VineTheme.secondaryText),
              ),
              maxLines: 3,
            ),
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancel'),
        ),
        TextButton(
          onPressed: _selectedReason != null ? _submitReport : null,
          child: const Text('Report'),
        ),
      ],
    );
  }

  String _getReasonDisplayName(ContentFilterReason reason) {
    switch (reason) {
      case ContentFilterReason.spam:
        return 'Spam or Unwanted Content';
      case ContentFilterReason.harassment:
        return 'Harassment or Bullying';
      case ContentFilterReason.violence:
        return 'Violence or Threats';
      case ContentFilterReason.sexualContent:
        return 'Sexual or Adult Content';
      case ContentFilterReason.copyright:
        return 'Copyright Violation';
      case ContentFilterReason.falseInformation:
        return 'False Information';
      case ContentFilterReason.csam:
        return 'Child Safety Violation';
      case ContentFilterReason.other:
        return 'Other Policy Violation';
    }
  }

  void _submitReport() async {
    if (_selectedReason == null) return;

    try {
      final reportService = context.read<ContentReportingService>();
      final result = await reportService.reportContent(
        eventId: widget.video.id,
        authorPubkey: widget.video.pubkey,
        reason: _selectedReason!,
        details: _detailsController.text.trim().isEmpty 
            ? _getReasonDisplayName(_selectedReason!)
            : _detailsController.text.trim(),
      );

      if (mounted) {
        Navigator.of(context).pop(); // Close dialog
        Navigator.of(context).pop(); // Close share menu
        
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              result.success 
                  ? 'Content reported successfully'
                  : 'Failed to report content: ${result.error}',
            ),
          ),
        );
      }
    } catch (e) {
      debugPrint('❌ Failed to submit report: $e');
    }
  }

  @override
  void dispose() {
    _detailsController.dispose();
    super.dispose();
  }
}