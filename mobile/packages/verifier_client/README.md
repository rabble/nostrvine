# verifier_client

HTTP client for the Divine identity verification service at
`https://verifyer.divine.video`.

This is a thin Dart client. It has no Nostr knowledge and no BLoC knowledge —
upper layers (`profile_repository`'s `IdentityClaimsRepository`, the profile
BLoCs, and the UI) compose it with their own logic.

## Usage

```dart
final client = VerifierClient();
final results = await client.verifyBatch([
  IdentityClaim(
    pubkey: pubkey,
    platform: 'github',
    identity: 'octocat',
    proof: 'https://gist.github.com/octocat/...',
  ),
]);
```
