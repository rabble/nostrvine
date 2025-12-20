// ABOUTME: Service that renders text overlays to PNG images using Flutter Canvas API
// ABOUTME: Supports multiple overlays with normalized positioning, custom fonts, colors, and alignment

import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:openvine/models/text_overlay.dart';
import 'package:openvine/utils/unified_logger.dart';

class TextOverlayRenderer {
  /// Renders a list of text overlays to a PNG image
  ///
  /// [overlays] - List of TextOverlay objects to render
  /// [videoSize] - Size of the video canvas in pixels
  /// [previewSize] - Size of the preview where text was positioned (for scaling)
  ///
  /// Returns PNG image data as Uint8List
  Future<Uint8List> renderOverlays(
    List<TextOverlay> overlays,
    Size videoSize, {
    Size? previewSize,
  }) async {
    try {
      Log.info(
        'Rendering ${overlays.length} overlays to ${videoSize.width}x${videoSize.height} canvas',
        name: 'TextOverlayRenderer',
        category: LogCategory.system,
      );

      // Create a picture recorder to capture canvas drawing
      final recorder = ui.PictureRecorder();
      final canvas = Canvas(
        recorder,
        Rect.fromLTWH(0, 0, videoSize.width, videoSize.height),
      );

      // Calculate scale factor for font sizing
      // If previewSize is provided, scale fonts from preview size to video size
      final scaleFactor = previewSize != null
          ? videoSize.width / previewSize.width
          : 1.0;

      Log.info(
        'Font scale factor: $scaleFactor (preview: ${previewSize?.width ?? 'N/A'}, video: ${videoSize.width})',
        name: 'TextOverlayRenderer',
        category: LogCategory.system,
      );

      // Render each overlay
      for (final overlay in overlays) {
        _renderSingleOverlay(canvas, overlay, videoSize, scaleFactor);
      }

      // Convert canvas to image
      final picture = recorder.endRecording();
      final image = await picture.toImage(
        videoSize.width.toInt(),
        videoSize.height.toInt(),
      );

      // Encode image to PNG
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

      if (byteData == null) {
        throw Exception('Failed to encode image to PNG');
      }

      final pngBytes = byteData.buffer.asUint8List();

      Log.info(
        'Successfully rendered overlays to PNG (${pngBytes.length} bytes)',
        name: 'TextOverlayRenderer',
        category: LogCategory.system,
      );

      return pngBytes;
    } catch (e, stackTrace) {
      Log.error(
        'Failed to render overlays: $e',
        name: 'TextOverlayRenderer',
        category: LogCategory.system,
        error: e,
        stackTrace: stackTrace,
      );
      rethrow;
    }
  }

  /// Renders a single text overlay on the canvas
  void _renderSingleOverlay(
    Canvas canvas,
    TextOverlay overlay,
    Size videoSize,
    double scaleFactor,
  ) {
    // Calculate absolute position from normalized position
    final absoluteX = overlay.normalizedPosition.dx * videoSize.width;
    final absoluteY = overlay.normalizedPosition.dy * videoSize.height;

    // Scale font size from preview to video resolution
    final scaledFontSize = overlay.fontSize * scaleFactor;

    // Create text painter with Google Fonts
    final textSpan = TextSpan(
      text: overlay.text,
      style: GoogleFonts.getFont(
        overlay.fontFamily,
        fontSize: scaledFontSize,
        color: overlay.color,
      ),
    );

    final textPainter = TextPainter(
      text: textSpan,
      textAlign: overlay.alignment,
      textDirection: TextDirection.ltr,
    );

    // Layout the text
    textPainter.layout();

    // Use top-left positioning to match DraggableTextOverlay preview behavior
    // The normalized position represents the top-left corner of the text
    final offsetX = absoluteX;
    final offsetY = absoluteY;

    // Paint the text
    textPainter.paint(canvas, Offset(offsetX, offsetY));
  }
}
