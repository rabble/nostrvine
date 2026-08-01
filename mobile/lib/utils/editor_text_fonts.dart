// ABOUTME: Registers the editor's Google Fonts before restored text renders
// ABOUTME: Shared by the editor screen and the headless draft rasterizer

import 'package:google_fonts/google_fonts.dart';
import 'package:openvine/constants/video_editor_constants.dart';

/// Registers every text-overlay font so a restored [TextLayer] paints in the
/// typeface the user picked.
///
/// A persisted text layer carries only the serialized font family name, and
/// Google Fonts register lazily per process. Anything that renders imported
/// overlays — the editor canvas importing a state history, or the headless
/// rasterizer baking them for a publish — has to register them first, or the
/// text falls back to the platform default: wrong typeface, and wrong metrics,
/// which also moves the layer (#5181).
///
/// Already-cached fonts resolve instantly; the timeout only bounds the first,
/// uncached load. Timing out is not an error — the render proceeds with
/// whatever resolved.
Future<void> preloadEditorTextFonts() async {
  for (final font in VideoEditorConstants.textFonts) {
    font();
  }
  await GoogleFonts.pendingFonts().timeout(
    VideoEditorConstants.textFontLoadTimeout,
    onTimeout: () => const [],
  );
}
