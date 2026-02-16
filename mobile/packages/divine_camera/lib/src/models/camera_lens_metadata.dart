// ABOUTME: Metadata class for camera lens properties
// ABOUTME: Contains hardware info like focal length, aperture, sensor size

import 'package:equatable/equatable.dart';

/// Contains hardware metadata for a specific camera lens.
///
/// This includes physical characteristics like focal length, aperture,
/// sensor dimensions, and capabilities like minimum focus distance.
class CameraLensMetadata extends Equatable {
  /// Creates camera lens metadata.
  const CameraLensMetadata({
    required this.lensType,
    this.focalLength,
    this.focalLengthEquivalent35mm,
    this.aperture,
    this.sensorWidth,
    this.sensorHeight,
    this.pixelArrayWidth,
    this.pixelArrayHeight,
    this.minFocusDistance,
    this.fieldOfView,
    this.hasOpticalStabilization = false,
    this.isLogicalCamera = false,
    this.physicalCameraIds = const [],
  });

  /// Creates [CameraLensMetadata] from a platform map.
  factory CameraLensMetadata.fromMap(Map<dynamic, dynamic> map) {
    return CameraLensMetadata(
      lensType: map['lensType'] as String? ?? 'unknown',
      focalLength: (map['focalLength'] as num?)?.toDouble(),
      focalLengthEquivalent35mm: (map['focalLengthEquivalent35mm'] as num?)
          ?.toDouble(),
      aperture: (map['aperture'] as num?)?.toDouble(),
      sensorWidth: (map['sensorWidth'] as num?)?.toDouble(),
      sensorHeight: (map['sensorHeight'] as num?)?.toDouble(),
      pixelArrayWidth: map['pixelArrayWidth'] as int?,
      pixelArrayHeight: map['pixelArrayHeight'] as int?,
      minFocusDistance: (map['minFocusDistance'] as num?)?.toDouble(),
      fieldOfView: (map['fieldOfView'] as num?)?.toDouble(),
      hasOpticalStabilization: map['hasOpticalStabilization'] as bool? ?? false,
      isLogicalCamera: map['isLogicalCamera'] as bool? ?? false,
      physicalCameraIds:
          (map['physicalCameraIds'] as List<dynamic>?)
              ?.whereType<String>()
              .toList() ??
          const [],
    );
  }

  /// The lens type identifier (e.g., 'back', 'front', 'ultraWide').
  final String lensType;

  /// Physical focal length in millimeters.
  ///
  /// Typical values:
  /// - Ultra-wide: ~1.5-2.5mm
  /// - Wide (main): ~4-6mm
  /// - Telephoto: ~6-12mm
  final double? focalLength;

  /// 35mm equivalent focal length.
  ///
  /// This standardized value allows comparison across devices:
  /// - Ultra-wide: ~13-16mm
  /// - Wide (main): ~24-28mm
  /// - Telephoto: ~52-77mm
  final double? focalLengthEquivalent35mm;

  /// Lens aperture (f-number).
  ///
  /// Lower values = wider aperture = more light.
  /// Typical smartphone values: f/1.5 - f/2.8
  final double? aperture;

  /// Physical sensor width in millimeters.
  final double? sensorWidth;

  /// Physical sensor height in millimeters.
  final double? sensorHeight;

  /// Sensor resolution width in pixels.
  final int? pixelArrayWidth;

  /// Sensor resolution height in pixels.
  final int? pixelArrayHeight;

  /// Minimum focus distance in diopters (1/distance in meters).
  ///
  /// Higher values = closer focusing capability.
  /// - Normal lenses: ~10 diopters (~10cm)
  /// - Macro lenses: ~25+ diopters (~4cm or less)
  /// - Fixed-focus front cameras: often 0 (infinity focus)
  final double? minFocusDistance;

  /// Horizontal field of view in degrees.
  ///
  /// Typical values:
  /// - Ultra-wide: ~120°
  /// - Wide (main): ~80°
  /// - Telephoto: ~40°
  final double? fieldOfView;

  /// Whether this lens has optical image stabilization (OIS).
  final bool hasOpticalStabilization;

  /// Whether this is a logical multi-camera
  /// (combines multiple physical cameras).
  final bool isLogicalCamera;

  /// IDs of physical cameras that make up this logical camera.
  final List<String> physicalCameraIds;

  /// Sensor resolution in megapixels.
  double? get megapixels {
    if (pixelArrayWidth == null || pixelArrayHeight == null) return null;
    return (pixelArrayWidth! * pixelArrayHeight!) / 1e6;
  }

  /// Minimum focus distance in centimeters.
  ///
  /// Returns null if the camera has fixed focus (diopters = 0).
  double? get minFocusDistanceCm {
    if (minFocusDistance == null || minFocusDistance == 0) return null;
    return 100.0 / minFocusDistance!;
  }

  /// Whether this lens can be considered a macro lens.
  ///
  /// Based on minimum focus distance being very close (< 5cm).
  bool get isMacroCapable {
    final distance = minFocusDistanceCm;
    return distance != null && distance < 5.0;
  }

  /// Converts this [CameraLensMetadata] to a map.
  Map<String, dynamic> toMap() {
    return {
      'lensType': lensType,
      'focalLength': focalLength,
      'focalLengthEquivalent35mm': focalLengthEquivalent35mm,
      'aperture': aperture,
      'sensorWidth': sensorWidth,
      'sensorHeight': sensorHeight,
      'pixelArrayWidth': pixelArrayWidth,
      'pixelArrayHeight': pixelArrayHeight,
      'minFocusDistance': minFocusDistance,
      'fieldOfView': fieldOfView,
      'hasOpticalStabilization': hasOpticalStabilization,
      'isLogicalCamera': isLogicalCamera,
      'physicalCameraIds': physicalCameraIds,
    };
  }

  @override
  String toString() {
    return 'CameraLensMetadata('
        'lensType: $lensType, '
        'focalLength: ${focalLength}mm, '
        'aperture: f/$aperture, '
        'megapixels: ${megapixels?.toStringAsFixed(1)}MP)';
  }

  @override
  List<Object?> get props => [
    lensType,
    focalLength,
    focalLengthEquivalent35mm,
    aperture,
    sensorWidth,
    sensorHeight,
    pixelArrayWidth,
    pixelArrayHeight,
    minFocusDistance,
    fieldOfView,
    hasOpticalStabilization,
    isLogicalCamera,
    physicalCameraIds,
  ];
}
