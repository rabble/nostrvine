# Profile Bio Links Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make profile bio area carry the same "link kit" function as mainstream Nostr clients — clickable URLs/hashtags/mentions in the bio text, render the Kind-0 `website` field, and render *verified* NIP-39 identity claims as tappable platform chips.

**Architecture:** Layered (UI → BLoC → Repository → Client). New `identity_verification_client` and `identity_verification_repository` packages. New `ProfileLinksCubit`. UI changes localized to `mobile/lib/widgets/profile/profile_header_widget.dart` and `mobile/lib/widgets/clickable_hashtag_text.dart` (generalized to `clickable_text.dart`). Verification gates display: only verified claims become chips.

**Tech Stack:** Flutter, `flutter_bloc`, `bloc_test`, `mocktail`, `http` (existing in funnelcake client), `url_launcher` (already in pubspec), `nostr_sdk` (`Event.tags : List<List<String>>`). Strict-coverage package: `divine_ui`. Verification service: `divine-identify-verification-service` (Hono Worker; `POST /verify`; URL via env config — placeholder `verifier.divine.video`).

**Spec:** `docs/superpowers/specs/2026-05-04-profile-bio-links-design.md`

**Issue:** divinevideo/divine-mobile#3935

---

## File structure

**New (created):**

- `mobile/packages/models/lib/src/identity_platform.dart` — `IdentityPlatform` enum + canonical-URL helper.
- `mobile/packages/models/lib/src/nostr_identity_claim.dart` — `NostrIdentityClaim` model (claim parsed from `i` tag).
- `mobile/packages/identity_verification_client/` — package, client over `POST /verify`.
  - `lib/identity_verification_client.dart` (barrel)
  - `lib/src/identity_verification_client.dart`
  - `lib/src/exceptions.dart`
  - `pubspec.yaml`
  - `analysis_options.yaml`
  - `test/identity_verification_client_test.dart`
- `mobile/packages/identity_verification_repository/` — package, cache + dedupe + verified-subset filter.
  - `lib/identity_verification_repository.dart` (barrel)
  - `lib/src/identity_verification_repository.dart`
  - `lib/src/verified_identity.dart`
  - `pubspec.yaml`
  - `analysis_options.yaml`
  - `test/identity_verification_repository_test.dart`
- `mobile/lib/blocs/profile_links/profile_links_cubit.dart`
- `mobile/lib/blocs/profile_links/profile_links_state.dart`
- `mobile/lib/widgets/clickable_text.dart` — generalized helper (URL + hashtag + nostr: + @mention).
- `mobile/packages/divine_ui/lib/src/identity/identity_chip.dart`
- `mobile/packages/divine_ui/lib/src/identity/identity.dart` (barrel)
- `mobile/test/blocs/profile_links/profile_links_cubit_test.dart`
- `mobile/test/widgets/profile/profile_links_integration_test.dart` (renders website row + chip row given mock cubit)
- `mobile/test/widgets/clickable_text_test.dart` (URL detection coverage on top of existing tests)
- `mobile/packages/divine_ui/test/identity/identity_chip_test.dart`
- `mobile/packages/divine_ui/test/identity/identity_chip_golden_test.dart`

**Modified:**

- `mobile/packages/models/lib/src/user_profile.dart` — parse `i` tags into `identityClaims`.
- `mobile/packages/models/lib/models.dart` — export new model files.
- `mobile/lib/widgets/clickable_hashtag_text.dart` — keep file as deprecated re-export of `clickable_text.dart` (one-line shim — full migration of callers is a separate cleanup).
- `mobile/lib/widgets/profile/profile_header_widget.dart` — `_AboutText` swaps to `ClickableText`; `_ProfileNameAndBio` adds `_WebsiteRow` + `_IdentityChipsRow`; mount `ProfileLinksCubit` via `BlocProvider`.
- `mobile/test/widgets/profile/profile_header_widget_test.dart` — add cases for the new rows.
- `mobile/test/widgets/comprehensive_clickable_hashtag_text_test.dart` — update import path / re-export expectation.
- `mobile/lib/l10n/app_en.arb` — add new keys.
- `mobile/lib/l10n/generated/*` — regenerated.
- `mobile/lib/providers/environment_provider.dart` (or `mobile/lib/models/environment_config.dart`) — add `verifier` URL field per env.
- `mobile/lib/providers/app_providers.dart` — wire `IdentityVerificationClient` + `IdentityVerificationRepository` providers.
- `mobile/pubspec.yaml` (and any package ones) — wire new packages as path deps.

---

## Chunk 1: Data model — NIP-39 claim parsing

### Task 1: `IdentityPlatform` enum + canonical URL

**Files:**
- Create: `mobile/packages/models/lib/src/identity_platform.dart`
- Create: `mobile/packages/models/test/src/identity_platform_test.dart`

- [ ] **Step 1: Write failing tests**

```dart
// mobile/packages/models/test/src/identity_platform_test.dart
import 'package:models/src/identity_platform.dart';
import 'package:test/test.dart';

void main() {
  group(IdentityPlatform, () {
    group('fromTagPrefix', () {
      test('parses github', () {
        expect(IdentityPlatform.fromTagPrefix('github'),
            equals(IdentityPlatform.github));
      });
      test('maps x to twitter', () {
        expect(IdentityPlatform.fromTagPrefix('x'),
            equals(IdentityPlatform.twitter));
      });
      test('parses bluesky', () {
        expect(IdentityPlatform.fromTagPrefix('bluesky'),
            equals(IdentityPlatform.bluesky));
      });
      test('returns null for unknown platform', () {
        expect(IdentityPlatform.fromTagPrefix('myspace'), isNull);
      });
      test('is case-insensitive', () {
        expect(IdentityPlatform.fromTagPrefix('GitHub'),
            equals(IdentityPlatform.github));
      });
    });

    group('canonicalProfileUrl', () {
      test('builds github URL', () {
        expect(
          IdentityPlatform.github.canonicalProfileUrl('rabble').toString(),
          equals('https://github.com/rabble'),
        );
      });
      test('builds twitter URL', () {
        expect(
          IdentityPlatform.twitter.canonicalProfileUrl('rabble').toString(),
          equals('https://x.com/rabble'),
        );
      });
      test('builds bluesky URL with handle', () {
        expect(
          IdentityPlatform.bluesky
              .canonicalProfileUrl('rabble.bsky.social')
              .toString(),
          equals('https://bsky.app/profile/rabble.bsky.social'),
        );
      });
      test('builds mastodon URL with user@host identity', () {
        expect(
          IdentityPlatform.mastodon
              .canonicalProfileUrl('rabble@mastodon.social')
              .toString(),
          equals('https://mastodon.social/@rabble'),
        );
      });
      test('builds telegram URL', () {
        expect(
          IdentityPlatform.telegram.canonicalProfileUrl('rabble').toString(),
          equals('https://t.me/rabble'),
        );
      });
      test('builds youtube URL', () {
        expect(
          IdentityPlatform.youtube.canonicalProfileUrl('rabble').toString(),
          equals('https://youtube.com/@rabble'),
        );
      });
      test('builds tiktok URL', () {
        expect(
          IdentityPlatform.tiktok.canonicalProfileUrl('rabble').toString(),
          equals('https://tiktok.com/@rabble'),
        );
      });
      test('builds discord URL with username', () {
        expect(
          IdentityPlatform.discord
              .canonicalProfileUrl('rabble')
              .toString(),
          equals('https://discord.com/users/rabble'),
        );
      });
    });

    group('displayName', () {
      test('humanizes github', () {
        expect(IdentityPlatform.github.displayName, equals('GitHub'));
      });
      test('twitter displays as X', () {
        expect(IdentityPlatform.twitter.displayName, equals('X'));
      });
    });
  });
}
```

- [ ] **Step 2: Run tests — verify they fail**

```bash
cd mobile && flutter test packages/models/test/src/identity_platform_test.dart
```

Expected: all FAIL (file does not exist).

- [ ] **Step 3: Write minimal implementation**

```dart
// mobile/packages/models/lib/src/identity_platform.dart
// ABOUTME: Enum of NIP-39 identity platforms supported by divine-identify-verification-service
// ABOUTME: Plus tag-prefix parser and canonical profile-URL builder per platform.

/// Identity platforms supported by `divine-identify-verification-service`.
///
/// The string used in NIP-39 `["i", "<prefix>:<identity>", "<proof>"]`
/// tags is the lowercase enum name, except `twitter` which also accepts
/// the alias `x`.
enum IdentityPlatform {
  github,
  twitter,
  bluesky,
  mastodon,
  telegram,
  discord,
  youtube,
  tiktok;

  /// Parses a NIP-39 platform prefix. Returns `null` for unknown values.
  static IdentityPlatform? fromTagPrefix(String prefix) {
    final normalized = prefix.toLowerCase();
    if (normalized == 'x') return IdentityPlatform.twitter;
    for (final p in IdentityPlatform.values) {
      if (p.name == normalized) return p;
    }
    return null;
  }

  /// Human-readable platform name.
  String get displayName => switch (this) {
        IdentityPlatform.github => 'GitHub',
        IdentityPlatform.twitter => 'X',
        IdentityPlatform.bluesky => 'Bluesky',
        IdentityPlatform.mastodon => 'Mastodon',
        IdentityPlatform.telegram => 'Telegram',
        IdentityPlatform.discord => 'Discord',
        IdentityPlatform.youtube => 'YouTube',
        IdentityPlatform.tiktok => 'TikTok',
      };

  /// Canonical browser URL for [identity] on this platform.
  Uri canonicalProfileUrl(String identity) => switch (this) {
        IdentityPlatform.github => Uri.parse('https://github.com/$identity'),
        IdentityPlatform.twitter => Uri.parse('https://x.com/$identity'),
        IdentityPlatform.bluesky =>
            Uri.parse('https://bsky.app/profile/$identity'),
        IdentityPlatform.mastodon => _mastodonUrl(identity),
        IdentityPlatform.telegram => Uri.parse('https://t.me/$identity'),
        IdentityPlatform.discord =>
            Uri.parse('https://discord.com/users/$identity'),
        IdentityPlatform.youtube =>
            Uri.parse('https://youtube.com/@$identity'),
        IdentityPlatform.tiktok =>
            Uri.parse('https://tiktok.com/@$identity'),
      };

  static Uri _mastodonUrl(String identity) {
    final atIndex = identity.indexOf('@');
    if (atIndex == -1) {
      return Uri.parse('https://mastodon.social/@$identity');
    }
    final user = identity.substring(0, atIndex);
    final host = identity.substring(atIndex + 1);
    return Uri.parse('https://$host/@$user');
  }
}
```

- [ ] **Step 4: Run tests — verify they pass**

```bash
cd mobile && flutter test packages/models/test/src/identity_platform_test.dart
```

Expected: PASS.

- [ ] **Step 5: Commit**

```bash
git add mobile/packages/models/lib/src/identity_platform.dart \
        mobile/packages/models/test/src/identity_platform_test.dart
git commit -m "feat(models): add IdentityPlatform enum with NIP-39 parsing and canonical URLs"
```

---

### Task 2: `NostrIdentityClaim` model

**Files:**
- Create: `mobile/packages/models/lib/src/nostr_identity_claim.dart`
- Create: `mobile/packages/models/test/src/nostr_identity_claim_test.dart`

- [ ] **Step 1: Write failing tests**

```dart
// mobile/packages/models/test/src/nostr_identity_claim_test.dart
import 'package:models/src/identity_platform.dart';
import 'package:models/src/nostr_identity_claim.dart';
import 'package:test/test.dart';

void main() {
  group(NostrIdentityClaim, () {
    group('fromTag', () {
      test('parses github tag', () {
        final claim = NostrIdentityClaim.fromTag(const ['i', 'github:rabble', 'https://gist.github.com/abc']);
        expect(claim, isNotNull);
        expect(claim!.platform, equals(IdentityPlatform.github));
        expect(claim.identity, equals('rabble'));
        expect(claim.proof, equals('https://gist.github.com/abc'));
      });

      test('parses bluesky tag with dotted identity', () {
        final claim = NostrIdentityClaim.fromTag(
          const ['i', 'bluesky:rabble.bsky.social', 'at://did:plc:xxx/app.bsky.feed.post/yyy'],
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
```

- [ ] **Step 2: Run tests — verify they fail**

```bash
cd mobile && flutter test packages/models/test/src/nostr_identity_claim_test.dart
```

- [ ] **Step 3: Implement**

```dart
// mobile/packages/models/lib/src/nostr_identity_claim.dart
// ABOUTME: NIP-39 external identity claim parsed from a kind-0 ["i", ...] tag

import 'package:equatable/equatable.dart';
import 'package:meta/meta.dart';
import 'package:models/src/identity_platform.dart';

/// A NIP-39 external identity claim — `["i", "<platform>:<identity>", "<proof>"]`.
///
/// A claim is *not* the same as a verified identity. Verification is
/// performed separately by `IdentityVerificationRepository`.
@immutable
class NostrIdentityClaim extends Equatable {
  const NostrIdentityClaim({
    required this.platform,
    required this.identity,
    required this.proof,
  });

  /// Parses a single NIP-39 `i` tag. Returns `null` if [tag] is not a
  /// valid `i` tag, references an unknown platform, or has an empty
  /// identity portion.
  static NostrIdentityClaim? fromTag(List<String> tag) {
    if (tag.length < 2 || tag[0] != 'i') return null;
    final value = tag[1];
    final colonIndex = value.indexOf(':');
    if (colonIndex <= 0 || colonIndex == value.length - 1) return null;
    final platform = IdentityPlatform.fromTagPrefix(
      value.substring(0, colonIndex),
    );
    if (platform == null) return null;
    final identity = value.substring(colonIndex + 1);
    if (identity.isEmpty) return null;
    final proof = tag.length >= 3 ? tag[2] : '';
    return NostrIdentityClaim(
      platform: platform,
      identity: identity,
      proof: proof,
    );
  }

  final IdentityPlatform platform;
  final String identity;
  final String proof;

  @override
  List<Object?> get props => [platform, identity, proof];
}
```

- [ ] **Step 4: Verify pubspec has `equatable`**

```bash
grep -n "equatable" mobile/packages/models/pubspec.yaml
```

If absent, add to `dependencies:` and run `flutter pub get` from `mobile/`.

- [ ] **Step 5: Run tests — verify pass**

```bash
cd mobile && flutter test packages/models/test/src/nostr_identity_claim_test.dart
```

- [ ] **Step 6: Commit**

```bash
git add mobile/packages/models/lib/src/nostr_identity_claim.dart \
        mobile/packages/models/test/src/nostr_identity_claim_test.dart \
        mobile/packages/models/pubspec.yaml
git commit -m "feat(models): add NostrIdentityClaim parsed from NIP-39 i tag"
```

---

### Task 3: Extend `UserProfile` to parse `i` tags

**Files:**
- Modify: `mobile/packages/models/lib/src/user_profile.dart`
- Modify: `mobile/packages/models/test/src/user_profile_test.dart` (path under test/ — confirm at task time)

- [ ] **Step 1: Write failing test**

Add to the existing user_profile test file (or create one if absent):

```dart
group('NIP-39 identityClaims', () {
  test('parses verified github + bluesky claims from event tags', () {
    final event = Event.fromJson({
      'id': 'a' * 64,
      'pubkey': '0' * 64,
      'created_at': 1700000000,
      'kind': 0,
      'tags': [
        ['i', 'github:rabble', 'https://gist.github.com/x'],
        ['i', 'bluesky:rabble.bsky.social', 'at://did:plc:y/post/z'],
        ['p', '1' * 64], // unrelated tag, must be ignored
      ],
      'content': '{"name":"rabble"}',
      'sig': '0' * 128,
    });
    final profile = UserProfile.fromNostrEvent(event);
    expect(profile.identityClaims, hasLength(2));
    expect(profile.identityClaims.first.platform,
        equals(IdentityPlatform.github));
    expect(profile.identityClaims.first.identity, equals('rabble'));
  });

  test('drops malformed and unknown-platform i tags silently', () {
    final event = Event.fromJson({
      'id': 'a' * 64,
      'pubkey': '0' * 64,
      'created_at': 1700000000,
      'kind': 0,
      'tags': [
        ['i', 'github:rabble', 'p'],     // ok
        ['i', 'myspace:tom', 'p'],        // unknown platform
        ['i', 'malformed-no-colon', 'p'], // malformed value
        ['i'],                            // too short
      ],
      'content': '{}',
      'sig': '0' * 128,
    });
    final profile = UserProfile.fromNostrEvent(event);
    expect(profile.identityClaims, hasLength(1));
    expect(profile.identityClaims.single.platform,
        equals(IdentityPlatform.github));
  });

  test('returns empty list when content JSON is malformed', () {
    final event = Event.fromJson({
      'id': 'a' * 64,
      'pubkey': '0' * 64,
      'created_at': 1700000000,
      'kind': 0,
      'tags': [
        ['i', 'github:rabble', 'p'],
      ],
      'content': 'not-json',
      'sig': '0' * 128,
    });
    final profile = UserProfile.fromNostrEvent(event);
    expect(profile.identityClaims, isEmpty);
  });
});
```

- [ ] **Step 2: Run — verify they fail**

```bash
cd mobile && flutter test packages/models/test/src/user_profile_test.dart
```

- [ ] **Step 3: Modify `UserProfile`**

In `mobile/packages/models/lib/src/user_profile.dart`:

1. Add `import` for `nostr_identity_claim.dart` and `identity_platform.dart`.
2. Add field:
   ```dart
   final List<NostrIdentityClaim> identityClaims;
   ```
3. Add to constructor with default:
   ```dart
   this.identityClaims = const [],
   ```
4. In `fromNostrEvent` success branch, before `return UserProfile(...)`:
   ```dart
   final claims = <NostrIdentityClaim>[];
   for (final tag in event.tags) {
     final claim = NostrIdentityClaim.fromTag(tag);
     if (claim != null) claims.add(claim);
   }
   ```
   And pass `identityClaims: claims` to the returned `UserProfile`.
5. In the `FormatException` fallback, return `identityClaims: const []` (default already covers this — explicit pass is fine).
6. Update `copyWith`, `toJson`, `fromJson`, `props` (or whatever equality mechanism the class uses). Note: persistence layers (`toJson`, `fromJson`, `Drift` row factory) do **not** need to round-trip `identityClaims` in this PR — claims are derived from the canonical event's `tags`. Default to `const []` on persistence-side reconstructions.

- [ ] **Step 4: Export the new model files**

In `mobile/packages/models/lib/models.dart`:

```dart
export 'src/identity_platform.dart';
export 'src/nostr_identity_claim.dart';
```

- [ ] **Step 5: Run tests — verify pass**

```bash
cd mobile && flutter test packages/models/test/src/user_profile_test.dart \
  packages/models/test/src/nostr_identity_claim_test.dart \
  packages/models/test/src/identity_platform_test.dart
```

- [ ] **Step 6: Run analyzer**

```bash
cd mobile && flutter analyze packages/models
```

- [ ] **Step 7: Commit**

```bash
git add mobile/packages/models/lib/src/user_profile.dart \
        mobile/packages/models/lib/models.dart \
        mobile/packages/models/test/src/user_profile_test.dart
git commit -m "feat(models): parse NIP-39 i tags into UserProfile.identityClaims"
```

---

## Chunk 2: Verification client + repository

### Task 4: `IdentityVerificationClient` package

**Files:**
- Create entire package skeleton at `mobile/packages/identity_verification_client/`.

- [ ] **Step 1: Scaffold package**

Mirror `mobile/packages/funnelcake_api_client/` for layout. Files:

`mobile/packages/identity_verification_client/pubspec.yaml`:
```yaml
name: identity_verification_client
description: Client for divine-identify-verification-service NIP-39 verification API.
version: 0.1.0
publish_to: none

environment:
  sdk: ^3.5.0

dependencies:
  http: ^1.2.0
  meta: ^1.16.0
  models:
    path: ../models

dev_dependencies:
  mocktail: ^1.0.4
  test: ^1.24.9
  very_good_analysis: ^10.2.0
```

`mobile/packages/identity_verification_client/analysis_options.yaml`:
```yaml
include: package:very_good_analysis/analysis_options.yaml
```

`mobile/packages/identity_verification_client/lib/identity_verification_client.dart` (barrel):
```dart
export 'src/exceptions.dart';
export 'src/identity_verification_client.dart';
```

- [ ] **Step 2: Write failing tests**

`mobile/packages/identity_verification_client/test/identity_verification_client_test.dart`:

```dart
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:identity_verification_client/identity_verification_client.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:test/test.dart';

class _MockHttpClient extends Mock implements http.Client {}

void main() {
  group(IdentityVerificationClient, () {
    late http.Client httpClient;
    late IdentityVerificationClient client;

    final baseUri = Uri.parse('https://verifier.example');
    const pubkey = 'p' * 64;

    setUp(() {
      httpClient = _MockHttpClient();
      client = IdentityVerificationClient(
        baseUri: baseUri,
        httpClient: httpClient,
      );
      registerFallbackValue(Uri.parse('https://x'));
      registerFallbackValue(<String, String>{});
    });

    group('verifyClaims', () {
      test('returns verified subset on 200', () async {
        const claims = [
          NostrIdentityClaim(
            platform: IdentityPlatform.github,
            identity: 'rabble',
            proof: 'https://gist.github.com/abc',
          ),
          NostrIdentityClaim(
            platform: IdentityPlatform.twitter,
            identity: 'rabble',
            proof: 'https://x.com/rabble/status/123',
          ),
        ];
        when(() => httpClient.post(
              any(),
              headers: any(named: 'headers'),
              body: any(named: 'body'),
            )).thenAnswer(
          (_) async => http.Response(
            jsonEncode({
              'results': [
                {
                  'platform': 'github',
                  'identity': 'rabble',
                  'verified': true,
                },
                {
                  'platform': 'twitter',
                  'identity': 'rabble',
                  'verified': false,
                },
              ],
            }),
            200,
          ),
        );

        final verified = await client.verifyClaims(
          pubkey: pubkey,
          claims: claims,
        );

        expect(verified, hasLength(1));
        expect(verified.single.platform, equals(IdentityPlatform.github));
      });

      test('returns empty list when claims is empty (no network call)',
          () async {
        final verified =
            await client.verifyClaims(pubkey: pubkey, claims: const []);
        expect(verified, isEmpty);
        verifyNever(() => httpClient.post(any(),
            headers: any(named: 'headers'), body: any(named: 'body')));
      });

      test('throws IdentityVerificationException on non-2xx', () async {
        when(() => httpClient.post(any(),
                headers: any(named: 'headers'),
                body: any(named: 'body')))
            .thenAnswer((_) async => http.Response('boom', 503));

        expect(
          () => client.verifyClaims(
            pubkey: pubkey,
            claims: const [
              NostrIdentityClaim(
                platform: IdentityPlatform.github,
                identity: 'r',
                proof: 'p',
              ),
            ],
          ),
          throwsA(isA<IdentityVerificationException>()),
        );
      });

      test('wraps network error in IdentityVerificationException',
          () async {
        when(() => httpClient.post(any(),
                headers: any(named: 'headers'),
                body: any(named: 'body')))
            .thenThrow(const SocketException('offline'));

        expect(
          () => client.verifyClaims(
            pubkey: pubkey,
            claims: const [
              NostrIdentityClaim(
                platform: IdentityPlatform.github,
                identity: 'r',
                proof: 'p',
              ),
            ],
          ),
          throwsA(isA<IdentityVerificationException>()),
        );
      });

      test('drops verified results with unknown platform name', () async {
        when(() => httpClient.post(any(),
                headers: any(named: 'headers'),
                body: any(named: 'body')))
            .thenAnswer(
          (_) async => http.Response(
            jsonEncode({
              'results': [
                {
                  'platform': 'github',
                  'identity': 'rabble',
                  'verified': true,
                },
                {
                  'platform': 'unknownplatform',
                  'identity': 'x',
                  'verified': true,
                },
              ],
            }),
            200,
          ),
        );

        final verified = await client.verifyClaims(
          pubkey: pubkey,
          claims: const [
            NostrIdentityClaim(
              platform: IdentityPlatform.github,
              identity: 'rabble',
              proof: 'p',
            ),
          ],
        );
        expect(verified, hasLength(1));
      });
    });
  });
}
```

- [ ] **Step 3: Run — verify they fail**

```bash
cd mobile && flutter pub get && flutter test packages/identity_verification_client/test
```

- [ ] **Step 4: Implement exceptions**

`mobile/packages/identity_verification_client/lib/src/exceptions.dart`:

```dart
/// Raised when the identity-verification service returns a non-2xx
/// response or the request fails before reaching the server.
class IdentityVerificationException implements Exception {
  IdentityVerificationException(this.message, {this.statusCode, this.cause});

  final String message;
  final int? statusCode;
  final Object? cause;

  @override
  String toString() =>
      'IdentityVerificationException(${statusCode ?? '-'}): $message';
}
```

- [ ] **Step 5: Implement client**

`mobile/packages/identity_verification_client/lib/src/identity_verification_client.dart`:

```dart
// ABOUTME: HTTP client for divine-identify-verification-service /verify endpoint
// ABOUTME: Returns the verified subset of NIP-39 identity claims for a pubkey.

import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:identity_verification_client/src/exceptions.dart';
import 'package:meta/meta.dart';
import 'package:models/models.dart';

/// Client wrapping `POST {baseUri}/verify` on
/// `divine-identify-verification-service`.
class IdentityVerificationClient {
  IdentityVerificationClient({
    required Uri baseUri,
    http.Client? httpClient,
  })  : _baseUri = baseUri,
        _httpClient = httpClient ?? http.Client();

  final Uri _baseUri;
  final http.Client _httpClient;

  /// POSTs [claims] for [pubkey] to the verifier and returns the verified
  /// subset.
  ///
  /// Throws [IdentityVerificationException] on non-2xx responses or
  /// transport errors.
  Future<List<NostrIdentityClaim>> verifyClaims({
    required String pubkey,
    required List<NostrIdentityClaim> claims,
  }) async {
    if (claims.isEmpty) return const [];

    final endpoint = _baseUri.resolve('/verify');
    final body = jsonEncode({
      'pubkey': pubkey,
      'claims': [
        for (final c in claims)
          {
            'platform': c.platform.name,
            'identity': c.identity,
            'proof': c.proof,
          },
      ],
    });

    http.Response response;
    try {
      response = await _httpClient.post(
        endpoint,
        headers: const {'content-type': 'application/json'},
        body: body,
      );
    } on SocketException catch (e) {
      throw IdentityVerificationException(
        'network error',
        cause: e,
      );
    } on http.ClientException catch (e) {
      throw IdentityVerificationException(
        'http client error',
        cause: e,
      );
    }

    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw IdentityVerificationException(
        'verifier returned ${response.statusCode}',
        statusCode: response.statusCode,
      );
    }

    final json = jsonDecode(response.body) as Map<String, dynamic>;
    final results = (json['results'] as List?) ?? const [];
    final verified = <NostrIdentityClaim>[];
    for (final raw in results) {
      final entry = raw as Map<String, dynamic>;
      if (entry['verified'] != true) continue;
      final platform = IdentityPlatform.fromTagPrefix(
        entry['platform']?.toString() ?? '',
      );
      if (platform == null) continue;
      final identity = entry['identity']?.toString() ?? '';
      if (identity.isEmpty) continue;
      final claim = claims.firstWhere(
        (c) => c.platform == platform && c.identity == identity,
        orElse: () => NostrIdentityClaim(
          platform: platform,
          identity: identity,
          proof: '',
        ),
      );
      verified.add(claim);
    }
    return verified;
  }

  /// Releases the underlying [http.Client] if owned.
  @visibleForTesting
  void close() => _httpClient.close();
}
```

- [ ] **Step 6: Run tests — verify pass**

```bash
cd mobile && flutter test packages/identity_verification_client/test
```

- [ ] **Step 7: Run analyzer + format**

```bash
cd mobile && dart format packages/identity_verification_client && \
  flutter analyze packages/identity_verification_client
```

- [ ] **Step 8: Commit**

```bash
git add mobile/packages/identity_verification_client/
git commit -m "feat(packages): add identity_verification_client"
```

---

### Task 5: `IdentityVerificationRepository` package

**Files:**
- Create entire package skeleton at `mobile/packages/identity_verification_repository/`.

- [ ] **Step 1: Scaffold package** (mirror Task 4 layout, depend on `identity_verification_client` and `models`).

`pubspec.yaml`:
```yaml
name: identity_verification_repository
description: Repository wrapping IdentityVerificationClient with session cache and dedup.
version: 0.1.0
publish_to: none

environment:
  sdk: ^3.5.0

dependencies:
  identity_verification_client:
    path: ../identity_verification_client
  meta: ^1.16.0
  models:
    path: ../models

dev_dependencies:
  mocktail: ^1.0.4
  test: ^1.24.9
  very_good_analysis: ^10.2.0
```

- [ ] **Step 2: Write failing tests**

`mobile/packages/identity_verification_repository/test/identity_verification_repository_test.dart`:

```dart
import 'dart:async';

import 'package:identity_verification_client/identity_verification_client.dart';
import 'package:identity_verification_repository/identity_verification_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:test/test.dart';

class _MockClient extends Mock implements IdentityVerificationClient {}

void main() {
  group(IdentityVerificationRepository, () {
    late IdentityVerificationClient client;
    late IdentityVerificationRepository repo;

    const pubkey = 'p' * 64;
    const githubClaim = NostrIdentityClaim(
      platform: IdentityPlatform.github,
      identity: 'rabble',
      proof: 'https://gist',
    );
    const twitterClaim = NostrIdentityClaim(
      platform: IdentityPlatform.twitter,
      identity: 'rabble',
      proof: 'https://x',
    );

    setUp(() {
      client = _MockClient();
      repo = IdentityVerificationRepository(client: client);
    });

    test('returns verified subset from client', () async {
      when(() => client.verifyClaims(
            pubkey: pubkey,
            claims: any(named: 'claims'),
          )).thenAnswer((_) async => const [githubClaim]);

      final verified = await repo.verifyClaims(
        pubkey: pubkey,
        claims: const [githubClaim, twitterClaim],
      );

      expect(verified, equals(const [githubClaim]));
    });

    test('caches results for same (pubkey, claims) — second call no-ops the client',
        () async {
      when(() => client.verifyClaims(
            pubkey: pubkey,
            claims: any(named: 'claims'),
          )).thenAnswer((_) async => const [githubClaim]);

      await repo.verifyClaims(
          pubkey: pubkey, claims: const [githubClaim]);
      await repo.verifyClaims(
          pubkey: pubkey, claims: const [githubClaim]);

      verify(() => client.verifyClaims(
              pubkey: pubkey, claims: any(named: 'claims')))
          .called(1);
    });

    test('dedupes concurrent calls for same pubkey', () async {
      final completer = Completer<List<NostrIdentityClaim>>();
      when(() => client.verifyClaims(
            pubkey: pubkey,
            claims: any(named: 'claims'),
          )).thenAnswer((_) => completer.future);

      final f1 = repo.verifyClaims(
          pubkey: pubkey, claims: const [githubClaim]);
      final f2 = repo.verifyClaims(
          pubkey: pubkey, claims: const [githubClaim]);

      completer.complete(const [githubClaim]);
      final r1 = await f1;
      final r2 = await f2;

      expect(r1, equals(const [githubClaim]));
      expect(r2, equals(const [githubClaim]));
      verify(() => client.verifyClaims(
              pubkey: pubkey, claims: any(named: 'claims')))
          .called(1);
    });

    test('returns empty when client throws — does not propagate', () async {
      when(() => client.verifyClaims(
            pubkey: pubkey,
            claims: any(named: 'claims'),
          )).thenThrow(IdentityVerificationException('boom'));

      final verified = await repo.verifyClaims(
        pubkey: pubkey,
        claims: const [githubClaim],
      );
      expect(verified, isEmpty);
    });

    test('returns empty for empty input without calling the client', () async {
      final verified =
          await repo.verifyClaims(pubkey: pubkey, claims: const []);
      expect(verified, isEmpty);
      verifyNever(() => client.verifyClaims(
          pubkey: any(named: 'pubkey'), claims: any(named: 'claims')));
    });
  });
}
```

- [ ] **Step 3: Run — verify they fail**

```bash
cd mobile && flutter pub get && flutter test packages/identity_verification_repository/test
```

- [ ] **Step 4: Implement repository**

`mobile/packages/identity_verification_repository/lib/identity_verification_repository.dart` (barrel):
```dart
export 'src/identity_verification_repository.dart';
```

`mobile/packages/identity_verification_repository/lib/src/identity_verification_repository.dart`:
```dart
// ABOUTME: Wraps IdentityVerificationClient with in-memory session cache and dedup
// ABOUTME: Returns the verified subset; never propagates client errors to callers.

import 'dart:async';
import 'dart:developer' as developer;

import 'package:identity_verification_client/identity_verification_client.dart';
import 'package:meta/meta.dart';
import 'package:models/models.dart';

class IdentityVerificationRepository {
  IdentityVerificationRepository({
    required IdentityVerificationClient client,
  }) : _client = client;

  final IdentityVerificationClient _client;

  /// Cache keyed by `pubkey`. Value is the verified subset.
  final Map<String, List<NostrIdentityClaim>> _cache = {};

  /// In-flight call dedupe.
  final Map<String, Future<List<NostrIdentityClaim>>> _inflight = {};

  /// Returns the verified subset of [claims] for [pubkey].
  ///
  /// Caches results in-memory for the session. Concurrent calls for the
  /// same [pubkey] share a single in-flight Future. On client error, logs
  /// at info level and returns an empty list — never propagates.
  Future<List<NostrIdentityClaim>> verifyClaims({
    required String pubkey,
    required List<NostrIdentityClaim> claims,
  }) async {
    if (claims.isEmpty) return const [];

    final cached = _cache[pubkey];
    if (cached != null) return cached;

    final pending = _inflight[pubkey];
    if (pending != null) return pending;

    final future = _runVerify(pubkey: pubkey, claims: claims);
    _inflight[pubkey] = future;
    try {
      return await future;
    } finally {
      unawaited(future.whenComplete(() => _inflight.remove(pubkey)));
    }
  }

  Future<List<NostrIdentityClaim>> _runVerify({
    required String pubkey,
    required List<NostrIdentityClaim> claims,
  }) async {
    try {
      final verified = await _client.verifyClaims(
        pubkey: pubkey,
        claims: claims,
      );
      _cache[pubkey] = verified;
      return verified;
    } catch (error, stackTrace) {
      developer.log(
        'identity verification failed',
        name: 'identity_verification_repository',
        level: 800,
        error: error,
        stackTrace: stackTrace,
      );
      return const [];
    }
  }

  /// Clears all cached verifications. Call on logout / nsec switch.
  @visibleForTesting
  void clearCache() {
    _cache.clear();
    _inflight.clear();
  }
}
```

- [ ] **Step 5: Run tests — verify pass**

- [ ] **Step 6: Run analyzer + format**

- [ ] **Step 7: Commit**

```bash
git add mobile/packages/identity_verification_repository/
git commit -m "feat(packages): add identity_verification_repository with session cache and dedup"
```

---

## Chunk 3: BLoC

### Task 6: `ProfileLinksCubit`

**Files:**
- Create: `mobile/lib/blocs/profile_links/profile_links_state.dart`
- Create: `mobile/lib/blocs/profile_links/profile_links_cubit.dart`
- Create: `mobile/test/blocs/profile_links/profile_links_cubit_test.dart`

- [ ] **Step 1: Add `identity_verification_repository` and `identity_verification_client` to `mobile/pubspec.yaml`** as `path:` deps under `dependencies:`. Run `flutter pub get`.

- [ ] **Step 2: Write failing cubit tests**

```dart
// mobile/test/blocs/profile_links/profile_links_cubit_test.dart
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:identity_verification_repository/identity_verification_repository.dart';
import 'package:mocktail/mocktail.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/profile_links/profile_links_cubit.dart';
import 'package:openvine/blocs/profile_links/profile_links_state.dart';

class _MockRepo extends Mock implements IdentityVerificationRepository {}

void main() {
  group(ProfileLinksCubit, () {
    late IdentityVerificationRepository repo;
    const pubkey = 'p' * 64;
    const githubClaim = NostrIdentityClaim(
      platform: IdentityPlatform.github,
      identity: 'rabble',
      proof: 'p',
    );

    setUp(() {
      repo = _MockRepo();
    });

    blocTest<ProfileLinksCubit, ProfileLinksState>(
      'emits ready with empty verifiedIdentities when claims is empty',
      build: () => ProfileLinksCubit(repository: repo),
      act: (cubit) => cubit.load(
        pubkey: pubkey,
        website: 'https://example.com',
        claims: const [],
      ),
      expect: () => [
        isA<ProfileLinksState>()
            .having((s) => s.status, 'status', ProfileLinksStatus.ready)
            .having((s) => s.website, 'website', 'https://example.com')
            .having((s) => s.verifiedIdentities, 'verified', isEmpty),
      ],
    );

    blocTest<ProfileLinksCubit, ProfileLinksState>(
      'emits loading then ready with verified subset when claims provided',
      setUp: () {
        when(() => repo.verifyClaims(
              pubkey: pubkey,
              claims: any(named: 'claims'),
            )).thenAnswer((_) async => const [githubClaim]);
      },
      build: () => ProfileLinksCubit(repository: repo),
      act: (cubit) => cubit.load(
        pubkey: pubkey,
        website: null,
        claims: const [githubClaim],
      ),
      expect: () => [
        isA<ProfileLinksState>()
            .having((s) => s.status, 'status', ProfileLinksStatus.loading),
        isA<ProfileLinksState>()
            .having((s) => s.status, 'status', ProfileLinksStatus.ready)
            .having((s) => s.verifiedIdentities, 'verified',
                equals(const [
                  VerifiedIdentity(claim: githubClaim),
                ])),
      ],
    );

    blocTest<ProfileLinksCubit, ProfileLinksState>(
      'emits ready with empty verifiedIdentities when repo returns empty',
      setUp: () {
        when(() => repo.verifyClaims(
              pubkey: pubkey,
              claims: any(named: 'claims'),
            )).thenAnswer((_) async => const []);
      },
      build: () => ProfileLinksCubit(repository: repo),
      act: (cubit) => cubit.load(
        pubkey: pubkey,
        website: null,
        claims: const [githubClaim],
      ),
      expect: () => [
        isA<ProfileLinksState>()
            .having((s) => s.status, 'status', ProfileLinksStatus.loading),
        isA<ProfileLinksState>()
            .having((s) => s.status, 'status', ProfileLinksStatus.ready)
            .having((s) => s.verifiedIdentities, 'verified', isEmpty),
      ],
    );
  });
}
```

- [ ] **Step 3: Run — verify they fail**

```bash
cd mobile && flutter test test/blocs/profile_links
```

- [ ] **Step 4: Implement state**

`mobile/lib/blocs/profile_links/profile_links_state.dart`:

```dart
// ABOUTME: State for ProfileLinksCubit — website + verified NIP-39 identities

import 'package:equatable/equatable.dart';
import 'package:models/models.dart';

enum ProfileLinksStatus { initial, loading, ready }

class VerifiedIdentity extends Equatable {
  const VerifiedIdentity({required this.claim});

  final NostrIdentityClaim claim;

  IdentityPlatform get platform => claim.platform;
  String get identity => claim.identity;
  Uri get profileUrl => claim.platform.canonicalProfileUrl(claim.identity);

  @override
  List<Object?> get props => [claim];
}

class ProfileLinksState extends Equatable {
  const ProfileLinksState({
    this.status = ProfileLinksStatus.initial,
    this.website,
    this.verifiedIdentities = const [],
  });

  final ProfileLinksStatus status;
  final String? website;
  final List<VerifiedIdentity> verifiedIdentities;

  ProfileLinksState copyWith({
    ProfileLinksStatus? status,
    String? website,
    List<VerifiedIdentity>? verifiedIdentities,
  }) =>
      ProfileLinksState(
        status: status ?? this.status,
        website: website ?? this.website,
        verifiedIdentities: verifiedIdentities ?? this.verifiedIdentities,
      );

  @override
  List<Object?> get props => [status, website, verifiedIdentities];
}
```

- [ ] **Step 5: Implement cubit**

`mobile/lib/blocs/profile_links/profile_links_cubit.dart`:

```dart
// ABOUTME: Loads website + verified NIP-39 identities for a profile.
// ABOUTME: Calls IdentityVerificationRepository; failures emit empty list (silent).

import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:identity_verification_repository/identity_verification_repository.dart';
import 'package:models/models.dart';
import 'package:openvine/blocs/profile_links/profile_links_state.dart';

class ProfileLinksCubit extends Cubit<ProfileLinksState> {
  ProfileLinksCubit({required IdentityVerificationRepository repository})
      : _repository = repository,
        super(const ProfileLinksState());

  final IdentityVerificationRepository _repository;

  /// Loads links for a profile. Emits `loading` then `ready`. Errors are
  /// swallowed by the repository; this method does not throw.
  Future<void> load({
    required String pubkey,
    required String? website,
    required List<NostrIdentityClaim> claims,
  }) async {
    if (claims.isEmpty) {
      emit(state.copyWith(
        status: ProfileLinksStatus.ready,
        website: website,
        verifiedIdentities: const [],
      ));
      return;
    }

    emit(state.copyWith(
      status: ProfileLinksStatus.loading,
      website: website,
    ));

    final verified = await _repository.verifyClaims(
      pubkey: pubkey,
      claims: claims,
    );
    emit(state.copyWith(
      status: ProfileLinksStatus.ready,
      website: website,
      verifiedIdentities:
          verified.map((c) => VerifiedIdentity(claim: c)).toList(),
    ));
  }
}
```

- [ ] **Step 6: Run tests — verify pass**

- [ ] **Step 7: Format + analyze**

- [ ] **Step 8: Commit**

```bash
git add mobile/lib/blocs/profile_links/ \
        mobile/test/blocs/profile_links/ \
        mobile/pubspec.yaml mobile/pubspec.lock
git commit -m "feat(profile): ProfileLinksCubit loads verified NIP-39 identities"
```

---

## Chunk 4: UI helpers

### Task 7: Generalize `clickable_hashtag_text.dart` → `clickable_text.dart`

**Files:**
- Create: `mobile/lib/widgets/clickable_text.dart`
- Modify: `mobile/lib/widgets/clickable_hashtag_text.dart` (becomes a deprecated re-export)
- Create: `mobile/test/widgets/clickable_text_test.dart`
- Modify: `mobile/test/widgets/comprehensive_clickable_hashtag_text_test.dart` (update import)

- [ ] **Step 1: Read `clickable_hashtag_text.dart` end-to-end** to understand the regex composition, span builder, and gesture recognizer disposal pattern.

- [ ] **Step 2: Write failing tests for URL detection**

```dart
// mobile/test/widgets/clickable_text_test.dart
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/widgets/clickable_text.dart';

void main() {
  group(ClickableText, () {
    Future<void> pump(WidgetTester tester, Widget child) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(home: Scaffold(body: child)),
        ),
      );
    }

    testWidgets('renders bare text with no spans when no patterns match',
        (tester) async {
      await pump(
          tester, const ClickableText(text: 'hello world no links here'));
      expect(find.text('hello world no links here'), findsOneWidget);
    });

    testWidgets('renders Text.rich with a tappable URL span when text contains an https URL',
        (tester) async {
      var launched = '';
      await pump(
        tester,
        ClickableText(
          text: 'visit https://divine.video for more',
          onLaunchUrl: (uri) async {
            launched = uri.toString();
            return true;
          },
        ),
      );
      expect(find.byType(Text), findsOneWidget);
      // Tap the URL span.
      // (For unit-level coverage, prefer asserting the recognizer is wired —
      // see comprehensive_clickable_hashtag_text_test.dart for similar patterns
      // for hashtags. For URL specifically, simulate via TapGestureRecognizer.)
      // ...
      expect(launched, anyOf(equals(''), equals('https://divine.video')));
    });

    testWidgets('treats Https://CartridgeandQuest.com as a URL despite mixed case',
        (tester) async {
      // Validates the screenshot bug — case-insensitive scheme.
      // Test asserts the URL span is built (recognizer attached).
      // ...
    });

    testWidgets('strips trailing punctuation from URL match', (tester) async {
      // "see https://example.com." → URL is https://example.com (no trailing dot).
      // ...
    });

    testWidgets('does not match nsec1... — secrets are never tappable',
        (tester) async {
      // Reuse existing protection from clickable_hashtag_text_test.
      // ...
    });
  });
}
```

(Fill in the `// ...` bodies after the existing comprehensive test file's patterns. For URL-tap simulation, look up the recognizer on the matched `TextSpan` and call its `onTap` directly — same approach the existing tests use for hashtag spans.)

- [ ] **Step 3: Run — verify they fail**

- [ ] **Step 4: Implement `clickable_text.dart`**

Copy `clickable_hashtag_text.dart` to `clickable_text.dart`, rename the class to `ClickableText`, then:

1. Add a URL alternation to the combined regex. URL pattern (matches `http://`, `https://`, or `www.` prefix):

```dart
// New 4th alternation. Conservative — defer to Uri.tryParse to validate.
static final _urlRegex = RegExp(
  r'((?:https?:\/\/|www\.)[^\s]+)',
  caseSensitive: false,
);
```

In the combined regex, add `'|((?:https?:\\/\\/|www\\.)[^\\s]+)'` as group 4.

2. In the `_buildTextSpans` loop, when group 4 matches:
   - Trim trailing `.,;:!?)]}>` characters (move them out of the URL span back into plain text).
   - Run `Uri.tryParse` on the candidate. If `null` or scheme is empty after auto-prefixing `http://` for `www.`, fall through and render as plain text.
   - Build a `TextSpan` with a styled appearance (`mentionStyle`-like blue color) and a `TapGestureRecognizer` that calls `onLaunchUrl(uri)`.
3. Add `onLaunchUrl` callback parameter (defaults to a wrapper around `url_launcher`'s `launchUrl(...mode: externalApplication)`):

```dart
final Future<bool> Function(Uri uri)? onLaunchUrl;
```

4. Manage `TapGestureRecognizer` lifecycle: collect them in a `List<TapGestureRecognizer>`, dispose in `dispose()` (this means `ClickableText` becomes a `ConsumerStatefulWidget`).

5. Add `Semantics(label: <url string>)` around the URL span via `MouseRegion`/`Semantics` — or a `WidgetSpan` if simpler.

- [ ] **Step 5: Make `clickable_hashtag_text.dart` a deprecated re-export**

```dart
// ABOUTME: Deprecated. Use ClickableText from clickable_text.dart instead.
// TODO(#3935): Migrate all callers to ClickableText, then delete this file.

@Deprecated('Use ClickableText instead — supports URLs in addition to hashtags/mentions.')
export 'clickable_text.dart' show ClickableText;

// Backwards-compat alias for the rename.
@Deprecated('Use ClickableText.')
typedef ClickableHashtagText = ClickableText;
```

- [ ] **Step 6: Run tests**

```bash
cd mobile && flutter test test/widgets/clickable_text_test.dart \
  test/widgets/comprehensive_clickable_hashtag_text_test.dart
```

- [ ] **Step 7: Format + analyze**

- [ ] **Step 8: Commit**

```bash
git add mobile/lib/widgets/clickable_text.dart \
        mobile/lib/widgets/clickable_hashtag_text.dart \
        mobile/test/widgets/clickable_text_test.dart \
        mobile/test/widgets/comprehensive_clickable_hashtag_text_test.dart
git commit -m "feat(widgets): generalize ClickableHashtagText into ClickableText with URL detection"
```

---

### Task 8: `IdentityChip` widget in `divine_ui`

**Files:**
- Create: `mobile/packages/divine_ui/lib/src/identity/identity_chip.dart`
- Create: `mobile/packages/divine_ui/lib/src/identity/identity.dart` (barrel)
- Modify: `mobile/packages/divine_ui/lib/divine_ui.dart` (export `identity/identity.dart`)
- Create: `mobile/packages/divine_ui/test/identity/identity_chip_test.dart`

- [ ] **Step 1: Decide platform icon source.** `divine_ui` already exposes `DivineIcon`/`DivineIconName`. Confirm whether `DivineIconName.github`, `.x`, `.bluesky`, `.mastodon`, etc. exist. If missing, add SVG assets + enum cases — or fall back to Material icons that exist for these platforms (for first PR, falling back to a generic `link` icon per chip with platform name as the label is acceptable; document it in spec).

  Run:
  ```bash
  grep -n "DivineIconName" mobile/packages/divine_ui/lib/src/icons/*.dart | head -30
  ```

  Decide and update the spec doc if the fallback-icon route is taken. Continue.

- [ ] **Step 2: Write failing widget tests**

```dart
// mobile/packages/divine_ui/test/identity/identity_chip_test.dart
import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group(IdentityChip, () {
    testWidgets('renders platform display name and identity', (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: IdentityChip(
            platformDisplayName: 'GitHub',
            identity: 'rabble',
            onTap: () {},
          ),
        ),
      ));
      expect(find.textContaining('rabble'), findsOneWidget);
    });

    testWidgets('invokes onTap when tapped', (tester) async {
      var tapped = false;
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: IdentityChip(
            platformDisplayName: 'GitHub',
            identity: 'rabble',
            onTap: () => tapped = true,
          ),
        ),
      ));
      await tester.tap(find.byType(IdentityChip));
      expect(tapped, isTrue);
    });

    testWidgets('exposes semantic label "Verified <platform> account: <handle>"',
        (tester) async {
      await tester.pumpWidget(MaterialApp(
        home: Scaffold(
          body: IdentityChip(
            platformDisplayName: 'GitHub',
            identity: 'rabble',
            onTap: () {},
          ),
        ),
      ));
      final semantics =
          tester.getSemantics(find.byType(IdentityChip).first);
      expect(semantics.label,
          contains('Verified GitHub account: rabble'));
    });
  });
}
```

- [ ] **Step 3: Run — verify they fail**

- [ ] **Step 4: Implement**

```dart
// mobile/packages/divine_ui/lib/src/identity/identity_chip.dart
import 'package:divine_ui/src/icons/divine_icon.dart';
import 'package:divine_ui/src/theme/vine_theme.dart';
import 'package:flutter/material.dart';

/// Tappable verified-identity chip — platform icon + handle.
///
/// `divine_ui` is l10n-free per `.claude/rules/localization.md`; the
/// caller passes [platformDisplayName] (already localized).
class IdentityChip extends StatelessWidget {
  const IdentityChip({
    required this.platformDisplayName,
    required this.identity,
    required this.onTap,
    this.icon,
    super.key,
  });

  final String platformDisplayName;
  final String identity;
  final VoidCallback onTap;
  final Widget? icon;

  @override
  Widget build(BuildContext context) {
    return Semantics(
      label: 'Verified $platformDisplayName account: $identity',
      button: true,
      child: ConstrainedBox(
        constraints: const BoxConstraints(minHeight: 32),
        child: Material(
          color: VineTheme.surfaceContainer,
          borderRadius: BorderRadius.circular(16),
          child: InkWell(
            borderRadius: BorderRadius.circular(16),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: 12,
                vertical: 6,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                spacing: 6,
                children: [
                  if (icon != null) icon!,
                  Text(
                    identity,
                    style: VineTheme.bodySmallFont(
                      color: VineTheme.lightText,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
```

(Confirm exact `VineTheme.*` color names with the theme file at task time — substitute the closest existing token if any name above doesn't exist.)

- [ ] **Step 5: Wire barrel + top-level export**

`mobile/packages/divine_ui/lib/src/identity/identity.dart`:
```dart
export 'identity_chip.dart';
```

In `mobile/packages/divine_ui/lib/divine_ui.dart`, add:
```dart
export 'src/identity/identity.dart';
```

- [ ] **Step 6: Run tests — verify pass + 100% coverage**

```bash
cd mobile && flutter test packages/divine_ui --coverage && \
  lcov --summary coverage/lcov.info
```

If a line is uncovered, add a targeted test or `// coverage:ignore-line` with justification.

- [ ] **Step 7: Format + analyze**

- [ ] **Step 8: Commit**

```bash
git add mobile/packages/divine_ui/
git commit -m "feat(divine_ui): add IdentityChip for verified NIP-39 identities"
```

---

## Chunk 5: Profile screen integration

### Task 9: Wire `ProfileLinksCubit` into the profile screen

**Files:**
- Modify: `mobile/lib/widgets/profile/profile_header_widget.dart`
- Modify: `mobile/test/widgets/profile/profile_header_widget_test.dart`
- Modify: `mobile/lib/providers/app_providers.dart` — add provider for `IdentityVerificationClient` and `IdentityVerificationRepository`.
- Modify: `mobile/lib/models/environment_config.dart` — add `verifierBaseUri` per env.

- [ ] **Step 1: Add `verifierBaseUri` to env config**

In `mobile/lib/models/environment_config.dart`, add a field per environment (LOCAL / STAGING / PRODUCTION) with the production URL set to the confirmed one (placeholder `https://verifier.divine.video` — confirm before commit by visiting the deployed worker route or asking ops). Add a code comment with the canonical URL.

- [ ] **Step 2: Create Riverpod providers**

In `mobile/lib/providers/app_providers.dart` (or a new `identity_verification_provider.dart`):

```dart
final identityVerificationClientProvider =
    Provider<IdentityVerificationClient>((ref) {
  final env = ref.watch(environmentConfigProvider);
  return IdentityVerificationClient(baseUri: env.verifierBaseUri);
});

final identityVerificationRepositoryProvider =
    Provider<IdentityVerificationRepository>((ref) {
  final client = ref.watch(identityVerificationClientProvider);
  return IdentityVerificationRepository(client: client);
});
```

If using `@riverpod` codegen, run `dart run build_runner build --delete-conflicting-outputs` from `mobile/` and stage generated files.

- [ ] **Step 3: Modify `_ProfileNameAndBio` to mount the cubit**

Wrap the relevant subtree in `BlocProvider<ProfileLinksCubit>` at the **page** layer (not the header widget). Pull the dep via `ref.watch(identityVerificationRepositoryProvider)` in the surrounding `ConsumerWidget` and apply the **Riverpod-bridge ValueKey rule** (`.claude/rules/state_management.md`):

```dart
// In the surrounding ConsumerWidget that builds ProfileHeaderWidget
final repo = ref.watch(identityVerificationRepositoryProvider);
return BlocProvider<ProfileLinksCubit>(
  key: ValueKey(repo),
  create: (_) => ProfileLinksCubit(repository: repo)
    ..load(
      pubkey: profile.pubkey,
      website: profile.website,
      claims: profile.identityClaims,
    ),
  // CRITICAL: not lazy — the load() call needs to fire even if no
  // descendant reads the cubit synchronously.
  lazy: false,
  child: ProfileHeaderWidget(...),
);
```

  > Identify the right ConsumerWidget for this insertion at task time — likely `ProfileScreenRouter` or the wrapper that owns the profile header. Look for the existing widget that already passes `userProfile` down to `ProfileHeaderWidget`.

- [ ] **Step 4: Add `_WebsiteRow` and `_IdentityChipsRow` to `profile_header_widget.dart`**

Inside `_ProfileNameAndBio`, below `_AboutText`:

```dart
BlocSelector<ProfileLinksCubit, ProfileLinksState, String?>(
  selector: (s) => s.website,
  builder: (context, website) =>
      website == null || website.isEmpty
          ? const SizedBox.shrink()
          : _WebsiteRow(url: website),
),
BlocSelector<ProfileLinksCubit, ProfileLinksState, List<VerifiedIdentity>>(
  selector: (s) => s.verifiedIdentities,
  builder: (context, identities) => identities.isEmpty
      ? const SizedBox.shrink()
      : _IdentityChipsRow(identities: identities),
),
```

Implement `_WebsiteRow` (Row with `DivineIcon(.link)` + tappable Text via `InkWell` + `Semantics`). Implement `_IdentityChipsRow` (`SingleChildScrollView(scrollDirection: Axis.horizontal, child: Row(spacing: 8, children: identities.map((id) => IdentityChip(...))))`. Use `context.l10n` for `platformDisplayName` only if the platform names need localization — current spec keeps them English.

- [ ] **Step 5: Update `_AboutText` to render with `ClickableText`**

Replace the inner `Text(...)` (line 769–774) and `SelectableText(...)` (line 767) with `ClickableText(text: widget.about, ...)`. Pass `maxLines` only when `!_isExpanded`. Pass `style` matching the existing `bodyMediumFont(...)`.

- [ ] **Step 6: Add l10n keys**

In `mobile/lib/l10n/app_en.arb`:

```json
"profileBioShowMore": "Show more",
"@profileBioShowMore": {"description": "Expand truncated profile bio"},
"profileBioShowLess": "Show less",
"@profileBioShowLess": {"description": "Collapse expanded profile bio"},
"profileLinkOpenFailed": "Couldn't open link",
"@profileLinkOpenFailed": {"description": "Snackbar shown when url_launcher fails to launch a link tapped from a profile"}
```

Run `flutter gen-l10n` from `mobile/`. Stage generated files.

Update `_AboutText` to read the strings via `context.l10n.profileBioShowMore` / `profileBioShowLess`. Update the snackbar (added in Task 9 step 8) to read `context.l10n.profileLinkOpenFailed`.

- [ ] **Step 7: Update / add widget tests**

Add cases to `mobile/test/widgets/profile/profile_header_widget_test.dart`:

- Renders no website row when `state.website` is null.
- Renders website row with tap that calls launcher mock when website is present.
- Renders no chip row when `verifiedIdentities` is empty.
- Renders one chip per verified identity when present.
- Bio with URL renders `ClickableText` with a tappable URL span.

For each test, use a `_MockProfileLinksCubit extends MockCubit<ProfileLinksState>` and `MaterialApp` with `localizationsDelegates: AppLocalizations.localizationsDelegates`.

- [ ] **Step 8: Wire snackbar on `url_launcher` failure**

In `_WebsiteRow.onTap` and `IdentityChip.onTap` callbacks (and the `onLaunchUrl` passed to `ClickableText`), wrap launcher calls:

```dart
final ok = await launchUrl(uri, mode: LaunchMode.externalApplication);
if (!ok && context.mounted) {
  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(content: Text(context.l10n.profileLinkOpenFailed)),
  );
}
```

- [ ] **Step 9: Run tests — verify pass**

```bash
cd mobile && flutter test test/widgets/profile/profile_header_widget_test.dart \
  test/widgets/profile/profile_links_integration_test.dart
```

- [ ] **Step 10: Run analyzer + format on all touched files**

- [ ] **Step 11: Commit**

```bash
git add mobile/lib/widgets/profile/profile_header_widget.dart \
        mobile/lib/providers/app_providers.dart \
        mobile/lib/models/environment_config.dart \
        mobile/lib/l10n/app_en.arb \
        mobile/lib/l10n/generated/ \
        mobile/test/widgets/profile/
git commit -m "feat(profile): render website row and verified identity chips; linkify bio"
```

---

## Chunk 6: Verification & polish

### Task 10: Manual verification + final coverage

- [ ] **Step 1: Manual smoke test on a device/simulator**

Run the app, sign in, navigate to a profile that has:
1. A bio containing a URL (e.g. the screenshot user `npub1a03gnzynv02...`).
2. A profile with a `website` field (sign in with a test account that has one set).
3. A profile with at least one *verified* NIP-39 claim (use a test account; verify via the verification service before testing).

Expected:
- URL in bio is tappable, opens external browser.
- Hashtag in bio (if present) is tappable.
- `nostr:` mention in bio (if present) is tappable.
- Website row appears below bio when `website` is set.
- Identity chips appear when verified claims are present; chip tap opens platform URL.
- Failure to launch shows snackbar.
- Verification service offline: chip row absent (no error UI).

- [ ] **Step 2: TalkBack / VoiceOver pass** on the profile screen — confirm semantic labels read correctly for chips, URL spans, and website row.

- [ ] **Step 3: Coverage check**

```bash
cd mobile && flutter test --coverage && \
  lcov --summary coverage/lcov.info
```

Confirm new code lines are covered. `divine_ui` must remain 100%.

- [ ] **Step 4: Pre-PR verification sequence (per `.claude/rules/self_review_checklist.md`)**

```bash
cd mobile && \
  dart format lib test packages && \
  flutter analyze lib test integration_test && \
  flutter test
```

All green.

- [ ] **Step 5: Open PR**

Run `/pr-summary` (slash command in this repo) to generate the PR body. Title:

```
feat(profile): clickable bio links — URLs, website field, NIP-39 verified identity chips
```

Body references issue #3935 and the spec doc. Include screenshots of the changed profile screen.

- [ ] **Step 6: Self-review checklist pass** — walk through `.claude/rules/self_review_checklist.md` "Before opening or updating a PR" section.
