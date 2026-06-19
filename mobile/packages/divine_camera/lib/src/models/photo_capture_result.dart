// ABOUTME: Result class for single-photo capture operations
// ABOUTME: Contains the file path and pixel dimensions of the captured photo

import 'dart:io';

import 'package:equatable/equatable.dart';

/// Result of a single-photo capture operation.
class PhotoCaptureResult extends Equatable {
  /// Creates a new photo capture result.
  const PhotoCaptureResult({required this.filePath, this.width, this.height});

  /// Creates a [PhotoCaptureResult] from a map.
  factory PhotoCaptureResult.fromMap(Map<dynamic, dynamic> map) {
    return PhotoCaptureResult(
      filePath: map['filePath'] as String,
      width: map['width'] as int?,
      height: map['height'] as int?,
    );
  }

  /// The path to the captured photo file (JPEG).
  final String filePath;

  /// The width of the captured photo in pixels.
  final int? width;

  /// The height of the captured photo in pixels.
  final int? height;

  /// Returns the captured photo file.
  File get file => File(filePath);

  /// Converts this result to a map.
  Map<String, dynamic> toMap() {
    return {'filePath': filePath, 'width': width, 'height': height};
  }

  @override
  String toString() {
    return 'PhotoCaptureResult(filePath: $filePath, width: $width, '
        'height: $height)';
  }

  @override
  List<Object?> get props => [filePath, width, height];
}
