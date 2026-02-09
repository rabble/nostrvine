// ABOUTME: Generates transparent PNG watermark overlays for video exports
// ABOUTME: Draws the diVine logo + username + URL at bottom-right with 60% opacity

import 'dart:ui' as ui;

import 'package:flutter/services.dart';

/// Generates a transparent PNG watermark overlay for video exports.
///
/// The watermark includes the diVine logo, @username, and "divine.video" URL
/// positioned in the bottom-right corner at 60% opacity.
class WatermarkImageGenerator {
  WatermarkImageGenerator._();

  static const _logoAssetPath = 'assets/icon/White on transparent.png';
  static const _watermarkOpacity = 0.6;
  static const _margin = 16.0;

  /// Generates a transparent PNG watermark image at the given resolution.
  ///
  /// The watermark includes:
  /// - diVine logo (from assets) in bottom-right corner
  /// - @username text below the logo
  /// - "divine.video" URL text below username
  /// All at ~60% opacity, sized to ~10% of video width.
  ///
  /// Returns PNG bytes ([Uint8List]) suitable for use as an image overlay.
  ///
  /// Throws [WatermarkGenerationException] if the logo asset cannot be loaded
  /// or image encoding fails.
  static Future<Uint8List> generateWatermark({
    required int videoWidth,
    required int videoHeight,
    required String username,
  }) async {
    final logoImage = await _loadLogoImage();

    try {
      final recorder = ui.PictureRecorder();
      final canvas = ui.Canvas(recorder);

      final logoSize = videoWidth * 0.10;
      final fontSize = logoSize * 0.22;
      final smallFontSize = fontSize * 0.85;

      // Draw username text
      final usernameParagraph = _buildParagraph(
        '@$username',
        fontSize,
        logoSize * 1.5,
      );
      usernameParagraph.layout(ui.ParagraphConstraints(width: logoSize * 1.5));

      // Draw URL text
      final urlParagraph = _buildParagraph(
        'divine.video',
        smallFontSize,
        logoSize * 1.5,
      );
      urlParagraph.layout(ui.ParagraphConstraints(width: logoSize * 1.5));

      // Calculate total block height: logo + gap + username + gap + url
      final gap = fontSize * 0.3;
      final totalHeight =
          logoSize + gap + usernameParagraph.height + gap + urlParagraph.height;

      // Position the block in the bottom-right corner
      final blockRight = videoWidth - _margin;
      final blockBottom = videoHeight - _margin;
      final blockTop = blockBottom - totalHeight;

      // Draw logo - right-aligned within the block
      final logoPaint = ui.Paint()
        ..color = ui.Color.fromRGBO(255, 255, 255, _watermarkOpacity);

      final logoAspectRatio = logoImage.width / logoImage.height;
      final logoDrawWidth = logoSize;
      final logoDrawHeight = logoDrawWidth / logoAspectRatio;

      final logoLeft = blockRight - logoDrawWidth;
      final logoTop = blockTop;

      canvas.drawImageRect(
        logoImage,
        ui.Rect.fromLTWH(
          0,
          0,
          logoImage.width.toDouble(),
          logoImage.height.toDouble(),
        ),
        ui.Rect.fromLTWH(logoLeft, logoTop, logoDrawWidth, logoDrawHeight),
        logoPaint,
      );

      // Draw username text - right-aligned below logo
      final usernameTop = logoTop + logoDrawHeight + gap;
      final usernameLeft = blockRight - usernameParagraph.maxIntrinsicWidth;
      canvas.drawParagraph(
        usernameParagraph,
        ui.Offset(usernameLeft, usernameTop),
      );

      // Draw URL text - right-aligned below username
      final urlTop = usernameTop + usernameParagraph.height + gap;
      final urlLeft = blockRight - urlParagraph.maxIntrinsicWidth;
      canvas.drawParagraph(urlParagraph, ui.Offset(urlLeft, urlTop));

      // Convert to image
      final picture = recorder.endRecording();
      final image = await picture.toImage(videoWidth, videoHeight);
      final byteData = await image.toByteData(format: ui.ImageByteFormat.png);

      if (byteData == null) {
        throw const WatermarkGenerationException(
          'Failed to encode watermark image to PNG',
        );
      }

      return byteData.buffer.asUint8List();
    } finally {
      logoImage.dispose();
    }
  }

  /// Loads the diVine logo from app assets.
  static Future<ui.Image> _loadLogoImage() async {
    try {
      final data = await rootBundle.load(_logoAssetPath);
      final codec = await ui.instantiateImageCodec(data.buffer.asUint8List());
      final frame = await codec.getNextFrame();
      codec.dispose();
      return frame.image;
    } catch (e) {
      throw WatermarkGenerationException('Failed to load logo asset: $e');
    }
  }

  /// Builds a right-aligned paragraph with the watermark text style.
  static ui.Paragraph _buildParagraph(
    String text,
    double fontSize,
    double maxWidth,
  ) {
    final builder =
        ui.ParagraphBuilder(
            ui.ParagraphStyle(textAlign: ui.TextAlign.right, maxLines: 1),
          )
          ..pushStyle(
            ui.TextStyle(
              color: ui.Color.fromRGBO(255, 255, 255, _watermarkOpacity),
              fontSize: fontSize,
              fontWeight: ui.FontWeight.w600,
            ),
          )
          ..addText(text)
          ..pop();

    return builder.build();
  }
}

/// Exception thrown when watermark generation fails.
class WatermarkGenerationException implements Exception {
  /// Creates a [WatermarkGenerationException] with the given [message].
  const WatermarkGenerationException(this.message);

  /// The error message.
  final String message;

  @override
  String toString() => 'WatermarkGenerationException: $message';
}
