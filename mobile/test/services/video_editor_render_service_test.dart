// ABOUTME: Tests for composite export progress allocation in VideoEditorRenderService
// ABOUTME: Verifies the reserved ProofMode progress budget stays within the intended bounds

import 'package:flutter_test/flutter_test.dart';
import 'package:openvine/services/video_editor/video_editor_render_service.dart';

void main() {
  group('VideoEditorRenderService proof progress allocation', () {
    test('reserves a minimum of 5 percent for proof finalization', () {
      expect(
        VideoEditorRenderService.proofModeProgressBudgetForClipCount(1),
        closeTo(0.05, 1e-9),
      );
      expect(
        VideoEditorRenderService.proofModeProgressBudgetForClipCount(3),
        closeTo(0.05, 1e-9),
      );
    });

    test('scales proof budget with clip count until the 10 percent cap', () {
      expect(
        VideoEditorRenderService.proofModeProgressBudgetForClipCount(5),
        closeTo(0.05, 1e-9),
      );
      expect(
        VideoEditorRenderService.proofModeProgressBudgetForClipCount(7),
        closeTo(0.07, 1e-9),
      );
      expect(
        VideoEditorRenderService.proofModeProgressBudgetForClipCount(10),
        closeTo(0.10, 1e-9),
      );
      expect(
        VideoEditorRenderService.proofModeProgressBudgetForClipCount(30),
        closeTo(0.10, 1e-9),
      );
    });
  });
}
