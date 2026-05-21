# State Management (Current)

Status: Current
Validated against: current mobile architecture direction on 2026-05-20.

Single source of truth for current state-management direction:

- `docs/BLOC_UI_MIGRATION_PRD.md`

## Summary

Divine is in an incremental migration where **BLoC/Cubit is the default for UI state**.
The codebase remains hybrid during transition; Riverpod still exists in some legacy/compatibility paths.

## Quick Reference

**The rule in one sentence:** Riverpod owns DI and long-lived services; BLoC/Cubit owns all feature UI state.

**Canonical examples to copy from:**

| What you are building | Copy from |
|-----------------------|-----------|
| Screen that needs a repository from Riverpod and must gate on nullable deps | `NotificationsPage` — `mobile/lib/notifications/view/notifications_page.dart` |
| Screen using a stable service (no auth-flip risk) | `AppsDirectoryScreen` — `mobile/lib/screens/apps/apps_directory_screen.dart` |
| Screen with auth-sensitive deps (needs `ValueKey` guard) | `VideoEngagementListScreen` — `mobile/lib/screens/video_engagement/video_engagement_list_screen.dart` |

**The pattern in brief:**

```dart
// Outer Page: ConsumerWidget — reads Riverpod deps, creates BlocProvider
class MyFeatureScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final repo = ref.watch(myRepositoryProvider);
    return BlocProvider<MyFeatureBloc>(
      key: ValueKey(repo),
      create: (_) => MyFeatureBloc(repo: repo)..add(const MyFeatureStarted()),
      child: const MyFeatureView(),
    );
  }
}

// Inner View: StatelessWidget — consumes only BLoC, zero Riverpod
class MyFeatureView extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<MyFeatureBloc, MyFeatureState>(
      builder: (context, state) { ... },
    );
  }
}
```

See `docs/BLOC_UI_MIGRATION_PRD.md` for the full Allowed/Disallowed pattern table, bridge inventory,
and migration model.

## Why this file exists

Older Riverpod migration docs were removed because they were stale and contradictory with current in-flight migration work.
If you need implementation guidance, use:

- `docs/FLUTTER.md` (engineering standards)
- `docs/BLOC_UI_MIGRATION_PRD.md` (migration rationale, best practices, allowed/disallowed patterns)
