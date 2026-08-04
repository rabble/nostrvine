// ABOUTME: Completion handshake shared by the profile tab sync events
// ABOUTME: Lets pull-to-refresh await a sync's real end, cache write included

import 'dart:async';

/// Completes [completer] unless it has already fired.
///
/// Every profile tab sync event carries an optional `Completer<void>` that its
/// handler completes in a `finally`, and `ProfileGridView` awaits those
/// completers to hold the pull-to-refresh indicator.
///
/// Watching the state stream instead cannot express this: a re-sync that finds
/// nothing changed emits a state equal to the current one, which bloc
/// suppresses, and a handler can stay busy past its terminal emit — the
/// cache-backed tabs write their snapshot there. That leaves a window in which
/// the tab looks settled while its handler is still running.
void completeProfileTabSync(Completer<void>? completer) {
  if (completer != null && !completer.isCompleted) {
    completer.complete();
  }
}
