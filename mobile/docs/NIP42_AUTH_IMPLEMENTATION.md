# NIP-42 Authentication Implementation Required

## Problem
The vine.hol.is relay requires NIP-42 authentication, but the current nostr_sdk doesn't implement it. This is causing profile updates and other events to fail.

## What is NIP-42?
NIP-42 defines authentication for Nostr relays. When a relay requires authentication:

1. **Relay sends AUTH challenge**: `["AUTH", <challenge-string>]`
2. **Client responds with signed event**: Kind 22242 event with the challenge
3. **Relay validates** the signature and grants access

## Current State
- The SDK has placeholders (`relayStatus.authed`, `pendingAuthedMessages`) but no implementation
- Events are being broadcast but not retrieved (likely due to missing AUTH)
- The relay logs show `authed=true` but this might be incorrect

## Implementation Needed

### 1. Handle AUTH Challenge in Relay/RelayBase
```dart
// In onMessage handler
if (message[0] == "AUTH") {
  final challenge = message[1] as String;
  await _handleAuthChallenge(challenge);
}
```

### 2. Create and Sign AUTH Event
```dart
Future<void> _handleAuthChallenge(String challenge) async {
  final authEvent = Event(
    publicKey,
    22242, // NIP-42 AUTH event kind
    [
      ["relay", url],
      ["challenge", challenge]
    ],
    "",
    createdAt: NostrTimestamp.now(), // Use our timestamp utility
  );
  
  authEvent.sign(privateKey);
  
  // Send AUTH response
  send(["AUTH", authEvent.toJson()]);
}
```

### 3. Update NostrService to Ensure AUTH
```dart
// After connecting to relay, wait for AUTH to complete
await relay.waitForAuth(timeout: Duration(seconds: 10));
```

## Temporary Workaround
Until NIP-42 is implemented in the SDK, consider:
1. Using a different Nostr client library that supports NIP-42
2. Implementing a custom relay connection handler
3. Using a relay that doesn't require authentication (not recommended)

## Testing
Once implemented, test with:
1. Connect to vine.hol.is
2. Verify AUTH challenge is received
3. Verify AUTH response is sent
4. Verify events can be both sent AND retrieved

## References
- [NIP-42 Specification](https://github.com/nostr-protocol/nips/blob/master/42.md)
- [Example Implementation](https://github.com/nbd-wtf/nostr-tools/blob/master/nip42.ts)