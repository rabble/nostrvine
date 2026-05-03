# Profile Bio Links — Design

Date: 2026-05-04
Status: Approved (ready to plan)
Branch: `feat/profile-bio-links`
Issue: divinevideo/divine-mobile#3935
Follow-ups: #3936 (persist cache), #3937 (editor entry-point), divinevideo/divine-web#324 (web parity)

## Problem

A profile's bio rendering is the user's "link kit" in mainstream Nostr clients (Damus, Amethyst, Primal, Nostur). diVine currently throws away every link signal a Kind-0 event carries:

- URLs inside `about` text are not tappable. Screenshot example: a Kind-0 with `"about": "Https://CartridgeandQuest.com Averagetrav & Foodie Mike C ..."` renders the URL as plain text.
- The standard Kind-0 `website` field (NIP-24) is parsed by `UserProfile` (`mobile/packages/models/lib/src/user_profile.dart`) but never rendered.
- NIP-39 external identity claims (`["i", "github:rabble", "<proof>"]` etc.) are not parsed at all.
- Hashtags and `nostr:` mentions inside the bio text are also not tappable, even though the rest of the app supports them via `clickable_hashtag_text.dart`.

## Goal

Bring the profile bio area to parity with mainstream Nostr clients: clickable URLs/hashtags/mentions inside the bio, render the `website` field, and render *verified* NIP-39 identity claims as tappable platform chips.

## Out of scope (this PR)

- NIP-05 verification badge UX (separate, already partially implemented).
- Lightning address rendering / zap button.
- *Editing* identity claims — `divine-identify-verification-service` has its own browser UI for OAuth and proof-post flows; we link users into it from the profile editor in a follow-up.
- Web client (`divine-web`) — separate parity issue.
- Disk-cache of verification results across sessions — in-memory session cache only; the service has its own KV cache.

## UX

Profile screen (`mobile/lib/widgets/profile/profile_header_widget.dart`), top to bottom:

1. Banner / avatar
2. Display name + npub
3. **Bio (`about`)** — now linkified (URLs, hashtags, `nostr:` mentions all tappable)
4. **Website row** *(new, only when `website` is non-empty)* — single tappable line, leading globe icon
5. **Identity chip row** *(new, only verified claims)* — horizontal scroll of platform-icon chips
6. Stats (Loops / Likes / Following / Followers)
7. Follow / message / share buttons

Behaviour:

- Tapping a URL span / website row / chip opens the destination in the system browser via `url_launcher`.
- A tap that fails to launch shows a snackbar (`'Couldn\'t open link'`); no crash.
- Verification failures are silent — the chip simply does not appear.

## Architecture

Layered per `.claude/rules/architecture.md`: UI → BLoC → Repository → Client.

### Client (new)

`IdentityVerificationClient` — `mobile/packages/identity_verification_client/`.

- Wraps `POST /verify` on `divine-identify-verification-service` (Hono Cloudflare Worker; KV-cached server-side).
- Base URL via existing environment config (placeholder `verifier.divine.video` to be confirmed at plan time).
- Input: `pubkey` + list of `IdentityClaim`. Output: list of verification results.
- No Flutter deps. Throws typed exceptions for non-2xx responses.

### Repository (new)

`IdentityVerificationRepository` — `mobile/packages/identity_verification_repository/`.

- Composes `IdentityVerificationClient`.
- In-memory session cache keyed by `(pubkey, platform, identity)`; returns cached result inside the same app session.
- Dedupes concurrent verification calls per pubkey (one in-flight `Future` per pubkey).
- Returns the **verified subset** to callers — drops unverified silently.
- On client error: returns empty list, logs at info level. UI does not surface a verification error.

### BLoC (new)

`ProfileLinksCubit` — `mobile/lib/blocs/profile_links/`.

- Constructor takes `IdentityVerificationRepository` (constructor injection per architecture rules).
- Method `loadFor({required String pubkey, required UserProfile profile})`:
  1. Emits `ProfileLinksState(status: loading, website: profile.website)`.
  2. Calls `repository.verifyClaims(pubkey, profile.identityClaims)`.
  3. Emits `ProfileLinksState(status: ready, website, verifiedIdentities)`.
- Errors: emit `ready` with empty `verifiedIdentities` (no error in state per `.claude/rules/state_management.md`).
- State has `enum ProfileLinksStatus { initial, loading, ready }` — no error string field.

### UI (changes)

- `_AboutText` (`mobile/lib/widgets/profile/profile_header_widget.dart:730-791`) swaps the inner `Text` / `SelectableText` for a new `ClickableText` widget (see Linkification below). "Show more / Show less" affordance unchanged.
- `_ProfileNameAndBio` gains a `_WebsiteRow` (only when `state.website` is non-empty) and an `_IdentityChipsRow` (only when `state.verifiedIdentities` is non-empty), driven by a `BlocSelector` on `ProfileLinksCubit`.
- `IdentityChip` — new widget in `mobile/packages/divine_ui/`. Platform icon + handle text, tappable. Reuses `VineTheme` chip styling.
- The cubit is `BlocProvider`-mounted at the page level (per Page/View pattern) and disposed when the profile route is left.

## Data model

### NIP-39 parsing

Extend `UserProfile` (`mobile/packages/models/lib/src/user_profile.dart`):

```dart
/// External identity claims from NIP-39 ["i", "<platform>:<identity>", "<proof>"] tags.
final List<NostrIdentityClaim> identityClaims;
```

`UserProfile.fromNostrEvent(Event event)` is updated to also walk `event.tags`, pick `i` tags, split the value on the first `:`, validate the platform against an allowlist, and discard malformed entries.

### `NostrIdentityClaim` (new model)

```dart
class NostrIdentityClaim extends Equatable {
  const NostrIdentityClaim({
    required this.platform,
    required this.identity,
    required this.proof,
  });

  final IdentityPlatform platform; // enum
  final String identity;            // handle/username on the platform
  final String proof;               // proof URL or token (NIP-39)
}

enum IdentityPlatform { github, twitter, bluesky, mastodon, telegram, discord, youtube, tiktok }
```

`twitter` and `x` map to the same enum value (the protocol uses `twitter`; the brand is `X`).

### `VerifiedIdentity` (cubit output)

```dart
class VerifiedIdentity extends Equatable {
  const VerifiedIdentity({
    required this.claim,
    required this.profileUrl, // canonical platform URL we link to
  });

  final NostrIdentityClaim claim;
  final Uri profileUrl;
}
```

`profileUrl` is computed deterministically from `(platform, identity)` (e.g. `https://github.com/<identity>`). The verification *service* returns the proof reference; we don't display the proof — we link to the user's account on the platform.

## Linkification

Generalize `mobile/lib/widgets/clickable_hashtag_text.dart` → rename to `clickable_text.dart`. Keep `clickable_hashtag_text.dart` as a one-line deprecated re-export so existing imports keep working until they are migrated in a separate cleanup PR.

Combined regex grows a fourth alternation for URLs:

- Match `https?://...` and `www....` host-prefixed URLs.
- Be lenient with trailing punctuation (drop trailing `.`, `,`, `)`, `]` from the matched span).
- Validate each candidate via `Uri.tryParse` before treating it as tappable; non-parsable spans render as plain text.
- Open via `url_launcher.launchUrl(..., mode: LaunchMode.externalApplication)`.

URL spans get `Semantics(label: '<the URL>')` plus a `recognizer` that calls the launcher.

## Verification flow

1. Profile route opens → `ProfileLinksCubit.loadFor(pubkey: ..., profile: ...)`.
2. Cubit emits `loading`. Chip row hidden during loading.
3. Cubit calls `repository.verifyClaims(pubkey, profile.identityClaims)`.
4. Repository:
   - Returns cached subset where present.
   - For uncached claims, POSTs `/verify` to the verification service.
   - Caches results.
   - Returns the verified subset.
5. Cubit emits `ready` with verified subset → chip row appears.
6. On any client error: repository returns empty; cubit emits `ready` with empty list; row stays hidden.

## Accessibility

- Each chip wraps with `Semantics(label: 'Verified <Platform> account: <handle>', button: true)`.
- URL spans have `Semantics(label: <url>)` (text already conveys the destination).
- Touch targets ≥ 48dp per `.claude/rules/accessibility.md`.
- Bio text scaling unchanged — wrapping the existing `Text`-based widget.

## Error handling

- `url_launcher` returning `false`: snackbar `'Couldn\'t open link'`.
- Verification client `HttpException` / network error: repository swallows, logs `developer.log(level: 800)`. No state error field.
- `i` tag with malformed value: dropped at parse time; logged at debug level.

## Telemetry

- Existing screen analytics unchanged.
- New analytics events (logged via the existing analytics path):
  - `profile_bio_link_tapped` — properties: `kind` (one of `url`, `hashtag`, `nostr_mention`, `website`, `identity_chip`), `platform` (when `kind = identity_chip`).

## Testing

Per `.claude/rules/testing.md` (mirror `lib/` structure, test behaviour, single-purpose tests, 100% coverage on new code).

### Unit / model

- `UserProfile.fromNostrEvent` — parses valid `i` tags, drops malformed, drops unknown platforms, normalizes `x` → `twitter`.
- `NostrIdentityClaim.canonicalProfileUrl` — produces correct URL per platform.

### Client

- Parses success response.
- Throws typed error on 4xx / 5xx.
- Handles network error → typed exception.

### Repository

- Returns verified subset.
- Caches results for the same `(pubkey, claim)`.
- Dedupes concurrent calls for the same pubkey (one in-flight `Future`).
- Returns empty on client error (does not propagate).

### Cubit (`blocTest`)

- `loadFor` with empty claims emits `ready` with empty `verifiedIdentities` and no client call.
- `loadFor` with claims emits `loading` then `ready` with verified subset.
- `loadFor` when repository returns empty emits `loading` then `ready` with empty list.

### Widget

- `_AboutText` with bio containing URL renders `Text.rich` with tappable URL span; tap calls launcher mock.
- `_AboutText` with bio containing hashtag → tappable, navigates to hashtag screen.
- `_AboutText` with bio containing `nostr:npub...` mention → tappable, navigates to profile.
- `_WebsiteRow` only renders when `website` is non-empty; tap launches.
- `_IdentityChipsRow` only renders when there are verified identities; chip tap launches platform URL.
- `IdentityChip` golden test (one per supported platform).

### l10n

- `'Show more'` / `'Show less'` / `'Couldn\'t open link'` extracted into the existing l10n flow if not already there. (The current `_AboutText` hardcodes these — fix while we are touching the widget.)

## Phasing

This issue / PR ships everything above. Three follow-up issues filed alongside this one, each with its own branch:

1. **Persist verification cache across sessions** — Hive box keyed by `(pubkey, platform, identity)`, TTL aligned with the service's KV TTL.
2. **Profile editor entry-point to verification flow** — deep-link button into `divine-identify-verification-service` browser UI.
3. **Web client parity (`divine-web`)** — same UX for the web app.
