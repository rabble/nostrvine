// ABOUTME: Tests that a pasted post link becomes the handle and bare id the
// ABOUTME: verifier rebuilds its lookup URL from.

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/blocs/verify/verify_proof_input.dart';

VerifyProofInput _normalize(
  String platform, {
  String identity = '',
  String proof = '',
}) => normalizeVerifyProof(
  platform: platform,
  identity: identity,
  proof: proof,
);

void main() {
  group('normalizeVerifyProof', () {
    test('splits a gist link into owner and gist id', () {
      final input = _normalize(
        'github',
        proof: 'https://gist.github.com/octocat/abc123',
      );

      expect(input.identity, equals('octocat'));
      expect(input.proof, equals('abc123'));
    });

    test('splits a tweet link into handle and status id', () {
      final input = _normalize(
        'twitter',
        proof: 'https://x.com/jack/status/1234567890',
      );

      expect(input.identity, equals('jack'));
      expect(input.proof, equals('1234567890'));
    });

    test('accepts a twitter.com link too', () {
      final input = _normalize(
        'twitter',
        proof: 'https://twitter.com/jack/status/99',
      );

      expect(input.proof, equals('99'));
    });

    test('splits a bluesky post link', () {
      final input = _normalize(
        'bluesky',
        proof: 'https://bsky.app/profile/alice.bsky.social/post/3kabc',
      );

      expect(input.identity, equals('alice.bsky.social'));
      expect(input.proof, equals('3kabc'));
    });

    test('splits a mastodon status link into instance-qualified handle', () {
      final input = _normalize(
        'mastodon',
        proof: 'https://mastodon.social/@alice/110123',
      );

      expect(input.identity, equals('mastodon.social/@alice'));
      expect(input.proof, equals('110123'));
    });

    test('handles the mastodon /users/ status shape', () {
      final input = _normalize(
        'mastodon',
        proof: 'https://mastodon.social/users/alice/statuses/110123',
      );

      expect(input.identity, equals('mastodon.social/@alice'));
      expect(input.proof, equals('110123'));
    });

    test('keeps the telegram channel in the proof, as the verifier wants', () {
      final input = _normalize('telegram', proof: 'https://t.me/mychannel/42');

      expect(input.identity, equals('mychannel'));
      expect(input.proof, equals('mychannel/42'));
      expect(input.problem, isNull);
    });

    test('strips the /s/ preview prefix off a telegram link', () {
      final input = _normalize(
        'telegram',
        proof: 'https://t.me/s/mychannel/42',
      );

      expect(input.identity, equals('mychannel'));
      expect(input.proof, equals('mychannel/42'));
      expect(input.problem, isNull);
    });

    test('flags a private telegram channel link', () {
      // What Telegram hands you for a channel with no public link — which is
      // every channel right after you create one.
      final input = _normalize(
        'telegram',
        proof: 'https://t.me/c/2812345678/42',
      );

      expect(input.problem, equals(VerifyProofProblem.telegramNotPublic));
    });

    test('flags telegram invite links', () {
      expect(
        _normalize('telegram', proof: 'https://t.me/+AbCdEfGh').problem,
        equals(VerifyProofProblem.telegramNotPublic),
      );
      expect(
        _normalize('telegram', proof: 'https://t.me/joinchat/AbCdEfGh').problem,
        equals(VerifyProofProblem.telegramNotPublic),
      );
    });

    test('flags a private telegram link pasted into the handle field', () {
      final input = _normalize(
        'telegram',
        identity: 'https://t.me/c/2812345678/42',
      );

      expect(input.problem, equals(VerifyProofProblem.telegramNotPublic));
    });

    test('pulls the video id out of a youtube link', () {
      expect(
        _normalize(
          'youtube',
          proof: 'https://www.youtube.com/watch?v=abc123',
        ).proof,
        equals('abc123'),
      );
      expect(
        _normalize('youtube', proof: 'https://youtu.be/abc123').proof,
        equals('abc123'),
      );
      expect(
        _normalize('youtube', proof: 'https://youtube.com/shorts/abc123').proof,
        equals('abc123'),
      );
    });

    test('splits a tiktok video link', () {
      final input = _normalize(
        'tiktok',
        proof: 'https://www.tiktok.com/@someone/video/7123',
      );

      expect(input.identity, equals('someone'));
      expect(input.proof, equals('7123'));
    });

    test('accepts a link pasted without its scheme', () {
      final input = _normalize('twitter', proof: 'x.com/jack/status/5');

      expect(input.identity, equals('jack'));
      expect(input.proof, equals('5'));
    });

    test('keeps a handle the user typed over the one in the link', () {
      final input = _normalize(
        'twitter',
        identity: 'realjack',
        proof: 'https://x.com/jack/status/5',
      );

      expect(input.identity, equals('realjack'));
      expect(input.proof, equals('5'));
    });

    test('reads a link pasted into the handle field', () {
      final input = _normalize(
        'github',
        identity: 'https://gist.github.com/octocat/abc123',
      );

      expect(input.identity, equals('octocat'));
      expect(input.proof, equals('abc123'));
    });

    test('leaves a bare id alone', () {
      final input = _normalize('twitter', identity: 'jack', proof: '1234');

      expect(input.identity, equals('jack'));
      expect(input.proof, equals('1234'));
    });

    test('leaves discord links intact — its verifier parses them itself', () {
      const url = 'https://discord.com/channels/1/2/3';
      final input = _normalize('discord', identity: 'alice', proof: url);

      expect(input.identity, equals('alice'));
      expect(input.proof, equals(url));
    });

    test('leaves an unrecognised link alone rather than guessing', () {
      const url = 'https://example.com/whatever';
      final input = _normalize('twitter', identity: 'jack', proof: url);

      expect(input.proof, equals(url));
    });

    test('drops a typed @ from the handle', () {
      // Verifiers compare against the author the platform reports, which never
      // carries the @ — a typed one fails as "author does not match".
      final input = _normalize(
        'telegram',
        identity: '@testdivine',
        proof: 'https://t.me/testdivine/2',
      );

      expect(input.identity, equals('testdivine'));
      expect(input.proof, equals('testdivine/2'));
    });

    test('keeps the @ in a mastodon handle, where it is structural', () {
      final input = _normalize(
        'mastodon',
        identity: 'mastodon.social/@alice',
        proof: '110123',
      );

      expect(input.identity, equals('mastodon.social/@alice'));
    });

    test('trims whitespace', () {
      final input = _normalize(
        'github',
        identity: '  octocat ',
        proof: ' abc ',
      );

      expect(input.identity, equals('octocat'));
      expect(input.proof, equals('abc'));
    });

    test('compares by value', () {
      const a = VerifyProofInput(identity: 'jack', proof: '1');
      const b = VerifyProofInput(identity: 'jack', proof: '1');
      const flagged = VerifyProofInput(
        identity: 'jack',
        proof: '1',
        problem: VerifyProofProblem.telegramNotPublic,
      );

      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
      expect(a, isNot(equals(flagged)));
      expect(a.toString(), contains('jack'));
    });
  });
}
