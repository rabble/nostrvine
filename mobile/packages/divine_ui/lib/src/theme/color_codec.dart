import 'package:flutter/painting.dart';

/// Reconstructs a [Color] from a 32-bit ARGB integer.
///
/// The inverse of [Color.toARGB32], for decoding colors persisted as ints
/// (e.g. in JSON). Lives in the design-system package so app code can
/// round-trip colors without raw `Color(int)` construction.
Color colorFromArgb32(int argb) => Color(argb);
