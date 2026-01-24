// ABOUTME: Reusable user avatar widget that displays profile pictures or fallback initials
// ABOUTME: Handles loading states, errors, and provides consistent avatar appearance across the app

import 'package:cached_network_image/cached_network_image.dart';
import 'package:flutter/material.dart';
import 'package:openvine/services/image_cache_manager.dart';
import 'package:openvine/utils/unified_logger.dart';

class UserAvatar extends StatelessWidget {
  const UserAvatar({
    super.key,
    this.imageUrl,
    this.name,
    this.size = 44,
    this.onTap,
  });
  final String? imageUrl;
  final String? name;
  final double size;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    return GestureDetector(
      onTap: onTap,
      child: ClipRRect(
        borderRadius: BorderRadius.circular(25),
        child: SizedBox(
          width: size,
          height: size,
          child: imageUrl != null && imageUrl!.isNotEmpty
              ? CachedNetworkImage(
                  imageUrl: imageUrl!,
                  width: size,
                  height: size,
                  fit: BoxFit.cover,
                  cacheManager: openVineImageCache,
                  placeholder: (context, url) => _buildDefaultAvatar(),
                  errorWidget: (context, url, error) {
                    // Log the failed URL for debugging
                    if (error.toString().contains('Invalid image data') ||
                        error.toString().contains('Image codec failed')) {
                      UnifiedLogger.warning(
                        '🖼️ Invalid image data for avatar URL: $url - Error: $error',
                        name: 'UserAvatar',
                      );
                    } else {
                      UnifiedLogger.debug(
                        'Avatar image failed to load URL: $url - Error: $error',
                        name: 'UserAvatar',
                      );
                    }
                    return _buildDefaultAvatar();
                  },
                )
              : _buildDefaultAvatar(),
        ),
      ),
    );
  }

  Widget _buildDefaultAvatar() {
    return Image.asset(
      'assets/icon/acid_avatar.png',
      width: size,
      height: size,
      fit: BoxFit.cover,
    );
  }
}
