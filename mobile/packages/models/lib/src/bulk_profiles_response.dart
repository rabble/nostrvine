import 'package:meta/meta.dart';

/// Response from the bulk profiles endpoint.
///
/// Contains a map of pubkeys to their profile metadata.
@immutable
class BulkProfilesResponse {
  /// Creates a new [BulkProfilesResponse].
  const BulkProfilesResponse({required this.profiles});

  /// Profile data keyed by pubkey (hex format).
  ///
  /// Each value is the raw profile metadata map from the API.
  final Map<String, Map<String, dynamic>> profiles;
}
