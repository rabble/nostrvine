// ABOUTME: Grid widget displaying user's liked videos on profile page
// ABOUTME: Currently shows empty state placeholder - liked videos feature not yet implemented

import 'package:flutter/material.dart';

/// Grid widget displaying user's liked videos
/// Currently shows a placeholder empty state
class ProfileLikedGrid extends StatelessWidget {
  const ProfileLikedGrid({super.key});

  @override
  Widget build(BuildContext context) => CustomScrollView(
    slivers: [
      SliverFillRemaining(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: const [
              Icon(Icons.favorite_border, color: Colors.grey, size: 64),
              SizedBox(height: 16),
              Text(
                'No Liked Videos Yet',
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 18,
                  fontWeight: FontWeight.bold,
                ),
              ),
              SizedBox(height: 8),
              Text(
                'Videos you like will appear here',
                style: TextStyle(color: Colors.grey, fontSize: 14),
              ),
            ],
          ),
        ),
      ),
    ],
  );
}
