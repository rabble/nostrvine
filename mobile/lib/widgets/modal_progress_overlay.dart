// ABOUTME: A blocking spinner shown as an OverlayEntry, removed by identity.
// ABOUTME: Deliberately not a dialog route, so it cannot be popped mid-await.

import 'package:divine_ui/divine_ui.dart';
import 'package:flutter/material.dart';

/// A blocking spinner inserted into the root [Overlay].
///
/// Intentionally an [OverlayEntry] rather than a dialog route. A dialog route
/// can be dismissed by the Android back button even with
/// `barrierDismissible: false`, which would let the user walk away from an
/// in-flight await and leave the caller believing its spinner is still up. An
/// overlay entry has no route to pop, so [dismiss] is the only way it goes away.
///
/// [dismiss] is idempotent and safe to call after the entry is gone.
class ModalProgressOverlay {
  ModalProgressOverlay._(this._entry);

  final OverlayEntry _entry;
  bool _dismissed = false;

  static ModalProgressOverlay show(BuildContext context) {
    final entry = OverlayEntry(builder: (_) => const _BlockingSpinner());
    Overlay.of(context, rootOverlay: true).insert(entry);
    return ModalProgressOverlay._(entry);
  }

  void dismiss() {
    if (_dismissed || !_entry.mounted) return;
    _dismissed = true;
    _entry.remove();
  }
}

class _BlockingSpinner extends StatelessWidget {
  const _BlockingSpinner();

  @override
  Widget build(BuildContext context) {
    return const AbsorbPointer(
      child: SizedBox.expand(
        child: Center(
          child: CircularProgressIndicator(color: VineTheme.vineGreen),
        ),
      ),
    );
  }
}
