import 'package:equatable/equatable.dart';

/// A single entry from the Nostr app directory.
///
/// Represents a vetted third-party Nostr app that can be surfaced
/// inside the host application.
class NostrAppDirectoryEntry extends Equatable {
  /// Creates a directory entry.
  const NostrAppDirectoryEntry({
    required this.id,
    required this.slug,
    required this.name,
    required this.tagline,
    required this.description,
    required this.iconUrl,
    required this.launchUrl,
    required this.allowedOrigins,
    required this.allowedMethods,
    required this.allowedSignEventKinds,
    required this.promptRequiredFor,
    required this.status,
    required this.sortOrder,
    required this.createdAt,
    required this.updatedAt,
  });

  /// Deserializes from JSON.
  factory NostrAppDirectoryEntry.fromJson(
    Map<String, dynamic> json,
  ) {
    return NostrAppDirectoryEntry(
      id: _readId(json['id']),
      slug: json['slug'] as String? ?? '',
      name: json['name'] as String? ?? '',
      tagline: json['tagline'] as String? ?? '',
      description: json['description'] as String? ?? '',
      iconUrl: json['icon_url'] as String? ?? '',
      launchUrl: json['launch_url'] as String? ?? '',
      allowedOrigins: _readStringList(json['allowed_origins']),
      allowedMethods: _readStringList(json['allowed_methods']),
      allowedSignEventKinds: _readIntList(json['allowed_sign_event_kinds']),
      promptRequiredFor: _readStringList(json['prompt_required_for']),
      status: json['status'] as String? ?? 'approved',
      sortOrder: (json['sort_order'] as num?)?.toInt() ?? 0,
      createdAt: _readDateTime(json['created_at']),
      updatedAt: _readDateTime(json['updated_at']),
    );
  }

  /// Unique identifier (numeric string from the directory).
  final String id;

  /// URL-safe slug used as the stable grant key.
  final String slug;

  /// Human-readable app name.
  final String name;

  /// Short tagline.
  final String tagline;

  /// Longer description.
  final String description;

  /// URL to the app icon.
  final String iconUrl;

  /// URL to launch the app.
  final String launchUrl;

  /// Origins that may make NIP-07 requests.
  final List<String> allowedOrigins;

  /// NIP-07 methods the app may call.
  final List<String> allowedMethods;

  /// Event kinds the app may sign.
  final List<int> allowedSignEventKinds;

  /// Methods or capabilities that require a user prompt.
  final List<String> promptRequiredFor;

  /// Approval status (`approved`, `revoked`, etc.).
  final String status;

  /// Sort order for display.
  final int sortOrder;

  /// When the entry was created.
  final DateTime? createdAt;

  /// When the entry was last updated.
  final DateTime? updatedAt;

  /// Whether the entry is currently approved.
  bool get isApproved => status == 'approved';

  /// The key used to persist grants (prefers slug over id).
  String get grantKey => slug.isNotEmpty ? slug : id;

  /// The origin portion of [launchUrl].
  ///
  /// Returns the full [launchUrl] when it cannot be parsed.
  String get primaryOrigin {
    final uri = Uri.tryParse(launchUrl);
    if (uri == null || !uri.hasScheme || !uri.hasAuthority) {
      return launchUrl;
    }
    return uri.origin;
  }

  @override
  List<Object?> get props => [
    id,
    slug,
    name,
    tagline,
    description,
    iconUrl,
    launchUrl,
    allowedOrigins,
    allowedMethods,
    allowedSignEventKinds,
    promptRequiredFor,
    status,
    sortOrder,
    createdAt,
    updatedAt,
  ];

  /// Serializes to JSON.
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'slug': slug,
      'name': name,
      'tagline': tagline,
      'description': description,
      'icon_url': iconUrl,
      'launch_url': launchUrl,
      'allowed_origins': allowedOrigins,
      'allowed_methods': allowedMethods,
      'allowed_sign_event_kinds': allowedSignEventKinds,
      'prompt_required_for': promptRequiredFor,
      'status': status,
      'sort_order': sortOrder,
      'created_at': createdAt?.toUtc().toIso8601String(),
      'updated_at': updatedAt?.toUtc().toIso8601String(),
    };
  }

  static List<String> _readStringList(dynamic value) {
    if (value is! List) return const [];
    return value.whereType<String>().toList(growable: false);
  }

  static String _readId(dynamic value) {
    if (value == null) return '';
    if (value is String) return value;
    if (value is num) return value.toInt().toString();
    return value.toString();
  }

  static List<int> _readIntList(dynamic value) {
    if (value is! List) return const [];
    return value
        .whereType<num>()
        .map((item) => item.toInt())
        .toList(growable: false);
  }

  static DateTime? _readDateTime(dynamic value) {
    if (value is! String || value.isEmpty) return null;
    return DateTime.tryParse(value)?.toUtc();
  }
}
