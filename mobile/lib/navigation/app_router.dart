// ABOUTME: Central app navigation configuration using go_router
// ABOUTME: Defines all routes, deep linking, and navigation guards for the app

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../screens/feed_screen.dart';
import '../screens/camera_screen.dart';
import '../screens/profile_screen.dart';
import '../screens/upload_manager_screen.dart';
import '../screens/search_screen.dart';
import '../screens/user_profile_screen.dart';
import '../navigation/main_shell.dart';
import '../main.dart' show AppInitializer;

/// Central router configuration for the app
class AppRouter {
  static const String splashPath = '/splash';
  static const String feedPath = '/';
  static const String cameraPath = '/camera';
  static const String profilePath = '/profile';
  static const String uploadManagerPath = '/uploads';
  static const String searchPath = '/search';
  static const String userProfilePath = '/user/:userId';
  static const String settingsPath = '/settings';
  static const String editProfilePath = '/edit-profile';
  static const String notificationsPath = '/notifications';
  static const String commentsPath = '/comments/:videoId';
  static const String videoDetailsPath = '/video/:videoId';
  static const String blockedUsersPath = '/blocked-users';

  /// Global router instance
  static final GoRouter router = GoRouter(
    debugLogDiagnostics: true,
    initialLocation: splashPath,
    routes: [
      // Splash/initialization route
      GoRoute(
        path: splashPath,
        name: 'splash',
        pageBuilder: (context, state) => const MaterialPage(
          child: AppInitializer(),
        ),
      ),
      ShellRoute(
        builder: (context, state, child) => MainShell(child: child),
        routes: [
          // Main tab routes
          GoRoute(
            path: feedPath,
            name: 'feed',
            pageBuilder: (context, state) => const MaterialPage(
              child: FeedScreen(),
            ),
          ),
          GoRoute(
            path: cameraPath,
            name: 'camera',
            pageBuilder: (context, state) => const MaterialPage(
              child: CameraScreen(),
            ),
          ),
          GoRoute(
            path: profilePath,
            name: 'profile',
            pageBuilder: (context, state) => const MaterialPage(
              child: ProfileScreen(),
            ),
          ),
        ],
      ),
      
      // Modal/overlay routes (outside main shell)
      GoRoute(
        path: uploadManagerPath,
        name: 'upload-manager',
        pageBuilder: (context, state) => const MaterialPage(
          child: UploadManagerScreen(),
        ),
      ),
      GoRoute(
        path: searchPath,
        name: 'search',
        pageBuilder: (context, state) => const MaterialPage(
          child: SearchScreen(),
        ),
      ),
      GoRoute(
        path: userProfilePath,
        name: 'user-profile',
        pageBuilder: (context, state) {
          final userId = state.pathParameters['userId']!;
          final displayName = state.uri.queryParameters['displayName'];
          
          return MaterialPage(
            child: UserProfileScreen(
              userPubkey: userId,
              initialDisplayName: displayName,
            ),
          );
        },
      ),
      
      // Settings and management routes
      GoRoute(
        path: settingsPath,
        name: 'settings',
        pageBuilder: (context, state) => MaterialPage(
          child: _buildPlaceholderScreen(
            title: 'Settings', 
            icon: Icons.settings,
            description: 'App settings and preferences',
          ),
        ),
      ),
      GoRoute(
        path: editProfilePath,
        name: 'edit-profile',
        pageBuilder: (context, state) => MaterialPage(
          child: _buildPlaceholderScreen(
            title: 'Edit Profile', 
            icon: Icons.edit,
            description: 'Edit your Nostr profile information',
          ),
        ),
      ),
      GoRoute(
        path: notificationsPath,
        name: 'notifications',
        pageBuilder: (context, state) => MaterialPage(
          child: _buildPlaceholderScreen(
            title: 'Notifications', 
            icon: Icons.notifications,
            description: 'Your notifications and mentions',
          ),
        ),
      ),
      GoRoute(
        path: commentsPath,
        name: 'comments',
        pageBuilder: (context, state) {
          final videoId = state.pathParameters['videoId']!;
          
          return MaterialPage(
            child: _buildPlaceholderScreen(
              title: 'Comments', 
              icon: Icons.comment,
              description: 'Comments for video ${videoId.substring(0, 8)}...',
            ),
          );
        },
      ),
      GoRoute(
        path: videoDetailsPath,
        name: 'video-details',
        pageBuilder: (context, state) {
          final videoId = state.pathParameters['videoId']!;
          
          return MaterialPage(
            child: _buildPlaceholderScreen(
              title: 'Video Details', 
              icon: Icons.video_library,
              description: 'Details for video ${videoId.substring(0, 8)}...',
            ),
          );
        },
      ),
      GoRoute(
        path: blockedUsersPath,
        name: 'blocked-users',
        pageBuilder: (context, state) => MaterialPage(
          child: _buildPlaceholderScreen(
            title: 'Blocked Users', 
            icon: Icons.block,
            description: 'Manage blocked users and content',
          ),
        ),
      ),
    ],
    
    // Error handling
    errorPageBuilder: (context, state) => MaterialPage(
      child: _buildErrorScreen(state.error.toString()),
    ),
  );

  /// Helper method to build placeholder screens for unimplemented routes
  static Widget _buildPlaceholderScreen({
    required String title,
    required IconData icon,
    required String description,
  }) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: Text(title),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(
              icon,
              size: 64,
              color: Colors.white54,
            ),
            const SizedBox(height: 16),
            Text(
              title,
              style: const TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                description,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 16,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 32),
            Container(
              padding: const EdgeInsets.all(16),
              margin: const EdgeInsets.symmetric(horizontal: 32),
              decoration: BoxDecoration(
                color: Colors.grey[900],
                borderRadius: BorderRadius.circular(8),
                border: Border.all(color: Colors.grey[700]!),
              ),
              child: const Text(
                'This screen is coming soon!\nNavigation is working correctly.',
                style: TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// Helper method to build error screens
  static Widget _buildErrorScreen(String error) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        title: const Text('Navigation Error'),
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
      ),
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(
              Icons.error_outline,
              size: 64,
              color: Colors.red,
            ),
            const SizedBox(height: 16),
            const Text(
              'Navigation Error',
              style: TextStyle(
                color: Colors.white,
                fontSize: 24,
                fontWeight: FontWeight.bold,
              ),
            ),
            const SizedBox(height: 8),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 32),
              child: Text(
                error,
                style: const TextStyle(
                  color: Colors.white70,
                  fontSize: 14,
                ),
                textAlign: TextAlign.center,
              ),
            ),
            const SizedBox(height: 32),
            ElevatedButton(
              onPressed: () {
                AppRouter.router.go(AppRouter.feedPath);
              },
              child: const Text('Go to Feed'),
            ),
          ],
        ),
      ),
    );
  }
}

/// Navigation service for programmatic navigation
class NavigationService {
  static final GoRouter _router = AppRouter.router;

  /// Navigate to feed screen
  static void goToFeed() => _router.go(AppRouter.feedPath);

  /// Navigate to camera screen
  static void goToCamera() => _router.go(AppRouter.cameraPath);

  /// Navigate to profile screen
  static void goToProfile() => _router.go(AppRouter.profilePath);

  /// Navigate to upload manager
  static void goToUploadManager() => _router.go(AppRouter.uploadManagerPath);

  /// Navigate to search screen
  static void goToSearch() => _router.go(AppRouter.searchPath);

  /// Navigate to user profile
  static void goToUserProfile(String userId, {String? displayName}) {
    final uri = Uri(
      path: AppRouter.userProfilePath.replaceAll(':userId', userId),
      queryParameters: displayName != null ? {'displayName': displayName} : null,
    );
    _router.go(uri.toString());
  }

  /// Navigate to settings
  static void goToSettings() => _router.go(AppRouter.settingsPath);

  /// Navigate to edit profile
  static void goToEditProfile() => _router.go(AppRouter.editProfilePath);

  /// Navigate to notifications
  static void goToNotifications() => _router.go(AppRouter.notificationsPath);

  /// Navigate to comments for a video
  static void goToComments(String videoId) =>
      _router.go(AppRouter.commentsPath.replaceAll(':videoId', videoId));

  /// Navigate to video details
  static void goToVideoDetails(String videoId) =>
      _router.go(AppRouter.videoDetailsPath.replaceAll(':videoId', videoId));

  /// Navigate to blocked users
  static void goToBlockedUsers() => _router.go(AppRouter.blockedUsersPath);

  /// Go back (pop current route)
  static void goBack() {
    if (_router.canPop()) {
      _router.pop();
    } else {
      // If can't pop, go to feed as fallback
      goToFeed();
    }
  }

  /// Get current location
  static String get currentLocation => _router.routeInformationProvider.value.uri.path;

  /// Check if we can go back
  static bool get canGoBack => _router.canPop();
}