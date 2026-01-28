// ABOUTME: Navigation extension helpers for clean GoRouter call-sites
// ABOUTME: Provides goMyProfileGrid for background upload navigation

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/providers/app_providers.dart';
import 'package:openvine/screens/profile_screen_router.dart';
import 'package:openvine/utils/nostr_key_utils.dart';

extension NavX on BuildContext {
  /// Navigate to my profile in grid mode (no video playing)
  void goMyProfileGrid() {
    // Access container to get auth service
    final container = ProviderScope.containerOf(this, listen: false);
    final authService = container.read(authServiceProvider);
    final currentUserHex = authService.currentPublicKeyHex;

    if (currentUserHex != null) {
      final npub = NostrKeyUtils.encodePubKey(currentUserHex);
      go(ProfileScreenRouter.pathForNpub(npub));
    }
  }
}
