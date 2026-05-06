---
name: flutter-dynamic-tabcontroller-ticker-mixin
description: |
  Fix Flutter TabController crash when dynamically showing/hiding tabs. Use when:
  (1) TabController rebuild causes "SingleTickerProviderStateMixin but multiple tickers were created",
  (2) Tabs need to appear/disappear based on feature flags or async state,
  (3) TabController.length changes at runtime based on provider state.
  The fix is to use TickerProviderStateMixin instead of SingleTickerProviderStateMixin.
author: Claude Code
version: 1.0.0
date: 2026-01-26
---

# Flutter Dynamic TabController with TickerProviderStateMixin

## Problem
When building a TabBar with dynamic tabs (tabs that show/hide based on feature availability,
user preferences, or async state), recreating the TabController during the widget lifecycle
causes a crash because `SingleTickerProviderStateMixin` only allows one ticker to be created.

## Context / Trigger Conditions

**Error message:**
```
_YourStateClass is a SingleTickerProviderStateMixin but multiple tickers were created.
A SingleTickerProviderStateMixin can only be used as a TickerProvider once.
If a State is used for multiple AnimationController objects, or if it is passed to other
objects and those objects might use it more than one time in total, then instead of mixing
in a SingleTickerProviderStateMixin, use a regular TickerProviderStateMixin.
```

**When this happens:**
- You dispose and recreate a TabController when tab count changes
- You have tabs that conditionally appear based on async state (e.g., Riverpod providers)
- Feature flags control which tabs are visible
- Tab visibility depends on API availability or user permissions

## Solution

### Step 1: Change the Mixin

Replace `SingleTickerProviderStateMixin` with `TickerProviderStateMixin`:

```dart
// WRONG - crashes when TabController is recreated
class _MyScreenState extends State<MyScreen>
    with SingleTickerProviderStateMixin {

// CORRECT - allows multiple TabControllers over widget lifetime
class _MyScreenState extends State<MyScreen>
    with TickerProviderStateMixin {
```

### Step 2: Track Tab Count State

Keep a state variable to track the current tab configuration:

```dart
bool? _lastFeatureAvailable;
TabController? _tabController;

int get _tabCount => (_lastFeatureAvailable ?? false) ? 4 : 3;

void _initTabController() {
  _tabController?.removeListener(_onTabChanged);
  _tabController?.dispose();
  _tabController = TabController(
    length: _tabCount,
    vsync: this,
  );
  _tabController!.addListener(_onTabChanged);
}
```

### Step 3: Synchronously Rebuild on State Change

When the condition changes, rebuild the TabController **synchronously** (not in postFrameCallback):

```dart
@override
Widget build(BuildContext context) {
  // Watch the async state
  final featureAvailableAsync = ref.watch(featureAvailableProvider);
  final featureAvailable = featureAvailableAsync.asData?.value ?? false;

  // Rebuild TabController SYNCHRONOUSLY when state changes
  if (_lastFeatureAvailable != featureAvailable) {
    _lastFeatureAvailable = featureAvailable;
    _initTabController();  // Synchronous rebuild
  }

  // Build tabs using the SAME variable for consistency
  return TabBar(
    controller: _tabController,
    tabs: [
      const Tab(text: 'Tab 1'),
      const Tab(text: 'Tab 2'),
      if (_lastFeatureAvailable ?? false) const Tab(text: 'Optional Tab'),
      const Tab(text: 'Tab 3'),
    ],
  );
}
```

### Step 4: Keep Tabs and TabBarView in Sync

Use the **same state variable** for both the tabs list and TabBarView children:

```dart
// TabBar tabs
tabs: [
  const Tab(text: 'Always'),
  if (_lastFeatureAvailable ?? false) const Tab(text: 'Conditional'),
],

// TabBarView children - MUST match tabs exactly
TabBarView(
  controller: _tabController,
  children: [
    const AlwaysTab(),
    if (_lastFeatureAvailable ?? false) const ConditionalTab(),
  ],
),
```

## Verification

After applying the fix:
1. No crash when the async state changes
2. Tabs appear/disappear correctly (not just grayed out)
3. Tab selection state is preserved (clamped to valid range)
4. No visual glitches during transition

## Example

Real-world example - hiding a "Classics" tab when REST API is unavailable:

```dart
class _ExploreScreenState extends ConsumerState<ExploreScreen>
    with TickerProviderStateMixin {  // NOT SingleTickerProviderStateMixin

  TabController? _tabController;
  bool? _lastClassicsAvailable;

  int get _tabCount => (_lastClassicsAvailable ?? false) ? 4 : 3;

  void _initTabController() {
    final savedTabIndex = ref.read(exploreTabIndexProvider);
    final validIndex = savedTabIndex.clamp(0, _tabCount - 1);
    _tabController?.removeListener(_onTabChanged);
    _tabController?.dispose();
    _tabController = TabController(
      length: _tabCount,
      vsync: this,
      initialIndex: validIndex,
    );
    _tabController!.addListener(_onTabChanged);
  }

  @override
  Widget build(BuildContext context) {
    final classicsAvailable =
        ref.watch(classicVinesAvailableProvider).asData?.value ?? false;

    if (_lastClassicsAvailable != classicsAvailable) {
      _lastClassicsAvailable = classicsAvailable;
      _initTabController();  // Synchronous, not postFrameCallback
    }

    return Column(
      children: [
        TabBar(
          controller: _tabController,
          tabs: [
            const Tab(text: 'New'),
            const Tab(text: 'Popular'),
            if (_lastClassicsAvailable ?? false) const Tab(text: 'Classics'),
            const Tab(text: 'Lists'),
          ],
        ),
        Expanded(
          child: TabBarView(
            controller: _tabController,
            children: [
              const NewVideosTab(),
              const PopularVideosTab(),
              if (_lastClassicsAvailable ?? false) const ClassicsTab(),
              const ListsTab(),
            ],
          ),
        ),
      ],
    );
  }
}
```

## Notes

- **Why not postFrameCallback?** Using `addPostFrameCallback` to rebuild the TabController
  causes a frame where the TabController length doesn't match the tabs list, resulting in
  tabs appearing "grayed out" or other visual glitches.

- **Performance**: `TickerProviderStateMixin` has slightly more overhead than
  `SingleTickerProviderStateMixin`, but it's negligible for typical use cases.

- **Tab index preservation**: When reducing tab count, clamp the current index to avoid
  out-of-bounds errors: `savedIndex.clamp(0, newTabCount - 1)`.

- **Riverpod patterns**: When using Riverpod async providers, remember that
  `asyncValue.asData?.value ?? false` gives you a synchronous default while loading.

## References

- [Flutter TabController class](https://api.flutter.dev/flutter/material/TabController-class.html)
- [TickerProviderStateMixin](https://api.flutter.dev/flutter/widgets/TickerProviderStateMixin-mixin.html)
- [SingleTickerProviderStateMixin](https://api.flutter.dev/flutter/widgets/SingleTickerProviderStateMixin-mixin.html)
