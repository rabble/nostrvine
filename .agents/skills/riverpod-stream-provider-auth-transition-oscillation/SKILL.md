---
name: riverpod-stream-provider-auth-transition-oscillation
description: |
  Fix Flutter home feed / main screen stuck on loading spinner after login when using
  Riverpod StreamProvider that watches GoRouter location changes. Use when: (1) Screen
  shows BrandedLoadingIndicator or CircularProgressIndicator permanently after successful
  auth redirect, (2) Widget watches a route-type-gating provider that returns
  AsyncValue.loading() intermittently, (3) Logs show route location oscillating between
  stale and current paths during post-login transition (e.g., /welcome/* after /home/0),
  (4) Provider chain has double-gate: widget gates on pageContext AND data provider also
  gates on pageContext. Distinct from riverpod-infinite-rebuild-loop (rapid rebuilds) —
  this causes permanent loading state, not infinite rebuilds.
author: Claude Code
version: 1.0.0
date: 2026-02-16
---

# Riverpod StreamProvider Auth Transition Oscillation

## Problem

After successful login and redirect, the main screen (home feed, dashboard, etc.) is
permanently stuck on a loading indicator. The auth redirect works correctly (URL shows
`/home/0`), but the screen never renders data. This is NOT a rapid rebuild issue — the
widget builds a few times then settles on a loading state.

## Context / Trigger Conditions

**Symptoms:**
- Screen stuck on loading spinner after successful login redirect
- URL bar / GoRouter shows correct path (e.g., `/home/0`)
- Data provider (e.g., `homeFeedProvider`) has data if checked directly
- No error messages — just permanent loading
- May show brief flash of content before reverting to loading

**Architecture that triggers this:**
1. A `StreamProvider` that watches `router.routerDelegate` for location changes
2. This stream parses routes into a `RouteContext` with a `type` field (home, explore, etc.)
3. Downstream providers gate on `routeContext.type == RouteType.home` and return
   `AsyncValue.loading()` when the type doesn't match
4. The widget watches the downstream provider and shows loading indicator

**The oscillation pattern:**
```
Auth state changes → Router redirects to /home/0
  → routerDelegate emits /home/0 ✓
  → routerDelegate emits /welcome/login (stale!) ✗
  → routerDelegate emits /home/0 ✓
  → routerDelegate emits /welcome/* (stale!) ✗
  ...oscillates for several frames
```

**Why it happens:**
GoRouter's `routerDelegate` listener fires for EVERY location change during transitions,
including intermediate/stale states. During post-login, the router processes multiple
pending navigations (pop welcome screen, push home screen) and the delegate emits each
intermediate state. A sync `StreamController` propagates these instantly.

**Log signature:**
```
CTX derive: type=RouteType.home npub=null index=0
CTX derive: type=RouteType.welcome npub=null index=null   ← stale!
CTX derive: type=RouteType.home npub=null index=0
```

## Root Cause Analysis

The issue is a **double gate** on an oscillating stream:

```
routerDelegate listener
  ↓ (emits every location change)
StreamProvider<RouteContext>  ← oscillates between /home and /welcome
  ↓
videosForHomeRouteProvider   ← returns loading() when type != home  [GATE 1]
  ↓
HomeScreenRouter.build()     ← watches pageContext for type check   [GATE 2]
```

When the stream oscillates, both gates open and close rapidly. The widget ends up
rendering the loading state from whichever emission came last in the settling period.

## Solution

### Pattern: "I Know Who I Am" — Bypass Route-Type Gating

When a widget **knows its own context** (it's only mounted at a specific route), it
doesn't need to gate on a route-type stream. It can read route info synchronously.

### Step 1: Read URL index synchronously from GoRouter

```dart
// BEFORE: Watching oscillating stream
final pageContext = ref.watch(pageContextProvider);
return pageContext.when(
  data: (ctx) {
    if (ctx.type != RouteType.home) return loading();
    // ...
  },
  loading: () => loading(),
  error: (e, s) => error(),
);

// AFTER: Read synchronously — this widget IS the home screen
final router = ref.read(goRouterProvider);
final location = router.routeInformationProvider.value.uri.toString();
final segments = location.split('/').where((s) => s.isNotEmpty).toList();
int urlIndex = 0;
if (segments.length > 1 && segments[0] == 'home') {
  urlIndex = int.tryParse(segments[1]) ?? 0;
}
```

### Step 2: Watch the data provider directly

```dart
// BEFORE: Watching intermediate provider that gates on route type
final videosAsync = ref.watch(videosForHomeRouteProvider);

// AFTER: Watch the data provider directly — no route-type gate needed
final videosAsync = ref.watch(homeFeedProvider);
```

### Step 3: Remove unused intermediate provider imports

Clean up imports for any intermediate route-gating providers that are no longer used.

## When NOT to Apply This Fix

- When the widget genuinely needs to render different content based on route type
  (e.g., a shared shell that shows different feeds)
- When the widget is mounted at multiple routes and needs to switch behavior
- If the issue is actually rapid rebuilds (use `riverpod-infinite-rebuild-loop` instead)

## Verification

After the fix:
1. Login → redirect to home → home feed loads immediately (no permanent spinner)
2. No `RAPID REBUILD` warnings (this fix doesn't cause those)
3. Swipe through feed works normally
4. Pull-to-refresh works
5. Navigate away and back — feed still loads
6. Test with `ref.watch(homeFeedProvider)` in initState to confirm data arrives

## Example: Complete Fix (HomeScreenRouter)

**Before (stuck on loading):**
```dart
@override
Widget build(BuildContext context) {
  final pageContext = ref.watch(pageContextProvider);
  return buildAsyncUI(
    pageContext,
    onData: (ctx) {
      if (ctx.type != RouteType.home) {
        return const Center(child: BrandedLoadingIndicator(size: 80));
      }
      final videosAsync = ref.watch(videosForHomeRouteProvider);
      return buildAsyncUI(videosAsync, ...);
    },
  );
}
```

**After (loads correctly):**
```dart
@override
Widget build(BuildContext context) {
  // Read URL synchronously — HomeScreenRouter is only at /home/:index
  final router = ref.read(goRouterProvider);
  final location = router.routeInformationProvider.value.uri.toString();
  final segments = location.split('/').where((s) => s.isNotEmpty).toList();
  int urlIndex = 0;
  if (segments.length > 1 && segments[0] == 'home') {
    urlIndex = int.tryParse(segments[1]) ?? 0;
  }

  // Watch data directly — no route-type gate needed
  final videosAsync = ref.watch(homeFeedProvider);
  return buildAsyncUI(videosAsync, onData: (state) { ... });
}
```

## Notes

- **Distinct from rebuild loops:** `riverpod-infinite-rebuild-loop` covers rapid rebuilds
  (50+ per second). This issue causes 3-8 rebuilds that settle on a LOADING state.
- **Related to auth timing:** Often co-occurs with synchronous router redirect needing
  data that isn't yet available. See companion fix: pre-fetch data before setting auth
  state so redirects have what they need.
- **StreamProvider vs read:** The oscillation only affects `StreamProvider` watching
  reactive router state. `ref.read()` of GoRouter's current location is stable.
- **GoRouter's routerDelegate:** This listener fires for every intermediate navigation
  state. It's reliable for final states but oscillates during multi-step transitions
  (login → pop welcome → push home).
- **Debug technique:** Add `print('CTX derive: type=${ctx.type}')` to the StreamProvider
  to see the oscillation pattern.

## Related Skills

- `riverpod-infinite-rebuild-loop` — rapid rebuilds from watch/listener issues
- `flutter-pageview-url-routing-reorder-loop` — infinite loop from item reorder tracking
- `flutter-startup-network-blocking` — blocking network ops during startup
