// ABOUTME: BuildContext extensions for common navigation patterns
// ABOUTME: Provides type-safe, reusable navigation helpers

import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import 'package:openvine/screens/profile_screen_router.dart';
import 'package:openvine/screens/pure/search_screen_pure.dart';
import 'package:openvine/utils/nostr_key_utils.dart';

/// Extension on BuildContext for common navigation patterns
extension NavExtensions on BuildContext {
  /// Navigate to another user's profile using their hex pubkey.
  ///
  /// Converts the hex pubkey to npub format and pushes the profile screen.
  /// Use this for navigating to profiles from mentions, comments, etc.
  void pushOtherProfile(String hexPubkey) {
    final npub = NostrKeyUtils.encodePubKey(hexPubkey);
    push(ProfileScreenRouter.pathForNpub(npub));
  }

  /// Navigate to another user's profile using their hex pubkey (using go).
  ///
  /// Converts the hex pubkey to npub format and goes to the profile screen.
  /// Use this when you want to replace the current route.
  void goOtherProfile(String hexPubkey) {
    final npub = NostrKeyUtils.encodePubKey(hexPubkey);
    go(ProfileScreenRouter.pathForNpub(npub));
  }

  /// Navigate to search with an optional pre-filled search term.
  ///
  /// Use this for @mention lookups, hashtag searches, etc.
  void goSearch([String? term]) {
    go(SearchScreenPure.pathForTerm(term: term));
  }

  /// Push search screen with an optional pre-filled search term.
  ///
  /// Use this when you want to keep the current screen in the back stack.
  void pushSearch([String? term]) {
    push(SearchScreenPure.pathForTerm(term: term));
  }
}
