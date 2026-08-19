import 'package:flutter_test/flutter_test.dart';
import 'package:nostr_sdk/relay/publish_outcome.dart';
import 'package:openvine/utils/relay_rejection_classifier.dart';

void main() {
  test('recognizes only explicit account-level relay restrictions', () {
    expect(isAccountRestrictedReason('blocked: pubkey is suspended'), isTrue);
    expect(isAccountRestrictedReason('BLOCKED: PUBKEY IS BANNED'), isTrue);
    expect(isAccountRestrictedReason('blocked: policy'), isFalse);
    expect(isAccountRestrictedReason('blocked: missing required tag'), isFalse);
    // Near-misses: the match is exact, so a reason that merely contains or
    // extends the restriction wording must not classify as a restriction.
    // These pin the exact-match boundary against a `contains`/`startsWith`
    // loosening.
    expect(isAccountRestrictedReason('blocked: pubkey is suspended.'), isFalse);
    expect(
      isAccountRestrictedReason('blocked: pubkey is suspended for 24h'),
      isFalse,
    );
    expect(isAccountRestrictedReason('blocked: pubkey is not banned'), isFalse);
  });

  test('requires the trusted relay to report an account restriction', () {
    const restricted = PublishOutcome(
      eventId: 'event',
      acceptedBy: [],
      rejectedBy: {
        'wss://relay.divine.video/': 'blocked: pubkey is suspended',
        'wss://third-party.example': 'blocked: policy',
      },
      noResponseFrom: ['wss://silent.example'],
    );
    const untrustedRestriction = PublishOutcome(
      eventId: 'event',
      acceptedBy: [],
      rejectedBy: {'wss://third-party.example': 'blocked: pubkey is suspended'},
      noResponseFrom: ['wss://relay.divine.video'],
    );

    expect(
      isAccountRestrictedOutcome(
        restricted,
        trustedRelayUrl: 'wss://relay.divine.video',
      ),
      isTrue,
    );
    expect(
      isAccountRestrictedOutcome(
        untrustedRestriction,
        trustedRelayUrl: 'wss://relay.divine.video',
      ),
      isFalse,
    );
  });

  test('an acceptance prevents an account restriction verdict', () {
    const outcome = PublishOutcome(
      eventId: 'event',
      acceptedBy: ['wss://third-party.example'],
      rejectedBy: {'wss://relay.divine.video': 'blocked: pubkey is banned'},
      noResponseFrom: [],
    );

    expect(
      isAccountRestrictedOutcome(
        outcome,
        trustedRelayUrl: 'wss://relay.divine.video',
      ),
      isFalse,
    );
  });

  test('recognizes rate limits only when no relay accepted', () {
    const rateLimited = PublishOutcome(
      eventId: 'event',
      acceptedBy: [],
      rejectedBy: {
        'wss://one.example': '  RATE-LIMITED: slow down  ',
        'wss://two.example': 'blocked: policy',
      },
      noResponseFrom: [],
    );
    const partlyAccepted = PublishOutcome(
      eventId: 'event',
      acceptedBy: ['wss://accepted.example'],
      rejectedBy: {'wss://one.example': 'rate-limited: slow down'},
      noResponseFrom: [],
    );
    const unrelated = PublishOutcome(
      eventId: 'event',
      acceptedBy: [],
      rejectedBy: {'wss://one.example': 'blocked: policy'},
      noResponseFrom: [],
    );

    expect(isRateLimitedOutcome(rateLimited), isTrue);
    expect(isRateLimitedOutcome(partlyAccepted), isFalse);
    expect(isRateLimitedOutcome(unrelated), isFalse);
  });
}
