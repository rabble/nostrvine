// ABOUTME: Shared Flutter accessibility-guideline assertions for widget tests.
// ABOUTME: Owns the SemanticsHandle so a failing check cannot leak one.

import 'package:flutter_test/flutter_test.dart';

/// The guidelines every interactive `divine_ui` control is expected to meet.
///
/// * [androidTapTargetGuideline] / [iOSTapTargetGuideline] hold tap targets at
///   48dp / 44pt.
/// * [labeledTapTargetGuideline] catches a tappable node that announces
///   nothing to a screen reader.
///
/// [textContrastGuideline] is deliberately absent. It rasterizes the tree
/// inside `runAsync`, which lets a pending `google_fonts` load surface as a
/// test error, and `divine_ui` bundles no font assets for `VineTheme`
/// typography to fall back on. The app layer bundles BricolageGrotesque and
/// Inter, so its copy of this helper adds contrast to the default set — put
/// contrast coverage for real components there.
const divineSemanticsGuidelines = <AccessibilityGuideline>[
  androidTapTargetGuideline,
  iOSTapTargetGuideline,
  labeledTapTargetGuideline,
];

/// Asserts the currently pumped widget tree meets [guidelines].
///
/// Call after `pumpWidget`. Semantics are enabled for the duration of the
/// check and the handle is disposed afterwards, including when an assertion
/// fails, so the count stays balanced across the merged test isolate.
///
/// Keep the subject away from the viewport and scrollable edges. Flutter's
/// tap-target guidelines skip boundary-touching semantics nodes because they
/// may be partially off-screen, so flush fixtures can pass without evaluating
/// the intended target size.
Future<void> expectMeetsAccessibilityGuidelines(
  WidgetTester tester, {
  Iterable<AccessibilityGuideline> guidelines = divineSemanticsGuidelines,
  String? reason,
}) async {
  final handle = tester.ensureSemantics();
  try {
    for (final guideline in guidelines) {
      await expectLater(tester, meetsGuideline(guideline), reason: reason);
    }
  } finally {
    handle.dispose();
  }
}
