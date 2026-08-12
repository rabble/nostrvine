// ABOUTME: Tests the shared VideoEvent blocklist policy for authors and reposters.
// ABOUTME: Prevents feed surfaces from regressing to author-only block checks.

import 'package:content_blocklist_repository/content_blocklist_repository.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/services/video_block_policy.dart';

class _MockBlocklistRepository extends Mock
    implements ContentBlocklistRepository {}

void main() {
  group(VideoBlockPolicy, () {
    late ContentBlocklistRepository blocklistRepository;

    setUp(() {
      blocklistRepository = ContentBlocklistRepository();
    });

    tearDown(() {
      blocklistRepository.dispose();
    });

    test('hides videos from blocked authors', () async {
      const author =
          'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
      await blocklistRepository.blockUser(author);

      expect(
        VideoBlockPolicy.isHiddenByBlocklist(
          _video(pubkey: author),
          blocklistRepository,
        ),
        isTrue,
      );
    });

    test('hides videos from blocked visible reposters', () async {
      const author =
          'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
      const reposter =
          'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
      await blocklistRepository.blockUser(reposter);

      final repost = _video(pubkey: author).copyWith(
        isRepost: true,
        reposterPubkey: reposter,
        reposterPubkeys: [reposter],
      );

      expect(
        VideoBlockPolicy.isHiddenByBlocklist(repost, blocklistRepository),
        isTrue,
      );
    });

    test('hides videos from authors who blocked the viewer', () {
      const author =
          'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
      const reposter =
          'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
      final mock = _MockBlocklistRepository();
      when(() => mock.shouldFilterFromFeeds(author)).thenReturn(true);
      when(() => mock.shouldFilterFromFeeds(reposter)).thenReturn(false);
      when(() => mock.isBlocked(any())).thenReturn(false);
      when(() => mock.isMutedByUs(any())).thenReturn(false);

      expect(
        VideoBlockPolicy.isHiddenByBlocklist(
          _video(pubkey: author),
          mock,
        ),
        isTrue,
      );
    });

    test(
      'does not hide a non-blocked author when a blocked-us account reposted',
      () {
        const author =
            'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
        const reposter =
            'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
        final mock = _MockBlocklistRepository();
        when(() => mock.shouldFilterFromFeeds(author)).thenReturn(false);
        when(() => mock.shouldFilterFromFeeds(reposter)).thenReturn(true);
        when(() => mock.isBlocked(any())).thenReturn(false);
        when(() => mock.isMutedByUs(any())).thenReturn(false);

        final repost = _video(pubkey: author).copyWith(
          isRepost: true,
          reposterPubkey: reposter,
          reposterPubkeys: [reposter],
        );

        expect(VideoBlockPolicy.isHiddenByBlocklist(repost, mock), isFalse);
      },
    );

    test('hides a video when the viewer muted the visible reposter', () {
      const author =
          'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
      const reposter =
          'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
      final mock = _MockBlocklistRepository();
      when(() => mock.shouldFilterFromFeeds(author)).thenReturn(false);
      when(() => mock.shouldFilterFromFeeds(reposter)).thenReturn(true);
      when(() => mock.isBlocked(reposter)).thenReturn(false);
      when(() => mock.isMutedByUs(reposter)).thenReturn(true);
      when(() => mock.isBlocked(author)).thenReturn(false);
      when(() => mock.isMutedByUs(author)).thenReturn(false);

      final repost = _video(pubkey: author).copyWith(
        isRepost: true,
        reposterPubkey: reposter,
        reposterPubkeys: [reposter],
      );

      expect(VideoBlockPolicy.isHiddenByBlocklist(repost, mock), isTrue);
    });
  });
}

VideoEvent _video({required String pubkey}) {
  final now = DateTime(2026);
  return VideoEvent(
    id: 'video-id',
    pubkey: pubkey,
    createdAt: now.millisecondsSinceEpoch ~/ 1000,
    content: '',
    timestamp: now,
    videoUrl: 'https://example.com/video.mp4',
  );
}
