// ABOUTME: Completion handshake shared by the profile tab sync events
// ABOUTME: Lets pull-to-refresh await a sync's real end, cache write included

import 'dart:async';

/// Releases the refresh waiter attached to a profile tab sync event.
///
/// Every profile tab sync event carries an optional `Completer<void>`, and
/// `ProfileGridView` awaits those completers to hold the pull-to-refresh
/// indicator. Call this exactly once per handled event, from a `finally`, so
/// the waiter is released on the error path too.
///
/// Watching the state stream instead cannot express this: a re-sync that finds
/// nothing changed emits a state equal to the current one, which bloc
/// suppresses, and a handler can stay busy past its terminal emit — the
/// cache-backed tabs write their snapshot there. That leaves a window in which
/// the tab looks settled while its handler is still running.
void completeProfileTabSync(Completer<void>? completer) =>
    completer?.complete();
