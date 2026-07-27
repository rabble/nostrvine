// ABOUTME: Blocking spinner inserted into the root overlay, dismissed by its owner
// ABOUTME: Used while a tap resolves data before the real dialog can open

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';

/// A blocking spinner the caller shows and hides explicitly.
///
/// Inserted into the root [Overlay] rather than pushed as a route: the caller
/// owns its lifetime for the length of an await, and a route could be popped
/// out from under it by a system back gesture while that await is still
/// running. Nothing here is dismissible by the user.
///
/// [dismiss] is safe to call more than once and after the overlay is gone,
/// which lets it sit in a `finally` without a mounted check at every call site.
class ModalProgressOverlay {
  ModalProgressOverlay._(this._entry);

  final OverlayEntry _entry;
  bool _dismissed = false;

  static ModalProgressOverlay show(BuildContext context) {
    final entry = OverlayEntry(
      builder: (context) => const _ProgressBarrier(),
    );
    Overlay.of(context, rootOverlay: true).insert(entry);
    return ModalProgressOverlay._(entry);
  }

  /// Removes the spinner. Safe to call twice, and safe to call before the
  /// entry has been built — [OverlayEntry.remove] handles both an unbuilt
  /// entry and an overlay that has already been disposed.
  void dismiss() {
    if (_dismissed) return;
    _dismissed = true;
    _entry
      ..remove()
      ..dispose();
  }
}

class _ProgressBarrier extends StatelessWidget {
  const _ProgressBarrier();

  @override
  Widget build(BuildContext context) {
    return const ColoredBox(
      color: VineTheme.scrim50,
      child: Center(
        child: CircularProgressIndicator(color: VineTheme.vineGreen),
      ),
    );
  }
}
