# PRD: Incremental UI Migration from Riverpod to BLoC

## Status
- **Owner:** mobile team
- **State:** In progress
- **Scope:** UI state management migration (incremental, feature-by-feature)

## Problem
The codebase currently uses mixed patterns (Riverpod + BLoC + service notifiers). This increases cognitive load, makes onboarding harder, and causes inconsistent state propagation behavior across screens.

Recent profile/follower issues exposed fragility in layered provider/service paths and motivated a clearer UI-state direction.

## Decision
For UI state, OpenVine is moving incrementally toward **BLoC/Cubit as the default pattern**.

Riverpod is not being removed everywhere immediately. Existing Riverpod code remains where migration has not yet happened or where non-UI/service-level usage is still stable.

## Why BLoC (for UI)
1. **Explicit event/state flow** makes UI logic easier to reason about and debug.
2. **Feature-local boundaries** reduce hidden coupling from globally watched providers.
3. **Predictable rebuild control** with `BlocBuilder`, `BlocSelector`, and `context.select`.
4. **Better phased migration ergonomics**: convert one feature/screen without a big-bang rewrite.

## In-Progress PR Evidence
- **#1908**: replace Riverpod profile providers with `ProfilesBloc` (Phase 6)  
  https://github.com/divinevideo/divine-mobile/pull/1908
- **#1894**: wire `MyProfileBloc` into main profile screen  
  https://github.com/divinevideo/divine-mobile/pull/1894
- **#1903**: retire `UserProfileService`; keep Riverpod bridge providers temporarily  
  https://github.com/divinevideo/divine-mobile/pull/1903
- **#1282 (merged)**: migrate username validation from Riverpod to BLoC  
  https://github.com/divinevideo/divine-mobile/pull/1282

## Migration Model
### Principles
- Prefer BLoC/Cubit for all new UI state logic.
- Migrate touched Riverpod UI paths opportunistically.
- Keep compatibility bridges only as temporary scaffolding.
- Avoid broad rewrites that combine architecture migration with unrelated behavior changes.

### Incremental rollout
1. Identify one feature boundary (e.g., profile, comments, editor controls).
2. Introduce feature bloc + tests.
3. Switch widget tree consumption to bloc selectors/builders.
4. Keep old provider bridge only if still required by adjacent flows.
5. Remove bridge provider once all consumers are migrated.

## Non-goals
- Immediate deletion of all Riverpod usage.
- Rewriting stable non-UI infrastructure purely for pattern uniformity.
- One-PR whole-app migration.

## Definition of Done (per feature)
- Feature UI no longer depends on Riverpod UI providers.
- Event/state transitions covered by bloc unit tests.
- Integration/widget tests pass for migrated flow.
- Any temporary Riverpod bridge usage is documented with removal follow-up.

## Risks and mitigations
- **Risk:** Regression during mixed-mode period.  
  **Mitigation:** phase-by-phase migration, strict tests, no behavior+architecture bundling.

- **Risk:** Team confusion from stale docs.  
  **Mitigation:** mark Riverpod migration docs as historical and point to this PRD + active PRs.

## BLoC Best Practices (VGV + bloclibrary aligned)

This section is intentionally written as implementation guidance for both humans and LLM agents.

### 1) Keep BLoCs feature-scoped and single-purpose
- One feature boundary per bloc/cubit where possible.
- Avoid "god blocs" that own unrelated flows.
- Keep business logic in bloc/repository layers, not in widgets.

### 2) Unidirectional flow and explicit contracts
- Events represent intent (`ProfileRequested`, `ProfileRefreshRequested`).
- States represent renderable outcomes (loading/success/failure/data-updated).
- Favor immutable state objects and equality semantics to avoid noisy rebuilds.

### 3) UI wiring rules
- Use `BlocBuilder` for render state.
- Use `BlocListener` for one-off side effects (navigation/snackbars/dialogs).
- Use `BlocSelector`/`context.select` for fine-grained rebuild control.
- Keep builder functions pure.

### 4) Concurrency/event handling (critical)
- Be explicit about event concurrency behavior when handlers can overlap.
- For user typing/search-like flows, prefer cancellation/restart semantics.
- For idempotent refresh/fetch events, avoid duplicate in-flight work.
- Do not assume global sequential ordering unless explicitly enforced.

### 5) Dependency boundaries
- Inject repositories/services at app/screen boundary (`BlocProvider`/`MultiBlocProvider`).
- UI should not call APIs directly.
- Avoid bloc-to-bloc tight coupling; prefer shared repository streams or higher-level orchestration.

### 6) Testing contract (required)
- `bloc_test` for event→state transitions.
- Widget tests for critical selector/listener behavior.
- Migration PRs should include tests that prove parity with prior behavior.

## Anti-patterns to avoid (especially for LLM-generated code)
- Creating a new bloc when a feature-local existing bloc should be extended.
- Putting network calls and parsing directly in widgets.
- Emitting many transient states that trigger full subtree rebuilds.
- Mixing migration with unrelated refactors in the same PR.
- Keeping temporary Riverpod bridges without TODO/issue linkage.

## How current PRs demonstrate the model
- **#1908** demonstrates app-level feature bloc migration (`ProfilesBloc`) and replacing bridge providers.
- **#1894** demonstrates incremental cutover of a specific screen path (`MyProfileBloc` into profile UI).
- **#1903** demonstrates transitional architecture: repository-first core with temporary compatibility bridges.
- **#1282** demonstrates focused Riverpod→BLoC migration in a narrower domain (username validation).

## External references
- VGV: Why we use flutter_bloc  
  https://www.verygood.ventures/blog/why-we-use-flutter-bloc
- VGV: BLoC streams and concurrency  
  https://www.verygood.ventures/blog/how-to-use-bloc-with-streams-and-concurrency
- bloclibrary/flutter_bloc package docs  
  https://pub.dev/packages/flutter_bloc

## Documentation policy update
When migration direction changes, docs must be updated in the same PR (or a paired docs PR) to avoid contradictory guidance.
