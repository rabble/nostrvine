// ABOUTME: Public credit and consent metadata for sharing reusable audio.
// ABOUTME: Deliberately separate from private device-local saved sound details.

import 'package:meta/meta.dart';

@immutable
class AudioShareAttribution {
  const AudioShareAttribution({
    required this.title,
    required this.creatorName,
    required List<String> publicTags,
    required this.confirmedOwnWork,
    this.creatorPubkey,
    this.creatorUrl,
    this.sourceUrl,
    this.licenseName,
    this.licenseUrl,
  }) : _publicTags = publicTags;

  factory AudioShareAttribution.forOwnedSound({
    required String title,
    required String publisherName,
    required String publisherPubkey,
    List<String> publicTags = const [],
  }) => AudioShareAttribution(
    title: title,
    creatorName: publisherName,
    creatorPubkey: publisherPubkey,
    publicTags: publicTags,
    confirmedOwnWork: true,
  );

  factory AudioShareAttribution.fromJson(Map<String, dynamic> json) {
    return AudioShareAttribution(
      title: json['title'] as String? ?? '',
      creatorName: json['creatorName'] as String? ?? '',
      creatorPubkey: json['creatorPubkey'] as String?,
      creatorUrl: json['creatorUrl'] as String?,
      sourceUrl: json['sourceUrl'] as String?,
      licenseName: json['licenseName'] as String?,
      licenseUrl: json['licenseUrl'] as String?,
      publicTags: switch (json['publicTags']) {
        final List values => values.whereType<String>().toList(growable: false),
        _ => const [],
      },
      confirmedOwnWork: json['confirmedOwnWork'] as bool? ?? false,
    );
  }

  final String title;
  final String creatorName;
  final String? creatorPubkey;
  final String? creatorUrl;
  final String? sourceUrl;
  final String? licenseName;
  final String? licenseUrl;
  final List<String> _publicTags;
  final bool confirmedOwnWork;

  List<String> get publicTags => normalizePublicAudioTags(_publicTags);

  bool get isValid =>
      title.trim().isNotEmpty &&
      creatorName.trim().isNotEmpty &&
      (confirmedOwnWork || (sourceUrl?.trim().isNotEmpty ?? false));

  AudioShareAttribution copyWith({
    String? title,
    String? creatorName,
    Object? creatorPubkey = _unset,
    Object? creatorUrl = _unset,
    Object? sourceUrl = _unset,
    Object? licenseName = _unset,
    Object? licenseUrl = _unset,
    List<String>? publicTags,
    bool? confirmedOwnWork,
  }) => AudioShareAttribution(
    title: title ?? this.title,
    creatorName: creatorName ?? this.creatorName,
    creatorPubkey: identical(creatorPubkey, _unset)
        ? this.creatorPubkey
        : creatorPubkey as String?,
    creatorUrl: identical(creatorUrl, _unset)
        ? this.creatorUrl
        : creatorUrl as String?,
    sourceUrl: identical(sourceUrl, _unset)
        ? this.sourceUrl
        : sourceUrl as String?,
    licenseName: identical(licenseName, _unset)
        ? this.licenseName
        : licenseName as String?,
    licenseUrl: identical(licenseUrl, _unset)
        ? this.licenseUrl
        : licenseUrl as String?,
    publicTags: publicTags ?? this.publicTags,
    confirmedOwnWork: confirmedOwnWork ?? this.confirmedOwnWork,
  );

  Map<String, dynamic> toJson() => {
    'title': title.trim(),
    'creatorName': creatorName.trim(),
    'creatorPubkey': ?_nonBlank(creatorPubkey),
    'creatorUrl': ?_nonBlank(creatorUrl),
    'sourceUrl': ?_nonBlank(sourceUrl),
    'licenseName': ?_nonBlank(licenseName),
    'licenseUrl': ?_nonBlank(licenseUrl),
    'publicTags': publicTags,
    'confirmedOwnWork': confirmedOwnWork,
  };

  @override
  bool operator ==(Object other) =>
      other is AudioShareAttribution &&
      other.title.trim() == title.trim() &&
      other.creatorName.trim() == creatorName.trim() &&
      other.creatorPubkey == creatorPubkey &&
      other.creatorUrl == creatorUrl &&
      other.sourceUrl == sourceUrl &&
      other.licenseName == licenseName &&
      other.licenseUrl == licenseUrl &&
      _listEquals(other.publicTags, publicTags) &&
      other.confirmedOwnWork == confirmedOwnWork;

  @override
  int get hashCode => Object.hash(
    title.trim(),
    creatorName.trim(),
    creatorPubkey,
    creatorUrl,
    sourceUrl,
    licenseName,
    licenseUrl,
    Object.hashAll(publicTags),
    confirmedOwnWork,
  );
}

const _unset = Object();

List<String> normalizePublicAudioTags(Iterable<String> values) {
  final seen = <String>{};
  final result = <String>[];
  for (final raw in values) {
    final normalized = raw
        .trim()
        .replaceFirst(RegExp('^#+'), '')
        .trim()
        .toLowerCase();
    if (normalized.isNotEmpty && seen.add(normalized)) result.add(normalized);
  }
  return List.unmodifiable(result);
}

String? _nonBlank(String? value) {
  final trimmed = value?.trim();
  return trimmed == null || trimmed.isEmpty ? null : trimmed;
}

bool _listEquals<T>(List<T> left, List<T> right) {
  if (left.length != right.length) return false;
  for (var index = 0; index < left.length; index++) {
    if (left[index] != right[index]) return false;
  }
  return true;
}
