// ABOUTME: Unit tests for VideoRepository
// ABOUTME: Tests write-time deduplication, normalized IDs, and subscription tracking

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/repositories/video_repository.dart';
import 'package:openvine/services/video_event_service.dart';

import '../builders/video_event_builder.dart';

void main() {
  group('VideoRepository', () {
    late VideoRepository repository;

    setUp(() {
      repository = VideoRepository();
    });

    tearDown(() {
      repository.dispose();
    });

    group('ID normalization', () {
      test('normalizes uppercase IDs to lowercase on add', () {
        final video = VideoEventBuilder(id: 'ABCD1234EFGH5678').build();
        repository.addVideo(
          video,
          subscriptionType: SubscriptionType.discovery,
        );

        // Should find by lowercase
        expect(repository.getVideoById('abcd1234efgh5678'), isNotNull);
        // Should also find by original uppercase
        expect(repository.getVideoById('ABCD1234EFGH5678'), isNotNull);
        // Mixed case should also work
        expect(repository.getVideoById('AbCd1234EfGh5678'), isNotNull);
      });

      test('containsVideo uses case-insensitive comparison', () {
        final video = VideoEventBuilder(id: 'TestVideoId123').build();
        repository.addVideo(
          video,
          subscriptionType: SubscriptionType.discovery,
        );

        expect(repository.containsVideo('testvideoid123'), isTrue);
        expect(repository.containsVideo('TESTVIDEOID123'), isTrue);
        expect(repository.containsVideo('TestVideoId123'), isTrue);
      });

      test('deduplicates same video with different case IDs', () {
        final video1 = VideoEventBuilder(id: 'abc123').build();
        final video2 = VideoEventBuilder(id: 'ABC123').build();

        final wasAdded1 = repository.addVideo(
          video1,
          subscriptionType: SubscriptionType.discovery,
        );
        final wasAdded2 = repository.addVideo(
          video2,
          subscriptionType: SubscriptionType.discovery,
        );

        expect(wasAdded1, isTrue);
        expect(wasAdded2, isFalse); // Second add returns false (duplicate)
        expect(repository.totalVideoCount, 1);
      });
    });

    group('subscription membership', () {
      test('tracks video across multiple subscription types', () {
        final video = VideoEventBuilder(id: 'video123').build();

        repository.addVideo(
          video,
          subscriptionType: SubscriptionType.discovery,
        );
        repository.addVideo(video, subscriptionType: SubscriptionType.hashtag);

        // Video should appear in both subscriptions
        expect(
          repository
              .getVideosForSubscription(SubscriptionType.discovery)
              .length,
          1,
        );
        expect(
          repository.getVideosForSubscription(SubscriptionType.hashtag).length,
          1,
        );

        // But stored only once
        expect(repository.totalVideoCount, 1);

        // Membership should track both
        final membership = repository.getSubscriptionMembership('video123');
        expect(membership.contains(SubscriptionType.discovery), isTrue);
        expect(membership.contains(SubscriptionType.hashtag), isTrue);
      });

      test('maintains separate ordering per subscription type', () {
        final video1 = VideoEventBuilder(id: 'video1').build();
        final video2 = VideoEventBuilder(id: 'video2').build();

        // Add to discovery: video1 first (historical), then video2 (real-time)
        repository.addVideo(
          video1,
          subscriptionType: SubscriptionType.discovery,
          isHistorical: true,
        );
        repository.addVideo(
          video2,
          subscriptionType: SubscriptionType.discovery,
          isHistorical: false,
        );

        // Discovery order: video2 (top), video1 (bottom)
        final discoveryVideos = repository.getVideosForSubscription(
          SubscriptionType.discovery,
        );
        expect(discoveryVideos[0].id, 'video2');
        expect(discoveryVideos[1].id, 'video1');

        // Add same videos to hashtag in different order
        repository.addVideo(
          video2,
          subscriptionType: SubscriptionType.hashtag,
          isHistorical: true,
        );
        repository.addVideo(
          video1,
          subscriptionType: SubscriptionType.hashtag,
          isHistorical: false,
        );

        // Hashtag order: video1 (top), video2 (bottom)
        final hashtagVideos = repository.getVideosForSubscription(
          SubscriptionType.hashtag,
        );
        expect(hashtagVideos[0].id, 'video1');
        expect(hashtagVideos[1].id, 'video2');
      });
    });

    group('hashtag indexing', () {
      test('indexes videos by lowercase hashtags', () {
        final video = VideoEventBuilder(
          id: 'video1',
        ).build().copyWith(hashtags: ['Vine', 'COMEDY', 'funny']);

        repository.addVideo(video, subscriptionType: SubscriptionType.hashtag);

        // Should find by any case
        expect(repository.getVideosByHashtag('vine').length, 1);
        expect(repository.getVideosByHashtag('VINE').length, 1);
        expect(repository.getVideosByHashtag('comedy').length, 1);
        expect(repository.getVideosByHashtag('COMEDY').length, 1);
        expect(repository.getVideosByHashtag('Funny').length, 1);
      });

      test('getVideosByHashtags deduplicates across multiple hashtags', () {
        final video = VideoEventBuilder(
          id: 'video1',
        ).build().copyWith(hashtags: ['vine', 'comedy']);

        repository.addVideo(video, subscriptionType: SubscriptionType.hashtag);

        // Searching for both hashtags should return video only once
        final videos = repository.getVideosByHashtags(['vine', 'comedy']);
        expect(videos.length, 1);
      });
    });

    group('author indexing', () {
      test('indexes videos by author pubkey (case-insensitive)', () {
        const pubkey = 'AbCdEf123456';
        final video = VideoEventBuilder(id: 'video1', pubkey: pubkey).build();

        repository.addVideo(
          video,
          subscriptionType: SubscriptionType.discovery,
        );

        expect(repository.getVideosByAuthor('abcdef123456').length, 1);
        expect(repository.getVideosByAuthor('ABCDEF123456').length, 1);
        expect(repository.getVideosByAuthor(pubkey).length, 1);
      });

      test('indexes reposts by reposter pubkey', () {
        const authorPubkey = 'author123';
        const reposterPubkey = 'reposter456';
        final video = VideoEventBuilder(
          id: 'video1',
          pubkey: authorPubkey,
        ).build().copyWith(isRepost: true, reposterPubkey: reposterPubkey);

        repository.addVideo(
          video,
          subscriptionType: SubscriptionType.discovery,
        );

        // Should find by both author and reposter
        expect(repository.getVideosByAuthor(authorPubkey).length, 1);
        expect(repository.getVideosByAuthor(reposterPubkey).length, 1);
      });
    });

    group('locally deleted videos', () {
      test('prevents adding locally deleted videos', () {
        final video = VideoEventBuilder(id: 'video1').build();

        repository.markVideoAsDeleted('video1');
        final wasAdded = repository.addVideo(
          video,
          subscriptionType: SubscriptionType.discovery,
        );

        expect(wasAdded, isFalse);
        expect(repository.totalVideoCount, 0);
      });

      test('isVideoLocallyDeleted returns true for deleted videos', () {
        repository.markVideoAsDeleted('video1');

        expect(repository.isVideoLocallyDeleted('video1'), isTrue);
        expect(
          repository.isVideoLocallyDeleted('VIDEO1'),
          isTrue,
        ); // Case-insensitive
        expect(repository.isVideoLocallyDeleted('video2'), isFalse);
      });

      test('removes video from all collections when marked as deleted', () {
        final video = VideoEventBuilder(
          id: 'video1',
        ).build().copyWith(hashtags: ['vine']);

        repository.addVideo(
          video,
          subscriptionType: SubscriptionType.discovery,
        );
        repository.addVideo(video, subscriptionType: SubscriptionType.hashtag);

        expect(repository.totalVideoCount, 1);

        repository.markVideoAsDeleted('video1');

        expect(repository.totalVideoCount, 0);
        expect(
          repository
              .getVideosForSubscription(SubscriptionType.discovery)
              .length,
          0,
        );
        expect(
          repository.getVideosForSubscription(SubscriptionType.hashtag).length,
          0,
        );
        expect(repository.getVideosByHashtag('vine').length, 0);
      });
    });

    group('clearSubscription', () {
      test('clears videos for specific subscription type', () {
        final video1 = VideoEventBuilder(id: 'video1').build();
        final video2 = VideoEventBuilder(id: 'video2').build();

        repository.addVideo(
          video1,
          subscriptionType: SubscriptionType.discovery,
        );
        repository.addVideo(video2, subscriptionType: SubscriptionType.hashtag);
        // Also add video1 to hashtag
        repository.addVideo(video1, subscriptionType: SubscriptionType.hashtag);

        repository.clearSubscription(SubscriptionType.discovery);

        // Discovery should be empty
        expect(
          repository
              .getVideosForSubscription(SubscriptionType.discovery)
              .length,
          0,
        );

        // Hashtag should still have both videos
        expect(
          repository.getVideosForSubscription(SubscriptionType.hashtag).length,
          2,
        );

        // video1 should still exist (still in hashtag)
        expect(repository.getVideoById('video1'), isNotNull);
        // video2 is only in hashtag
        expect(repository.getVideoById('video2'), isNotNull);
      });
    });

    group('updateVideo', () {
      test('updates existing video data', () {
        final video = VideoEventBuilder(
          id: 'video1',
          title: 'Original',
        ).build();
        repository.addVideo(
          video,
          subscriptionType: SubscriptionType.discovery,
        );

        final updatedVideo = video.copyWith(title: 'Updated');
        final wasUpdated = repository.updateVideo(updatedVideo);

        expect(wasUpdated, isTrue);
        expect(repository.getVideoById('video1')?.title, 'Updated');
      });

      test('returns false for non-existent video', () {
        final video = VideoEventBuilder(id: 'nonexistent').build();
        final wasUpdated = repository.updateVideo(video);

        expect(wasUpdated, isFalse);
      });
    });

    group('Funnelcake + WebSocket deduplication scenario', () {
      test(
        'deduplicates videos with different case IDs from different sources',
        () {
          // Simulate Funnelcake returning uppercase ID
          final funnelcakeVideo = VideoEventBuilder(
            id: 'ABCD1234567890ABCD1234567890ABCD1234567890ABCD1234567890ABCD1234',
          ).build();

          // Simulate WebSocket returning lowercase ID for same video
          final websocketVideo = VideoEventBuilder(
            id: 'abcd1234567890abcd1234567890abcd1234567890abcd1234567890abcd1234',
          ).build();

          repository.addVideo(
            funnelcakeVideo,
            subscriptionType: SubscriptionType.hashtag,
          );
          repository.addVideo(
            websocketVideo,
            subscriptionType: SubscriptionType.hashtag,
          );

          // Should only have one video
          expect(repository.totalVideoCount, 1);
          expect(
            repository
                .getVideosForSubscription(SubscriptionType.hashtag)
                .length,
            1,
          );
        },
      );
    });
  });
}
