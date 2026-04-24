# Self-review checklist

Run through this list mentally at every gate. Most review comments on
this repo map directly to a rule that already exists — the failure mode
is forgetting to self-check, not missing information. Keep the list
flat and scannable; each bullet links to the detailed rule.

If a bullet applies and you are unsure, stop and read the linked rule
before continuing.

---

## Before planning a feature

Architecture and ownership:

- [ ] Which layer owns each concern? UI → BLoC → Repository → Client.
  Any logic that filters, sorts, fetches conditionally, falls back, or
  composes data sources belongs **below** the UI. See
  [`architecture.md`](architecture.md).
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
- [ ] Any bespoke widget that deliberately diverges from a `divine_ui`
  component has a docstring explaining **why** (size delta, missing
  variant, Figma node that forced it). See
  [`code_style.md`](code_style.md#document-design-system-divergence).

Composition and style:

- [ ] No methods returning `Widget`. Extract to a widget class (private
  `_Xxx` inside the same file is fine). See
  [`code_style.md`](code_style.md).
- [ ] No `Future.delayed()` **or `Timer`** for UI timing. Use
  `AnimationController` + `FadeTransition` / `AnimatedSwitcher` /
  stream listeners — they pause with the route, respect reduced-motion,
  and align with vsync. See
  [`ui_theming.md`](ui_theming.md#animationcontroller-over-timer-for-ui-timing).
- [ ] No `ValueKey` on `AnimatedSwitcher` branches that are already
  different runtime types. See
  [`ui_theming.md`](ui_theming.md#animatedswitcher-differentiates-children-by-runtime-type).
- [ ] Build methods stay small — a high-level composition of widget
  classes.
- [ ] Check `context.mounted` after every `await` before using
  `BuildContext`.
- [ ] No speculative parameters on a reusable widget/utility. If the
  branch a parameter unlocks is unreachable from any caller, delete
  the parameter. See
  [`code_style.md`](code_style.md#no-speculative-parameters-on-reusable-widgets).
- [ ] To inject an ancestor (`BlocProvider`, `InheritedWidget`) above
  every slot of a modal/sheet/route, use a `contentWrapper` parameter
  on the target — not a builder closure at the call site. See
  [`code_style.md`](code_style.md#dont-hide-ancestors-inside-a-one-off-widget-function-closure)
  and
  [`state_management.md`](state_management.md#scoping-blocprovider-to-a-modal-route).
- [ ] No multi-line design-rationale inline comments. If the
  explanation is longer than a sentence, move it to the PR
  description or a rule file and leave at most a one-line pointer in
  the code. Paragraph-length comments drift and get cited by LLMs as
  bad authority. See [`code_style.md`](code_style.md#comments).

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
- [ ] No error strings / exception objects in BLoC `state`. Use status
  enums + `addError`. See [`state_management.md`](state_management.md).
- [ ] No mutable instance variables on a BLoC class. All state lives in
  the state object.
- [ ] Modal-scoped blocs are owned by a `BlocProvider` **inside** the
  modal's subtree (via `contentWrapper` or equivalent) — never
  instantiated at the call site and `close()`-d in a `try/finally`.

Testing:

- [ ] Any widget test that pumps code calling `context.l10n` includes
  `localizationsDelegates: AppLocalizations.localizationsDelegates` and
  `supportedLocales: AppLocalizations.supportedLocales` on its
  `MaterialApp`.
- [ ] New public method on a strict-coverage package (currently
  `mobile/packages/divine_ui`) has a matching test **in the same PR**.
  See [`testing.md`](testing.md#strict-coverage-packages).
- [ ] No absolute wall-clock bounds on benchmark assertions (`<100 ns`,
  `<100 ms`); use relative comparisons, `fakeAsync`, or skip with a
  `TODO(any):`. See
  [`testing.md`](testing.md#absolute-timing-bounds-flake-on-shared-ci-runners).
- [ ] No incidental `expect(tester.takeException(), isNotNull)` that
  depends on a partially-set-up provider throwing. Assert the test's
  actual contract; drain incidental errors with
  `tester.takeException()` without assertion. See
  [`testing.md`](testing.md#testertakeexception-isnotnull-is-fragile-under-test-suite-optimization).
- [ ] Code that compares wall-clock timestamps (`DateTime.now()`) reads
  through `package:clock`'s `clock.now()`; the test wraps its body in
  `withClock(...)` so the comparison is deterministic. See
  [`testing.md`](testing.md#inject-packageclock-for-time-sensitive-logic).

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
- [ ] Format, analyze, and scoped tests all pass locally.
- [ ] Generated files (Riverpod, Freezed, JSON, Mockito, Drift) are
  regenerated and staged if you touched inputs.
- [ ] `pubspec.lock` churn from a different SDK/pub-resolver run is
  **discarded**, not committed — only commit lockfile changes that come
  from an explicit `flutter pub get` tied to a `pubspec.yaml` change.
- [ ] Commit message explains the *why* (1–2 sentence body), not just
  the *what*.

---

## Before opening or updating a PR

- [ ] PR description follows `pull_request_template.md` (use
  `/pr-summary` to regenerate from commits).
- [ ] Deferred work is tracked in linked follow-up issues — not left
  implicit in the PR body.
- [ ] Screenshots or screen recordings attached for UI changes.
- [ ] Manual test plan covers both own-profile and other-profile paths
  (or equivalent primary vs secondary code paths) where relevant.
- [ ] CI: `build / build` (divine_ui coverage), `Analyze`, `Tests`,
  `Format`, `Generated Files` all green before requesting review.

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
