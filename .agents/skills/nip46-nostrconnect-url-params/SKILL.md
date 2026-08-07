---
name: nip46-nostrconnect-url-params
description: |
  Fix NIP-46 nostrconnect:// URLs not being recognized by signer apps (Amber, nsec.app, nsecBunker).
  Use when: (1) QR code or URL paste fails in signer app despite valid-looking URL, (2) Using
  metadata JSON object instead of separate query params, (3) Implementing client-initiated NIP-46
  connections. The NIP-46 spec requires name/url/image as separate query parameters, not a metadata
  JSON object.
author: Claude Code
version: 1.0.0
date: 2026-02-01
---

# NIP-46 nostrconnect:// URL Parameter Format

## Problem
When implementing NIP-46 client-initiated connections (nostrconnect://), signer apps may fail
to recognize the URL if app metadata is passed as a JSON object instead of separate query
parameters.

## Context / Trigger Conditions
- Signer app (Amber, nsec.app, nsecBunker) shows error or fails silently when scanning/pasting URL
- URL contains `metadata={"name":"...","url":"..."}` format
- QR code generates successfully but signer doesn't connect
- Other parameters (relay, secret, perms) appear correct

## Solution

### Wrong (metadata JSON object):
```
nostrconnect://<pubkey>?relay=wss://relay.example.com&secret=abc123&metadata={"name":"MyApp","url":"https://myapp.com","icon":"https://myapp.com/icon.png"}&perms=sign_event
```

### Correct (separate parameters per NIP-46):
```
nostrconnect://<pubkey>?relay=wss://relay.example.com&secret=abc123&name=MyApp&url=https://myapp.com&image=https://myapp.com/icon.png&perms=sign_event
```

### Code fix example (Dart):
```dart
// WRONG - Don't bundle in metadata JSON
if (metadata.isNotEmpty) {
  final metadataJson = jsonEncode(metadata);
  params.add('metadata=${Uri.encodeComponent(metadataJson)}');
}

// CORRECT - Use separate params as specified in NIP-46
if (appName != null && appName.isNotEmpty) {
  params.add('name=${Uri.encodeComponent(appName)}');
}
if (appUrl != null && appUrl.isNotEmpty) {
  params.add('url=${Uri.encodeComponent(appUrl)}');
}
if (appIcon != null && appIcon.isNotEmpty) {
  params.add('image=${Uri.encodeComponent(appIcon)}');
}
```

## Verification
1. Generate a nostrconnect:// URL
2. Verify URL contains `name=`, `url=`, `image=` as separate params (not `metadata=`)
3. Test with signer app (Amber Android, nsec.app web, or nsecBunker)
4. Signer should show app name and prompt for approval

## NIP-46 Spec Reference

From NIP-46:
> Additional information should be passed as query parameters:
> - `name` (optional) - the name of the _client_ application
> - `url` (optional) - the canonical url of the _client_ application
> - `image` (optional) - a small image representing the _client_ application

The spec does NOT mention a `metadata` parameter - each field is a separate query param.

## Notes
- All query parameter values should be URL-encoded
- The `relay` parameter can appear multiple times for multiple relays
- The `secret` parameter is REQUIRED for nostrconnect:// (not optional like bunker://)
- Some signer apps may be more lenient than others - always follow spec exactly
- Note the param is `image`, not `icon` (easy to confuse with the metadata field name)

## References
- [NIP-46 Nostr Remote Signing](https://github.com/nostr-protocol/nips/blob/master/46.md)
