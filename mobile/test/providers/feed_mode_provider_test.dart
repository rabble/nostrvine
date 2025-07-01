// ABOUTME: Tests for FeedMode and FeedContext providers
// ABOUTME: Verifies feed mode switching and context management

import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:openvine/providers/feed_mode_providers.dart';
import 'package:openvine/state/video_feed_state.dart';

void main() {
  group('FeedModeProvider', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('should start with following mode', () {
      final mode = container.read(feedModeNotifierProvider);
      expect(mode, equals(FeedMode.following));
    });

    test('should switch to different modes', () {
      final notifier = container.read(feedModeNotifierProvider.notifier);
      
      // Test each mode
      notifier.setMode(FeedMode.curated);
      expect(container.read(feedModeNotifierProvider), equals(FeedMode.curated));
      
      notifier.setMode(FeedMode.discovery);
      expect(container.read(feedModeNotifierProvider), equals(FeedMode.discovery));
      
      notifier.showFollowing();
      expect(container.read(feedModeNotifierProvider), equals(FeedMode.following));
    });

    test('should set hashtag mode with context', () {
      final notifier = container.read(feedModeNotifierProvider.notifier);
      
      notifier.setHashtagMode('bitcoin');
      
      expect(container.read(feedModeNotifierProvider), equals(FeedMode.hashtag));
      expect(container.read(feedContextProvider), equals('bitcoin'));
    });

    test('should set profile mode with pubkey', () {
      final notifier = container.read(feedModeNotifierProvider.notifier);
      
      notifier.setProfileMode('pubkey123');
      
      expect(container.read(feedModeNotifierProvider), equals(FeedMode.profile));
      expect(container.read(feedContextProvider), equals('pubkey123'));
    });

    test('should clear context when switching to non-contextual mode', () {
      final notifier = container.read(feedModeNotifierProvider.notifier);
      
      // First set a contextual mode
      notifier.setHashtagMode('nostr');
      expect(container.read(feedContextProvider), equals('nostr'));
      
      // Switch to non-contextual mode
      notifier.showFollowing();
      expect(container.read(feedContextProvider), isNull);
    });

    test('should identify modes that require context', () {
      final notifier = container.read(feedModeNotifierProvider.notifier);
      
      notifier.setMode(FeedMode.following);
      expect(notifier.requiresContext, isFalse);
      
      notifier.setMode(FeedMode.hashtag);
      expect(notifier.requiresContext, isTrue);
      
      notifier.setMode(FeedMode.profile);
      expect(notifier.requiresContext, isTrue);
    });
  });

  group('FeedContextProvider', () {
    late ProviderContainer container;

    setUp(() {
      container = ProviderContainer();
    });

    tearDown(() {
      container.dispose();
    });

    test('should start with null context', () {
      final context = container.read(feedContextProvider);
      expect(context, isNull);
    });

    test('should get hashtag without # prefix', () {
      final modeNotifier = container.read(feedModeNotifierProvider.notifier);
      final contextNotifier = container.read(feedContextProvider.notifier);
      
      // Set hashtag mode
      modeNotifier.setMode(FeedMode.hashtag);
      
      // Test with # prefix
      contextNotifier.setContext('#bitcoin');
      expect(contextNotifier.hashtag, equals('bitcoin'));
      
      // Test without # prefix
      contextNotifier.setContext('nostr');
      expect(contextNotifier.hashtag, equals('nostr'));
    });

    test('should get pubkey only in profile mode', () {
      final modeNotifier = container.read(feedModeNotifierProvider.notifier);
      final contextNotifier = container.read(feedContextProvider.notifier);
      
      // Set context in non-profile mode
      modeNotifier.setMode(FeedMode.hashtag);
      contextNotifier.setContext('pubkey123');
      expect(contextNotifier.pubkey, isNull);
      
      // Switch to profile mode
      modeNotifier.setMode(FeedMode.profile);
      expect(contextNotifier.pubkey, equals('pubkey123'));
    });
  });
}