// ABOUTME: Provides the app-wide LayerRasterizer used to bake draft layers
// ABOUTME: Its host is mounted once in main.dart above every route

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:pro_image_editor/pro_image_editor.dart';

/// The single [LayerRasterizer] for the app.
///
/// Layers can only be captured while mounted, so this is paired with exactly
/// one `LayerRasterizerHost` in `main.dart`. Keep it app-scoped: a rasterizer
/// whose host is gone throws on capture, which is why it must not be tied to
/// the lifetime of any screen.
final layerRasterizerProvider = Provider<LayerRasterizer>((ref) {
  final rasterizer = LayerRasterizer();
  ref.onDispose(rasterizer.dispose);
  return rasterizer;
});
