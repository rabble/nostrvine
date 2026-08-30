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

| Pubkey | Retired | Rotated by |
|---|---|---|
| `121b915baba659cbe59626a8afaf83b01dc42354dfecaad9d465d51bb5715d72` | 2026-03-15 | `divine-moderation-service#31` (`8dd56cbc9`), which unified signing on `NOSTR_PRIVATE_KEY` |

### `121b915b…`

Rotated because the service and the clients had drifted onto different keys.
It held **three** roles, which is the part worth knowing — retiring a
moderation key is not one revocation:

| Role | Revoked |
|---|---|
| Moderation DM + label signing identity | 2026-03-15, by the rotation itself |
| Relay admin pubkey | 2026-03-17, in the infrastructure config, across all four environments |
| NIP-32 labeler this app subscribed to | 2026-03-20, `divine-mobile#2321` — plus `ModerationLabelService._migrateLegacyPubkey`, which unsubscribes it on every init |

`divine-mobile#2321` is frequently cited as the retirement. It is not — it is
the client catching up five days later. The key stopped being the moderation
account on 2026-03-15.

## What the client does with a retired key

| Behaviour | Where |
|---|---|
| Recognised as moderation — official display name | `moderation_identity.dart`, via `isModerationAccount` |
| Recognised as moderation — bundled wordmark avatar | `conversation_tile.dart`, `request_tile.dart`, `request_preview_view.dart`, `empty_conversation.dart` |
| Composer closed, thread labelled retired | `conversation_view.dart`, via `isRetiredModerationAccount` |
| Outbound sends refused at the policy layer | `dmSendPolicyProvider` → `terminallyBlocked` |
| Labeler subscription migrated to the current key | `ModerationLabelService._migrateLegacyPubkey` |

`isModerationAccount` answers *"is this the moderation team"* and is true for
retired keys on purpose, so old threads still read correctly.
`isRetiredModerationAccount` answers *"is this a key we can still talk to"*.
Anything picking a **send target** must use `kModerationPubkeyHex` and neither
predicate.

Recognition is keyed on the pubkey alone: it does not consider when a message
arrived relative to the rotation, and the layers below the UI — `dm_repository`
included — have no notion of a retired key at all. Whether that should change
is an open product question, tracked with the custody work rather than here.

## Rotating the moderation key

The client half is small and belongs in one PR:

1. Add the outgoing pubkey to `kLegacyModerationPubkeys`, with a comment
   naming the rotation commit and date.
2. Add a row to [the register](#the-register) above, including every role the
   key held — check for relay admin and labeler roles, not just DM signing.
3. Update `kModerationPubkeyHex` to the incoming key. It is the NIP-05
   fallback; live resolution of `moderation@divine.video` is the primary path,
   so a stale constant fails quietly rather than loudly.
4. Confirm `ModerationLabelService._migrateLegacyPubkey` covers the new entry
   — it reads the list, so it does, but the test should say so.

The service and infrastructure half — rotating the signing key, updating the
relay admin list, republishing kind-0 and kind-10050, repointing NIP-05 — lives
outside this repo. No step-by-step procedure for it is written down anywhere;
the March 2026 rotation had to be reconstructed from PR bodies after the fact.
If you run the next one, write it down.

### What a rotation cannot fix

Messages already sent to the outgoing key are unreachable. The DM reader
derives its subscription from its own signing key
(`divine-moderation-service`, `src/nostr/dm-reader.mjs`), so it watches exactly
one pubkey and cannot be configured to watch a second. Anything addressed to a
retired key is accepted by the relay and read by nobody — it does not error,
bounce, or queue. This is why the composer is closed rather than optimistic.

Retired keys also publish no kind-10050. Under NIP-17 that already signals "not
ready to receive messages", so the protocol and the client agree.

## Key custody

No moderation key material has ever been committed to this repo, and none is
recoverable from it. Custody of the signing keys themselves is owned by Trust &
Safety and tracked on their private issue tracker, not here — including for
retired keys. If you need the custody status of an entry in the register, ask
there rather than inferring it from this repo.

## Open items

- `divinevideo/divine-mobile#7851` — custody of `121b915b…`, and this register.
- No written procedure for the service-side half of a rotation.
