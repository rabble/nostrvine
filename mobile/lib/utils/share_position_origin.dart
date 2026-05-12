import 'package:flutter/material.dart';

Rect? sharePositionOriginForContext(BuildContext context) {
  final renderObject = context.findRenderObject();
  if (renderObject is! RenderBox || !renderObject.hasSize) return null;
  final topLeft = renderObject.localToGlobal(Offset.zero);
  final rect = topLeft & renderObject.size;
  if (rect.isEmpty) return null;
  return rect;
}
