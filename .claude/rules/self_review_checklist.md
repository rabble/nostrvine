# Self-review checklist

Run through this list mentally at every gate. Most review comments on
this repo map directly to a rule that already exists — the failure mode
is forgetting to self-check, not missing information. Keep the list
flat and scannable; each bullet links to the detailed rule.

If a bullet applies and you are unsure, stop and read the linked rule
before continuing.

---

## Before touching an existing PR

Do this **first** — before reading the diff, running tests, or planning
a fix. See [`pr_takeover.md`](pr_takeover.md).

- [ ] **Whose PR is this?** `gh pr view <n> --json author,isCrossRepository,isDraft,maintainerCanModify`
  vs `gh api user --jq .login`. Your own PR, a same-repo takeover, and
  a fork PR each carry different gates. Treat `maintainerCanModify` as
  fork-only; same-repo PRs can report `false` even when mutable.
  Learning the answer from a GitHub API rejection means you skipped this
  and re-triage is required.
- [ ] If it's **your own** PR: you cannot review or approve it, and no
  reviewer is downstream to catch a red build. Blockers go in a regular
  issue comment, clearly labelled.
- [ ] If it's **someone else's**: every gate in `PR_REVIEW.md` clears
  before you push. Draft or feedback-only ⇒ read-only.
- [ ] Every review item sorted into fixed / escalated / declined —
  including inline threads fetched via GraphQL, and outdated ones.
- [ ] Unrequested changes called out separately from review fixes.

---

## Before starting any task

Branch hygiene (see [`agent_workflow.md`](agent_workflow.md)):

- [ ] Working in a **new worktree branched from `origin/main`** — not on
  `main`, not in a stale worktree, not on a branch from local `main`.
  Did you `git fetch origin` first?
- [ ] One task per worktree. If the current worktree has unrelated WIP,
  it's not the right place to start new work.

---

## Before planning a feature

Architecture and ownership:

- [ ] Which layer owns each concern? UI → BLoC → Repository → Client.
  Any logic that filters, sorts, fetches conditionally, falls back, or
  composes data sources belongs **below** the UI. See
  [`architecture.md`](architecture.md).
- [ ] New storage/cache choices follow the data-foundation decision tree:
  `cache_sync` for remote-derived cacheable data, Drift for durable
  structured data, narrow `SharedPreferences`, and no new Hive boxes without
  explicit justification. See [`data_foundation.md`](data_foundation.md).
- [ ] "Cache warming" and "pre-fetch" work belongs in the **repository**
  layer, not in a `BlocProvider` wrapper. BlocProviders are lazy — see
  [`state_management.md`](state_management.md#blocprovider-is-lazy-by-default).
- [ ] State that must survive route transitions (e.g. the active tab on
  a screen that can be briefly unmounted when the URL leaves the route)
  needs to live **outside** the widget — in a `StateProvider` keyed by a
  stable identifier. See
  [`state_management.md`](state_management.md#persisting-state-across-shell-route-transitions).

Routing and URL:

- [ ] Every navigable state should be expressible as a URL (go_router).
  See [`routing.md`](routing.md).

Localization and brand:

- [ ] Every user-facing string will come from `context.l10n` — plan ARB
  keys up front, not at commit time. See
  [`localization.md`](localization.md).
- [ ] Copy matches brand voice (`brand-guidelines/TONE_OF_VOICE.md`).

---

## While implementing

Design system (check `divine_ui` first — most review nits map here):

- [ ] No hardcoded `Color(0x...)` literals. Use `VineTheme.*` colors;
  apply transparency via `.withValues(alpha: x)` on a theme color.
- [ ] No inline `TextStyle(...)`. Use a `VineTheme.*Font()` helper.
  If the design needs a style that doesn't exist, **add it to
  `VineTheme`** with a matching test (see coverage note below). See
  [`ui_theming.md`](ui_theming.md).
- [ ] No raw `Image.network` / `NetworkImage`. Use `VineCachedImage`.
- [ ] No raw `Icons.*` / `SvgPicture.asset(...)`. Use `DivineIcon` or
  `DivineIconButton`. Icon colors are picked automatically from the
  button variant — never pass color manually to icon-in-button cases.
- [ ] Uniform gaps between children in a `Row`/`Column` → use
  `spacing: N`, not manual `SizedBox` spacers. `SizedBox` is fine when
  gaps differ.
- [ ] Interactive tap targets (`GestureDetector`, `InkWell`, custom) are
  wrapped in `Semantics(button: true, label: ...)`. Decorative images
  use `ExcludeSemantics`. See [`accessibility.md`](accessibility.md).

Composition and style:

- [ ] No methods returning `Widget`. Extract to a widget class (private
  `_Xxx` inside the same file is fine). See
  [`code_style.md`](code_style.md).
- [ ] No `Future.delayed()` for UI timing. Use `AnimatedSwitcher`,
  animation controllers, stream listeners.
- [ ] Build methods stay small — a high-level composition of widget
  classes.
- [ ] Check `context.mounted` after every `await` before using
  `BuildContext`.

Scroll and navigation:

- [ ] `NestedScrollView` with a pinned `SliverPersistentHeader` needs a
  `topInset` in the delegate when the outer layout is edge-to-edge (no
  `SafeArea`). See
  [`ui_theming.md`](ui_theming.md#nestedscrollview-edge-to-edge-and-pinned-headers).

State management:

- [ ] Every `BlocProvider<X>(create: ...)` has a descendant that reads
  `X` via `context.read/watch/select<X>`, `BlocBuilder<X,`,
  `BlocListener<X,`, `BlocConsumer<X,`, or `BlocSelector<X,`. If not,
  either add `lazy: false` with a justification or delete the wrapper
  entirely — side effects in `create:` never fire without a consumer.
- [ ] Inside every `BlocProvider<X>(create: ...)` factory, any
  Riverpod-provided dependency whose identity can change at runtime
  (auth flip, account switch, sign-out, explicit `ref.invalidate`) is
  read via `ref.watch` *and* the surrounding `BlocProvider` carries a
  `ValueKey` over the dependency tuple. `ref.read` here silently
  captures stale state on the next dep rebuild — see
  [`state_management.md`](state_management.md#bridging-riverpod-provided-dependencies-into-blocprovider).
- [ ] No `ConsumerStatefulWidget` constructs a bloc with
  `late final SomeBloc _bloc = SomeBloc(repo: ref.read(...Provider))`
  in `initState` capturing an identity-flippable Riverpod
  dependency. The preferred fix is the Page/View split — push bloc
  construction into a `ConsumerWidget` parent that wraps a stateful
  child via `BlocProvider`-keyed-on-identity (the existing rule
  then covers the parent). See
  [`state_management.md`](state_management.md#stateful-widgets-that-hold-the-captured-dep-bloc-directly).
- [ ] Anything that signs or publishes through the app-wide `NostrClient`
  waits on `nostrSessionProvider` reaching `nostrReady`; relay-free
  signing such as REST NIP-98 watches a signer-capability signal such as
  `currentAuthRpcCapabilityProvider` before sampling
  `canPublishNostrWritesNow`. Auth state only says the pubkey is known;
  a Keycast signer with no local key arrives after it. See
  [`state_management.md`](state_management.md#signing-readiness-identity-known-is-not-signer-ready).
- [ ] Every `emit` / `add` reachable across a suspension point — an
  `await`, a stream callback, a timer, an unawaited future — is guarded.
  Use `emitIfOpen` / `addIfOpen` from `lib/blocs/close_guard.dart`, or
  return early on `isClosed` *after* the await. `close()` does not cancel
  in-flight work, and the resumed call throws `Cannot emit new states /
  add new events after calling close`. A guard *before* the await is the
  bug, not the fix. An `on<Event>` handler's own `emit` parameter is
  exempt — `Bloc.close()` cancels it. See
  [`state_management.md`](state_management.md#work-that-outlives-close-emitifopen--addifopen).
- [ ] No error strings / exception objects in BLoC `state`. Use status
  enums + `addError`. See [`state_management.md`](state_management.md).
- [ ] No mutable instance variables on a BLoC class. All state lives in
  the state object.

Testing:

- [ ] Any widget test that pumps code calling `context.l10n` includes
  `localizationsDelegates: AppLocalizations.localizationsDelegates` and
  `supportedLocales: AppLocalizations.supportedLocales` on its
  `MaterialApp`.
- [ ] New public method on a strict-coverage package (currently
  `mobile/packages/divine_ui`) has a matching test **in the same PR**.
  See [`testing.md`](testing.md#strict-coverage-packages).

---

## Before committing

Run the verification sequence from `mobile/`:

```
dart format <changed files>
flutter analyze lib test integration_test
flutter test <scoped tests for your change>
```

Then:

- [ ] No debug `print` / `developer.log` / red-background markers /
  emoji TODOs left behind.
- [ ] No unused imports, unused locals, dead code from a removed
  approach.
- [ ] Format, analyze, and scoped tests all pass locally. **Never push
  red** — assume any failing test on your branch is caused by your diff.
  In the rare case it genuinely isn't, prove it both ways and report
  rather than patch. See
  [`agent_workflow.md`](agent_workflow.md#5-failing-tests-are-never-acceptable-and-always-your-fault)
  and [when the failure is not yours](agent_workflow.md#when-the-failure-is-not-yours).
- [ ] Generated files (Riverpod, Freezed, JSON, Mockito, Drift) are
  regenerated and staged if you touched inputs.
- [ ] `pubspec.lock` churn from a different SDK/pub-resolver run is
  **discarded**, not committed — only commit lockfile changes that come
  from an explicit `flutter pub get` tied to a `pubspec.yaml` change.
- [ ] Commit message explains the *why* (1–2 sentence body), not just
  the *what*.

---

## Before opening or updating a PR

- [ ] **Rebased onto fresh `origin/main`** before publishing or final
  handoff, and whenever GitHub reports merge conflicts
  (`git fetch origin && git rebase origin/main`), then pushed with
  `--force-with-lease`. During PR review, if GitHub reports no merge
  conflicts and the push only addresses review feedback, push normally
  without a history-refresh rebase. See
  [`agent_workflow.md`](agent_workflow.md#2-rebase-when-publishing-finalizing-or-resolving-conflicts).
- [ ] PR targets `main`. **Never `--base <other-branch>`** — if this
  work depends on another in-flight branch, combine them into one PR.
  See [`agent_workflow.md`](agent_workflow.md#3-never-stack-prs--combine-dependent-features-into-one-bigger-pr).
- [ ] PR description follows `pull_request_template.md` (use
  `/pr-summary` to regenerate from commits).
- [ ] No deferred work in the diff. No `// TODO` (except
  transitional-code TODOs with tracking issues), no `@Skip`, no
  commented-out code, no half-finished refactors. See
  [`agent_workflow.md`](agent_workflow.md#4-do-not-accumulate-technical-debt).
- [ ] Screenshots or screen recordings attached for UI changes.
- [ ] Manual test plan covers both own-profile and other-profile paths
  (or equivalent primary vs secondary code paths) where relevant.
- [ ] CI: `build / build` (divine_ui coverage), `Analyze`,
  `Tests (shard N/total)` for every shard, aggregate `Mobile CI`,
  `Format`, `Generated Files` all green before requesting review.
- [ ] **Checks watched to completion after the push**
  (`gh pr checks <n> --watch`), not merely launched. The handback
  comment is written *after* reading the result — never alongside the
  push. Red ⇒ fix and push again until green. The only acceptable red
  handback names the breaking commit and the PR that unblocks it; see
  [`agent_workflow.md`](agent_workflow.md#when-the-failure-is-not-yours).

## Responding to review

- [ ] Fetch **all** unresolved threads (including `isOutdated`) via
  GraphQL before triaging — comments on outdated lines still need a
  reply and a resolve.
- [ ] Categorize: blocking / nit / superseded / deferred.
- [ ] Sort by complexity; batch related fixes into one commit per
  workstream; post one reply per thread citing the commit SHA.
- [ ] Leave a single summary comment on the review tagging the reviewer
  when all their blockers are addressed; don't expect them to
  reconstruct it from 20 inline replies.
