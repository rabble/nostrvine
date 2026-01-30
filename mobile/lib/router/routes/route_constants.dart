// ABOUTME: Route constants for social screens (followers, following)
// ABOUTME: Provides route names, paths, and path builders

/// Route constants for followers screen.
class FollowersRoutes {
  FollowersRoutes._();

  /// Route name for followers screen.
  static const routeName = 'followers';

  /// Base path for followers routes.
  static const basePath = '/followers';

  /// Path pattern for followers route.
  static const path = '/followers/:pubkey';

  /// Build path for a specific user's followers.
  static String pathForPubkey(String pubkey) => '$basePath/$pubkey';
}

/// Route constants for following screen.
class FollowingRoutes {
  FollowingRoutes._();

  /// Route name for following screen.
  static const routeName = 'following';

  /// Base path for following routes.
  static const basePath = '/following';

  /// Path pattern for following route.
  static const path = '/following/:pubkey';

  /// Build path for a specific user's following list.
  static String pathForPubkey(String pubkey) => '$basePath/$pubkey';
}
