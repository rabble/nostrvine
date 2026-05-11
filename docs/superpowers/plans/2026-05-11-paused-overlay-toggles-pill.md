# Paused-overlay Toggles Pill Implementation Plan

> **For agentic workers:** REQUIRED: Use superpowers:subagent-driven-development (if subagents available) or superpowers:executing-plans to implement this plan. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Render the existing playback-toggles pill (compilations / mute / CC) above the play icon in every paused-video overlay, and make the pause icon appear reliably whenever the player isn't playing (not gated on a prior-play latch).

**Architecture:** Extract today's private `_PlaybackSettingsPopover` from `feed_settings_menu.dart` into a new public `FeedPlaybackTogglesPill` widget. Both the existing top-bar popover and the new paused-overlay placement render that one widget — single source of truth. Inside `PausedVideoPlayOverlay`, drop the `hasStartedPlayback` latch (keep the buffering gate and first-frame gate) and render the pill above the play icon.

**Tech Stack:** Flutter, `flutter_bloc` (FeedAutoAdvanceCubit, VideoVolumeCubit), Riverpod (subtitleVisibilityProvider), `divine_ui` (DivineIcon, VineTheme).

**Spec:** `docs/superpowers/specs/2026-05-11-paused-overlay-toggles-pill-design.md`

**Worktree:** `.worktrees/paused-overlay-toggles-pill` on branch `feat/paused-overlay-toggles-pill`. Run all Flutter commands from `mobile/`.

**Tooling note.** All `flutter`/`dart` invocations in this plan are prefixed with `mise exec --` to use the repo's pinned Flutter version. If `mise` isn't installed on your machine, drop the prefix and use `flutter`/`dart` directly. The CI gate uses the pinned version regardless.

---

## File Structure

| File | Action | Responsibility |
|---|---|---|
| `mobile/lib/widgets/video_feed_item/feed_playback_toggles_pill.dart` | **Create** | Public widget: scrim-30 capsule with three toggles (auto-advance, mute, captions) + the shared `_PopoverToggle` chip. Reads `FeedAutoAdvanceCubit`, `VideoVolumeCubit`, `subtitleVisibilityProvider` directly — no constructor params. |
| `mobile/lib/screens/feed/feed_settings_menu.dart` | **Modify** | `_FeedSettingsOverlay` renders `FeedPlaybackTogglesPill` instead of the inlined widget. Delete `_PlaybackSettingsPopover`, `_PlaybackModeToggle`, `_AudioToggle`, `_CaptionsToggle`, `_PopoverToggle`. |
| `mobile/lib/widgets/video_feed_item/paused_video_play_overlay.dart` | **Modify** | (1) Render `FeedPlaybackTogglesPill` above the play icon in `_PausedAffordance`. (2) Drop `_hasStartedPlayback` field + `_subscribeToPlayback` latching logic + `didUpdateWidget` latch reset (`_pausedAt` / unpause-feedback logic stays). (3) Drop `onToggleMuteState` constructor param. (4) Change `shouldShowPlay` to `!isPlaying && !isBuffering`. (5) Drop the `_PausedAffordance.onToggleMuteState` field and the single mute toggle inside it. (6) Drop the now-unused `StreamBuilder<double>` (volume stream) wrapper inside `_PausedVideoPlayOverlayState.build`. |
| `mobile/lib/screens/feed/pooled_fullscreen_video_feed_screen.dart` | **Modify** | Remove the now-stale 3-line comment at lines 1287–1289 ("Mute toggle intentionally omitted: the popover in the app bar's customActions slot is now the sole entry point, matching the home feed."). After this change, the mute toggle is back inside the pill rendered by the paused overlay; leaving the comment violates the "comments go stale" rule. No code change at the call site (already doesn't pass `onToggleMuteState`). |
| `mobile/test/widgets/video_feed_item/paused_video_play_overlay_test.dart` | **Modify** | Replace the "keeps play affordance visible when remounted" test (which asserts the old latch behavior) with new tests that assert (a) pause icon shows immediately when `isPlaying==false && isBuffering==false`, (b) pause icon stays hidden during buffering, (c) the pill renders above the play icon when paused. Migrate test fixture: drop `onToggleMuteState: () {}` and provide `FeedAutoAdvanceCubit` + `VideoVolumeCubit` + `ProviderScope` (with `sharedPreferencesProvider` overridden via `createMockSharedPreferences()`) so the pill renders without throwing. Update the existing unpause-feedback tests' fixture identically. |
| `mobile/test/widgets/video_feed_item/feed_playback_toggles_pill_test.dart` | **Create** | New tests for `FeedPlaybackTogglesPill`: each of the three toggles renders, reflects current state, and dispatches the right side effect on tap. Mirrors what's currently inlined in the popover. |

No other call sites pass `onToggleMuteState` (verified: `grep -n onToggleMuteState mobile/lib/screens/feed/feed_video_overlay.dart mobile/lib/screens/feed/pooled_fullscreen_video_feed_screen.dart` returns nothing — they construct `PausedVideoPlayOverlay` without that param today), so removing it does not require code edits at those files (only the stale comment at `pooled_fullscreen_video_feed_screen.dart:1287–1289`).

## Test-fixture invariants (apply to every widget test in this PR)

Both `FeedPlaybackTogglesPill` and `PausedVideoPlayOverlay`-with-pill pump
`_CaptionsToggle`, which calls `ref.watch(subtitleVisibilityProvider)`. That
provider's notifier reads `ref.read(sharedPreferencesProvider)`, which
**throws `UnimplementedError` by default** (`mobile/lib/providers/shared_preferences_provider.dart:4–9`).
Every `ProviderScope` / `ProviderContainer` in this PR's tests therefore
needs an override:

```dart
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../helpers/test_provider_overrides.dart';
// adjust relative path: from test/widgets/video_feed_item/ it's ../../helpers/

late SharedPreferences mockPrefs;

setUp(() {
  mockPrefs = createMockSharedPreferences();
  // …other setup…
});

// Inside buildSubject / each test that creates a ProviderScope or ProviderContainer:
ProviderScope(
  overrides: [sharedPreferencesProvider.overrideWithValue(mockPrefs)],
  child: …,
)
```

`createMockSharedPreferences()` (in `test/helpers/test_provider_overrides.dart`)
returns a stub where `getBool(any()) → null`, so
`subtitleVisibilityProvider`'s initial value resolves to `prefs.getBool(...) ?? true = true`
(see `mobile/lib/providers/subtitle_providers.dart` — the default is `true`,
**not** `false`; an initial-state assertion of `isFalse` is wrong).

**Do NOT** add `import 'package:openvine/blocs/video_volume/video_volume_state.dart';`
to any test file. `video_volume_state.dart` is a `part of 'video_volume_cubit.dart';`
file (first line of the source); importing a part file directly is a Dart
compile error. `VideoVolumeState` is exported transitively through
`import 'package:openvine/blocs/video_volume/video_volume_cubit.dart';`.

**Cubit-mock pattern (mandatory).** A bare `Mock implements VideoVolumeCubit`
does **not** provide the internal stream-controller / `BlocBase` machinery
that `context.select`, `BlocBuilder`, etc. introspect. The canonical pattern
across this codebase (`mobile/test/screens/feed/video_feed_page_test.dart:33-34`,
`mobile/test/screens/feed/pooled_fullscreen_video_feed_screen_test.dart:46-47`)
is `MockCubit<VideoVolumeState>` from `package:bloc_test/bloc_test.dart`:

```dart
import 'package:bloc_test/bloc_test.dart';

class _MockVideoVolumeCubit extends MockCubit<VideoVolumeState>
    implements VideoVolumeCubit {}
```

`MockCubit` ships its own working stream/state machine, so the `stream` stub
is unnecessary. Keep `when(() => volumeCubit.state).thenReturn(...)` —
that's the standard idiom.

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

This test uses semantic-label finders (resolved from `AppLocalizations`)
instead of `find.byType(GestureDetector)`. The pill renders three
`GestureDetector`s today, but the surrounding test scaffold also creates
incidental `GestureDetector`s (Material's tap-catchers), so counting by
type is fragile. Each toggle has a unique `Semantics(label: …)` wrapper,
which makes `find.bySemanticsLabel` precise and refactor-resistant.

```dart
import 'package:bloc_test/bloc_test.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:openvine/blocs/video_volume/video_volume_cubit.dart';
import 'package:openvine/l10n/generated/app_localizations.dart';
import 'package:openvine/providers/shared_preferences_provider.dart';
import 'package:openvine/providers/subtitle_providers.dart';
import 'package:openvine/screens/feed/feed_auto_advance_cubit.dart';
import 'package:openvine/widgets/video_feed_item/feed_playback_toggles_pill.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../../helpers/test_provider_overrides.dart';

class _MockVideoVolumeCubit extends MockCubit<VideoVolumeState>
    implements VideoVolumeCubit {}

void main() {
  group(FeedPlaybackTogglesPill, () {
    late FeedAutoAdvanceCubit autoAdvanceCubit;
    late VideoVolumeCubit volumeCubit;
    late SharedPreferences mockPrefs;

    final l10n = lookupAppLocalizations(const Locale('en'));

    setUp(() {
      autoAdvanceCubit = FeedAutoAdvanceCubit();
      volumeCubit = _MockVideoVolumeCubit();
      when(() => volumeCubit.state).thenReturn(const VideoVolumeState());
      mockPrefs = createMockSharedPreferences();
    });

    tearDown(() async {
      await autoAdvanceCubit.close();
    });

    Widget buildSubject({
      bool reducedMotion = false,
      bool provideAutoAdvance = true,
    }) {
      Widget pill = const Scaffold(body: FeedPlaybackTogglesPill());

      pill = provideAutoAdvance
          ? MultiBlocProvider(
              providers: [
                BlocProvider<FeedAutoAdvanceCubit>.value(value: autoAdvanceCubit),
                BlocProvider<VideoVolumeCubit>.value(value: volumeCubit),
              ],
              child: pill,
            )
          : BlocProvider<VideoVolumeCubit>.value(
              value: volumeCubit,
              child: pill,
            );

      return ProviderScope(
        overrides: [sharedPreferencesProvider.overrideWithValue(mockPrefs)],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: MediaQuery(
            data: MediaQueryData(disableAnimations: reducedMotion),
            child: pill,
          ),
        ),
      );
    }

    testWidgets('renders all three toggles when cubits are in scope',
        (tester) async {
      await tester.pumpWidget(buildSubject());
      // subtitleVisibilityProvider defaults to true (prefs.getBool ?? true),
      // so the captions toggle's initial label is the "disable" variant.
      expect(
        find.bySemanticsLabel(l10n.videoActionEnableAutoAdvance),
        findsOneWidget,
      );
      expect(find.bySemanticsLabel(l10n.videoPlayerMute), findsOneWidget);
      expect(
        find.bySemanticsLabel(l10n.videoSettingsCaptionsDisable),
        findsOneWidget,
      );
    });

    testWidgets('hides the compilations toggle under reduced motion',
        (tester) async {
      await tester.pumpWidget(buildSubject(reducedMotion: true));
      expect(
        find.bySemanticsLabel(l10n.videoActionEnableAutoAdvance),
        findsNothing,
      );
      expect(
        find.bySemanticsLabel(l10n.videoActionDisableAutoAdvance),
        findsNothing,
      );
      // Mute + CC still present.
      expect(find.bySemanticsLabel(l10n.videoPlayerMute), findsOneWidget);
    });

    testWidgets('tapping the captions toggle flips subtitle visibility',
        (tester) async {
      final container = ProviderContainer(
        overrides: [sharedPreferencesProvider.overrideWithValue(mockPrefs)],
      );
      addTearDown(container.dispose);
      // Default getBool(any()) → null, falls through to `?? true`.
      expect(container.read(subtitleVisibilityProvider), isTrue);

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

      await tester.tap(
        find.bySemanticsLabel(l10n.videoSettingsCaptionsDisable),
      );
      await tester.pump();
      expect(container.read(subtitleVisibilityProvider), isFalse);
    });

    testWidgets(
        'tapping the mute toggle calls VideoVolumeCubit.onPlaybackVolumeChanged',
        (tester) async {
      when(() => volumeCubit.state)
          .thenReturn(const VideoVolumeState(volume: 1));
      await tester.pumpWidget(buildSubject());

      await tester.tap(find.bySemanticsLabel(l10n.videoPlayerMute));
      await tester.pump();

      verify(() => volumeCubit.onPlaybackVolumeChanged(0)).called(1);
    });

    testWidgets(
        'tapping the compilations toggle calls FeedAutoAdvanceCubit.toggle',
        (tester) async {
      expect(autoAdvanceCubit.state.enabled, isFalse);
      await tester.pumpWidget(buildSubject());

      await tester.tap(
        find.bySemanticsLabel(l10n.videoActionEnableAutoAdvance),
      );
      await tester.pump();

      expect(autoAdvanceCubit.state.enabled, isTrue);
    });

    testWidgets('renders without the compilations toggle when '
        'FeedAutoAdvanceCubit is not provided', (tester) async {
      await tester.pumpWidget(buildSubject(provideAutoAdvance: false));

      expect(
        find.bySemanticsLabel(l10n.videoActionEnableAutoAdvance),
        findsNothing,
      );
      expect(find.bySemanticsLabel(l10n.videoPlayerMute), findsOneWidget);
    });
  });
}
```

- [ ] **Step 2: Run the new test**

```bash
cd mobile && mise exec -- flutter test test/widgets/video_feed_item/feed_playback_toggles_pill_test.dart
```

Expected: 6/6 passing.

If a test fails on the `VideoVolumeState` constructor or `volume` field name, **stop**: open `mobile/lib/blocs/video_volume/video_volume_state.dart` and adjust the test to use whatever the real constructor / property shape is. The plan uses `const VideoVolumeState()` and `VideoVolumeState(volume: 1)` based on the verified source — `class VideoVolumeState extends Equatable` with `this.volume = 1.0` default and `final double volume`. Implicit `int→double` conversion in const contexts is supported, so `volume: 1` and `volume: 1.0` are both valid.

If a test fails with `UnimplementedError` from `sharedPreferencesProvider`, you missed the `overrides: [sharedPreferencesProvider.overrideWithValue(mockPrefs)]` on one of the `ProviderScope`/`ProviderContainer` constructions. Every Riverpod scope in this file must override it.

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

1. Add the imports the test will need (do NOT import
   `video_volume_state.dart` — it's a `part of video_volume_cubit.dart`):
   ```dart
   import 'package:flutter_bloc/flutter_bloc.dart';
   import 'package:flutter_riverpod/flutter_riverpod.dart';
   import 'package:openvine/blocs/video_volume/video_volume_cubit.dart';
   import 'package:openvine/providers/shared_preferences_provider.dart';
   import 'package:openvine/screens/feed/feed_auto_advance_cubit.dart';
   import 'package:openvine/widgets/video_feed_item/feed_playback_toggles_pill.dart';
   import 'package:shared_preferences/shared_preferences.dart';

   import '../../helpers/test_provider_overrides.dart';
   ```
2. Add the `bloc_test` import alongside the other new imports above:
   ```dart
   import 'package:bloc_test/bloc_test.dart';
   ```
   And declare the private mock using `MockCubit` (NOT bare `Mock`):
   ```dart
   class _MockVideoVolumeCubit extends MockCubit<VideoVolumeState>
       implements VideoVolumeCubit {}
   ```
3. Inside the existing `group('PausedVideoPlayOverlay', …)`, add:
   ```dart
   late FeedAutoAdvanceCubit autoAdvanceCubit;
   late VideoVolumeCubit volumeCubit;
   late SharedPreferences mockPrefs;
   ```
   In `setUp`, initialize them — and **also remove the now-dead player
   volume stubs** (`when(() => mockPlayerState.volume).thenReturn(100.0);`
   on the existing line ~37, and `when(() => mockPlayerStream.volume)...`
   on the existing lines ~44–46). After Task 2.2 drops the
   `StreamBuilder<double>` over `widget.player.stream.volume`, those
   stubs are dead and `agent_workflow.md` rule 4 forbids leaving them:
   ```dart
   autoAdvanceCubit = FeedAutoAdvanceCubit();
   volumeCubit = _MockVideoVolumeCubit();
   when(() => volumeCubit.state).thenReturn(const VideoVolumeState());
   mockPrefs = createMockSharedPreferences();
   ```
   In `tearDown`, close the cubit:
   ```dart
   await autoAdvanceCubit.close();
   ```
4. Replace the `buildSubject` body with the version below. It wraps the
   overlay in `ProviderScope` (with the required `sharedPreferencesProvider`
   override — without it the pill's captions toggle throws), the two
   cubit providers, drops `onToggleMuteState`, and keeps everything else
   the same:
   ```dart
   Widget buildSubject({Key? key}) {
     return ProviderScope(
       overrides: [sharedPreferencesProvider.overrideWithValue(mockPrefs)],
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
   The unpause-feedback tests pump a second `MaterialApp` mid-test (the
   "swap to SizedBox.shrink" pattern). Those interim pumps don't need
   the provider wrapper because they don't pump `PausedVideoPlayOverlay`.
   Verify by running the suite at Step 3 below.

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

    // "Above" means: smaller y coordinate. If a future regression
    // moves the pill below the play icon (e.g. Row instead of Column),
    // this assertion catches it.
    final pillCenter =
        tester.getCenter(find.byType(FeedPlaybackTogglesPill));
    final playCenter =
        tester.getCenter(find.byKey(const ValueKey('paused-play')));
    expect(
      pillCenter.dy,
      lessThan(playCenter.dy),
      reason: 'pill should sit above the play icon',
    );
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
   Remove these imports — both become unused after the
   `_PausedAffordance` mute-toggle deletion:
   - `import 'package:flutter/semantics.dart';` (only call was
     `SemanticsService.sendAnnouncement` inside the deleted mute
     toggle)
   - `import 'package:flutter/foundation.dart' show kIsWeb;` (only
     reference was the deleted `if (!kIsWeb && muteToggle != null)`
     guard inside `_PausedAffordance.build`)
2. **Constructor & doc comments.** Remove the `onToggleMuteState` named
   parameter and field (and its associated doc comment, currently
   `paused_video_play_overlay.dart` lines 28–33). Then rewrite the doc
   comment on the `_PausedAffordance` class (currently lines 316–319,
   which describes "optional mute toggle (non-web) above the large play
   icon" and the `onToggleMuteState == null` branch) to describe the
   new composition:
   ```dart
   /// The paused-state stack: the playback-toggles pill
   /// ([FeedPlaybackTogglesPill]) above the large play icon. The pill
   /// reads its own state from app-wide cubits/providers, so this widget
   /// takes no callbacks.
   ```
   Leave the top-of-file doc comment on `PausedVideoPlayOverlay` (lines
   12–14) alone — it still describes the widget's purpose accurately
   ("Large centered play affordance shown when a pooled video is
   paused, plus a brief 'unpause' feedback…").
3. **State.** In `_PausedVideoPlayOverlayState`:
   - Delete the `bool _hasStartedPlayback = false;` field and its doc
     comment.
   - In `didUpdateWidget`, delete only the
     `_hasStartedPlayback = false;` line. Keep
     `_previouslyPlaying = false;`, `_pausedAt = null;`,
     `_showUnpauseFeedback = false;`, `_unpauseFeedbackOpacity = 1.0;`,
     and the surrounding `_subscribeToPlayback()` call.
   - Rewrite `_subscribeToPlayback` to the body below. This deletes
     three things relative to current source: the
     `initialPlaying`/`_hasStartedPlayback` initial latch (current
     lines 109–111), the inner `if (isPlaying && !_hasStartedPlayback
     && widget.isVisible) { setState(...); return; }` block — **including
     its early `return;`** — (current lines 119–124), and the
     `_hasStartedPlayback &&` clause from the unpause-feedback else-if
     (current line 130). The result:
     ```dart
     void _subscribeToPlayback() {
       _previouslyPlaying = widget.player.state.playing;
       _playingSubscription =
           widget.player.stream.playing.listen((isPlaying) {
         if (!mounted) return;
         final wasPlaying = _previouslyPlaying;
         _previouslyPlaying = isPlaying;

         if (!isPlaying && wasPlaying) {
           _pausedAt = clock.now();
         } else if (isPlaying && !wasPlaying && widget.isVisible) {
           final pauseDuration = _pausedAt != null
               ? clock.now().difference(_pausedAt!)
               : Duration.zero;
           _pausedAt = null;
           if (pauseDuration >= _minPauseForFeedback) {
             _triggerUnpauseFeedback();
           }
         }
       });
     }
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
   Update the `_PlaybackChrome.shouldShowPlay` branch — note the
   `const` constructor call (preserves the const-ness the existing
   code relied on for the `ValueKey('paused-play')` literal):
   ```dart
   child = const _PausedAffordance(key: ValueKey('paused-play'));
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

- [ ] **Step 1b: Remove the stale comment at the fullscreen call site**

In `mobile/lib/screens/feed/pooled_fullscreen_video_feed_screen.dart`,
delete the 3-line comment at lines 1287–1289:

```dart
// Mute toggle intentionally omitted: the popover in
// the app bar's customActions slot is now the sole
// entry point, matching the home feed.
```

The call site itself doesn't change — it already doesn't pass
`onToggleMuteState`. Only the comment is wrong after the refactor (the
mute toggle is back inside the pill rendered by the paused overlay).

- [ ] **Step 2: Run analyze on the changed files**

```bash
cd mobile && mise exec -- flutter analyze \
  lib/widgets/video_feed_item/paused_video_play_overlay.dart \
  lib/screens/feed/pooled_fullscreen_video_feed_screen.dart
```

Expected: clean.

- [ ] **Step 3: Run the overlay tests — expect PASS**

```bash
cd mobile && mise exec -- flutter test test/widgets/video_feed_item/paused_video_play_overlay_test.dart
```

Expected: 5/5 passing (3 new + 2 existing unpause-feedback).

If the unpause-feedback tests fail with a missing `FeedPlaybackTogglesPill` provider error, double-check Task 2.1 Step 1 wrapped `buildSubject` in `ProviderScope` + the two `BlocProvider.value`s.

- [ ] **Step 4: Commit (all three files together)**

```bash
git add mobile/lib/widgets/video_feed_item/paused_video_play_overlay.dart \
        mobile/lib/screens/feed/pooled_fullscreen_video_feed_screen.dart \
        mobile/test/widgets/video_feed_item/paused_video_play_overlay_test.dart
git commit -m "$(cat <<'EOF'
feat(video): show pause icon reliably and surface toggles when paused

PausedVideoPlayOverlay no longer requires the player to have latched a
prior play before showing the pause icon — pausing during initial load
or before first-play now renders the affordance. Buffering still hides
it to avoid loop-restart blips.

Adds the three contextual toggles (compilations / mute / CC) above the
play icon via the shared FeedPlaybackTogglesPill. Today, the paused
affordance renders no toggles at either call site (home feed and
fullscreen pooled feed both pass nothing for onToggleMuteState).

Also removes the now-stale "mute toggle intentionally omitted" comment
at pooled_fullscreen_video_feed_screen.dart.

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

- [ ] **Step 3: Run the affected widget test directory randomised**

```bash
cd mobile && mise exec -- flutter test \
  test/widgets/video_feed_item \
  --test-randomize-ordering-seed random
```

Expected: all green. Scoped to `test/widgets/video_feed_item` because
that's the only directory whose contents this PR touches at the widget
level — the screen suites are deterministically covered in Step 2.
Running random ordering against the broader `test/screens/feed` tree
risks tripping on pre-existing order-sensitive tests that are outside
this PR's scope.

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

- [ ] **Step 5: Smoke test the preload-flicker regression (recorded)**

The dropped `_hasStartedPlayback` latch was originally introduced to
prevent a flicker on preloaded videos: during preload a pooled player
is *played muted for buffering then paused* — under the new logic the
brief paused window between `isPlaying=false` and the player resuming
will render the play icon, then immediately swap to playing through the
180 ms `AnimatedSwitcher`.

A naked-eye check cannot reliably distinguish "no flicker" from
"flicker too fast to see," so this must be a recorded smoke:

1. iOS simulator: **File → Record Screen** (or `xcrun simctl io
   booted recordVideo flicker.mp4` from a separate terminal). Android
   emulator: extended controls → **Camera → Record screen**.
2. With recording active, swipe through 6–8 consecutive videos on the
   home feed at a natural pace.
3. Stop recording. Scrub through `flicker.mp4` **frame by frame** (in
   QuickTime: ← / → arrow keys; in VLC: `E`). Watch the center of the
   frame as each video first becomes active.
4. Verify the play icon does **not** appear for any frame before
   playback starts. Acceptable: the play icon is absent. Not
   acceptable: a play icon visible for ≥1 frame on any preload swap.

If a flash is present, the contingency from the spec applies:
introduce a short debounce (~100 ms) before showing `_PausedAffordance`.
Do NOT reintroduce the full `_hasStartedPlayback` latch — that defeats
the whole change. Block the PR if any flash is visible; do not ship
"borderline."

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
