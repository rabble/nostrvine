# Paused-overlay Toggles Pill Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Render the existing playback-toggles pill (compilations / mute / CC) above the play icon in every paused-video overlay, and make the pause icon appear reliably whenever the player isn't playing (not gated on a prior-play latch).

**Architecture:** Extract today's private `_PlaybackSettingsPopover` from `feed_settings_menu.dart` into a new public `FeedPlaybackTogglesPill` widget. Both the existing top-bar popover and the new paused-overlay placement render that one widget — single source of truth. Inside `PausedVideoPlayOverlay`, drop the `hasStartedPlayback` latch (keep the buffering gate and first-frame gate) and render the pill above the play icon.

**Tech Stack:** Flutter, `flutter_bloc` (FeedAutoAdvanceCubit, VideoVolumeCubit), Riverpod (subtitleVisibilityProvider), `divine_ui` (DivineIcon, VineTheme).

**Spec:** `docs/superpowers/specs/2026-05-11-paused-overlay-toggles-pill-design.md`

**Worktree:** `.worktrees/paused-overlay-toggles-pill` on branch `feat/paused-overlay-toggles-pill`. Run all Flutter commands from `mobile/`.

---

## File Structure

| File | Action | Responsibility |
|---|---|---|
| `mobile/lib/widgets/video_feed_item/feed_playback_toggles_pill.dart` | **Create** | Public widget: scrim-30 capsule with three toggles (auto-advance, mute, captions) + the shared `_PopoverToggle` chip. Reads `FeedAutoAdvanceCubit`, `VideoVolumeCubit`, `subtitleVisibilityProvider` directly — no constructor params. |
| `mobile/lib/screens/feed/feed_settings_menu.dart` | **Modify** | `_FeedSettingsOverlay` renders `FeedPlaybackTogglesPill` instead of the inlined widget. Delete `_PlaybackSettingsPopover`, `_PlaybackModeToggle`, `_AudioToggle`, `_CaptionsToggle`, `_PopoverToggle`. |
| `mobile/lib/widgets/video_feed_item/paused_video_play_overlay.dart` | **Modify** | (1) Render `FeedPlaybackTogglesPill` above the play icon in `_PausedAffordance`. (2) Drop `_hasStartedPlayback` field + `_subscribeToPlayback` latching logic + `didUpdateWidget` latch reset (`_pausedAt` / unpause-feedback logic stays). (3) Drop `onToggleMuteState` constructor param. (4) Change `shouldShowPlay` to `!isPlaying && !isBuffering`. (5) Drop the `_PausedAffordance.onToggleMuteState` field and the single mute toggle inside it. |
| `mobile/test/widgets/video_feed_item/paused_video_play_overlay_test.dart` | **Modify** | Replace the "keeps play affordance visible when remounted" test (which asserts the old latch behavior) with new tests that assert (a) pause icon shows immediately when `isPlaying==false && isBuffering==false`, (b) pause icon stays hidden during buffering, (c) the pill renders above the play icon when paused. Migrate test fixture: drop `onToggleMuteState: () {}` and provide `FeedAutoAdvanceCubit` + `VideoVolumeCubit` + `ProviderScope` so the pill renders without throwing. Update the existing unpause-feedback tests' fixture identically. |
| `mobile/test/widgets/video_feed_item/feed_playback_toggles_pill_test.dart` | **Create** | New tests for `FeedPlaybackTogglesPill`: each of the three toggles renders, reflects current state, and dispatches the right side effect on tap. Mirrors what's currently inlined in the popover. |

No other call sites pass `onToggleMuteState` (verified: `grep -n onToggleMuteState mobile/lib/screens/feed/feed_video_overlay.dart mobile/lib/screens/feed/pooled_fullscreen_video_feed_screen.dart` returns nothing — they construct `PausedVideoPlayOverlay` without that param today), so removing it does not require edits at `feed_video_overlay.dart` or `pooled_fullscreen_video_feed_screen.dart`.

---

## Chunk 1: Extract `FeedPlaybackTogglesPill`

This chunk creates the new shared widget and switches `FeedSettingsMenu`'s popover to use it. After this chunk the top-bar popover renders identically to today, but its content comes from the new file. The paused overlay is unchanged.

### Task 1.1: Create the new file with the pill and its three toggles

**Files:**
- Create: `mobile/lib/widgets/video_feed_item/feed_playback_toggles_pill.dart`

- [ ] **Step 1: Create the file with the full implementation**

The content below is the lift-and-shift of `_PlaybackSettingsPopover` + its three private toggles + `_PopoverToggle` from `feed_settings_menu.dart`, exposed as a public widget. Behavior is unchanged.

```dart
// ABOUTME: Scrim-30 capsule with three playback toggles
// ABOUTME: (compilations / mute / closed-captions). Rendered both as
// ABOUTME: the body of the top-bar settings popover and above the play
// ABOUTME: affordance in the paused-video overlay.

import 'dart:ui';

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:openvine/blocs/video_volume/video_volume_cubit.dart';
import 'package:openvine/l10n/l10n.dart';
import 'package:openvine/providers/subtitle_providers.dart';
import 'package:openvine/screens/feed/feed_auto_advance_cubit.dart';

/// Scrim-30 backdrop-blurred capsule housing the three playback toggles:
/// auto-advance ("compilations"), audio mute, and closed-captions.
///
/// Each toggle reads and writes app-wide state directly
/// ([FeedAutoAdvanceCubit], [VideoVolumeCubit], `subtitleVisibilityProvider`),
/// so the pill takes no constructor params and works as a drop-in child of
/// any feed surface that provides those scopes.
class FeedPlaybackTogglesPill extends StatelessWidget {
  const FeedPlaybackTogglesPill({super.key});

  @override
  Widget build(BuildContext context) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(24),
      child: BackdropFilter(
        filter: ImageFilter.blur(sigmaX: 4, sigmaY: 4),
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: VineTheme.scrim30,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: VineTheme.scrim15),
            boxShadow: const [
              BoxShadow(color: VineTheme.shadow25, blurRadius: 4),
            ],
          ),
          child: const Padding(
            padding: EdgeInsets.all(12),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              spacing: 8,
              children: [
                _PlaybackModeToggle(),
                _AudioToggle(),
                _CaptionsToggle(),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// Auto-advance ("compilations") toggle. Hidden when the OS-level
/// reduced-motion preference is set — auto-advance is unavailable in
/// that state. Also hidden when no [FeedAutoAdvanceCubit] is provided
/// in the surrounding scope, so the pill can be rendered in any
/// surface without requiring callers to wire up the cubit when they
/// don't use auto-advance.
class _PlaybackModeToggle extends StatelessWidget {
  const _PlaybackModeToggle();

  @override
  Widget build(BuildContext context) {
    if (MediaQuery.disableAnimationsOf(context)) {
      return const SizedBox.shrink();
    }
    final cubit = _maybeReadFeedAutoAdvanceCubit(context);
    if (cubit == null) return const SizedBox.shrink();

    return BlocBuilder<FeedAutoAdvanceCubit, FeedAutoAdvanceState>(
      bloc: cubit,
      builder: (context, state) {
        final enabled = state.enabled;
        return _PopoverToggle(
          isOn: enabled,
          semanticLabel: enabled
              ? context.l10n.videoActionDisableAutoAdvance
              : context.l10n.videoActionEnableAutoAdvance,
          onTap: () {
            cubit.toggle();
            if (!cubit.state.isEffectivelyActive) {
              cubit.clearPendingPaginationAdvance();
            }
            announceAutoAdvanceToggle(
              context,
              enabled: cubit.state.enabled,
            );
          },
          child: DivineIcon(
            icon: enabled
                ? DivineIconName.playbackModeOn
                : DivineIconName.playbackModeOff,
            color: VineTheme.onSurface,
          ),
        );
      },
    );
  }
}

FeedAutoAdvanceCubit? _maybeReadFeedAutoAdvanceCubit(BuildContext context) {
  try {
    return BlocProvider.of<FeedAutoAdvanceCubit>(context, listen: false);
  } on ProviderNotFoundException {
    return null;
  }
}

/// Audio mute toggle. Drives [VideoVolumeCubit] directly.
class _AudioToggle extends StatelessWidget {
  const _AudioToggle();

  @override
  Widget build(BuildContext context) {
    final isMuted = context.select(
      (VideoVolumeCubit c) => c.state.volume == 0,
    );
    return _PopoverToggle(
      isOn: isMuted,
      semanticLabel: isMuted
          ? context.l10n.videoPlayerUnmute
          : context.l10n.videoPlayerMute,
      onTap: () {
        context.read<VideoVolumeCubit>().onPlaybackVolumeChanged(
          isMuted ? 1 : 0,
        );
        SemanticsService.sendAnnouncement(
          View.of(context),
          isMuted
              ? context.l10n.videoPlayerUnmute
              : context.l10n.videoPlayerMute,
          Directionality.of(context),
        );
      },
      child: DivineIcon(
        icon: isMuted
            ? DivineIconName.speakerSimpleSlash
            : DivineIconName.speakerSimpleHigh,
        color: VineTheme.onSurface,
      ),
    );
  }
}

/// Closed-captions toggle. Active state means subtitles are visible.
class _CaptionsToggle extends ConsumerWidget {
  const _CaptionsToggle();

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final enabled = ref.watch(subtitleVisibilityProvider);
    return _PopoverToggle(
      isOn: enabled,
      semanticLabel: enabled
          ? context.l10n.videoSettingsCaptionsDisable
          : context.l10n.videoSettingsCaptionsEnable,
      onTap: () {
        ref.read(subtitleVisibilityProvider.notifier).toggle();
      },
      child: DivineIcon(
        icon: enabled
            ? DivineIconName.closedCaptioningFill
            : DivineIconName.closedCaptioning,
        color: VineTheme.onSurface,
      ),
    );
  }
}

/// 48 px touch target wrapping a 12 px-padded scrim button (40 px
/// visible at 20 px radius). Background flips between scrim-15 (off)
/// and scrim-50 (on).
class _PopoverToggle extends StatelessWidget {
  const _PopoverToggle({
    required this.isOn,
    required this.onTap,
    required this.child,
    required this.semanticLabel,
  });

  final bool isOn;
  final VoidCallback onTap;
  final Widget child;
  final String semanticLabel;

  @override
  Widget build(BuildContext context) {
    final bg = isOn ? VineTheme.scrim50 : VineTheme.scrim15;
    return Semantics(
      button: true,
      toggled: isOn,
      label: semanticLabel,
      container: true,
      explicitChildNodes: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: onTap,
        child: DecoratedBox(
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(20),
          ),
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: SizedBox.square(dimension: 24, child: child),
          ),
        ),
      ),
    );
  }
}
```

> **Note on `_maybeReadFeedAutoAdvanceCubit`:** `BlocProvider.of` throws
> `ProviderNotFoundException` when the cubit isn't in scope. Catching
> that and returning `null` is the standard Flutter-Bloc idiom for "use
> if present, hide otherwise" — see the [package's docs](https://pub.dev/documentation/flutter_bloc/latest/flutter_bloc/BlocProvider/of.html).
> `context.select` cannot do this because it doesn't have a nullable form.
> The new `BlocBuilder` wrapper exists only because we can't use
> `context.select` after the nullable lookup (it requires the cubit to
> be in scope at the time of the call). Behavior matches the original
> `context.select` path when the cubit is present.

- [ ] **Step 2: Verify the file compiles**

Run: `cd mobile && mise exec -- flutter analyze lib/widgets/video_feed_item/feed_playback_toggles_pill.dart`
Expected: clean — `No issues found!`

If `mise` isn't available, fall back to `flutter analyze …`.

- [ ] **Step 3: Commit**

```bash
git add mobile/lib/widgets/video_feed_item/feed_playback_toggles_pill.dart
git commit -m "$(cat <<'EOF'
feat(feed): extract feed playback toggles pill widget

Lifts the private _PlaybackSettingsPopover and its three toggles out of
feed_settings_menu.dart into a public widget so the same pill can be
rendered in both the top-bar popover and the paused-video overlay.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

### Task 1.2: Switch `FeedSettingsMenu` popover to the new shared widget

**Files:**
- Modify: `mobile/lib/screens/feed/feed_settings_menu.dart`

- [ ] **Step 1: Replace the popover body and delete the now-redundant private widgets**

In `mobile/lib/screens/feed/feed_settings_menu.dart`:

1. Remove these imports (no longer needed in this file after the lift-out):
   ```dart
   import 'dart:ui';
   import 'package:flutter/semantics.dart';
   import 'package:flutter_bloc/flutter_bloc.dart';
   import 'package:flutter_riverpod/flutter_riverpod.dart';
   import 'package:openvine/blocs/video_volume/video_volume_cubit.dart';
   import 'package:openvine/providers/subtitle_providers.dart';
   import 'package:openvine/screens/feed/feed_auto_advance_cubit.dart';
   ```
2. Add this import:
   ```dart
   import 'package:openvine/widgets/video_feed_item/feed_playback_toggles_pill.dart';
   ```
   Keep the remaining imports (`divine_ui`, `flutter/material`, `openvine/l10n/l10n`).
3. Inside `_FeedSettingsOverlay.build`, change
   `child: const Material(... child: _PlaybackSettingsPopover())` to
   `child: const Material(... child: FeedPlaybackTogglesPill())`.
4. Delete the now-unused classes from this file:
   `_PlaybackSettingsPopover`, `_PlaybackModeToggle`, `_AudioToggle`,
   `_CaptionsToggle`, `_PopoverToggle`. Also update the doc comment on
   `FeedSettingsMenu` — the line "All three toggles read and write
   app-wide state…" — to reference the new widget by name. Leave the
   `OverlayPortal` wrapper, the trigger button, and the open/close
   logic untouched.

- [ ] **Step 2: Verify analyze and test**

Run from `mobile/`:

```bash
mise exec -- flutter analyze lib/screens/feed/feed_settings_menu.dart lib/widgets/video_feed_item/feed_playback_toggles_pill.dart
mise exec -- flutter test test/screens/feed/video_feed_page_test.dart test/screens/feed/pooled_fullscreen_video_feed_screen_test.dart
```

Expected: analyze clean; both `_test.dart` suites pass. (`video_feed_page_test.dart` and `pooled_fullscreen_video_feed_screen_test.dart` cover `FeedSettingsMenu`'s open/close from the top-bar — those tests should still pass because the popover content is byte-for-byte equivalent.)

If `video_feed_page_test.dart` references a deleted private symbol, those references should be `byType(FeedSettingsMenu)` only — we just verified that in the spec. Stop and re-read the test if anything else is failing.

- [ ] **Step 3: Commit**

```bash
git add mobile/lib/screens/feed/feed_settings_menu.dart
git commit -m "$(cat <<'EOF'
refactor(feed): use shared FeedPlaybackTogglesPill in settings popover

No behavior change. The popover renders the same three toggles by
delegating to the new shared widget instead of inlining the
implementation here.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

### Task 1.3: Add unit-style widget tests for the extracted pill

**Files:**
- Create: `mobile/test/widgets/video_feed_item/feed_playback_toggles_pill_test.dart`

- [ ] **Step 1: Write the new test file**

```dart
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/video_volume/video_volume_cubit.dart';
import 'package:openvine/blocs/video_volume/video_volume_state.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/providers/subtitle_providers.dart';
import 'package:openvine/screens/feed/feed_auto_advance_cubit.dart';
import 'package:openvine/widgets/video_feed_item/feed_playback_toggles_pill.dart';

class _MockVideoVolumeCubit extends Mock implements VideoVolumeCubit {}

void main() {
  group(FeedPlaybackTogglesPill, () {
    late FeedAutoAdvanceCubit autoAdvanceCubit;
    late VideoVolumeCubit volumeCubit;

    setUp(() {
      autoAdvanceCubit = FeedAutoAdvanceCubit();
      volumeCubit = _MockVideoVolumeCubit();
      when(() => volumeCubit.state).thenReturn(const VideoVolumeState());
      when(() => volumeCubit.stream)
          .thenAnswer((_) => const Stream<VideoVolumeState>.empty());
    });

    tearDown(() async {
      await autoAdvanceCubit.close();
    });

    Widget buildSubject({bool reducedMotion = false}) {
      return ProviderScope(
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: MediaQuery(
            data: MediaQueryData(disableAnimations: reducedMotion),
            child: MultiBlocProvider(
              providers: [
                BlocProvider<FeedAutoAdvanceCubit>.value(value: autoAdvanceCubit),
                BlocProvider<VideoVolumeCubit>.value(value: volumeCubit),
              ],
              child: const Scaffold(body: FeedPlaybackTogglesPill()),
            ),
          ),
        ),
      );
    }

    testWidgets('renders all three toggles when cubits are in scope',
        (tester) async {
      await tester.pumpWidget(buildSubject());
      // 3 _PopoverToggle = 3 GestureDetectors inside the pill body.
      expect(
        find.byType(GestureDetector),
        findsNWidgets(3),
        reason: 'expected 3 toggles in the pill',
      );
    });

    testWidgets('hides the compilations toggle under reduced motion',
        (tester) async {
      await tester.pumpWidget(buildSubject(reducedMotion: true));
      expect(find.byType(GestureDetector), findsNWidgets(2));
    });

    testWidgets('tapping the captions toggle flips subtitle visibility',
        (tester) async {
      final container = ProviderContainer();
      addTearDown(container.dispose);
      expect(container.read(subtitleVisibilityProvider), isFalse);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: MultiBlocProvider(
              providers: [
                BlocProvider<FeedAutoAdvanceCubit>.value(value: autoAdvanceCubit),
                BlocProvider<VideoVolumeCubit>.value(value: volumeCubit),
              ],
              child: const Scaffold(body: FeedPlaybackTogglesPill()),
            ),
          ),
        ),
      );

      // Tap the CC toggle (last GestureDetector in the row).
      await tester.tap(find.byType(GestureDetector).last);
      await tester.pump();
      expect(container.read(subtitleVisibilityProvider), isTrue);
    });

    testWidgets(
        'tapping the mute toggle calls VideoVolumeCubit.onPlaybackVolumeChanged',
        (tester) async {
      when(() => volumeCubit.state)
          .thenReturn(const VideoVolumeState(volume: 1));
      await tester.pumpWidget(buildSubject());

      // Mute toggle is the middle GestureDetector (index 1) when
      // compilations is visible.
      await tester.tap(find.byType(GestureDetector).at(1));
      await tester.pump();

      verify(() => volumeCubit.onPlaybackVolumeChanged(0)).called(1);
    });

    testWidgets(
        'tapping the compilations toggle calls FeedAutoAdvanceCubit.toggle',
        (tester) async {
      expect(autoAdvanceCubit.state.enabled, isFalse);
      await tester.pumpWidget(buildSubject());

      await tester.tap(find.byType(GestureDetector).first);
      await tester.pump();

      expect(autoAdvanceCubit.state.enabled, isTrue);
    });

    testWidgets('renders without the compilations toggle when '
        'FeedAutoAdvanceCubit is not provided', (tester) async {
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: BlocProvider<VideoVolumeCubit>.value(
              value: volumeCubit,
              child: const Scaffold(body: FeedPlaybackTogglesPill()),
            ),
          ),
        ),
      );

      // 2 toggles (mute + CC), no compilations.
      expect(find.byType(GestureDetector), findsNWidgets(2));
    });
  });
}
```

- [ ] **Step 2: Run the new test**

```bash
cd mobile && mise exec -- flutter test test/widgets/video_feed_item/feed_playback_toggles_pill_test.dart
```

Expected: 6/6 passing.

If a test fails on the `VideoVolumeState` constructor or `volume` field name, **stop**: open `mobile/lib/blocs/video_volume/video_volume_state.dart` and adjust the test to use whatever the real constructor / property shape is. The plan uses `const VideoVolumeState()` and `VideoVolumeState(volume: 1)` as best guesses given current usage at `feed_settings_menu.dart:215` and `main.dart:1648`.

- [ ] **Step 3: Commit**

```bash
git add mobile/test/widgets/video_feed_item/feed_playback_toggles_pill_test.dart
git commit -m "$(cat <<'EOF'
test: cover FeedPlaybackTogglesPill toggles and missing-cubit guard

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Chunk 2: Always-visible pause + pill in `PausedVideoPlayOverlay`

This chunk does the two user-visible changes: (a) drop the
`hasStartedPlayback` latch so the pause icon shows whenever the player
is not playing and not buffering; (b) render the pill above the play
icon. Driven from the existing tests that need to be updated first
(TDD: red → green).

### Task 2.1: Update the existing overlay tests to match new behavior

**Files:**
- Modify: `mobile/test/widgets/video_feed_item/paused_video_play_overlay_test.dart`

- [ ] **Step 1: Update the setUp + `buildSubject` helper**

In `mobile/test/widgets/video_feed_item/paused_video_play_overlay_test.dart`:

1. Add the imports the test will need for cubits + Riverpod:
   ```dart
   import 'package:flutter_bloc/flutter_bloc.dart';
   import 'package:flutter_riverpod/flutter_riverpod.dart';
   import 'package:openvine/blocs/video_volume/video_volume_cubit.dart';
   import 'package:openvine/blocs/video_volume/video_volume_state.dart';
   import 'package:openvine/screens/feed/feed_auto_advance_cubit.dart';
   import 'package:openvine/widgets/video_feed_item/feed_playback_toggles_pill.dart';
   ```
2. Add a private mock:
   ```dart
   class _MockVideoVolumeCubit extends Mock implements VideoVolumeCubit {}
   ```
3. Inside the existing `group('PausedVideoPlayOverlay', …)`, add:
   ```dart
   late FeedAutoAdvanceCubit autoAdvanceCubit;
   late VideoVolumeCubit volumeCubit;
   ```
   In `setUp`, initialize them:
   ```dart
   autoAdvanceCubit = FeedAutoAdvanceCubit();
   volumeCubit = _MockVideoVolumeCubit();
   when(() => volumeCubit.state).thenReturn(const VideoVolumeState());
   when(() => volumeCubit.stream)
       .thenAnswer((_) => const Stream<VideoVolumeState>.empty());
   ```
   In `tearDown`, close the cubit:
   ```dart
   await autoAdvanceCubit.close();
   ```
4. Replace the `buildSubject` body with the version below (wraps the
   overlay in cubit providers + `ProviderScope`, drops `onToggleMuteState`):
   ```dart
   Widget buildSubject({Key? key}) {
     return ProviderScope(
       child: MultiBlocProvider(
         providers: [
           BlocProvider<FeedAutoAdvanceCubit>.value(value: autoAdvanceCubit),
           BlocProvider<VideoVolumeCubit>.value(value: volumeCubit),
         ],
         child: MaterialApp(
           localizationsDelegates: AppLocalizations.localizationsDelegates,
           supportedLocales: AppLocalizations.supportedLocales,
           home: Scaffold(
             body: PausedVideoPlayOverlay(
               key: key,
               player: mockPlayer,
               firstFrameFuture: Future<void>.value(),
             ),
           ),
         ),
       ),
     );
   }
   ```

- [ ] **Step 2: Replace the "keeps the play affordance visible when remounted" test**

That test (lines 69–108 of the current file) asserts that after a
remount the overlay is *hidden* until playback transitions through
playing again. The new behavior is the opposite — the play affordance
appears as soon as the player reports not-playing and not-buffering,
regardless of whether the new mount has ever observed a play. Replace
that whole `testWidgets` with the three tests below:

```dart
testWidgets(
  'shows the play affordance immediately when the player is paused, '
  'even before any play has been observed',
  (tester) async {
    await tester.pumpWidget(buildSubject());
    // First-frame future is already resolved (Future<void>.value()).
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 220));

    expect(find.byKey(const ValueKey('paused-play')), findsOneWidget);
  },
);

testWidgets(
  'hides the play affordance while the player is buffering',
  (tester) async {
    when(() => mockPlayerState.buffering).thenReturn(true);
    await tester.pumpWidget(buildSubject());
    await tester.pump();
    bufferingController.add(true);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 220));

    expect(find.byKey(const ValueKey('paused-play')), findsNothing);
  },
);

testWidgets(
  'renders the playback toggles pill above the play icon when paused',
  (tester) async {
    await tester.pumpWidget(buildSubject());
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 220));

    expect(find.byType(FeedPlaybackTogglesPill), findsOneWidget);
    expect(find.byKey(const ValueKey('paused-play')), findsOneWidget);
  },
);
```

- [ ] **Step 3: Run the file — expect FAIL**

```bash
cd mobile && mise exec -- flutter test test/widgets/video_feed_item/paused_video_play_overlay_test.dart
```

Expected: the three new tests fail.
- "shows the play affordance immediately…" fails: today's overlay requires the `_hasStartedPlayback` latch.
- "renders the playback toggles pill…" fails: today's `_PausedAffordance` doesn't render `FeedPlaybackTogglesPill`.
- "hides the play affordance while buffering" — may pass today (buffering already gates `shouldShowPlay`); still good to keep as a regression test.

The two unpause-feedback tests should still pass (they're already
playing-then-pause-then-play, which exercises the unchanged
`_pausedAt`/`_minPauseForFeedback` machinery).

Do not commit yet — production code changes in the next task make these tests green.

### Task 2.2: Drop the `hasStartedPlayback` latch and render the pill

**Files:**
- Modify: `mobile/lib/widgets/video_feed_item/paused_video_play_overlay.dart`

- [ ] **Step 1: Edit the file**

Apply these changes:

1. **Imports.** Add at the top with the other openvine imports:
   ```dart
   import 'package:openvine/widgets/video_feed_item/feed_playback_toggles_pill.dart';
   ```
   Remove the now-unused `package:flutter/semantics.dart` import — the
   only `SemanticsService.sendAnnouncement` call was inside
   `_PausedAffordance`'s mute toggle, which is being deleted.
2. **Constructor.** Remove the `onToggleMuteState` named parameter and
   field. Update the doc comment block above
   `PausedVideoPlayOverlay` (currently mentions
   "in-pause mute toggle") to describe the new pill placement.
3. **State.** In `_PausedVideoPlayOverlayState`:
   - Delete the `bool _hasStartedPlayback = false;` field and its doc
     comment.
   - In `didUpdateWidget`, delete the
     `_hasStartedPlayback = false;` line. The rest of the player-swap
     reset logic stays.
   - In `_subscribeToPlayback`, delete:
     - The `final initialPlaying = widget.player.state.playing;` line.
     - The `_hasStartedPlayback = widget.isVisible && initialPlaying;`
       line.
     - The whole `if (isPlaying && !_hasStartedPlayback && widget.isVisible) {…}` latch block inside the `.listen` callback.
     - The `_hasStartedPlayback &&` clause from the unpause-feedback
       check (line ~129):
       ```dart
       } else if (isPlaying &&
           !wasPlaying &&
           _hasStartedPlayback &&
           widget.isVisible) {
       ```
       becomes:
       ```dart
       } else if (isPlaying && !wasPlaying && widget.isVisible) {
       ```
   - Keep `_previouslyPlaying = initialPlaying;` working by sourcing the
     initial value inline:
     ```dart
     _previouslyPlaying = widget.player.state.playing;
     ```
4. **`_PlaybackChrome.build`.** Replace:
   ```dart
   final shouldShowPlay = hasStartedPlayback && !isPlaying && !isBuffering;
   ```
   with:
   ```dart
   final shouldShowPlay = !isPlaying && !isBuffering;
   ```
   Drop the `hasStartedPlayback` parameter from `_PlaybackChrome`'s
   constructor, fields, and the call from `_PausedVideoPlayOverlayState.build` (where it was `hasStartedPlayback: _hasStartedPlayback`).
5. **`_PausedAffordance`.** Replace its `build`, fields, and constructor
   so it always renders the pill above the play icon, with no `isMuted`
   / `onToggleMuteState`:
   ```dart
   class _PausedAffordance extends StatelessWidget {
     const _PausedAffordance({super.key});

     @override
     Widget build(BuildContext context) {
       return Center(
         child: Column(
           mainAxisSize: MainAxisSize.min,
           spacing: 16,
           children: [
             const FeedPlaybackTogglesPill(),
             IgnorePointer(
               child: CenterPlaybackControl(
                 state: CenterPlaybackControlState.play,
                 semanticsLabel: context.l10n.videoPlayerPlayVideo,
               ),
             ),
           ],
         ),
       );
     }
   }
   ```
   Update the `_PlaybackChrome.shouldShowPlay` branch:
   ```dart
   child = _PausedAffordance(key: const ValueKey('paused-play'));
   ```
   The two `_PausedAffordance.isMuted`/`onToggleMuteState` arguments
   in the existing call disappear. Also drop the `isMuted` and
   `onToggleMuteState` fields from `_PlaybackChrome` itself — they
   were only used to forward to `_PausedAffordance`. Drop the
   surrounding `StreamBuilder<double>` (for `volume`) in
   `_PausedVideoPlayOverlayState.build`, since `isMuted` is no longer
   read by `_PlaybackChrome`. The pill computes mute state from
   `VideoVolumeCubit` itself.

   > **Why dropping the volume StreamBuilder is safe:** The mute
   > badge in the old `_PausedAffordance` derived `isMuted` from
   > `widget.player.stream.volume` — i.e. the actual `Player`. The new
   > pill reads `VideoVolumeCubit`, which is wired to the active
   > player by the page-level `BlocListener<VideoVolumeCubit>` in
   > `video_feed_page.dart` and
   > `pooled_fullscreen_video_feed_screen.dart` (the `onVolumeChanged`
   > callback on the controller forwards player volume back into the
   > cubit). Cubit and player stay in sync.

- [ ] **Step 2: Run analyze on the changed file**

```bash
cd mobile && mise exec -- flutter analyze lib/widgets/video_feed_item/paused_video_play_overlay.dart
```

Expected: clean.

- [ ] **Step 3: Run the overlay tests — expect PASS**

```bash
cd mobile && mise exec -- flutter test test/widgets/video_feed_item/paused_video_play_overlay_test.dart
```

Expected: 5/5 passing (3 new + 2 existing unpause-feedback).

If the unpause-feedback tests fail with a missing `FeedPlaybackTogglesPill` provider error, double-check Task 2.1 Step 1 wrapped `buildSubject` in `ProviderScope` + the two `BlocProvider.value`s.

- [ ] **Step 4: Commit (both files together)**

```bash
git add mobile/lib/widgets/video_feed_item/paused_video_play_overlay.dart \
        mobile/test/widgets/video_feed_item/paused_video_play_overlay_test.dart
git commit -m "$(cat <<'EOF'
feat(video): show pause icon reliably and surface toggles when paused

PausedVideoPlayOverlay no longer requires the player to have latched a
prior play before showing the pause icon — pausing during initial load
or before first-play now renders the affordance. Buffering still hides
it to avoid loop-restart blips.

Replaces the optional single mute toggle inside the paused affordance
with the full FeedPlaybackTogglesPill (compilations / mute / CC), so
the three controls are discoverable contextually on every video
surface that uses PausedVideoPlayOverlay.

Co-Authored-By: Claude Opus 4.7 (1M context) <noreply@anthropic.com>
EOF
)"
```

---

## Chunk 3: Full verification + PR prep

### Task 3.1: Full repo analyze + scoped test suites

**Files:** (verification only — no edits)

- [ ] **Step 1: Run full analyze**

```bash
cd mobile && mise exec -- flutter analyze lib test integration_test
```

Expected: `No issues found!` If anything fails, fix at the source — never silence with `// ignore:`.

- [ ] **Step 2: Run all touched test suites**

```bash
cd mobile && mise exec -- flutter test \
  test/widgets/video_feed_item/feed_playback_toggles_pill_test.dart \
  test/widgets/video_feed_item/paused_video_play_overlay_test.dart \
  test/screens/feed/video_feed_page_test.dart \
  test/screens/feed/pooled_fullscreen_video_feed_screen_test.dart
```

Expected: all passing.

- [ ] **Step 3: Run the full widget+screen test directories that touch this surface, randomised**

```bash
cd mobile && mise exec -- flutter test \
  test/widgets/video_feed_item \
  test/screens/feed \
  --test-randomize-ordering-seed random
```

Expected: all green. Order-dependence in this surface is the kind of
regression random ordering catches.

- [ ] **Step 4: Format**

```bash
cd mobile && mise exec -- dart format \
  lib/widgets/video_feed_item/feed_playback_toggles_pill.dart \
  lib/widgets/video_feed_item/paused_video_play_overlay.dart \
  lib/screens/feed/feed_settings_menu.dart \
  test/widgets/video_feed_item/feed_playback_toggles_pill_test.dart \
  test/widgets/video_feed_item/paused_video_play_overlay_test.dart
```

If `dart format` reports changes, amend the relevant commit:

```bash
git add -u
git commit --amend --no-edit
```

### Task 3.2: Manual smoke test

These cannot be automated; run them on a real device/simulator before
opening the PR.

- [ ] **Step 1: Smoke test the home feed**

Run the app on iOS or Android. On the home feed:

1. Tap to pause a playing video → verify the pill (3 buttons) appears above the play icon, and the play icon is visible.
2. Tap the captions toggle → verify subtitles toggle on/off.
3. Tap the mute toggle → verify audio mutes/unmutes (use a video known to have audio).
4. Tap the compilations toggle → verify auto-advance toggles. (Reduced motion off.)
5. Tap somewhere outside the pill on the paused background → verify the video resumes playing.
6. While playing, tap the top-bar three-dot menu → verify the same three toggles still appear in the popover, and their state is in sync with what you set from the pill.

- [ ] **Step 2: Smoke test the fullscreen pooled feed**

Push a video into fullscreen (from a profile grid, hashtag feed, or
search result). Repeat steps 1–5 from Task 3.2 Step 1.

- [ ] **Step 3: Smoke test the "pause before first play" path**

Cold-launch the app, land on the home feed. Before the first video
visibly starts playing, tap to pause. Verify the pause icon appears
(this is the bug we fixed — previously it would not).

- [ ] **Step 4: Smoke test the buffering case**

On a flaky network (Network Link Conditioner or airplane-mode toggle
mid-load), pause a video that's still buffering. Verify the pause icon
**does not** flash during buffer; it appears once buffering completes
and the player is paused.

### Task 3.3: Rebase, push, open PR

- [ ] **Step 1: Rebase onto fresh `origin/main`**

```bash
git fetch origin
git rebase origin/main
```

If conflicts arise, resolve them and rerun analyze + tests before
continuing.

- [ ] **Step 2: Push**

```bash
git push --force-with-lease -u origin feat/paused-overlay-toggles-pill
```

- [ ] **Step 3: Open the PR**

Use the `/pr-summary` skill if available; otherwise:

```bash
gh pr create --base main --title "feat(video): always-on pause icon + toggles pill when paused" --body "$(cat <<'EOF'
## Summary

- Paused-video overlay now renders the three playback toggles
  (compilations / mute / CC) above the play icon, applied uniformly
  across every surface that uses `PausedVideoPlayOverlay`.
- Pause icon shows whenever the player is paused (not gated on a
  prior-play latch). Buffering still hides it to avoid loop-restart
  blips, and the first-frame gate still suppresses the pre-render
  window.
- Pill is a single shared `FeedPlaybackTogglesPill` widget — the
  top-bar three-dot popover now delegates to it too, so the two
  render sites can't drift.

Spec: `docs/superpowers/specs/2026-05-11-paused-overlay-toggles-pill-design.md`
Plan: `docs/superpowers/plans/2026-05-11-paused-overlay-toggles-pill.md`

## Test plan

- [x] `flutter analyze lib test integration_test` clean
- [x] `flutter test test/widgets/video_feed_item test/screens/feed --test-randomize-ordering-seed random` green
- [x] Manual: home feed paused state, fullscreen pooled feed paused state, pause-before-first-play, pause-during-buffer
- [ ] Reviewer: please verify on a low-end Android device that the pill backdrop blur isn't dropping frames during the AnimatedSwitcher transition.

🤖 Generated with [Claude Code](https://claude.com/claude-code)
EOF
)"
```

- [ ] **Step 4: Verify CI**

Wait for `build / build` (divine_ui coverage), `Analyze`, `Tests`,
`Format`, `Generated Files`. All must be green before requesting
review. If any check fails, treat it as your fault (per
`agent_workflow.md` rule 5) — investigate the diff, do not retry.

---

## Risk register (carried over from spec for reviewer reference)

1. **Flicker window from dropping the latch.** In the narrow gap
   between "active video transitioned out of preload-paused" and
   "isPlaying=true," the play icon could briefly render. The
   first-frame gate suppresses anything before the first frame; the
   180 ms `AnimatedSwitcher` smooths the transition. If reports come
   in, consider a small debounce (~100 ms) before showing the play
   icon, but do not reintroduce the full latch.
2. **Visual noise.** Three toggles every time someone pauses is more
   chrome than the previous single mute. Rollback path: revert the
   `_PausedAffordance` change only; the extracted pill stays available
   in the top bar.
3. **`FeedAutoAdvanceCubit` provider scope.** The compilations toggle
   now silently hides when the cubit isn't in scope. Current call
   sites all provide it, so behavior is unchanged today. The graceful
   degradation means a future call site doesn't crash, but it also
   means a misconfigured site silently loses the compilations toggle —
   reviewers should flag a missing `FeedAutoAdvanceCubit` if they
   spot a new `PausedVideoPlayOverlay` host without it.
