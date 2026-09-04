# Retired Moderation Keys

Divine's moderation account is a Nostr identity, and it has rotated. A DM
thread opened before a rotation stays keyed on the old pubkey forever — Nostr
has no way to move a conversation to a new key — so the app has to keep
recognising identities it will never talk to again.

`kLegacyModerationPubkeys` in `mobile/lib/config/official_accounts.dart` is
that recognition list. This file is its register: what each entry was, when it
stopped being the moderation account, and what the client still does with it.

Read this before adding an entry.

## The register

| Pubkey | Retired | Rotated by | Private key |
|---|---|---|---|
| `121b915baba659cbe59626a8afaf83b01dc42354dfecaad9d465d51bb5715d72` | 2026-03-12 | An operational secret change, carrying no PR of its own — see below | Unrecovered — see [Key custody](#key-custody) |

### `121b915b…`

Rotated because the service and the clients had drifted onto different keys.
It held **three** roles, which is the part worth knowing — retiring a
moderation key is not one revocation:

| Role | Revoked |
|---|---|
| Moderation DM, label, and report signing identity | 2026-03-12 by the secret rotation itself — though only for labels and reports; the DM half is unverifiable, see below |
| Funnelcake `RELAY_PUBKEY`, plus one of the two `ADMIN_PUBKEYS` entries | 2026-03-17, `divinevideo/divine-iac-coreconfig#280`, across the poc, test, staging, and production overlays |
| NIP-32 labeler this app subscribed to | 2026-03-20, `divinevideo/divine-mobile#2321` — plus `ModerationLabelService._migrateLegacyPubkey`, which unsubscribes it on every init |

#### Dating the rotation

No PR performed it, so every PR this gets credited to is the wrong answer. The
rotation was a secret change, and neither key appears anywhere in
`divine-moderation-service`'s history — `git log --all -S<hex>` returns nothing
for either. What *can* be dated, in UTC:

| When | What |
|---|---|
| 2026-03-12 22:50:41 | The incoming key's kind-0 is signed and published to `relay.divine.video` (`17e11af3…`) |
| 2026-03-12 22:54:42 | `divine-iac-coreconfig#280` is opened, recording NIP-05 as already repointed, kind-0 as published, and the incoming key as verified through moderation-service's debug endpoint — which derived its answer from `NOSTR_PRIVATE_KEY` alone |
| 2026-03-13 01:57:35 | `divine-moderation-service#31` is authored, describing label publishing as broken "since the key rotation" |
| 2026-03-15 15:39:37 | #31 merges |
| 2026-03-17 15:32:10 | #280 merges |
| 2026-03-20 14:54:11 | `divine-mobile#2321` merges |

The signing secret therefore already resolved to the incoming key on
**2026-03-12** — three days before the earliest PR this is usually credited to,
and eight before the latest.

Both of the usual citations name a merge date rather than the act:

- `divine-mobile#2321` (2026-03-20) is the client catching up, eight days late.
- `divine-moderation-service#31` (2026-03-15) is the cleanup. It removed the
  superseded `MODERATOR_NSEC` path and fixed the label publishing the rotation
  had just broken. Its own text dates the rotation to "today" — and it was
  written on the 13th, not the 15th it merged on.

One part is genuinely unrecoverable. DM signing read `MODERATOR_NSEC`, a secret
with no git trace, so whether the DM role moved on the 12th with everything
else or lingered until #31 removed that path on the 15th cannot be established
from any repo. Labels and reports are pinned to the 12th; treat the DM half as
"on or before 2026-03-15".

Do not read that middle row as "the relay admin key", despite `RELAY_PUBKEY`.
`divine-iac-coreconfig#280` uses the phrase *relay admin pubkey* for a
different identity —
`81549bc0b5153b4b970fe4a3892ad185698b8b8b26ec69321a527d0644cd2898` — and states
in the same PR that it is **unchanged** by the rotation. `ADMIN_PUBKEYS` was a
two-entry list holding both keys, and only the `121b915b…` entry was replaced;
`81549bc0…` sits untouched on both sides of every edit. So a rotation that goes
looking for "the relay admin key" finds `81549bc0…` and changes the wrong
thing. Match on the variable name, not the prose.

Funnelcake's `nostr.trusted_labelers` and `nostr.moderation_sources` tables are
a third trust surface, distinct from both of the above. Their configured
identity differs from the user-facing moderation account — it is `81549bc0…`
as well, so that key holds this role on top of relay admin. Whether that is an
intentional automated role or drift is tracked in
`divinevideo/divine-mobile#8253`. A rotation must audit and reconcile those
tables with the intended labeler roles rather than assuming every moderation
role uses the shared support identity.

## What the client does with a retired key

| Behaviour | Where |
|---|---|
| Recognised as moderation — official display name and inbox search name | `dm_peer_identity.dart`, `moderation_identity.dart`, and `dm_peer_name.dart`, via `isModerationAccount` |
| Recognised as moderation — bundled wordmark avatar | `conversation_tile.dart`, `request_tile.dart`, `request_preview_view.dart`, `empty_conversation.dart` |
| Conversation and request rows labelled closed | `conversation_tile.dart` and `request_tile.dart`, via `isRetiredModerationAccount` |
| Composer closed; banner routes replies to the current support key | `conversation_view.dart`, via `isRetiredModerationAccount` and `kModerationPubkeyHex` |
| Pinned support row, unread partition, and retired predicates wired into list state | `inbox_page.dart`, `message_requests_page.dart`, `app_shell_badge_scope.dart`, and `ConversationListBloc` |
| Destructive request action withheld for moderation threads | `request_preview_view.dart`, via `isModerationAccount` |
| Outbound sends refused and retained as non-retryable evidence | `dmSendPolicyProvider` → `DmSendPolicyDecision.terminallyBlockedRetain` |
| Pre-rotation threads excluded from pinned-support adoption | `DmRepository.extractPinnedSupport` |
| Labeler subscription migrated to the current key | `ModerationLabelService._migrateLegacyPubkey` |

`isModerationAccount` answers *"is this the moderation team"* and is true for
retired keys on purpose, so old threads still read correctly.
`isRetiredModerationAccount` answers *"is this a key we can still talk to"*.
Anything picking a **send target** must use `kModerationPubkeyHex` and neither
predicate.

Recognition is keyed on the pubkey alone: it does not consider when a message
arrived relative to the rotation. The repository layer is nevertheless
retired-key-aware at the two delivery seams that matter: the injected
`DmSendPolicy` blocks every outbound publisher at the lowest send primitive,
and pinned-support extraction avoids adopting a pre-rotation thread whose
participants would route replies to the retired key. Whether a *newly
discovered* event from a retired key should keep Divine's official name and
wordmark is a separate recognition decision, tracked in
`divinevideo/support-trust-safety#211`. The retirement and custody protocol it
depends on is tracked in `divinevideo/support-trust-safety#199`.

## Rotating the moderation key

The client half is small and belongs in one PR:

1. Add the outgoing pubkey to `kLegacyModerationPubkeys`, with a comment
   naming the date and what performed the rotation — date it from the act,
   not from the merge of whatever PR cleaned up after it, and expect that
   there may be no commit to name at all.
2. Add a row to [the register](#the-register) above, including every role the
   key held — check Funnelcake's `RELAY_PUBKEY` and `ADMIN_PUBKEYS` and the
   labeler roles, not just DM signing.
3. Update `kModerationPubkeyHex` to the incoming shared support key. This is a
   mandatory routing change: the constant is the report target, pinned support
   row destination, protected-minor gate anchor, unread partition, retired
   thread redirect target, and `ModerationLabelService`'s NIP-05 fallback. A
   stale value silently routes support traffic to the retired account even
   when live NIP-05 resolution succeeds elsewhere. Treat this step as
   transitional: `divinevideo/divine-mobile#8355` decided on 2026-08-31 that
   the client should resolve the moderation identity through NIP-05 instead of
   a shipped pubkey, so that rotation no longer needs an app release.
   `divinevideo/divine-mobile#8253` owns that change; until it lands, a
   rotation still needs one.
4. Confirm `ModerationLabelService._migrateLegacyPubkey` covers the new entry
   — it reads the list, so it does, but the test should say so.
5. Record the outgoing key's [custody status](#key-custody). Unrecovered means
   the closed composer is permanent for it; archived means the reader could in
   principle be pointed at it, and the decision is then a real one.

The service and infrastructure half — rotating the signing key, updating
Funnelcake's `RELAY_PUBKEY` and its `ADMIN_PUBKEYS` allowlist (replacing only
the outgoing entry), republishing kind-0 and kind-10050,
repointing NIP-05, and auditing Funnelcake's `nostr.trusted_labelers` and
`nostr.moderation_sources` — lives outside this repo. Do not assume those trust
tables must use the user-facing support key: reconcile them with the approved
human-support and automated-labeler roles in `divinevideo/divine-mobile#8253`.
No step-by-step service procedure is written down. The *current*-identity model
was settled on 2026-08-31 (`divinevideo/divine-mobile#8355`); what a retirement
has to do is still open at `divinevideo/support-trust-safety#199`.

### What a rotation cannot fix

Messages already sent to the outgoing key are unreachable, for two independent
reasons — which matters, because only the second one is permanent.

The DM reader derives its subscription from its own signing key
(`divine-moderation-service`, `src/nostr/dm-reader.mjs`), so it watches exactly
one pubkey and cannot be configured to watch a second. Anything addressed to a
retired key is accepted by the relay and read by nobody — it does not error,
bounce, or queue. That much is a code limitation, and someone could lift it.

What cannot be lifted is custody. Reading those messages needs the retired
private key, because a gift wrap is encrypted to its recipient; a watched-set
in the reader would deliver ciphertext nobody can open. So for a key whose
private half is unrecovered — which is the status of the only entry in this
register — the composer is closed permanently rather than pending a backlog
item. Record each new entry's [custody status](#key-custody) so the next
rotation does not have to rediscover which of the two reasons applies.

Retired keys also publish no kind-10050. Under NIP-17 that already signals "not
ready to receive messages", so the protocol and the client agree.

## Key custody

No moderation key material has ever been committed to this repo, and none is
recoverable from it. Custody of live signing keys is owned by Trust & Safety
and is deliberately not described here. For a future register entry, obtain
the custody status from Trust & Safety or the operator responsible for the
rotation and record only the public-safe result here; do not infer it from this
repo.

One custody fact does belong in the register, because a shipped client
behaviour rests on it and looked provisional without it.

**`121b915b…` has no known private-key holder. Treat it as unrecovered, not as
archived somewhere.** It is an early key from Divine's initial setup — it
enters this repo on 2026-02-25 in `divinevideo/divine-mobile#1797`
(`ba51840a2`), as `ModerationLabelService.divineModerationPubkeyHex`, 15 days
before the rotation — and the operator who later rotated it out was not the one
who created it. Established on the 2026-08-31 support call and confirmed by the
rotating operator on `divinevideo/divine-mobile#7851`.

That is not a gap to be closed later. It is what makes the closed composer
correct **by fact rather than by policy**, and it retires the "if the nsec
turns up, reopen the thread" branch that
`divinevideo/support-trust-safety#199` had been holding open for this key:

- Gift wraps addressed to a retired key are NIP-44-encrypted to it. Without
  that private key nobody can read them — not Trust & Safety, not a future
  DM reader, not us. So watching the key is impossible rather than merely
  unimplemented, which is the stronger half of the argument in
  [What a rotation cannot fix](#what-a-rotation-cannot-fix).
- Recognition is therefore the only control this key still has behind it, and
  recognition is what `kLegacyModerationPubkeys` provides. Every other role it
  held was revoked either operationally or by the client's subscription
  migration — see the roles table above.

Do not re-litigate the composer for this key. A future retirement is a
different question: what makes a key retired, how access is revoked, where
remaining private material lives, how a retired identity is proved
unreactivatable, and how a replacement is announced. That protocol is owned by
`divinevideo/support-trust-safety#199`, and the mobile behaviour that follows
from it by `divinevideo/divine-mobile#7851`. This custody result does not settle
whether newly discovered events from this retired key should retain official
Divine branding; `divinevideo/support-trust-safety#211` owns that decision.

## Open items

- `divinevideo/support-trust-safety#199` — the retirement protocol: what makes
  a key retired, how access is revoked, where remaining private material is
  held, how a retired identity is proved unreactivatable, and how a
  replacement is announced and verified. The custody branch is already closed
  for `121b915b…`; this is for the next one.
- `divinevideo/support-trust-safety#211` — decide whether newly discovered
  events signed by a retired moderation key should retain Divine's official
  name and wordmark. Custody is settled for the current register entry, but
  that inbound recognition decision remains open.
- `divinevideo/divine-mobile#7851` — the mobile behaviour that follows from
  the retirement protocol. Its send predicate and closed composer are settled
  for the entry currently in the register; the recognition question is tracked
  separately in `divinevideo/support-trust-safety#211`.
- `divinevideo/divine-mobile#8253` — resolve the moderation identity through
  NIP-05 rather than a shipped pubkey, and reconcile Funnelcake's trusted
  labeler with the user-facing support identity.

Settled, kept here because the register used to cite it as open:
`divinevideo/divine-mobile#8355` decided on 2026-08-31 that shared access to
the current moderation identity stays acceptable, and that the client should
resolve that identity through NIP-05. It did not cover retirement.
