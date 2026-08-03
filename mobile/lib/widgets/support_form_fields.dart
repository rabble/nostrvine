// ABOUTME: Base form state for the support flows (bug report, feature request)
// ABOUTME: Owns the subject/description pair and the footer's change signal

import 'package:flutter/widgets.dart';

/// The two required fields every support sheet collects, plus the focus
/// wiring and the change signal its pinned footer needs.
///
/// Subclasses add their own optional fields and dispose them before calling
/// `super.dispose()`.
abstract class SupportFormFields {
  final subject = TextEditingController();
  final description = TextEditingController();

  /// Target of the subject field's keyboard "next" action. The remaining
  /// fields are multiline, so their action key inserts a newline instead of
  /// advancing.
  final descriptionFocus = FocusNode();

  /// Notifies when a required field changes, so the footer can re-evaluate
  /// whether the form can be sent.
  ///
  /// Built once so the footer's `ListenableBuilder` keeps a single
  /// subscription; a fresh `Listenable.merge` per read would tear it down and
  /// rebuild it on every rebuild of the footer.
  late final Listenable requiredFields = Listenable.merge([
    subject,
    description,
  ]);

  bool get canSubmit =>
      subject.text.trim().isNotEmpty && description.text.trim().isNotEmpty;

  @mustCallSuper
  void dispose() {
    subject.dispose();
    description.dispose();
    descriptionFocus.dispose();
  }
}
