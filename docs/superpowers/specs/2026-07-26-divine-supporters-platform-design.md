# Divine supporters platform design

**Date:** 2026-07-26

**Status:** Approved product and architecture design

**Scope:** `divine-supporters` (new), Funnelcake, `divine-mobile`, and shared
profile/feed consumers

**Product owner:** Rabble

## 1. Summary

Divine will offer one optional monthly supporter subscription through Apple
StoreKit and Google Play Billing. A supporter funds Divine and, while their
subscription is paid or in billing grace, may receive:

- a warm-gold halo over their avatar throughout Divine;
- placement in a fairly rotating supporter directory on Explore; and
- eligibility for an engagement-ranked Supporters video feed.

The subscription does not unlock content or ordinary app functionality. It does
not boost For You, Popular, search, or any other general ranking system.

Supporter status is bound to the Divine pubkey active when the purchase is made.
It is verified server-side by a new Cloudflare Worker in a new
`divinevideo/divine-supporters` repository. Funnelcake receives only the
sanitized public projection needed for profile decoration and discovery.
Receipts, purchase tokens, transaction identifiers, and billing history remain
private to the supporter service.

The feature is default-off until the service, store products, mobile purchase
lifecycle, Funnelcake projection, and sandbox end-to-end tests are complete.

## 2. Product decisions

The following decisions were made during product review:

| Area | Decision |
|---|---|
| Initial offering | One monthly supporter tier |
| Price | Configured in App Store Connect and Play Console before launch; the app displays store-localized price metadata |
| Account ownership | Bound to the Divine pubkey active at purchase |
| Public recognition | On by default after verification |
| Privacy control | One control hides both the halo and Supporters discovery placement without cancelling payment |
| Expiry | Recognition remains through paid-through and billing grace, then disappears |
| Avatar treatment | Warm-gold halo at roughly 10–11 o'clock, slightly overlapping the avatar |
| Explore structure | Classics-style rotating supporter directory followed by a supporter video grid/feed |
| Directory order | Fair rotation among active, visible supporters |
| Video order | Engagement-ranked within the active, visible supporter cohort |
| General ranking | No paid boost outside the explicitly labeled Supporters surface |
| Canonical status | Server-verified entitlement, not local store state and not NIP-58 |
| Server ownership | New `divine-supporters` GitHub repository and Cloudflare Worker |

## 3. Goals

1. Let people fund Divine with a clear, recurring native-store subscription.
2. Celebrate active supporters without creating a paywall or a wealth-tier
   hierarchy.
3. Give supporters a transparent discovery surface without altering organic
   ranking elsewhere.
4. Bind purchases safely to one Divine identity across devices.
5. Handle renewals, grace periods, refunds, revocations, restores, and account
   switching without relying on the app process.
6. Keep store evidence and financial metadata private.
7. Make the public status consumable by mobile, web, and future Divine clients
   through ordinary profile/feed APIs.

## 4. Non-goals

- Multiple supporter tiers at launch.
- Paid access to content, posting, messaging, storage, ranking, or moderation
  privileges.
- Boosting supporter posts in For You, Popular, search, lists, or hashtag
  results.
- Transfer of a subscription between Divine pubkeys.
- Publishing purchase evidence or billing state to Nostr.
- Using NIP-58 as the canonical recurring entitlement.
- Permanent alumni or lifetime-supporter recognition after payment ends.
- External checkout inside the native supporter flow.
- Replacing creator-controlled profile tip and subscription links delivered by
  `divine-mobile` PR
  [#5665](https://github.com/divinevideo/divine-mobile/pull/5665).

## 5. User experience

### 5.1 Entry point

Behind `FeatureFlag.divineSupporters`, Settings includes a **Support Divine**
entry. The screen uses direct Divine voice:

- heading: **Support Divine**
- primary message: **Keep Divine weird.**
- supporting copy explains that monthly support helps keep human creativity
  independent and alive;
- the store-localized price is shown on the native purchase button;
- Restore Purchases, Terms, Privacy, and native subscription-management links
  remain accessible.

The screen must clearly state that the halo and Supporters discovery are
recognition benefits. It must not imply that payment improves general ranking.

### 5.2 Active state

After the Worker verifies the purchase for the current pubkey, the screen shows:

- active paid-through or billing-grace state;
- the account that owns the subscription;
- the halo preview;
- native subscription-management action; and
- a default-on control:

> **Show that I'm a supporter and include me in Supporters discovery.**

Turning this control off:

- hides the halo on every public surface;
- removes the account from the supporter directory;
- removes its videos from the Supporters feed;
- does not cancel, pause, refund, transfer, or otherwise mutate payment.

### 5.3 Pending and confirmation

A store purchase is not treated as a public entitlement until the Worker
verifies it. While verification is pending, the screen says **Confirming your
support**. It does not show an unverified halo.

A pending renewal or second purchase never replaces an already verified active
entitlement with an inactive state.

### 5.4 Expiry, refund, and grace

- Cancellation keeps benefits through the paid-through date.
- Store billing grace keeps benefits while the store reports grace.
- Expiry removes the halo and discovery eligibility.
- Refund or revocation removes benefits according to the canonical store state.
- If more than one valid store transaction exists for the same pubkey, the
  account remains active while any one entitlement remains valid.

### 5.5 Account switching and restore

The purchase attempt captures the active pubkey at initiation. An async store
result cannot be attached to whichever account happens to be active later.

An original Apple or Google transaction can bind to only one Divine pubkey.
Restore on another device succeeds only for that same signed-in Divine account.
If the store transaction is already bound to another pubkey, the service returns
a typed ownership conflict and does not rebind it.

Account transfer is not offered in v1. A user who no longer controls the bound
Divine identity can manage or cancel the subscription through Apple or Google,
but cannot silently move its public status to another identity.

## 6. Visual design

### 6.1 Halo

The supporter mark is a warm-gold ring inspired by the halo in Divine's app
icon:

- anchor at roughly 10–11 o'clock;
- slightly overlaps the avatar crop so it looks perched rather than floating;
- tilted approximately 10–12 degrees;
- proportional to the avatar;
- uses a subtle warm shadow where the platform can render it cleanly;
- never resembles a verification checkmark;
- does not add height to rows or shift surrounding content; and
- remains visible without obscuring the person's face.

The halo appears everywhere a public supporter avatar appears, including:

- profile headers and profile cards;
- video author bylines;
- comments and replies;
- inbox and DM conversation rows;
- search results;
- notifications;
- lists and follower/following rows; and
- the Supporters directory.

The shared avatar primitive must own the decoration. Individual screens must
not implement one-off halo overlays. At very small sizes, stroke width scales
down but remains at least a device-pixel-safe visible width.

Accessibility exposes **Divine supporter** as supplemental semantics. Color is
not the only signal: the ring shape is stable across surfaces.

### 6.2 Explore

Explore gains a flag-gated **Supporters** tab. Its structure parallels the
existing Classics tab in `mobile/lib/widgets/classic_vines_tab.dart`:

1. a horizontally scrollable supporter directory/slider; and
2. a masonry video grid that opens the standard fullscreen feed.

The directory rotates fairly among active, publicly visible supporters.
Rotation must be deterministic for a bounded period so it does not jump on
every rebuild, while changing often enough to expose smaller and newer
supporters.

The video grid uses the existing engagement-ranking signals, restricted to:

- indexed, playable, moderation-eligible videos;
- authors with an active public supporter projection;
- videos allowed by the current viewer's block, mute, age, and content-safety
  rules; and
- the same recency/availability constraints used by the corresponding Explore
  ranking implementation.

Recent eligible videos published before the author subscribed may appear while
the author is active. When the author expires, is refunded, or opts out, their
videos leave this surface. Support amount and tenure are not ranking inputs.

The tab is viewable by supporters and non-supporters. Empty, loading, error,
pagination, and pull-to-refresh behavior must match current Explore patterns.

## 7. System architecture

```text
StoreKit / Play Billing
          |
          | purchase proof + signed Divine pubkey claim
          v
divine-supporters Cloudflare Worker  <--- Apple / Google lifecycle notifications
          |
          +--- private D1 billing + entitlement state
          |
          +--- signed sanitized projection changes
                         |
                         v
                    Funnelcake
                         |
                         +--- supporter directory
                         +--- supporter video feed
                         +--- profile/feed is_supporter presentation field
                                      |
                                      v
                                mobile + web
```

### 7.1 Trust boundary

`divine-supporters` is the sole authority for paid entitlement. Store clients
are input sources, not authorities. Funnelcake and clients consume a
presentation projection and cannot create or extend an entitlement.

### 7.2 Repository responsibilities

#### `divinevideo/divine-supporters` — new

Recommended stack: TypeScript, Hono, Wrangler, D1, Cloudflare Queues, and
Vitest, following existing Divine Worker conventions.

Owns:

- Apple and Google purchase verification;
- NIP-98-authenticated pubkey binding;
- store lifecycle notification verification and processing;
- canonical entitlement calculation;
- public-visibility preference;
- idempotency, audit history, and reconciliation;
- sanitized projection outbox;
- private account entitlement API; and
- operational health and metrics.

It does not rank or serve videos and does not issue Nostr badges.

#### Funnelcake

Owns:

- a local projection of active public supporter pubkeys;
- idempotent application of Worker projection changes;
- periodic snapshot reconciliation;
- fair supporter-directory rotation;
- engagement-ranked supporter video discovery;
- viewer-specific moderation/block/mute filtering; and
- presentation-only supporter fields in profile/feed responses.

Funnelcake never receives store evidence or billing history.

#### `divine-mobile`

Owns:

- the native store purchase client;
- a process/device-scope purchase listener started at app startup;
- durable claim retry;
- NIP-98-authenticated supporter API client;
- account-bound repository and Cubit state;
- purchase, restore, management, visibility, and error UI;
- shared halo avatar decoration;
- Supporters Explore tab; and
- analytics that contain no purchase proof, transaction ID, pubkey, or price.

The current draft supporter PR
[#6378](https://github.com/divinevideo/divine-mobile/pull/6378) may supply
useful models, tests, and store abstractions, but its local
`SharedPreferences` entitlement is not canonical. Its existing review blockers
must be fixed rather than carried forward.

#### Web and other clients

Clients read the same Funnelcake presentation projection and reuse the same
visual meaning. They do not need store SDKs to render a verified public halo.

## 8. Worker data model

Exact D1 migrations may refine names, but the ownership and uniqueness rules
are fixed.

### 8.1 `supporter_accounts`

One row per Divine pubkey:

- `pubkey` — full 64-character hex key, primary key;
- `public_visibility` — boolean, default true;
- `created_at`;
- `updated_at`; and
- `visibility_version` — monotonic version for projection ordering.

This table does not claim the account is active. Activity is derived from
verified store transactions.

### 8.2 `store_transactions`

One row per original store subscription transaction:

- `store` — `apple` or `google`;
- `original_transaction_lookup` — keyed HMAC of the store and original
  transaction identifier, unique and used only for equality lookup;
- `original_transaction_ciphertext` — application-layer AES-GCM encryption of
  the original identifier using a versioned Worker secret;
- `verification_artifact_ciphertext` — application-layer encryption of any
  renewable store token or artifact required for later canonical verification;
- `pubkey` — immutable owner after first successful binding;
- `product_id`;
- `environment` — sandbox/test or production;
- `status` — canonical normalized state;
- `paid_through_at`;
- `grace_through_at`;
- `store_updated_at`;
- `verified_at`;
- `verification_version`; and
- created/updated timestamps.

Plaintext identifiers and verification artifacts exist only in memory while a
request is processed. Key rotation can rewrite ciphertext without changing the
stable keyed lookup. An original transaction cannot be rebound to a different
pubkey. A pubkey may have more than one transaction, but the UI should prevent
accidental duplicate subscriptions when an active entitlement is already known.

### 8.3 `store_events`

Idempotent notification inbox:

- store notification/event identifier, unique;
- signed payload hash;
- received time;
- store event time;
- processing status and attempt count;
- non-sensitive normalized error code; and
- processed time.

Verified notification data is normalized during ingestion. Raw signed payloads
are not retained after the request is processed and are never written to
ordinary logs. Any store token needed for deferred processing is persisted only
as the encrypted verification artifact on its transaction.

### 8.4 `projection_outbox`

Transactional outbox for Funnelcake:

- monotonic sequence;
- pubkey;
- `active_public` boolean;
- canonical effective time;
- reason code;
- created time; and
- delivery/retry state.

The public projection contains no store, product, price, transaction, or
billing fields.

## 9. Entitlement state machine

Normalized states:

- `unbound` — verified store transaction exists but is not yet bound to a
  Divine pubkey;
- `pending` — purchase or renewal awaits a terminal store result;
- `active` — paid and verified;
- `grace` — store-authorized billing grace;
- `expired`;
- `refunded`;
- `revoked`; and
- `unknown` — verification temporarily unavailable; never used to overwrite a
  newer active/grace result.

Public entitlement is true when at least one transaction for the pubkey is
`active`, or `grace` within its verified grace window, and public visibility is
true.

Cancellation is metadata about future renewal, not immediate inactivity.

Store event timestamps and verification versions prevent older or duplicated
notifications from regressing newer state. When a notification is ambiguous,
the Worker queries the store's canonical subscription API before changing
entitlement.

## 10. Worker API

All version-one JSON APIs live under `/v1`.

### 10.1 User-authenticated endpoints

`POST /v1/purchases/claim`

- NIP-98 authentication is required.
- Body identifies store and product and carries the minimum purchase proof
  required for server verification.
- The authenticated pubkey is the requested owner.
- The operation is idempotent.
- Returns the canonical account entitlement, not an optimistic local state.

`GET /v1/me`

- NIP-98 authentication is required.
- Returns normalized private entitlement state, paid/grace timing suitable for
  UI, public-visibility preference, and typed management/repair status.
- Does not echo store proofs or transaction identifiers.

`PATCH /v1/me/visibility`

- NIP-98 authentication is required.
- Accepts one boolean controlling halo and Supporters discovery together.
- Emits an outbox change only when effective public state changes.

### 10.2 Store endpoints

`POST /v1/store/apple/notifications`

- verifies App Store Server Notification signed payloads;
- persists idempotently before acknowledging; and
- enqueues canonical processing.

`POST /v1/store/google/notifications`

- verifies Google Pub/Sub push authentication and RTDN data;
- persists idempotently before acknowledging; and
- enqueues canonical processing.

### 10.3 Internal endpoints

`GET /internal/v1/supporters/snapshot`

- service-authenticated and paginated;
- returns full active-public pubkeys plus monotonic snapshot version;
- supports ETag or equivalent unchanged responses.

`GET /internal/v1/supporters/changes`

- service-authenticated and cursor-based;
- returns ordered sanitized projection changes.

`GET /health`

- reports process health without secrets or private counts.

Signed push delivery to Funnelcake may complement the pull endpoints, but the
snapshot endpoint remains the repair path and source for reconciliation.

## 11. Purchase and restore flow

1. The signed-in user opens Support Divine.
2. Mobile loads store-localized product metadata.
3. Mobile captures the current pubkey in a durable purchase-attempt record.
4. Native StoreKit/Play Billing starts the transaction.
5. The device-scope listener receives the store result regardless of route or
   account-container lifetime.
6. Mobile durably records the proof needed for claim retry.
7. Mobile submits an NIP-98 claim for the captured pubkey.
8. The Worker verifies the store evidence and immutable ownership rule.
9. The Worker updates D1 and the projection outbox transactionally.
10. After successful claim, Mobile completes/acknowledges the store
    transaction. If the Worker remains unavailable, Mobile may do so only after
    durably retaining the account-bound claim attempt and encrypted-at-rest
    proof needed for retry, and always before the store deadline.
11. Funnelcake receives or reconciles the sanitized public projection.
12. Clients render the halo and Supporters surface from verified Divine data.

Store acknowledgement must not depend on the supporter screen remaining
mounted. The device-scope coordinator owns it. Acknowledgement does not grant
supporter status; only later Worker verification can do that. If the Worker is
unavailable, the durable attempt and store restore/redelivery paths retain
enough information to retry without attaching the transaction to a different
account.

Restore enumerates store purchases, claims them for the signed-in pubkey, and
lets the Worker enforce existing ownership. Restore never means rebind.

## 12. Funnelcake projection and discovery

Projection changes are applied idempotently by monotonic version. A periodic
full snapshot compares the Worker set with the Funnelcake projection and repairs
missed delivery in either direction.

Required read surfaces:

- supporter presentation field on relevant profile/author response models;
- paginated supporter directory;
- paginated engagement-ranked supporter videos; and
- enough projection freshness metadata for operational diagnosis.

Fair directory rotation must:

- include every active public supporter over repeated windows;
- avoid domination by high-engagement accounts;
- avoid multiple adjacent entries for the same account;
- remain stable within a browsing session or bounded rotation period; and
- apply ordinary moderation and viewer filters.

Supporter video ranking must reuse existing engagement signals and eligibility
rules. It adds one cohort filter; it does not create a second opaque ranking
system.

## 13. Mobile architecture

Follow `UI -> Cubit -> Repository -> Client`.

### 13.1 Device-scope store coordinator

The store purchase stream starts during app startup and survives account
container swaps. It:

- listens for purchase updates;
- completes required store acknowledgements;
- persists sensitive proof material in OS-backed secure storage and retries
  claim work;
- associates results with captured purchase attempts, not current ambient
  identity; and
- exposes account-neutral transaction progress.

No Cubit or screen owns the native purchase-stream subscription.

### 13.2 Account-scoped supporter repository

The account container supplies the immutable active pubkey. The repository:

- reads canonical entitlement from the Worker;
- starts purchase attempts through the device coordinator;
- claims/restores only for its pubkey;
- updates public visibility;
- maps typed API/store failures; and
- may cache the last verified private response for offline display, clearly
  timestamped and never used to grant public status.

### 13.3 Supporter Cubit and UI

The Cubit models explicit states for:

- loading product metadata;
- available to purchase;
- purchase pending;
- confirming with Divine;
- active;
- billing grace;
- expired;
- ownership conflict;
- store unavailable;
- verification unavailable; and
- restore result.

Async continuations check closure/account activity before emitting. Store error
types remain typed; localized store prose is not parsed to infer behavior.

### 13.4 Avatar integration

Add supporter decoration to the shared avatar component or a single shared
wrapper used by all avatar call sites. API models provide presentation state.
The halo must be tested against clipping, tiny sizes, large text, RTL layouts,
loading placeholders, missing profile images, and avatar tap targets.

### 13.5 Explore integration

Add a dynamically available `supporters` tab to the existing Explore tab model,
routes, localized labels, tab bar, grid/feed state, analytics, and route-title
mapping. The tab uses the same grid-to-fullscreen-feed navigation behavior as
Classics.

## 14. Security and privacy

- Purchase claims require NIP-98 authentication and exact body/URL binding.
- Worker store credentials live only in Cloudflare secrets.
- Apple signed data and Google notification authentication are verified before
  state mutation.
- Funnelcake integration uses dedicated service authentication and replay
  protection.
- Original store transactions are unique and immutable in ownership.
- No endpoint accepts a pubkey in place of authenticated identity for user
  mutation.
- Rate limits cover claim, restore, and visibility mutation.
- Receipt/token values are redacted at logger boundaries and prohibited from
  analytics.
- Mobile never stores receipt or purchase-token material in
  `SharedPreferences`; durable retries use OS-backed secure storage and delete
  proof material once it is no longer required.
- Full Nostr IDs are used internally and never truncated in logs or tests.
- Public APIs reveal only the boolean status the supporter explicitly leaves
  enabled.
- Visibility defaults on, but purchase UI explains it before confirmation and
  the control is available immediately afterward.
- Deleting a Divine account removes public projection and visibility state while
  retaining only financial records required for fraud prevention, reconciliation,
  or legal obligations under a documented retention policy.

## 15. Observability

Operational metrics use counts and typed reasons, never purchase evidence:

- verification success/failure by store and environment;
- notification lag, duplicate count, and dead-letter count;
- active/grace/expired/refunded transitions;
- unbound transaction count;
- projection delivery lag and reconciliation repairs;
- claim retry age;
- ownership conflicts; and
- Store-to-Worker and Worker-to-Funnelcake availability.

Alert on:

- notification verification failures;
- oldest undelivered outbox age;
- reconciliation divergence;
- claims approaching store acknowledgement deadlines;
- sudden entitlement drops; and
- repeated store API authentication failures.

## 16. Testing strategy

### 16.1 `divine-supporters`

- D1 migration tests.
- NIP-98 request-authentication and replay tests.
- Apple and Google verification fixtures.
- Original-transaction ownership conflict tests.
- Duplicate and out-of-order notification tests.
- Cancellation versus expiry tests.
- Grace, refund, revoke, and recovery tests.
- Multiple transactions for one pubkey.
- Visibility changes independent of payment.
- Transactional outbox and retry tests.
- Snapshot/delta reconciliation tests.
- Secret/log redaction tests.
- Sandbox versus production isolation.

### 16.2 Funnelcake

- Idempotent projection application.
- Snapshot drift repair.
- Fair directory coverage and session stability.
- Engagement ranking restricted to active public supporters.
- Expired/refunded/opted-out removal.
- Block, mute, moderation, age, and content-safety filtering.
- Profile and feed presentation-field serialization.
- Pagination and empty/error behavior.

### 16.3 Mobile

- Store listener starts at device scope.
- Purchase result survives route disposal.
- Purchase result survives account-container swap without rebinding.
- Pending does not clear active entitlement.
- Restore accepts the bound account and rejects another account.
- Worker outage persists and retries confirmation.
- Cubit close/dispose regression coverage.
- Typed failure mapping.
- Visibility toggle semantics.
- Full localization and ARB consistency.
- Shared halo widget tests at every supported avatar size.
- Golden tests for purchase, active, pending, grace, error, and Explore states.
- Explore directory/grid/feed navigation tests.
- Feature flag off/on tests.

### 16.4 End-to-end

Before enabling the feature:

- Apple sandbox purchase, restore, renewal, billing retry/grace, cancellation,
  refund/revoke, and new-device restore;
- Google license-tester purchase, acknowledgement, pending payment, renewal,
  grace/account hold where available, cancellation, refund/revoke, and restore;
- same Store account with a different Divine pubkey;
- account switch while the store sheet is open;
- app termination during purchase confirmation;
- Worker outage and recovery;
- missed projection delivery followed by reconciliation;
- opt-out and opt-in propagation; and
- moderation/block filtering in Supporters Explore.

## 17. Store and policy requirements

Before release:

- create the monthly product in App Store Connect and Google Play Console;
- choose the launch price and localized availability;
- add the iOS In-App Purchase capability and refresh signing profiles;
- configure App Store Server Notifications;
- configure Google Real-time Developer Notifications and API credentials;
- provide subscription terms, privacy links, restore, and management;
- explain the business model and recognition/discovery benefits in review notes;
- ensure store listing metadata discloses in-app purchases as required; and
- verify the subscription provides ongoing value across the user's devices.

References:

- [Apple App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
- [Google Play Payments policy](https://support.google.com/googleplay/android-developer/answer/9858738)

## 18. Rollout

1. Create `divinevideo/divine-supporters` and establish CI, preview/prod
   environments, D1 migrations, secrets policy, and threat model.
2. Deploy the Worker with user purchase endpoints disabled outside test
   environments.
3. Implement store verification and lifecycle processing with sandbox
   credentials.
4. Add Funnelcake projection and discovery behind server-side flags.
5. Refactor and harden mobile PR #6378 against the server authority and its
   outstanding money-path review findings.
6. Add shared halo decoration and Supporters Explore behind
   `FF_DIVINE_SUPPORTERS`.
7. Configure store products and native capabilities.
8. Complete sandbox end-to-end verification.
9. Enable for internal accounts and verify metrics/reconciliation.
10. Roll out through the existing feature-flag process.

Rollback disables purchase entry and the Supporters Explore tab while leaving
the Worker processing renewals, refunds, store notifications, and subscription
management. An app rollback must never stop server-side lifecycle processing
for people who already paid.

## 19. Acceptance criteria

The initiative is ready to enable only when:

- a purchase binds exactly one original store transaction to the intended
  Divine pubkey;
- verified status restores on another device for that same pubkey;
- another pubkey cannot claim the transaction;
- renewals, grace, cancellation, expiry, refund, and revoke update entitlement
  without the app running;
- public visibility defaults on and can be disabled without cancelling;
- halo and discovery disappear after effective expiry/refund or opt-out;
- halo placement matches the approved warm-gold perched design across shared
  avatar surfaces;
- the directory rotates fairly;
- supporter videos are engagement-ranked only inside Supporters Explore;
- general ranking is unchanged;
- no billing evidence appears in public APIs, Nostr, analytics, or logs;
- Worker and Funnelcake reconcile after dropped projection events;
- all relevant repository tests, mobile analysis, localization checks, design
  ratchets, and goldens pass; and
- Apple and Google sandbox lifecycle matrices pass on real builds.

## 20. Implementation decomposition

This is one product initiative but not one cross-repository patch. Implementation
plans must preserve these boundaries:

1. **`divine-supporters` foundation and canonical entitlement**
2. **Funnelcake projection and Supporters discovery**
3. **Mobile store lifecycle and server-backed entitlement**
4. **Mobile halo and Explore presentation**
5. **Store configuration and end-to-end rollout**

Each repository uses a focused branch and PR targeting its own `main`. Mobile
work continues from or deliberately supersedes PR #6378 only after takeover
review and conflict resolution under the shared PR runbook.
