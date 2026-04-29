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
    required this.packData,
    this.networkUrl,
    this.assetPath,
  });

  /// Creates a [StickerData] from a network URL.
  const factory StickerData.network(
    String url, {
    required String description,
    required List<String> tags,
    required StickerPackData packData,
  }) = _NetworkStickerData;

  /// Creates a [StickerData] from a local asset path.
  const factory StickerData.asset(
    String path, {
    required String description,
    required List<String> tags,
    required StickerPackData packData,
  }) = _AssetStickerData;

  /// Creates a [StickerData] from a JSON map.
  ///
  /// Expected keys:
  /// - `networkUrl` (String, optional): The URL of a network image.
  /// - `assetPath` (String, optional): The path to a local asset image.
  /// - `description` (String): A human-readable description.
  /// - `tags` (List): Keywords for search functionality.
  /// - `packData` (Map, optional): Sticker pack metadata. Absent in older
  ///   serialized data — falls back to an empty [StickerPackData] so legacy
  ///   JSON remains deserializable.
  factory StickerData.fromJson(Map<String, dynamic> json) {
    return StickerData(
      networkUrl: json['networkUrl'] as String?,
      assetPath: json['assetPath'] as String?,
      description: json['description'] as String,
      tags: (json['tags'] as List<dynamic>).cast<String>(),
      packData: json['packData'] != null
          ? StickerPackData.fromJson(json['packData'] as Map<String, dynamic>)
          : const StickerPackData(packId: '', packName: ''),
    );
  }

  String get layerName {
    if (packData.packName.isEmpty) return description;

    return '$description ∙ ${packData.packName}';
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

  /// The sticker pack this sticker belongs to.
  final StickerPackData packData;

  /// Creates a copy of this [StickerData] with the given fields
  /// replaced by new values.
  StickerData copyWith({
    String? networkUrl,
    String? assetPath,
    String? description,
    List<String>? tags,
    StickerPackData? packData,
  }) {
    return StickerData(
      networkUrl: networkUrl ?? this.networkUrl,
      assetPath: assetPath ?? this.assetPath,
      description: description ?? this.description,
      tags: tags ?? this.tags,
      packData: packData ?? this.packData,
    );
  }

  /// Converts this [StickerData] to a JSON map.
  Map<String, dynamic> toJson() {
    return {
      if (networkUrl != null) 'networkUrl': networkUrl,
      if (assetPath != null) 'assetPath': assetPath,
      'description': description,
      'tags': tags,
      'packData': packData.toJson(),
    };
  }

  @override
  List<Object> get props => [
    ?networkUrl,
    ?assetPath,
    description,
    tags,
    packData,
  ];
}

/// Metadata about the sticker pack a [StickerData] belongs to.
///
/// Allows stickers to be grouped and filtered by pack in the picker UI.
class StickerPackData extends Equatable {
  /// Creates a new [StickerPackData] instance.
  const StickerPackData({
    required this.packId,
    required this.packName,
  });

  /// Creates a [StickerPackData] from a JSON map.
  ///
  /// Expected keys:
  /// - `packId` (String): The unique identifier of the sticker pack.
  /// - `packName` (String): The display name of the sticker pack.
  factory StickerPackData.fromJson(Map<String, dynamic> json) {
    return StickerPackData(
      packId: json['packId'] as String,
      packName: json['packName'] as String,
    );
  }

  /// Fallback pack used when a sticker has no pack metadata.
  static const fallback = StickerPackData(
    packId: 'diVine',
    packName: 'Divine Originals',
  );

  /// The unique identifier of the sticker pack.
  final String packId;

  /// The display name of the sticker pack (e.g. "Holiday", "Reactions").
  final String packName;

  /// Creates a copy of this [StickerPackData] with the given fields
  /// replaced by new values.
  StickerPackData copyWith({
    String? packId,
    String? packName,
  }) {
    return StickerPackData(
      packId: packId ?? this.packId,
      packName: packName ?? this.packName,
    );
  }

  /// Converts this [StickerPackData] to a JSON map.
  Map<String, dynamic> toJson() {
    return {
      'packId': packId,
      'packName': packName,
    };
  }

  @override
  List<Object?> get props => [packId, packName];
}

class _NetworkStickerData extends StickerData {
  const _NetworkStickerData(
    String url, {
    required super.description,
    required super.tags,
    required super.packData,
  }) : super(networkUrl: url);
}

class _AssetStickerData extends StickerData {
  const _AssetStickerData(
    String path, {
    required super.description,
    required super.tags,
    required super.packData,
  }) : super(assetPath: path);
}
