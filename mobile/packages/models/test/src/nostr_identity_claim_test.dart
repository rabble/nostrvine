import 'package:models/src/identity_platform.dart';
import 'package:models/src/nostr_identity_claim.dart';
import 'package:test/test.dart';

void main() {
  group(NostrIdentityClaim, () {
    group('fromTag', () {
      test('parses github tag', () {
        final claim = NostrIdentityClaim.fromTag(
          const ['i', 'github:rabble', 'https://gist.github.com/abc'],
        );
        expect(claim, isNotNull);
        expect(claim!.platform, equals(IdentityPlatform.github));
        expect(claim.identity, equals('rabble'));
        expect(claim.proof, equals('https://gist.github.com/abc'));
      });

      test('parses bluesky tag with dotted identity', () {
        final claim = NostrIdentityClaim.fromTag(
          const [
            'i',
            'bluesky:rabble.bsky.social',
            'at://did:plc:xxx/app.bsky.feed.post/yyy',
          ],
        );
        expect(claim!.identity, equals('rabble.bsky.social'));
      });

      test('returns null for non-i tag', () {
        expect(NostrIdentityClaim.fromTag(const ['p', 'pubkey']), isNull);
      });

      test('returns null for short tag', () {
        expect(NostrIdentityClaim.fromTag(const ['i']), isNull);
      });

      test('returns null for unknown platform', () {
        expect(
          NostrIdentityClaim.fromTag(
            const ['i', 'myspace:rabble', 'proof'],
          ),
          isNull,
        );
      });

      test('returns null for malformed value (no colon)', () {
        expect(
          NostrIdentityClaim.fromTag(const ['i', 'rabble', 'proof']),
          isNull,
        );
      });

      test('returns null when identity portion is empty', () {
        expect(
          NostrIdentityClaim.fromTag(const ['i', 'github:', 'proof']),
          isNull,
        );
      });

      test('proof defaults to empty string when missing', () {
        final claim = NostrIdentityClaim.fromTag(const ['i', 'github:rabble']);
        expect(claim, isNotNull);
        expect(claim!.proof, equals(''));
      });
    });

    group('toTag', () {
      test('serialises platform, identity, and proof', () {
        const claim = NostrIdentityClaim(
          platform: IdentityPlatform.github,
          identity: 'rabble',
          proof: 'https://gist.github.com/abc',
        );
        expect(
          claim.toTag(),
          equals(const ['i', 'github:rabble', 'https://gist.github.com/abc']),
        );
      });

      test('emits an empty proof slot when no proof is set', () {
        const claim = NostrIdentityClaim(
          platform: IdentityPlatform.mastodon,
          identity: 'rabble@mastodon.social',
          proof: '',
        );
        expect(
          claim.toTag(),
          equals(const ['i', 'mastodon:rabble@mastodon.social', '']),
        );
      });

      test('round-trips with fromTag', () {
        const original = NostrIdentityClaim(
          platform: IdentityPlatform.bluesky,
          identity: 'rabble.bsky.social',
          proof: 'at://did:plc:xxx/app.bsky.feed.post/yyy',
        );
        final reparsed = NostrIdentityClaim.fromTag(original.toTag());
        expect(reparsed, equals(original));
      });
    });

    test('is value-equal', () {
      const a = NostrIdentityClaim(
        platform: IdentityPlatform.github,
        identity: 'rabble',
        proof: 'p',
      );
      const b = NostrIdentityClaim(
        platform: IdentityPlatform.github,
        identity: 'rabble',
        proof: 'p',
      );
      expect(a, equals(b));
      expect(a.hashCode, equals(b.hashCode));
    });
  });
}
