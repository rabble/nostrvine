import 'dart:math' as math;

/// Converts an 8-bit sRGB channel value (0–255) to linear light (0–1).
double sRgbToLinear(int value) {
  final v = value / 255.0;
  if (v <= 0.04045) return v / 12.92;
  return math.pow((v + 0.055) / 1.055, 2.4).toDouble();
}

/// Converts a linear-light channel value to an 8-bit sRGB value (0–255).
///
/// Values outside 0–1 (AC overshoot) are clamped before conversion.
int linearToSRgb(double value) {
  final v = value.clamp(0.0, 1.0);
  if (v <= 0.0031308) {
    return (v * 12.92 * 255 + 0.5).toInt();
  }
  return ((1.055 * math.pow(v, 1 / 2.4) - 0.055) * 255 + 0.5).toInt();
}

/// Raises [value] to [exponent] while preserving its sign
/// (`sign(value) * pow(|value|, exponent)`).
double signPow(double value, double exponent) =>
    math.pow(value.abs(), exponent).toDouble() * value.sign;
