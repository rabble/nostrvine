import 'package:meta/meta.dart';

/// Typed model for approved Nostr app directory entries.
@immutable
class NostrAppDirectoryEntry {
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

  factory NostrAppDirectoryEntry.fromJson(Map<String, dynamic> json) {
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

  final String id;
  final String slug;
  final String name;
  final String tagline;
  final String description;
  final String iconUrl;
  final String launchUrl;
  final List<String> allowedOrigins;
  final List<String> allowedMethods;
  final List<int> allowedSignEventKinds;
  final List<String> promptRequiredFor;
  final String status;
  final int sortOrder;
  final DateTime? createdAt;
  final DateTime? updatedAt;

  bool get isApproved => status == 'approved';
  String get grantKey => slug.isNotEmpty ? slug : id;

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
    if (value == null) {
      return '';
    }
    if (value is String) {
      return value;
    }
    if (value is num) {
      return value.toInt().toString();
    }
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
