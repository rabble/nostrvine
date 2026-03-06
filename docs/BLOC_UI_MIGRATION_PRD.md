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

## Documentation policy update
When migration direction changes, docs must be updated in the same PR (or a paired docs PR) to avoid contradictory guidance.
