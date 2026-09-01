# A durable home for the enforcement reason

Design for [#8304](https://github.com/divinevideo/divine-mobile/issues/8304).
Product half: `support-trust-safety#200`. Status: **design only — no implementation.**

Written 2026-09-01 against `origin/main` `5d4d5a46fa`.

## Summary

#8304 asks for the moderation enforcement reason to be given a durable home
outside the one-shot NIP-17 DM. Investigation found that the issue treats one
problem where there are two, and that they have opposite shapes:

| | Account-level (suspend / ban) | Content-level (per video) |
|---|---|---|
| Does a reason exist? | **No** | **Yes** — a reviewed six-category taxonomy |
| Where does it live? | nowhere user-presentable | **only** in the DM |
| Recommended action | confirm the omission; restore the guard | give the category a durable home |

The account-level half needs a decision and no code. The content-level half is
the real gap, and it is not the one the issue's proposal addresses.

## Finding that drives the split

The account-level enforcement DM carries no reason. Its templates take no
parameters, and the template selector deliberately discards the reason argument
for account-level actions. So the proposal in #8304 — *"`AccountStatusResponse`
gains an optional human-readable reason … the moderation service already has
the exact string"* — has no string to gain.

What a user actually loses when that DM is destroyed is not the reason; it is
the **appeal instruction**. The Account Status screen already replaces that with
a Contact Support button, reachable without a failed post.

The content-level templates are different: six categories, each with reviewed
English copy and a policy URL, selected from the moderation categories on the
action. That reason is specific, is real, and lives in exactly one destructible
place.

## Why no existing stored field can be surfaced

Three independent stores hold something called a "reason". None is fit to send.

1. **Keycast `users.suspended_reason`** — its admin API accepts arbitrary
   caller-supplied text (sanitised for control characters and truncated, but
   validated against no set), while Divine's only production writer constrains
   it to four internal tags. Untrusted by contract; an untranslated token in
   practice.
2. **Funnelcake's enforcement tables** — free text supplied by whoever performed
   the action, with a default that carries operator context when none is given.
   Tracked separately as a disclosure risk; not usable as user-facing copy.
3. **The moderation service's sent-message log** — holds the rendered DM body,
   so for account actions it holds the same generic sentence, and for content
   actions it holds the category copy. This is the one store whose contents are
   already reviewed, because they are what was sent.

The common failure is the same in all three: an operator-facing note and a
user-facing explanation are being treated as the same field. They are not, and
no amount of plumbing makes one into the other.

## Recommendation

### Part 1 — account level: confirm, do not build

Recommend T&S confirm that account-level enforcement carries no per-account
reason, because none exists to carry. This is the exit #8304's author offered
("If the answer is 'the reason stays private', say so and this closes"), and the
evidence supports it more strongly than the issue assumed.

Two consequences, both already true and worth stating:

- The generic copy the Account Status screen shows is not a placeholder for a
  specific reason that exists elsewhere. It is the whole message.
- Because the DM is the only carrier of the appeal instruction, the guards that
  keep it from being destroyed remain load-bearing rather than defensive.

If T&S instead wants account actions to carry a category, that is **new product
work**: assigning a category at enforcement time, which nothing does today. It
is not exposure of an existing field.

### Part 2 — content level: give the category a durable home

Surface the per-content moderation **category** — a closed enum drawn from the
existing six — on a self-authenticated, owner-scoped surface, next to the
content it describes.

The natural anchor already exists: funnelcake's owner-export path is
self-authenticated, carries a per-event moderation annotation today, and is
deliberately available to suspended and banned accounts. Extending that
annotation from a status to a status-plus-category is a smaller change than a
new endpoint, and it inherits the auth binding that is already in place.

Client side: render the category on the owner's own view of the affected video
(My Library / video detail), mapping enum to copy through `context.l10n`,
exactly as `AccountEnforcementKind` is mapped today.

## Invariants any implementation must hold

1. **No free text crosses the boundary.** The wire carries a closed enum only.
   Copy is chosen client-side. This is what makes the surface safe, and it is
   the same shape the account status surface already uses.
2. **The operator note and the user-facing category are different fields.**
   Never the same column, never derived from one another.
3. **Owner-scoped, self-authenticated**, with the same caller-equals-subject
   binding the account status endpoint enforces.
4. **Localised** across all supported locales before shipping — six categories,
   not free text, is what makes that possible at all.
5. **The self-harm category's crisis-line text is part of its copy** and must
   survive the move; it is currently spliced in at render time and is
   deliberately excluded from account-level notices.

## Risks and open decisions

- **OQ-1 (T&S, blocking Part 2).** Publishing the category tells a user which
  classification tripped. That is the substance of s-t-s#200's "how much reason
  do we give", and it is a policy call, not an engineering one.
- **OQ-2 (owner needed).** Part 2 is a funnelcake schema and API change; it
  needs an owner in that repo.
- **A ban purges content.** The per-event annotation may have nothing left to
  attach to after a ban, since a ban deletes the author's events. The owner
  export snapshot is the surviving artifact and is therefore the correct anchor
  — designing against the live event tables would produce a surface that is
  empty exactly for the users who most need it.
- **Web and mobile currently disagree on the source of truth** for account
  status. That divergence should be settled before either client renders a
  reason, or the two will disagree about more than plumbing.

## Non-goals

- No appeals workflow. None exists in any repo; this design does not add one.
- No change to any enforcement decision, threshold, or process.
- No exposure of reviewer identity, rule identifiers, thresholds, or scores.
- No email or push notification.

## What was shipped alongside this design

Two commits, neither of which requires the decision above:

- Restored the client-side guard that a moderation reason cannot influence
  enforcement state — a rationale and test that existed, then were removed as
  collateral of a source change rather than by re-decision.
- Documented why Keycast's `suspendedReason` is parsed and deliberately never
  read, so it is neither deleted as dead code nor wired up as "the reason we
  already have".
