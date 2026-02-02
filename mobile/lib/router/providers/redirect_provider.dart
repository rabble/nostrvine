// ABOUTME: Riverpod providers for route redirect guards
// ABOUTME: Checks following cache for redirect logic

import 'dart:convert';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/screens/explore_screen.dart';
import 'package:openvine/screens/welcome_screen.dart';
import 'package:openvine/utils/unified_logger.dart';

/// Checks if the current user has any following in cache.
///
/// This provider can be used in redirect logic without
/// needing async operations.
final hasFollowingInCacheProvider = Provider<bool>((ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  final currentUserPubkey = prefs.getString('current_user_pubkey_hex');

  Log.debug(
    'Current user pubkey from prefs: $currentUserPubkey',
    name: 'RedirectGuards',
    category: LogCategory.ui,
  );

  if (currentUserPubkey == null || currentUserPubkey.isEmpty) {
    Log.debug(
      'No current user pubkey stored, treating as no following',
      name: 'RedirectGuards',
      category: LogCategory.ui,
    );
    return false;
  }

  final key = 'following_list_$currentUserPubkey';
  final value = prefs.getString(key);

  if (value == null || value.isEmpty) {
    Log.debug(
      'No following list cache for current user',
      name: 'RedirectGuards',
      category: LogCategory.ui,
    );
    return false;
  }

  try {
    final List<dynamic> decoded = jsonDecode(value);
    Log.debug(
      'Current user following list has ${decoded.length} entries',
      name: 'RedirectGuards',
      category: LogCategory.ui,
    );
    return decoded.isNotEmpty;
  } catch (e) {
    Log.debug(
      'Current user following list has invalid JSON: $e',
      name: 'RedirectGuards',
      category: LogCategory.ui,
    );
    return false;
  }
});

/// Checks if TOS (age verification) has been accepted.
final hasTosAcceptedProvider = Provider<bool>((Ref ref) {
  final prefs = ref.watch(sharedPreferencesProvider);
  return prefs.getBool('age_verified_16_plus') ?? false;
});

/// Check if we should redirect to explore because user has no following list.
///
/// Returns the redirect path (/explore) or null if no redirect needed.
/// This is a family provider that takes the current location as a parameter.
final checkEmptyFollowingRedirectProvider = Provider.family<String?, String>((
  ref,
  location,
) {
  // Only redirect to explore when coming from WelcomeScreen if user follows
  // nobody. After that, let users navigate to home freely (they'll see a
  // message to follow people)
  if (!location.startsWith(WelcomeScreen.path)) return null;

  final hasFollowing = ref.watch(hasFollowingInCacheProvider);

  Log.debug(
    'Empty contacts check: hasFollowing=$hasFollowing, '
    'redirecting=${!hasFollowing}',
    name: 'AppRouter',
    category: LogCategory.ui,
  );

  if (!hasFollowing) {
    Log.debug(
      'Redirecting to /explore because no following list found',
      name: 'AppRouter',
      category: LogCategory.ui,
    );
    return ExploreScreen.path;
  }

  return null;
});
