import 'package:equatable/equatable.dart';
import 'package:meta/meta.dart';

/// How healthy one status-page component is.
///
/// The status page owns the vocabulary and can add to it, so parsing is
/// deliberately asymmetric: only the literal `operational` reads as healthy,
/// only a literal `unknown` (or a missing/unreadable value) reads as
/// [ComponentHealth.unknown], and every other value reads as [impaired].
///
/// The asymmetry is the safety property. Guessing the full set of failure
/// words would go quiet during an outage that used a word we did not
/// anticipate, which is the one moment this has to work.
enum ComponentHealth {
  /// The status page affirms the component is working.
  operational,

  /// The status page reports something other than operational.
  impaired,

  /// The status page has no usable opinion, so neither do we.
  unknown;

  /// Maps a raw `status` string from the status page.
  static ComponentHealth parse(Object? raw) {
    if (raw is! String) return ComponentHealth.unknown;
    return switch (raw.trim().toLowerCase()) {
      'operational' => ComponentHealth.operational,
      '' || 'unknown' => ComponentHealth.unknown,
      _ => ComponentHealth.impaired,
    };
  }
}

/// One component of the Divine platform, as the status page sees it.
@immutable
class StatusComponent extends Equatable {
  const StatusComponent({
    required this.id,
    required this.health,
    this.label,
    this.message,
  });

  /// Stable identifier, such as `api` or `relay`.
  final String id;

  final ComponentHealth health;

  /// Human-readable name, such as `Video Playback`.
  final String? label;

  /// The status page's own note about the latest probe.
  final String? message;

  @override
  List<Object?> get props => [id, health, label, message];
}
