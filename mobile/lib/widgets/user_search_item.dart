// ABOUTME: User search result list item widget with profile info and follow action
// ABOUTME: Displays user profile data with tap-to-profile and follow functionality

import 'package:flutter/material.dart';
import '../models/search_result.dart';

class UserSearchItem extends StatelessWidget {
  final UserSearchResult user;
  final VoidCallback? onTap;
  final Function(UserSearchResult)? onFollow;
  final bool showFollowButton;

  const UserSearchItem({
    super.key,
    required this.user,
    this.onTap,
    this.onFollow,
    this.showFollowButton = true,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        child: Row(
          children: [
            // Profile picture
            _buildProfilePicture(),
            
            const SizedBox(width: 12),
            
            // User info
            Expanded(
              child: _buildUserInfo(),
            ),
            
            // Follow button
            if (showFollowButton)
              _buildFollowButton(),
          ],
        ),
      ),
    );
  }

  Widget _buildProfilePicture() {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.grey[800],
        border: Border.all(
          color: Colors.grey[600]!,
          width: 1,
        ),
      ),
      child: user.profilePicture != null
          ? ClipOval(
              child: Image.network(
                user.profilePicture!,
                width: 48,
                height: 48,
                fit: BoxFit.cover,
                errorBuilder: (context, error, stackTrace) {
                  return _buildDefaultAvatar();
                },
              ),
            )
          : _buildDefaultAvatar(),
    );
  }

  Widget _buildDefaultAvatar() {
    return Icon(
      Icons.person,
      color: Colors.grey[500],
      size: 24,
    );
  }

  Widget _buildUserInfo() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        // Display name
        Text(
          user.displayName,
          style: const TextStyle(
            color: Colors.white,
            fontSize: 16,
            fontWeight: FontWeight.w600,
          ),
          maxLines: 1,
          overflow: TextOverflow.ellipsis,
        ),
        
        const SizedBox(height: 2),
        
        // Username with @ prefix if it's not an email
        if (user.username.isNotEmpty)
          Text(
            user.username.contains('@') ? user.username : '@${user.username}',
            style: TextStyle(
              color: Colors.grey[400],
              fontSize: 14,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        
        // Bio preview (first line only)
        if (user.bio != null && user.bio!.isNotEmpty) ...[
          const SizedBox(height: 2),
          Text(
            user.bio!,
            style: TextStyle(
              color: Colors.grey[300],
              fontSize: 13,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
        ],
        
        // Follow count
        if (user.followCount > 0) ...[
          const SizedBox(height: 2),
          Text(
            '${_formatCount(user.followCount)} followers',
            style: TextStyle(
              color: Colors.grey[500],
              fontSize: 12,
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildFollowButton() {
    return Container(
      margin: const EdgeInsets.only(left: 8),
      child: ElevatedButton(
        onPressed: () => onFollow?.call(user),
        style: ElevatedButton.styleFrom(
          backgroundColor: user.isFollowing ? Colors.grey[700] : Colors.purple,
          foregroundColor: Colors.white,
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
          minimumSize: const Size(0, 32),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
          ),
        ),
        child: Text(
          user.isFollowing ? 'Following' : 'Follow',
          style: const TextStyle(
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
    );
  }

  String _formatCount(int count) {
    if (count >= 1000000) {
      return '${(count / 1000000).toStringAsFixed(1)}M';
    } else if (count >= 1000) {
      return '${(count / 1000).toStringAsFixed(1)}K';
    } else {
      return count.toString();
    }
  }
}

/// Compact user search item for suggestions or smaller lists
class CompactUserSearchItem extends StatelessWidget {
  final UserSearchResult user;
  final VoidCallback? onTap;

  const CompactUserSearchItem({
    super.key,
    required this.user,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
        child: Row(
          children: [
            // Small profile picture
            Container(
              width: 32,
              height: 32,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: Colors.grey[800],
              ),
              child: user.profilePicture != null
                  ? ClipOval(
                      child: Image.network(
                        user.profilePicture!,
                        width: 32,
                        height: 32,
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) {
                          return Icon(
                            Icons.person,
                            color: Colors.grey[500],
                            size: 16,
                          );
                        },
                      ),
                    )
                  : Icon(
                      Icons.person,
                      color: Colors.grey[500],
                      size: 16,
                    ),
            ),
            
            const SizedBox(width: 12),
            
            // User info
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    user.displayName,
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 14,
                      fontWeight: FontWeight.w500,
                    ),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                  ),
                  if (user.username.isNotEmpty)
                    Text(
                      user.username.contains('@') ? user.username : '@${user.username}',
                      style: TextStyle(
                        color: Colors.grey[400],
                        fontSize: 12,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}