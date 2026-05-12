import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:nostr_sdk/nip19/nip19.dart';
import 'package:nostr_sdk/nip19/nip19_tlv.dart';
import 'package:openvine/utils/nostr_key_utils.dart';
import 'package:openvine/widgets/linkified_text/linkified_text_span_builder.dart';

void main() {
  group(LinkifiedTextSpanBuilder, () {
    const defaultStyle = TextStyle(color: Colors.white);
    const linkStyle = TextStyle(color: Colors.green);
    const mentionStyle = TextStyle(color: Colors.blue);

    test('returns one plain span when text has no link tokens', () {
      final spans = const LinkifiedTextSpanBuilder(
        text: 'plain bio text',
        defaultStyle: defaultStyle,
        linkStyle: linkStyle,
      ).build();

      expect(spans, hasLength(1));
      expect(spans.single.text, equals('plain bio text'));
      expect(spans.single.style, equals(defaultStyle));
      expect(spans.single.recognizer, isNull);
    });

    test('creates tappable spans for bare domains and emails', () {
      final tappedUrls = <String>[];
      final spans = LinkifiedTextSpanBuilder(
        text: 'violetblue.com + hi@example.com',
        defaultStyle: defaultStyle,
        linkStyle: linkStyle,
        onUrlTap: (rawUrl) async => tappedUrls.add(rawUrl),
      ).build();

      final tappable = spans.tappableSpans;
      expect(
        tappable.map((span) => span.text),
        equals(['violetblue.com', 'hi@example.com']),
      );

      tappable.first.tap();
      tappable.last.tap();
      expect(tappedUrls, equals(['violetblue.com', 'hi@example.com']));
    });

    test('keeps trailing punctuation outside URL spans', () {
      final spans = const LinkifiedTextSpanBuilder(
        text: 'Visit violetblue.com.! More: https://example.com/path?:;',
        defaultStyle: defaultStyle,
        linkStyle: linkStyle,
      ).build();

      expect(
        spans.map((span) => span.text).join(),
        equals('Visit violetblue.com.! More: https://example.com/path?:;'),
      );
      expect(
        spans.tappableSpans.map((span) => span.text),
        equals(['violetblue.com', 'https://example.com/path']),
      );
      expect(spans[2].text, startsWith('.!'));
      expect(spans.last.text, equals('?:;'));
      expect(spans[2].recognizer, isNull);
      expect(spans.last.recognizer, isNull);
    });

    test('preserves token precedence across supported token types', () {
      const profileHex =
          'aaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaaa';
      const videoHex =
          'bbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbbb';
      final npub = NostrKeyUtils.encodePubKey(profileHex);
      final tapped = <String>[];

      final spans = LinkifiedTextSpanBuilder(
        text: [
          'hi@example.com',
          '#tag',
          npub,
          'clip $videoHex',
          '@alice',
        ].join(' '),
        defaultStyle: defaultStyle,
        linkStyle: linkStyle,
        mentionStyle: mentionStyle,
        profileLabelForHex: (hexPubkey) => 'profile-$hexPubkey',
        videoLabel: 'View video',
        onUrlTap: (rawUrl) async => tapped.add('url:$rawUrl'),
        onHashtagTap: (hashtag) => tapped.add('hashtag:$hashtag'),
        onProfileTap: (hexPubkey) => tapped.add('profile:$hexPubkey'),
        onVideoTap: (routeReference) => tapped.add('video:$routeReference'),
        onMentionTap: (username) => tapped.add('mention:$username'),
      ).build();

      final tappable = spans.tappableSpans;
      expect(
        tappable.map((span) => span.text),
        equals([
          'hi@example.com',
          '#tag',
          '@profile-$profileHex',
          'View video',
          '@alice',
        ]),
      );
      expect(
        tappable.map((span) => span.style),
        equals([linkStyle, linkStyle, mentionStyle, linkStyle, mentionStyle]),
      );

      for (final span in tappable) {
        span.tap();
      }

      expect(
        tapped,
        equals([
          'url:hi@example.com',
          'hashtag:tag',
          'profile:$profileHex',
          'video:$videoHex',
          'mention:alice',
        ]),
      );
    });

    test('routes note1 references to normalized event ids', () {
      const eventId =
          '1111111111111111111111111111111111111111111111111111111111111111';
      final note = Nip19.encodeNoteId(eventId);
      String? tappedVideo;

      final spans = LinkifiedTextSpanBuilder(
        text: 'Watch $note',
        defaultStyle: defaultStyle,
        linkStyle: linkStyle,
        videoLabel: 'View video',
        onVideoTap: (routeReference) => tappedVideo = routeReference,
      ).build();

      final videoSpan = spans.tappableSpans.single;
      expect(videoSpan.text, equals('View video'));
      videoSpan.tap();
      expect(tappedVideo, equals(eventId));
    });

    test('routes nevent references to normalized event ids', () {
      const eventId =
          '2222222222222222222222222222222222222222222222222222222222222222';
      final nevent = NIP19Tlv.encodeNevent(Nevent(id: eventId));
      String? tappedVideo;

      final spans = LinkifiedTextSpanBuilder(
        text: 'Watch $nevent',
        defaultStyle: defaultStyle,
        linkStyle: linkStyle,
        videoLabel: 'View video',
        onVideoTap: (routeReference) => tappedVideo = routeReference,
      ).build();

      final videoSpan = spans.tappableSpans.single;
      expect(videoSpan.text, equals('View video'));
      videoSpan.tap();
      expect(tappedVideo, equals(eventId));
    });

    test('routes naddr references with the original normalized reference', () {
      const authorHex =
          '3333333333333333333333333333333333333333333333333333333333333333';
      final naddr = NIP19Tlv.encodeNaddr(
        Naddr(id: 'stable-video', author: authorHex, kind: 34236),
      );
      String? tappedVideo;

      final spans = LinkifiedTextSpanBuilder(
        text: 'Watch nostr:$naddr',
        defaultStyle: defaultStyle,
        linkStyle: linkStyle,
        videoLabel: 'View video',
        onVideoTap: (routeReference) => tappedVideo = routeReference,
      ).build();

      final videoSpan = spans.tappableSpans.single;
      expect(videoSpan.text, equals('View video'));
      videoSpan.tap();
      expect(tappedVideo, equals(naddr));
    });

    test('keeps malformed event references tappable without crashing', () {
      const malformedNote = 'note1notavalidevent';
      const malformedNevent = 'nevent1notavalidevent';
      final tapped = <String>[];

      final spans = LinkifiedTextSpanBuilder(
        text: '$malformedNote nostr:$malformedNevent',
        defaultStyle: defaultStyle,
        linkStyle: linkStyle,
        videoLabel: 'View video',
        onVideoTap: tapped.add,
      ).build();

      final tappable = spans.tappableSpans;
      expect(
        tappable.map((span) => span.text),
        equals(['View video', 'View video']),
      );

      for (final span in tappable) {
        span.tap();
      }

      expect(tapped, equals([malformedNote, malformedNevent]));
    });

    test('routes profile-like hex references to profile taps', () {
      const profileHex =
          'cccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccccc';
      String? tappedProfile;

      final spans = LinkifiedTextSpanBuilder(
        text: 'author: $profileHex',
        defaultStyle: defaultStyle,
        linkStyle: linkStyle,
        mentionStyle: mentionStyle,
        profileLabelForHex: (_) => 'casey',
        onProfileTap: (hexPubkey) => tappedProfile = hexPubkey,
      ).build();

      final profileSpan = spans.tappableSpans.single;
      expect(profileSpan.text, equals('@casey'));
      profileSpan.tap();
      expect(tappedProfile, equals(profileHex));
    });

    test('leaves invalid profile Nostr IDs plain and unchanged', () {
      const invalidNpub = 'npub1invalidprofile';

      final spans = const LinkifiedTextSpanBuilder(
        text: invalidNpub,
        defaultStyle: defaultStyle,
        linkStyle: linkStyle,
      ).build();

      expect(spans, hasLength(1));
      expect(spans.single.text, equals(invalidNpub));
      expect(spans.single.style, equals(linkStyle));
      expect(spans.single.recognizer, isNull);
    });
  });
}

extension on List<TextSpan> {
  List<TextSpan> get tappableSpans =>
      where((span) => span.recognizer is TapGestureRecognizer).toList();
}

extension on TextSpan {
  void tap() {
    (recognizer! as TapGestureRecognizer).onTap!();
  }
}
