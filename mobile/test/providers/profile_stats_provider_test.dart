import 'package:flutter_test/flutter_test.dart';
import 'package:mockito/mockito.dart';
import 'package:mockito/annotations.dart';
import 'package:openvine/providers/profile_stats_provider.dart';
import 'package:openvine/services/social_service.dart';

// Generate mocks
@GenerateMocks([SocialService])
import 'profile_stats_provider_test.mocks.dart';

void main() {
  group('ProfileStatsProvider', () {
    late ProfileStatsProvider provider;
    late MockSocialService mockSocialService;

    setUp(() {
      mockSocialService = MockSocialService();
      provider = ProfileStatsProvider(mockSocialService);
    });

    tearDown(() {
      provider.dispose();
    });

    group('Initial State', () {
      test('should have correct initial state', () {
        expect(provider.loadingState, ProfileStatsLoadingState.idle);
        expect(provider.stats, isNull);
        expect(provider.error, isNull);
        expect(provider.isLoading, false);
        expect(provider.hasError, false);
        expect(provider.hasData, false);
      });
    });

    group('Loading Profile Stats', () {
      const testPubkey = 'test_pubkey_123';

      test('should load profile stats successfully', () async {
        // Mock social service responses
        when(mockSocialService.getFollowerStats(testPubkey)).thenAnswer(
          (_) async => {'followers': 100, 'following': 50},
        );
        when(mockSocialService.getUserVideoCount(testPubkey)).thenAnswer(
          (_) async => 25,
        );
        when(mockSocialService.getUserTotalLikes(testPubkey)).thenAnswer(
          (_) async => 500,
        );

        // Track loading state changes
        final states = <ProfileStatsLoadingState>[];
        provider.addListener(() {
          states.add(provider.loadingState);
        });

        // Load stats
        await provider.loadProfileStats(testPubkey);

        // Verify state progression
        expect(states, contains(ProfileStatsLoadingState.loading));
        expect(provider.loadingState, ProfileStatsLoadingState.loaded);
        expect(provider.hasData, true);
        expect(provider.error, isNull);

        // Verify stats content
        final stats = provider.stats!;
        expect(stats.videoCount, 25);
        expect(stats.totalLikes, 500);
        expect(stats.followers, 100);
        expect(stats.following, 50);
        expect(stats.totalViews, 0); // Placeholder

        // Verify service calls
        verify(mockSocialService.getFollowerStats(testPubkey)).called(1);
        verify(mockSocialService.getUserVideoCount(testPubkey)).called(1);
        verify(mockSocialService.getUserTotalLikes(testPubkey)).called(1);
      });

      test('should handle loading errors gracefully', () async {
        // Mock service failure
        when(mockSocialService.getFollowerStats(testPubkey)).thenThrow(
          Exception('Network error'),
        );

        // Load stats
        await provider.loadProfileStats(testPubkey);

        // Verify error state
        expect(provider.loadingState, ProfileStatsLoadingState.error);
        expect(provider.hasError, true);
        expect(provider.error, contains('Network error'));
        expect(provider.stats, isNull);
      });

      test('should not reload if already loaded for same user', () async {
        // First load
        when(mockSocialService.getFollowerStats(testPubkey)).thenAnswer(
          (_) async => {'followers': 100, 'following': 50},
        );
        when(mockSocialService.getUserVideoCount(testPubkey)).thenAnswer(
          (_) async => 25,
        );
        when(mockSocialService.getUserTotalLikes(testPubkey)).thenAnswer(
          (_) async => 500,
        );

        await provider.loadProfileStats(testPubkey);

        // Reset mock call counts
        clearInteractions(mockSocialService);

        // Second load for same user
        await provider.loadProfileStats(testPubkey);

        // Should not call services again
        verifyNever(mockSocialService.getFollowerStats(any));
        verifyNever(mockSocialService.getUserVideoCount(any));
        verifyNever(mockSocialService.getUserTotalLikes(any));
      });
    });

    group('Caching', () {
      const testPubkey = 'test_pubkey_123';

      test('should use cached stats when available', () async {
        // First load
        when(mockSocialService.getFollowerStats(testPubkey)).thenAnswer(
          (_) async => {'followers': 100, 'following': 50},
        );
        when(mockSocialService.getUserVideoCount(testPubkey)).thenAnswer(
          (_) async => 25,
        );
        when(mockSocialService.getUserTotalLikes(testPubkey)).thenAnswer(
          (_) async => 500,
        );

        await provider.loadProfileStats(testPubkey);

        // Create new provider instance
        final newProvider = ProfileStatsProvider(mockSocialService);
        
        // Cache should be empty for new instance
        expect(newProvider.stats, isNull);
        
        newProvider.dispose();
      });

      test('should refresh stats by clearing cache', () async {
        // First load
        when(mockSocialService.getFollowerStats(testPubkey)).thenAnswer(
          (_) async => {'followers': 100, 'following': 50},
        );
        when(mockSocialService.getUserVideoCount(testPubkey)).thenAnswer(
          (_) async => 25,
        );
        when(mockSocialService.getUserTotalLikes(testPubkey)).thenAnswer(
          (_) async => 500,
        );

        await provider.loadProfileStats(testPubkey);
        clearInteractions(mockSocialService);

        // Mock updated stats
        when(mockSocialService.getFollowerStats(testPubkey)).thenAnswer(
          (_) async => {'followers': 150, 'following': 75},
        );
        when(mockSocialService.getUserVideoCount(testPubkey)).thenAnswer(
          (_) async => 30,
        );
        when(mockSocialService.getUserTotalLikes(testPubkey)).thenAnswer(
          (_) async => 600,
        );

        // Refresh stats
        await provider.refreshStats();

        // Should have new stats
        expect(provider.stats!.videoCount, 30);
        expect(provider.stats!.totalLikes, 600);
        expect(provider.stats!.followers, 150);
        expect(provider.stats!.following, 75);

        // Should have called services again
        verify(mockSocialService.getFollowerStats(testPubkey)).called(1);
        verify(mockSocialService.getUserVideoCount(testPubkey)).called(1);
        verify(mockSocialService.getUserTotalLikes(testPubkey)).called(1);
      });

      test('should clear all cache', () {
        provider.clearAllCache();
        // Just verify it doesn't throw - internal state is private
      });
    });

    group('Utility Methods', () {
      test('should format counts correctly', () {
        expect(ProfileStatsProvider.formatCount(0), '0');
        expect(ProfileStatsProvider.formatCount(999), '999');
        expect(ProfileStatsProvider.formatCount(1000), '1.0K');
        expect(ProfileStatsProvider.formatCount(1500), '1.5K');
        expect(ProfileStatsProvider.formatCount(1000000), '1.0M');
        expect(ProfileStatsProvider.formatCount(2500000), '2.5M');
        expect(ProfileStatsProvider.formatCount(1000000000), '1.0B');
        expect(ProfileStatsProvider.formatCount(3200000000), '3.2B');
      });
    });

    group('ProfileStats Model', () {
      test('should create ProfileStats correctly', () {
        final stats = ProfileStats(
          videoCount: 25,
          totalLikes: 500,
          followers: 100,
          following: 50,
          totalViews: 1000,
          lastUpdated: DateTime.now(),
        );

        expect(stats.videoCount, 25);
        expect(stats.totalLikes, 500);
        expect(stats.followers, 100);
        expect(stats.following, 50);
        expect(stats.totalViews, 1000);
      });

      test('should copy ProfileStats with changes', () {
        final original = ProfileStats(
          videoCount: 25,
          totalLikes: 500,
          followers: 100,
          following: 50,
          totalViews: 1000,
          lastUpdated: DateTime.now(),
        );

        final updated = original.copyWith(
          videoCount: 30,
          totalLikes: 600,
        );

        expect(updated.videoCount, 30);
        expect(updated.totalLikes, 600);
        expect(updated.followers, 100); // Unchanged
        expect(updated.following, 50); // Unchanged
        expect(updated.totalViews, 1000); // Unchanged
      });

      test('should have meaningful toString', () {
        final stats = ProfileStats(
          videoCount: 25,
          totalLikes: 500,
          followers: 100,
          following: 50,
          totalViews: 1000,
          lastUpdated: DateTime.now(),
        );

        final string = stats.toString();
        expect(string, contains('25'));
        expect(string, contains('500'));
        expect(string, contains('100'));
        expect(string, contains('50'));
        expect(string, contains('1000'));
      });
    });
  });
}