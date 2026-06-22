import 'package:models/models.dart';
import 'package:test/test.dart';

const allowedClassicPubkey =
    'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
const otherPubkey =
    'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';

void main() {
  group('VideoServingPolicy', () {
    const policy = VideoServingPolicy(
      allowedClassicVinePubkeys: {allowedClassicPubkey},
    );

    test('allows certified mobile ProofMode videos', () {
      final video = _video(
        pubkey: otherPubkey,
        rawTags: const {'verification': 'verified_mobile'},
      );

      expect(policy.allows(video), isTrue);
      expect(policy.isAllowedProofModeVideo(video), isTrue);
    });

    test('allows certified web ProofMode videos', () {
      final video = _video(
        pubkey: otherPubkey,
        rawTags: const {'verification': 'verified_web'},
      );

      expect(policy.allows(video), isTrue);
      expect(policy.isAllowedProofModeVideo(video), isTrue);
    });

    test('rejects basic proof when certification is required', () {
      final video = _video(
        pubkey: otherPubkey,
        rawTags: const {'verification': 'basic_proof'},
      );

      expect(video.hasBasicProof, isTrue);
      expect(policy.allows(video), isFalse);
    });

    test('allows basic proof when configured for any proof', () {
      const anyProofPolicy = VideoServingPolicy(
        allowedClassicVinePubkeys: {},
        proofModeLevel: ProofModeServingLevel.anyProof,
      );
      final video = _video(
        pubkey: otherPubkey,
        rawTags: const {'verification': 'basic_proof'},
      );

      expect(anyProofPolicy.allows(video), isTrue);
    });

    test('allows recovered classic Vines from curated accounts', () {
      final video = _video(
        pubkey: allowedClassicPubkey.toUpperCase(),
        rawTags: const {'platform': 'vine'},
      );

      expect(video.isOriginalVine, isTrue);
      expect(policy.allows(video), isTrue);
      expect(policy.isAllowedClassicVine(video), isTrue);
    });

    test('rejects recovered classic Vines from non-curated accounts', () {
      final video = _video(
        pubkey: otherPubkey,
        rawTags: const {'platform': 'vine'},
      );

      expect(video.isOriginalVine, isTrue);
      expect(policy.allows(video), isFalse);
    });

    test('rejects unverified non-classic videos', () {
      expect(policy.allows(_video(pubkey: otherPubkey)), isFalse);
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
