# Divine supporters platform design

**Date:** 2026-07-26

**Status:** Approved product and architecture design

**Scope:** `divine-supporters` (new), Funnelcake, `divine-mobile`, and shared
profile/feed consumers

**Product owner:** Rabble

## 1. Summary

Divine will offer one optional supporter membership through Apple StoreKit and
Google Play Billing. The launch storefront products are standard monthly,
standard annual, and a bounded founding annual offer. All three grant the same
entitlement. A supporter funds Divine and, while their subscription is paid or
in billing grace, may receive:

- a warm-gold halo over their avatar throughout Divine;
- placement in a fairly rotating supporter directory on Explore; and
- eligibility to submit videos for consideration in bounded, clearly labelled
  Supporter Showcases;
- eligibility for selected experimental feature trials where separately enabled;
- visibility into what supporter funding pays for; and
- founding-supporter recognition where applicable.

The subscription does not unlock content or ordinary app functionality. It does
not boost For You, Popular, search, or any other general ranking system. Draft
and saved-clip sync is a future initiative, not a launch benefit or dependency.

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
| Initial offering | One supporter entitlement with monthly, annual, and bounded founding annual products |
| Price | US$6.99 monthly, US$69.99 annual, and US$59.99 founding annual; storefronts own localized display prices |
| Annual discount | The UI may describe the standard annual product as saving about 17% when supported by localized metadata |
| Founding offer | A predeclared bounded cohort or date window; same benefits as standard membership |
| Account ownership | Bound to the Divine pubkey active at purchase |
| Public recognition | Optional and separately modelled for halo, discovery, and founding history |
| Privacy control | Recognition can be disabled without cancelling payment or changing private entitlement |
| Expiry | Recognition remains through paid-through and billing grace, then disappears |
| Avatar treatment | Warm-gold halo at roughly 10–11 o'clock, slightly overlapping the avatar |
| Explore structure | Fairly rotating supporter directory plus bounded, labelled Supporter Showcases |
| Directory order | Fair rotation among active, visible supporters |
| Showcase selection | Published editorial and eligibility criteria; payment creates eligibility, not guaranteed placement |
| General ranking | Supporter state is unavailable to ordinary ranking systems |
| Sync | Explicitly deferred; no draft or saved-clip storage is part of launch |
| Canonical status | Server-verified entitlement, not local store state and not NIP-58 |
| Experimental access | Feature-specific, separately enabled, private, and never a gate on ordinary Divine functionality |
| Impact reporting | Authoritative aggregate counts and broad funding-use reporting; no invented per-user claims |
| Server ownership | New `divine-supporters` GitHub repository and Cloudflare Worker |

## 3. Goals

1. Let people fund Divine with a clear, recurring native-store subscription.
2. Celebrate active supporters without creating a paywall or a wealth-tier
   hierarchy.
3. Give supporters optional, transparent recognition and bounded discovery
   surfaces without altering organic ranking elsewhere.
4. Bind purchases safely to one Divine identity across devices.
5. Handle renewals, grace periods, refunds, revocations, restores, and account
   switching without relying on the app process.
6. Keep store evidence and financial metadata private.
7. Make the public status consumable by mobile, web, and future Divine clients
   through ordinary profile/feed APIs.
8. Explain what supporter funding pays for using reliable aggregate reporting.

## 4. Non-goals

- Multiple supporter tiers at launch.
- Paid access to content, posting, messaging, storage, ranking, verification,
  or moderation privileges.
- Draft and saved-clip sync, storage quotas, export, or retention changes at
  launch. Those belong to a separately approved future initiative.
- Boosting supporter posts in For You, Popular, search, lists, or hashtag
  results.
- An engagement-ranked feed consisting only of paying authors.
- Guaranteed placement in a Supporter Showcase.
- Transfer of a subscription between Divine pubkeys.
- Publishing purchase evidence or billing state to Nostr.
- Using NIP-58 as the canonical recurring entitlement.
- Permanent alumni or lifetime-supporter recognition after payment ends.
- External checkout inside the native supporter flow.
- Making supporter membership a general-purpose cloud-storage product.
- Replacing creator-controlled profile tip and subscription links delivered by
  `divine-mobile` PR
  [#5665](https://github.com/divinevideo/divine-mobile/pull/5665).

## 5. User experience

### 5.1 Entry point

Behind `FeatureFlag.divineSupporters`, Settings includes a **Support Divine**
entry. The screen uses direct Divine voice:

- heading: **Support Divine**
- primary message: **Help keep human creativity independent, weird, and alive.**
- supporting copy explains that supporter funding helps pay for video hosting
  and delivery, trust and safety, human-made authenticity systems, independent
  product development, preservation of internet culture, and open and
  decentralized infrastructure;
- the screen says the ordinary Divine experience remains available without
  payment;
- store-localized monthly, annual, and founding prices are shown when
  available;
- the annual saving is shown only when supported by localized store metadata;
- the screen explains that recognition is optional, the halo is not
  verification, and Showcase inclusion is never guaranteed;
- any experimental access is described as a separate, limited trial and never
  as a promise of a particular feature or release date;
- Restore Purchases, Terms, Privacy, and native subscription-management links
  remain accessible; and
- supporter-impact information is available from the screen.

The screen must clearly state that the halo, directory, and Showcase eligibility
are recognition/discovery benefits. It must not imply that payment improves
general ranking, moderation, verification, or ordinary access.

### 5.2 Active state

After the Worker verifies the purchase for the current pubkey, the screen shows:

- active paid-through or billing-grace state;
- the account that owns the subscription;
- the halo preview;
- public-recognition controls;
- founding-supporter history controls where applicable;
- supporter-impact information;
- experimental-trial availability where separately enabled;
- native subscription-management action; and
- a clearly presented recognition control before or immediately after purchase:

> **Show that I'm a supporter.**

The data model permits separate controls for halo visibility, directory and
Showcase discovery, and founding-history visibility. A combined v1 control is
acceptable only when the screen explains all of its effects.

Turning recognition off:

- hides the halo on every public surface;
- removes the account from the supporter directory;
- removes the account from future Supporter Showcase consideration;
- does not cancel, pause, refund, transfer, or otherwise mutate payment.

Recognition must not default to public exposure before the purchase flow has
presented these effects to the user.

### 5.3 Pending and confirmation

A store purchase is not treated as a public entitlement until the Worker
verifies it. While verification is pending, the screen says **Confirming your
support**. It does not show an unverified halo.

A pending renewal or second purchase never replaces an already verified active
entitlement with an inactive state.

### 5.4 Expiry, refund, and grace

- Cancellation keeps benefits through the paid-through date.
- Store billing grace keeps benefits while the store reports grace.
- Expiry removes the active halo, directory eligibility, Showcase eligibility,
  and any experimental-trial eligibility.
- Refund or revocation removes benefits according to the canonical store state.
- A permanent, optional founding-supporter history entry may remain after
  expiry, but it must not imply active support or preserve active benefits.
- If more than one valid store transaction exists for the same pubkey, the
  account remains active while any one entitlement remains valid.

### 5.5 Account switching and restore

The purchase attempt captures the active pubkey at initiation. An async store
result cannot be attached to whichever account happens to be active later.

If the captured pubkey is no longer the active authenticated account when a
retry is needed, the attempt remains queued for that pubkey and is not retried
with the current account. The user must sign back into the captured account (or
the account's signer must otherwise become available) before the claim can be
sent. A store result is never silently discarded or rebound because of an
account switch.

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
2. bounded, clearly labelled Supporter Showcase collections that open the
   standard fullscreen feed.

The directory rotates fairly among active, publicly visible supporters.
Rotation must be deterministic for a bounded period so it does not jump on
every rebuild, while changing often enough to expose smaller and newer
supporters.

Showcase collections are selected from active, publicly visible supporters who
opted into consideration. They are restricted to:

- indexed, playable, moderation-eligible videos;
- authors with an active public supporter projection;
- videos allowed by the current viewer's block, mute, age, and content-safety
  rules; and
- published Showcase criteria and cadence; and
- diversity and repeated-exposure limits across creators and content.

Recent eligible videos published before the author subscribed may appear while
the author is active. Payment creates eligibility to submit or opt into
consideration; it does not guarantee placement. Selection must not use support
amount, price, billing period, founding status, tenure, or payment as an
engagement multiplier. When the author expires, is refunded, revoked, or opts
out, their videos leave future Showcase selection according to the published
refresh and safety policy.

The Supporters tab must not become an infinite engagement-ranked feed whose only
distinguishing criterion is payment. Existing engagement signals may be used
only as one bounded quality or abuse-resistance input after editorial and
eligibility constraints, never as the definition of the surface.

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
          +--- private aggregate supporter-impact data
          |
          +--- signed sanitized projection changes
                         |
                         v
                    Funnelcake
                         |
                         +--- supporter directory
                         +--- Supporter Showcases
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
- recognition preferences;
- founding cohort eligibility and historical recognition;
- idempotency, audit history, and reconciliation;
- sanitized projection outbox;
- private account entitlement API;
- supporter-count and funding-use aggregates; and
- operational health and metrics.

It does not rank or serve videos and does not issue Nostr badges.

#### Funnelcake

Owns:

- a local projection of active public supporter pubkeys;
- idempotent application of Worker projection changes;
- periodic snapshot reconciliation;
- fair supporter-directory rotation;
- bounded Supporter Showcase retrieval and eligibility filtering;
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
- Supporters Explore tab with directory and bounded Showcase collections; and
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
- `halo_visible` — boolean;
- `discovery_visible` — boolean;
- `founding_history_visible` — boolean;
- `recognition_choice_recorded_at`;
- `created_at`;
- `updated_at`; and
- `visibility_version` — monotonic version for projection ordering.

This table does not claim the account is active. Activity is derived from
verified store transactions. Recognition fields must not expose a purchaser
before the purchase UI has clearly presented the recognition controls.

### 8.2 `store_transactions`

One row per original store subscription transaction:

- `store` — `apple` or `google`;
- `original_transaction_lookup` — keyed HMAC of the store and original
  transaction identifier, unique and used only for equality lookup;
- `original_transaction_ciphertext` — application-layer AES-GCM encryption of
  the original identifier using a versioned Worker secret;
- `verification_artifact_ciphertext` — application-layer encryption of any
  renewable store token or artifact required for later canonical verification;
- `pubkey` — nullable until first successful binding, then immutable owner;
- `product_id`;
- `plan_kind` — monthly, annual, or founding annual;
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
- `founding_history_public` boolean where applicable;
- canonical effective time;
- reason code;
- created time; and
- delivery/retry state.

The public projection contains no store, product, price, transaction, billing,
or contribution fields.

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

Private entitlement is true when at least one transaction for the pubkey is
`active`, or `grace` within its verified grace window. `grace` retains the same
public benefits as `active` until the verified grace window ends. The public
projection is derived from that entitlement plus the account's recognition
preferences. A transient `unknown` result preserves the newest known
`active`/`grace` projection until canonical store verification establishes a
newer state; it cannot remove benefits on its own.

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
- Body includes a client-generated idempotency key scoped to the captured
  pubkey and store transaction attempt.
- The authenticated pubkey is the requested owner.
- The operation is idempotent.
- Returns the canonical account entitlement, not an optimistic local state.

`GET /v1/me`

- NIP-98 authentication is required.
- Returns normalized private entitlement state, paid/grace timing suitable for
  UI, recognition preferences, founding history, experimental-trial
  eligibility, supporter-impact data, and typed management/repair status.
- Does not echo store proofs or transaction identifiers.

`PATCH /v1/me/recognition`

- NIP-98 authentication is required.
- Accepts the supported recognition preferences. A combined boolean may be
  used by the v1 UI, but the API and data model must allow halo, discovery, and
  founding-history visibility to separate later.
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
6. Mobile durably records the proof needed for claim retry in OS-backed secure
   storage, along with the captured pubkey and idempotency key.
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
- paginated, bounded Supporter Showcase collections; and
- enough projection freshness metadata for operational diagnosis.

Fair directory rotation must:

- include every active public supporter over repeated windows;
- avoid domination by high-engagement accounts;
- avoid multiple adjacent entries for the same account;
- remain stable within a browsing session or bounded rotation period; and
- apply ordinary moderation and viewer filters.

Supporter state must not be passed to ordinary For You, Popular, search,
hashtag, list, notification, or ordinary Explore ranking services. The
Supporter Showcase service applies published criteria, diversity limits,
moderation eligibility, and bounded exposure. Engagement may be used only as a
bounded quality or abuse-resistance input after those constraints; it must not
turn the Showcase into a paid-only version of Popular.

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

Each durable purchase attempt contains the captured full pubkey, store and
product identifiers, an idempotency key, lifecycle status, and the minimum
encrypted proof needed for retry. It is deleted after the Worker reaches a
terminal claim result and the native store transaction has been safely
completed. If the captured signer is unavailable after an account switch, the
coordinator keeps the attempt pending without sending it as another identity.

No Cubit or screen owns the native purchase-stream subscription.

### 13.2 Account-scoped supporter repository

The account container supplies the immutable active pubkey. The repository:

- reads canonical entitlement from the Worker;
- starts purchase attempts through the device coordinator;
- claims/restores only for its pubkey;
- updates recognition preferences;
- updates recognition preferences independently of payment;
- reports feature-specific experimental-trial eligibility without exposing it
  in public profile or discovery projections;
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
routes, localized labels, tab bar, directory and Showcase collection state,
analytics, and route-title mapping. Showcase playback uses the same
grid-to-fullscreen-feed navigation behavior as Classics, but the tab does not
expose an engagement-ranked paid cohort feed.

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
- Public APIs reveal only recognition state the supporter explicitly leaves
  enabled.
- Recognition defaults to private until the purchase UI has presented the
  controls and the supporter has made a choice.
- Deleting a Divine account removes public projection and visibility state while
  retaining only financial records required for fraud prevention, reconciliation,
  or legal obligations under a documented retention policy.

## 15. Supporter impact and transparency

The Support Divine screen includes an impact section backed by authoritative
aggregate data. It may show:

- total active supporters;
- founding-supporter count;
- broad monthly funding goals;
- broad categories of supporter-funded work; and
- reliable, qualified coverage percentages where accounting supports them.

Permitted categories include video hosting and bandwidth, moderation and trust
and safety, human-made authenticity systems, independent app development,
preservation of recovered internet culture, open-source work, and decentralized
infrastructure.

The service must not invent direct per-user impact calculations. It must not
claim that one subscription pays for a precise quantity of storage, moderation,
or video delivery unless the calculation is current, reproducible, and
appropriately qualified.

Public supporter counts include active paid and grace entitlements, exclude
complimentary testing entitlements, count each annual subscriber as one
supporter, and are updated on a documented cadence. Identity is never exposed
without recognition opt-in. Counts may be withheld until they are large enough
to avoid misleading scarcity signals.

Impact copy may come from an authenticated configuration source, but counts and
funding coverage must come from authoritative aggregate data.

## 16. Observability

Operational metrics use counts and typed reasons, never purchase evidence:

- verification success/failure by store and environment;
- notification lag, duplicate count, and dead-letter count;
- active/grace/expired/refunded transitions;
- unbound transaction count;
- projection delivery lag and reconciliation repairs;
- claim retry age;
- ownership conflicts;
- active supporter and founding-supporter aggregate refresh age; and
- Store-to-Worker and Worker-to-Funnelcake availability.

Alert on:

- notification verification failures;
- oldest undelivered outbox age;
- reconciliation divergence;
- claims approaching store acknowledgement deadlines;
- sudden entitlement drops; and
- repeated store API authentication failures.

## 17. Testing strategy

### 17.1 `divine-supporters`

- D1 migration tests.
- NIP-98 request-authentication and replay tests.
- Apple and Google verification fixtures.
- Original-transaction ownership conflict tests.
- Duplicate and out-of-order notification tests.
- Cancellation versus expiry tests.
- Grace, refund, revoke, and recovery tests.
- Multiple transactions for one pubkey.
- Visibility changes independent of payment.
- Founding cohort boundary and founding-history visibility tests.
- Supporter-impact aggregate counting and complimentary-entitlement exclusion.
- Transactional outbox and retry tests.
- Snapshot/delta reconciliation tests.
- Secret/log redaction tests.
- Sandbox versus production isolation.

### 17.2 Funnelcake

- Idempotent projection application.
- Snapshot drift repair.
- Fair directory coverage and session stability.
- Bounded Showcase eligibility, criteria, diversity, and exposure limits.
- Expired/refunded/opted-out removal.
- Ordinary ranking outputs are unchanged when supporter projections are enabled.
- Block, mute, moderation, age, and content-safety filtering.
- Profile and feed presentation-field serialization.
- Pagination and empty/error behavior.

### 17.3 Mobile

- Store listener starts at device scope.
- Purchase result survives route disposal.
- Purchase result survives account-container swap without rebinding.
- Pending does not clear active entitlement.
- Grace retains active recognition until the verified grace window ends.
- Restore accepts the bound account and rejects another account.
- Worker outage persists and retries confirmation.
- Cubit close/dispose regression coverage.
- Typed failure mapping.
- Visibility toggle semantics.
- Experimental-trial eligibility is private, feature-specific, and removed at
  effective expiry or revocation.
- Impact screen uses authoritative aggregate data and does not invent per-user
  claims.
- Full localization and ARB consistency.
- Shared halo widget tests at every supported avatar size.
- Golden tests for purchase, active, pending, grace, error, and Explore states.
- Explore directory/grid/feed navigation tests.
- Showcase collections are labelled and do not behave as an engagement-ranked
  paid cohort feed.
- Feature flag off/on tests.

### 17.4 End-to-end

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

## 18. Store and policy requirements

Before release:

- create standard monthly, standard annual, and bounded founding annual
  products in App Store Connect and Google Play Console;
- configure US$6.99 monthly, US$69.99 annual, and US$59.99 founding annual
  reference prices, with localized storefront prices owned by each store;
- declare the founding cohort boundary and renewal behavior before launch;
- add the iOS In-App Purchase capability and refresh signing profiles;
- configure App Store Server Notifications;
- configure Google Real-time Developer Notifications and API credentials;
- provide subscription terms, privacy links, restore, and management;
- explain the business model and recognition/discovery benefits in review notes;
- ensure store listing metadata discloses in-app purchases as required; and
- verify the membership provides ongoing supporter value without promising
  storage, sync, ranking, verification, or ordinary functionality.

References:

- [Apple App Review Guidelines](https://developer.apple.com/app-store/review/guidelines/)
- [Google Play Payments policy](https://support.google.com/googleplay/android-developer/answer/9858738)

## 19. Rollout

1. Create `divinevideo/divine-supporters` and establish CI, preview/prod
   environments, D1 migrations, secrets policy, and threat model.
2. Deploy the Worker with user purchase endpoints disabled outside test
   environments.
3. Implement store verification and lifecycle processing with sandbox
   credentials.
4. Add Funnelcake projection and discovery behind server-side flags.
5. Refactor and harden mobile PR #6378 against the server authority. Resolve
   its known money-path blockers before reuse: app-start store-listener
   ownership, purchase-stream error handling, Cubit close/dispose behavior,
   pending-entitlement preservation, localization/design-system violations,
   and red Format, Generated Files, or `iap_repository` analyze checks.
6. Add shared halo decoration and Supporters Explore behind
   `FF_DIVINE_SUPPORTERS`.
7. Add supporter-impact aggregates and the labelled Showcase presentation.
8. Configure store products and native capabilities.
9. Complete sandbox end-to-end verification.
10. Enable for internal accounts and verify metrics/reconciliation.
11. Roll out through the existing feature-flag process.

Rollback disables purchase entry and the Supporters Explore tab while leaving
the Worker processing renewals, refunds, store notifications, and subscription
management. An app rollback must never stop server-side lifecycle processing
for people who already paid.

## 20. Acceptance criteria

The initiative is ready to enable only when:

- a purchase binds exactly one original store transaction to the intended
  Divine pubkey;
- monthly, annual, and founding annual products map to one equal-benefit
  entitlement;
- verified status restores on another device for that same pubkey;
- another pubkey cannot claim the transaction;
- renewals, grace, cancellation, expiry, refund, and revoke update entitlement
  without the app running;
- grace preserves active recognition only through the verified grace window, and
  experimental access is removed at effective expiry or revocation;
- recognition remains private until explicitly chosen and can be disabled
  without cancelling;
- halo, directory eligibility, and Showcase eligibility disappear after
  effective expiry/refund or opt-out;
- halo placement matches the approved warm-gold perched design across shared
  avatar surfaces;
- the directory rotates fairly;
- Supporter Showcases are bounded, labelled, criteria-driven, and do not
  guarantee placement;
- supporter amount, plan, founding status, and tenure do not affect selection;
- impact counts exclude complimentary access and do not make invented per-user
  claims;
- general ranking is unchanged;
- no billing evidence appears in public APIs, Nostr, analytics, or logs;
- Worker and Funnelcake reconcile after dropped projection events;
- all relevant repository tests, mobile analysis, localization checks, design
  ratchets, and goldens pass; and
- Apple and Google sandbox lifecycle matrices pass on real builds.

## 21. Implementation decomposition

This is one product initiative but not one cross-repository patch. Implementation
plans must preserve these boundaries:

1. **`divine-supporters` foundation, canonical entitlement, and impact aggregates**
2. **Funnelcake projection, fair directory, and bounded Supporter Showcases**
3. **Mobile store lifecycle and server-backed entitlement**
4. **Mobile halo, recognition controls, and Explore presentation**
5. **Store configuration and end-to-end rollout**

Draft and saved-clip sync is intentionally absent from every launch slice. It
requires a separate product and architecture design before implementation.

Each repository uses a focused branch and PR targeting its own `main`. Mobile
work continues from or deliberately supersedes PR #6378 only after takeover
review and conflict resolution under the shared PR runbook.
