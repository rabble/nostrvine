import 'package:flutter_test/flutter_test.dart';
import 'package:nostr_sdk/relay/publish_outcome.dart';
import 'package:openvine/utils/relay_rejection_classifier.dart';

void main() {
  test('recognizes only explicit account-level relay restrictions', () {
    expect(isAccountRestrictedReason('blocked: pubkey is suspended'), isTrue);
    expect(isAccountRestrictedReason('BLOCKED: PUBKEY IS BANNED'), isTrue);
    expect(isAccountRestrictedReason('blocked: policy'), isFalse);
    expect(isAccountRestrictedReason('blocked: missing required tag'), isFalse);
  });

  test('requires every relay rejection to be an account restriction', () {
    const restricted = PublishOutcome(
      eventId: 'event',
      acceptedBy: [],
      rejectedBy: {
        'wss://one.example': 'blocked: pubkey is suspended',
        'wss://two.example': 'blocked: pubkey is banned',
      },
      noResponseFrom: [],
    );
    const mixed = PublishOutcome(
      eventId: 'event',
      acceptedBy: [],
      rejectedBy: {
        'wss://one.example': 'blocked: pubkey is suspended',
        'wss://two.example': 'blocked: policy',
      },
      noResponseFrom: [],
    );

    expect(isAccountRestrictedOutcome(restricted), isTrue);
    expect(isAccountRestrictedOutcome(mixed), isFalse);
  });
}
