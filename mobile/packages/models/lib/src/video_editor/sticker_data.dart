import 'package:equatable/equatable.dart';

/// Data model representing a sticker in the video editor.
///
/// A sticker can be loaded from either a network URL or a local asset path.
/// At least one of [networkUrl] or [assetPath] should be provided.
class StickerData extends Equatable {
  /// Creates a new [StickerData] instance.
  const StickerData({
    required this.description,
    required this.tags,
    this.networkUrl,
    this.assetPath,
  });

  /// Creates a [StickerData] from a network URL.
  const factory StickerData.network(
    String url, {
    required String description,
    required List<String> tags,
  }) = _NetworkStickerData;

  /// Creates a [StickerData] from a local asset path.
  const factory StickerData.asset(
    String path, {
    required String description,
    required List<String> tags,
  }) = _AssetStickerData;

  /// Creates a [StickerData] from a JSON map.
  ///
  /// Expected keys:
  /// - `networkUrl` (String, optional): The URL of a network image.
  /// - `assetPath` (String, optional): The path to a local asset image.
  /// - `description` (String): A human-readable description.
  /// - `tags` (List): Keywords for search functionality.
  factory StickerData.fromJson(Map<String, dynamic> json) {
    return StickerData(
      networkUrl: json['networkUrl'] as String?,
      assetPath: json['assetPath'] as String?,
      description: json['description'] as String,
      tags: (json['tags'] as List<dynamic>).cast<String>(),
    );
  }

  /// The URL of a network image to display.
  ///
  /// If provided, the sticker image will be fetched from this URL.
  final String? networkUrl;

  /// The path to a local asset image to display.
  ///
  /// If provided, the sticker image will be loaded from the app's assets.
  final String? assetPath;

  /// A human-readable description of the sticker.
  ///
  /// Used for accessibility and semantic labels (e.g., screen readers).
  final String description;

  /// A list of keywords associated with the sticker.
  ///
  /// Used for search functionality to help users find stickers by
  /// related terms.
  /// For example, a heart sticker might have tags like
  /// `['love', 'heart', 'romantic']`.
  final List<String> tags;

  /// Creates a copy of this [StickerData] with the given fields
  /// replaced by new values.
  StickerData copyWith({
    String? networkUrl,
    String? assetPath,
    String? description,
    List<String>? tags,
  }) {
    return StickerData(
      networkUrl: networkUrl ?? this.networkUrl,
      assetPath: assetPath ?? this.assetPath,
      description: description ?? this.description,
      tags: tags ?? this.tags,
    );
  }

  /// Converts this [StickerData] to a JSON map.
  Map<String, dynamic> toJson() {
    return {
      if (networkUrl != null) 'networkUrl': networkUrl,
      if (assetPath != null) 'assetPath': assetPath,
      'description': description,
      'tags': tags,
    };
  }

  @override
  List<Object?> get props => [networkUrl, assetPath, description, tags];
}

class _NetworkStickerData extends StickerData {
  const _NetworkStickerData(
    String url, {
    required super.description,
    required super.tags,
  }) : super(networkUrl: url);
}

class _AssetStickerData extends StickerData {
  const _AssetStickerData(
    String path, {
    required super.description,
    required super.tags,
  }) : super(assetPath: path);
}
