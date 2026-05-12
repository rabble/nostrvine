# Paused-overlay playback-toggles pill + reliable pause button

## Problem

Two related issues on the paused-video state:

1. **The pause button doesn't always show.** Today the gate is
   `hasStartedPlayback && !isPlaying && !isBuffering` in
   `PausedVideoPlayOverlay._PlaybackChrome`. If the user pauses before
   the player has latched as "started," no button renders — they see
   only the still frame.
2. **No paused-state discovery** of the three playback toggles
   (auto-advance / "compilations," mute, closed-captions) that live
   behind the three-dot menu in the home-feed top bar. The popover
   isn't visible on fullscreen video, and isn't discoverable while a
   user is staring at a paused video.

## Goals

- The pause icon renders reliably whenever a video is paused (modulo
  the still-needed buffering gate that prevents loop-restart blips).
- The same three toggles already in the top-bar popover are surfaced
  inside the paused overlay, above the pause icon, so users discover
  CC, mute, and auto-advance/compilations contextually.
- Single source of truth for the pill — no copy/paste between the
  top-bar popover and the paused overlay.
- Applies to every video surface that uses `PausedVideoPlayOverlay`
  (home feed, fullscreen pooled feed, anything else built on the same
  overlay).

## Non-goals

- Removing or changing the top-bar three-dot popover. It stays as the
  always-reachable entry point while a video is playing.
- Adding new toggles (e.g. quality, speed). The pill renders exactly
  the three controls that exist today.
- Changing the underlying behavior of any toggle. Auto-advance, mute,
  and captions read/write the same state sources as before
  (`FeedAutoAdvanceCubit`, `VideoVolumeCubit`,
  `subtitleVisibilityProvider`).

## Design

### Extract a shared pill widget

`feed_settings_menu.dart` currently houses
`_PlaybackSettingsPopover` — a private widget that renders a
scrim-30 backdrop-blurred pill containing three `_PopoverToggle`s
(`_PlaybackModeToggle`, `_AudioToggle`, `_CaptionsToggle`). The pill
and its toggles are exactly the UI we want in the paused overlay.

Move the pill + its three toggles + `_PopoverToggle` into a new
public file:

```
lib/widgets/video_feed_item/feed_playback_toggles_pill.dart
```

Public surface:

```dart
class FeedPlaybackTogglesPill extends StatelessWidget {
  const FeedPlaybackTogglesPill({super.key});
  // Renders the scrim-30 capsule with three toggles. Each toggle
  // reads/writes app-wide state directly — no props needed.
}
```

`feed_settings_menu.dart`'s `_FeedSettingsOverlay` then renders
`const FeedPlaybackTogglesPill()` instead of
`const _PlaybackSettingsPopover()`. Open/close logic, backdrop tap
catcher, and `OverlayPortal` wiring stay where they are.

### Guard the auto-advance toggle

`_PlaybackModeToggle` today calls
`context.select((FeedAutoAdvanceCubit c) => c.state.enabled)`
unconditionally. That crashes if the widget is mounted in a subtree
that doesn't provide `FeedAutoAdvanceCubit`. Every current call site
provides one, but `PausedVideoPlayOverlay` is generic, so a future
host could miss it.

Inside the extracted toggle, look the cubit up nullably and hide the
control if absent:

```dart
@override
Widget build(BuildContext context) {
  final autoAdvanceAvailable = !MediaQuery.disableAnimationsOf(context);
  if (!autoAdvanceAvailable) return const SizedBox.shrink();

  final cubit = context
      .findAncestorStateOfType<BlocProvider<FeedAutoAdvanceCubit>>()
      // Equivalent: try BlocProvider.of with nullable lookup.
      ;
  // ...
}
```

(Final shape decided during implementation — the cleanest in-codebase
idiom is a nullable `BlocProvider.of` lookup, but `context.select` is
not nullable, so the toggle re-watches via a small `BlocBuilder` or
hides altogether when the cubit isn't in scope.)

### Render the pill inside the paused overlay

In `PausedVideoPlayOverlay._PausedAffordance`, replace today's
optional single mute button with the pill, above the play icon:

```dart
Center(
  child: Column(
    mainAxisSize: MainAxisSize.min,
    spacing: 16,
    children: const [
      FeedPlaybackTogglesPill(),
      IgnorePointer(
        child: CenterPlaybackControl(
          state: CenterPlaybackControlState.play,
          // semanticsLabel from l10n…
        ),
      ),
    ],
  ),
)
```

The `onToggleMuteState` callback param on `PausedVideoPlayOverlay`
becomes dead. Remove it and the corresponding param-passing at the
two call sites (`feed_video_overlay.dart`,
`pooled_fullscreen_video_feed_screen.dart`).

### Fix pause-button visibility

In `_PlaybackChrome.build`:

```dart
// Before
final shouldShowPlay = hasStartedPlayback && !isPlaying && !isBuffering;

// After
final shouldShowPlay = !isPlaying && !isBuffering;
```

Remove `_hasStartedPlayback`, the latch in
`_subscribeToPlayback`, and the latch reset in `didUpdateWidget`.

Keep:

- The `firstFrameFuture` gate (`SizedBox.shrink` until the first
  frame renders) — still prevents flashes on initial mount.
- The buffering gate — still suppresses loop-restart blips.
- The `_pausedAt` / `_minPauseForFeedback` / unpause-feedback flash
  machinery — orthogonal to pause-button visibility, still wanted.

### Tap handling

Toggle taps already use
`GestureDetector(behavior: HitTestBehavior.opaque, …)`, which absorbs
the tap before it reaches the surrounding tap-to-play handler. No
new hit-test work needed.

### Accessibility

Existing toggles already set `Semantics(button:true, toggled:isOn,
label:…)`. The pill is a `Row` of three of them, so the screen reader
announces each one in order. The play icon below already has its own
semantics label.

Test obligations follow existing patterns: each toggle is reachable
by `find.bySemanticsLabel` / `find.byType` in widget tests, and the
extracted file's golden behavior (if covered today) moves with it.

## Risks

1. **Flicker window after dropping the latch.** When an active video
   transitions out of the preload-paused state into playing, there's
   a narrow window when `isPlaying==false && isBuffering==false`
   before the player starts. The first-frame gate suppresses anything
   pre-first-frame; after first-frame the play icon could flash for
   ~1 frame. Mitigation: the `AnimatedSwitcher`'s 180ms fade smooths
   it; we'll watch for reports and reintroduce a smaller latch (e.g.
   debounce by 100ms) if it bites.
2. **Visual noise.** Three controls every time someone pauses is
   more chrome than today's single mute. Easy rollback if users
   complain: revert the `_PausedAffordance` change only, pill stays
   available in the top bar.
3. **Strict-coverage on `divine_ui`.** No new public API on
   `divine_ui` — the pill is in the app's `lib/widgets/`. Existing
   `DivineIcon`/`DivineIconButton`/`VineTheme.*` usage only.

## Files

| File | Change |
|---|---|
| `mobile/lib/widgets/video_feed_item/feed_playback_toggles_pill.dart` | **New.** Public extracted pill housing the three toggles + `_PopoverToggle`. |
| `mobile/lib/screens/feed/feed_settings_menu.dart` | `_FeedSettingsOverlay` now renders `FeedPlaybackTogglesPill`. Remove `_PlaybackSettingsPopover`, `_PlaybackModeToggle`, `_AudioToggle`, `_CaptionsToggle`, `_PopoverToggle`. |
| `mobile/lib/widgets/video_feed_item/paused_video_play_overlay.dart` | Drop `hasStartedPlayback` latch (state, init, didUpdateWidget, build). Drop `onToggleMuteState` param. Render pill in `_PausedAffordance`. |
| `mobile/lib/screens/feed/feed_video_overlay.dart` | Stop passing `onToggleMuteState` (if it does today). |
| `mobile/lib/screens/feed/pooled_fullscreen_video_feed_screen.dart` | Same. |
| `mobile/test/widgets/video_feed_item/paused_video_play_overlay_test.dart` | New assertions: pill renders in paused state; pause icon shows without prior-play latch; buffering still hides pause icon. Existing tests that asserted on the mute-toggle prop are migrated to pill presence. |
| `mobile/test/widgets/video_feed_item/feed_playback_toggles_pill_test.dart` | **New.** Mirrors the toggle-content tests that currently live in `feed_settings_menu_test.dart` (auto-advance toggle, mute toggle, captions toggle behavior). |
| `mobile/test/screens/feed/feed_settings_menu_test.dart` | Trim — toggle-content tests move to the pill test. Keep open/close/anchor tests. |

## Test plan

- `flutter analyze lib test integration_test` clean.
- `flutter test test/widgets/video_feed_item/ test/screens/feed/feed_settings_menu_test.dart` green.
- Manual: home feed — tap to pause, verify pill appears above play icon, all three toggles flip state, top-bar popover still works.
- Manual: fullscreen pooled feed — same.
- Manual: pause during buffering — pause icon stays hidden until buffer clears (regression check).
- Manual: pause immediately on app launch before video plays — pause icon now visible (the bug we're fixing).

## Localization

No new strings. All toggle semantic labels come from existing
`context.l10n.videoActionDisableAutoAdvance` /
`videoPlayerMute` / `videoSettingsCaptionsDisable` etc.

## Rollout

Single PR. Behind no feature flag — the fix is small enough that flag
overhead would dwarf the change, and rollback is one revert.
