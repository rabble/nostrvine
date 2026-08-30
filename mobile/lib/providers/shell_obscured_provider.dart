// ABOUTME: Tracks whether a full-screen route covers the bottom-nav shell.
// ABOUTME: Driven by AppShell's RouteAware subscription to the root navigator.

import 'package:flutter_riverpod/flutter_riverpod.dart';

/// Whether a full-screen route (profile, fullscreen video, recorder, …) is
/// currently pushed on top of the bottom-nav shell on the root navigator.
///
/// [AppShell] subscribes to the root `routeObserver` and drives this flag:
/// `didPushNext` sets it `true`, `didPopNext` sets it `false`. Because the
/// subscription is keyed on the shell's own route, popping a route that sits
/// *above another pushed route* (e.g. closing a fullscreen video while a
/// profile is still open) does not flip it back to `false` — only popping the
/// route directly above the shell does.
///
/// `didPush` resets it to `false` whenever a fresh shell mounts, so a stale
/// `true` left behind when the shell is removed while covered and re-shown
/// without a pop event (e.g. sign-out → /welcome → back to home) cannot keep
/// the feed paused.
///
/// AppShell also reconciles `overlayVisibilityProvider` when this flag becomes
/// `false`. A fresh shell mount clears every stale overlay owner only when the
/// shell is the current route. No branch-navigator sheet can predate that new
/// shell, while a non-current shell may still sit below a live page owner.
/// `didPopNext` is narrower: it clears only page owners because go_router can
/// remove a pushed route with `go()` without completing the original
/// `pushWithVideoPause` future. It preserves bottom-sheet owners because a
/// branch-navigator sheet can remain visible while an unrelated root route is
/// pushed and popped above the shell; that sheet releases its own owner when
/// its route is dismissed.
///
/// The home feed reads this to know it is offstage behind a pushed screen.
/// GoRouter's `routeInformationProvider` collapses to the shell location
/// (`/home`) while popping between pushed routes, so the feed cannot rely on
/// route reporting alone to tell whether it is actually visible.
final shellObscuredProvider = NotifierProvider<ShellObscuredNotifier, bool>(
  ShellObscuredNotifier.new,
);

class ShellObscuredNotifier extends Notifier<bool> {
  @override
  bool build() => false;

  void setObscured({required bool obscured}) {
    if (state != obscured) state = obscured;
  }
}
