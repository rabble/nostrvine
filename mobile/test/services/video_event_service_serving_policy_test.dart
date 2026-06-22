import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:nostr_client/nostr_client.dart';
import 'package:openvine/services/subscription_manager.dart';
import 'package:openvine/services/video_event_service.dart';

const allowedClassicPubkey =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const otherPubkey =
    'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';

class _MockNostrClient extends Mock implements NostrClient {}

class _MockSubscriptionManager extends Mock implements SubscriptionManager {}

void main() {
  group('VideoEventService serving policy', () {
    late VideoEventService service;

    setUp(() {
      service =
          VideoEventService(
            _MockNostrClient(),
            subscriptionManager: _MockSubscriptionManager(),
          )..setVideoServingPolicy(
            const VideoServingPolicy(
              allowedClassicVinePubkeys: {allowedClassicPubkey},
            ),
          );
    });

    tearDown(() => service.dispose());

    test('hides unverified non-classic videos', () {
      expect(service.shouldHideVideo(_video(pubkey: otherPubkey)), isTrue);
    });

    test('keeps certified ProofMode videos', () {
      final video = _video(
        pubkey: otherPubkey,
        rawTags: const {'verification': 'verified_mobile'},
      );

      expect(service.shouldHideVideo(video), isFalse);
    });

    test('keeps allowlisted recovered classic Vines', () {
      final video = _video(
        pubkey: allowedClassicPubkey,
        rawTags: const {'platform': 'vine'},
      );

      expect(service.shouldHideVideo(video), isFalse);
    });

    test('hides non-allowlisted recovered classic Vines', () {
      final video = _video(
        pubkey: otherPubkey,
        rawTags: const {'platform': 'vine'},
      );

      expect(service.shouldHideVideo(video), isTrue);
    });
  });
}

VideoEvent _video({
  required String pubkey,
  Map<String, String> rawTags = const {},
}) {
  return VideoEvent(
    id: 'video-id',
    pubkey: pubkey,
    createdAt: 1000,
    content: '',
    timestamp: DateTime.fromMillisecondsSinceEpoch(1000 * 1000, isUtc: true),
    videoUrl: 'https://cdn.example.com/video.mp4',
    rawTags: rawTags,
  );
}
