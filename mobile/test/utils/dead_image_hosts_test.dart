// ABOUTME: Unit tests for the known-dead image host predicate.
// ABOUTME: Pins the exact host match — no over-blocking of sibling subdomains.

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/utils/dead_image_hosts.dart';

void main() {
  group(isKnownDeadImageHost, () {
    test('matches v.cdn.vine.co under both schemes', () {
      expect(
        isKnownDeadImageHost('http://v.cdn.vine.co/v/avatars/x.jpg'),
        isTrue,
      );
      expect(
        isKnownDeadImageHost('https://v.cdn.vine.co/v/avatars/x.jpg'),
        isTrue,
      );
    });

    test('matches case-insensitively', () {
      expect(isKnownDeadImageHost('HTTP://V.CDN.VINE.CO/v/x.jpg'), isTrue);
    });

    test('does not match unverified sibling subdomains', () {
      // mt.cdn.vine.co is unverified content-wise; only extend with evidence.
      expect(
        isKnownDeadImageHost('https://mt.cdn.vine.co/v/thumb.jpg'),
        isFalse,
      );
    });

    test('does not match live hosts', () {
      expect(
        isKnownDeadImageHost('https://blossom.example.com/x.jpg'),
        isFalse,
      );
    });

    test('does not throw on malformed input', () {
      expect(isKnownDeadImageHost('not a url'), isFalse);
      expect(isKnownDeadImageHost(''), isFalse);
    });
  });

  group(isUsableNetworkImageUrl, () {
    test('accepts HTTPS URLs with an authority', () {
      expect(
        isUsableNetworkImageUrl('https://images.example/avatar.jpg'),
        isTrue,
      );
      expect(
        isUsableNetworkImageUrl('HTTPS://images.example/avatar.jpg'),
        isTrue,
      );
    });

    test('rejects insecure, malformed, and known-dead URLs', () {
      expect(
        isUsableNetworkImageUrl('http://images.example/avatar.jpg'),
        isFalse,
      );
      expect(isUsableNetworkImageUrl('not a url'), isFalse);
      expect(
        isUsableNetworkImageUrl('https://v.cdn.vine.co/avatar.jpg'),
        isFalse,
      );
    });
  });
}
