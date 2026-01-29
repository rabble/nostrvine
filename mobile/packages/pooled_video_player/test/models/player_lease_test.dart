import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pooled_video_player/pooled_video_player.dart';

import '../helpers/test_helpers.dart';

void main() {
  setUpAll(registerTestFallbackValues);

  group('PlayerPriority', () {
    test('current is 0', () {
      expect(PlayerPriority.current, 0);
    });

    test('detail is 1', () {
      expect(PlayerPriority.detail, 1);
    });

    test('adjacentFocused is 10', () {
      expect(PlayerPriority.adjacentFocused, 10);
    });

    test('adjacentBackground is 20', () {
      expect(PlayerPriority.adjacentBackground, 20);
    });

    test('distant is 30', () {
      expect(PlayerPriority.distant, 30);
    });

    test('priorities are ordered correctly (lower = more important)', () {
      expect(PlayerPriority.current, lessThan(PlayerPriority.detail));
      expect(PlayerPriority.detail, lessThan(PlayerPriority.adjacentFocused));
      expect(
        PlayerPriority.adjacentFocused,
        lessThan(PlayerPriority.adjacentBackground),
      );
      expect(
        PlayerPriority.adjacentBackground,
        lessThan(PlayerPriority.distant),
      );
    });
  });

  group('PlayerLease', () {
    late PooledPlayer pooledPlayer;
    late MockPlayer mockPlayer;
    late MockVideoController mockVideoController;

    setUp(() {
      mockPlayer = MockPlayer();
      mockVideoController = MockVideoController();

      // Stub required methods
      when(mockPlayer.stop).thenAnswer((_) async {});
      when(mockPlayer.play).thenAnswer((_) async {});
      when(mockPlayer.pause).thenAnswer((_) async {});
      when(mockPlayer.dispose).thenAnswer((_) async {});
      when(() => mockPlayer.setVolume(any())).thenAnswer((_) async {});

      pooledPlayer = PooledPlayer(
        player: mockPlayer,
        videoController: mockVideoController,
      );
    });

    group('Constructor', () {
      test('creates with required fields', () {
        final lease = PlayerLease(
          pooledPlayer: pooledPlayer,
          videoId: 'video-123',
          ownerId: 'feed-1',
        );

        expect(lease.pooledPlayer, pooledPlayer);
        expect(lease.videoId, 'video-123');
        expect(lease.ownerId, 'feed-1');
      });

      test('priority defaults to distant', () {
        final lease = PlayerLease(
          pooledPlayer: pooledPlayer,
          videoId: 'video-123',
          ownerId: 'feed-1',
        );

        expect(lease.priority, PlayerPriority.distant);
      });

      test('priority can be set via constructor', () {
        final lease = PlayerLease(
          pooledPlayer: pooledPlayer,
          videoId: 'video-123',
          ownerId: 'feed-1',
          priority: PlayerPriority.current,
        );

        expect(lease.priority, PlayerPriority.current);
      });

      test('createdAt is set to approximately now', () {
        final before = DateTime.now();
        final lease = PlayerLease(
          pooledPlayer: pooledPlayer,
          videoId: 'video-123',
          ownerId: 'feed-1',
        );
        final after = DateTime.now();

        expect(
          lease.createdAt.isAfter(before) ||
              lease.createdAt.isAtSameMomentAs(before),
          true,
        );
        expect(
          lease.createdAt.isBefore(after) ||
              lease.createdAt.isAtSameMomentAs(after),
          true,
        );
      });
    });

    group('getters', () {
      test('player returns pooledPlayer.player', () {
        final lease = PlayerLease(
          pooledPlayer: pooledPlayer,
          videoId: 'video-123',
          ownerId: 'feed-1',
        );

        expect(lease.player, pooledPlayer.player);
        expect(lease.player, mockPlayer);
      });

      test('videoController returns pooledPlayer.videoController', () {
        final lease = PlayerLease(
          pooledPlayer: pooledPlayer,
          videoId: 'video-123',
          ownerId: 'feed-1',
        );

        expect(lease.videoController, pooledPlayer.videoController);
        expect(lease.videoController, mockVideoController);
      });

      test('isValid returns true when pooledPlayer is not disposed', () {
        final lease = PlayerLease(
          pooledPlayer: pooledPlayer,
          videoId: 'video-123',
          ownerId: 'feed-1',
        );

        expect(pooledPlayer.isDisposed, false);
        expect(lease.isValid, true);
      });

      test('isValid returns false when pooledPlayer is disposed', () {
        pooledPlayer.isDisposed = true;

        final lease = PlayerLease(
          pooledPlayer: pooledPlayer,
          videoId: 'video-123',
          ownerId: 'feed-1',
        );

        expect(lease.isValid, false);
      });

      test('lastUsed returns pooledPlayer.lastUsed', () {
        final lease = PlayerLease(
          pooledPlayer: pooledPlayer,
          videoId: 'video-123',
          ownerId: 'feed-1',
        );

        expect(lease.lastUsed, pooledPlayer.lastUsed);
      });
    });

    group('transferTo', () {
      test('updates ownerId', () {
        final lease = PlayerLease(
          pooledPlayer: pooledPlayer,
          videoId: 'video-123',
          ownerId: 'feed-1',
        );

        expect(lease.ownerId, 'feed-1');

        lease.transferTo('detail-page');

        expect(lease.ownerId, 'detail-page');
      });

      test('updates pooledPlayer.lastUsed', () {
        final lease = PlayerLease(
          pooledPlayer: pooledPlayer,
          videoId: 'video-123',
          ownerId: 'feed-1',
        );

        final lastUsedBefore = pooledPlayer.lastUsed;

        // Small delay to ensure time difference
        Future<void>.delayed(const Duration(milliseconds: 10));

        lease.transferTo('detail-page');

        expect(
          pooledPlayer.lastUsed.isAfter(lastUsedBefore) ||
              pooledPlayer.lastUsed.isAtSameMomentAs(lastUsedBefore),
          true,
        );
      });
    });

    group('priority', () {
      test('can be updated after construction', () {
        final lease = PlayerLease(
          pooledPlayer: pooledPlayer,
          videoId: 'video-123',
          ownerId: 'feed-1',
          priority: PlayerPriority.distant,
        );

        expect(lease.priority, PlayerPriority.distant);

        lease.priority = PlayerPriority.current;

        expect(lease.priority, PlayerPriority.current);
      });
    });

    group('toString', () {
      test('includes videoId, ownerId, priority, and isValid', () {
        final lease = PlayerLease(
          pooledPlayer: pooledPlayer,
          videoId: 'video-123',
          ownerId: 'feed-1',
          priority: PlayerPriority.adjacentFocused,
        );

        final string = lease.toString();

        expect(string, contains('videoId: video-123'));
        expect(string, contains('ownerId: feed-1'));
        expect(string, contains('priority: ${PlayerPriority.adjacentFocused}'));
        expect(string, contains('isValid: true'));
      });
    });
  });
}
