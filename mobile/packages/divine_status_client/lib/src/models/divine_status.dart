import 'package:divine_status_client/src/models/component_health.dart';
import 'package:equatable/equatable.dart';
import 'package:meta/meta.dart';

/// A snapshot of the Divine status page.
@immutable
class DivineStatus extends Equatable {
  const DivineStatus({
    required this.components,
    this.updatedAt,
    this.incidentMessage,
  });

  /// Components keyed by id (`api`, `relay`, `uploads`, `playback`, ...).
  final Map<String, StatusComponent> components;

  /// When the status page last recomputed, if it said.
  final DateTime? updatedAt;

  /// The on-call operator's own words about an open incident.
  ///
  /// Preferred over any canned copy when present: a human saying what is
  /// happening beats the app guessing from component states.
  final String? incidentMessage;

  /// Health of [id], or [ComponentHealth.unknown] when the page omits it.
  ComponentHealth healthOf(String id) =>
      components[id]?.health ?? ComponentHealth.unknown;

  /// Whether any of [ids] is explicitly reported as impaired.
  ///
  /// [ComponentHealth.unknown] deliberately does not count — an absent
  /// opinion is not corroboration.
  bool anyImpaired(Iterable<String> ids) =>
      ids.any((id) => healthOf(id) == ComponentHealth.impaired);

  /// Parses the `/api/status` payload.
  ///
  /// Returns `null` when [body] is not a status document. Every non-API path
  /// on the status host answers `200` with the single-page-app shell, so a
  /// wrong URL or an intercepting portal yields HTML rather than an error
  /// code; treating that as "all clear" would silently disable the feature.
  static DivineStatus? tryParse(Object? body) {
    if (body is! Map<String, dynamic>) return null;
    final rawComponents = body['components'];
    if (rawComponents is! Map<String, dynamic>) return null;

    final components = <String, StatusComponent>{};
    for (final entry in rawComponents.entries) {
      final value = entry.value;
      if (value is! Map<String, dynamic>) continue;
      components[entry.key] = StatusComponent(
        id: entry.key,
        health: ComponentHealth.parse(value['status']),
        label: value['label'] as String?,
        message: value['message'] as String?,
      );
    }
    if (components.isEmpty) return null;

    return DivineStatus(
      components: components,
      updatedAt: DateTime.tryParse(body['updatedAt'] as String? ?? ''),
      incidentMessage: _incidentMessage(body['incident']),
    );
  }

  /// Pulls a displayable sentence out of the `incident` field.
  ///
  /// The field is `null` outside an incident, so its populated shape is
  /// unverified here — it is read defensively as either a bare string or a
  /// map carrying one of the usual message keys, and ignored otherwise.
  static String? _incidentMessage(Object? incident) {
    if (incident is String) {
      final trimmed = incident.trim();
      return trimmed.isEmpty ? null : trimmed;
    }
    if (incident is! Map<String, dynamic>) return null;
    for (final key in const ['message', 'body', 'description', 'title']) {
      final value = incident[key];
      if (value is String && value.trim().isNotEmpty) return value.trim();
    }
    return null;
  }

  @override
  List<Object?> get props => [components, updatedAt, incidentMessage];
}
