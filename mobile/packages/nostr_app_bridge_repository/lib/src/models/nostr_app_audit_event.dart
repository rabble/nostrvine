import 'package:meta/meta.dart';

/// Decision outcome for a bridge audit event.
enum NostrAppAuditDecision {
  /// The request was allowed by policy.
  allowed('allowed'),

  /// The request was denied by policy.
  denied('denied'),

  /// The user approved the request via a prompt.
  promptAllowed('prompt_allowed'),

  /// The user denied the request via a prompt.
  promptDenied('prompt_denied'),

  /// The request was blocked before reaching the user.
  blocked('blocked')
  ;

  const NostrAppAuditDecision(this.wireValue);

  /// The serialized string sent to the audit backend.
  final String wireValue;

  /// Parses a wire-format string into an [NostrAppAuditDecision].
  static NostrAppAuditDecision fromWireValue(String value) {
    return NostrAppAuditDecision.values.firstWhere(
      (decision) => decision.wireValue == value,
      orElse: () => throw ArgumentError('Unknown audit decision: $value'),
    );
  }
}

/// A single audit record for a Nostr app bridge request.
@immutable
class NostrAppAuditEvent {
  /// Creates an audit event.
  const NostrAppAuditEvent({
    required this.appId,
    required this.origin,
    required this.userPubkey,
    required this.method,
    required this.decision,
    required this.createdAt,
    this.eventKind,
    this.errorCode,
  });

  /// Deserializes from JSON.
  factory NostrAppAuditEvent.fromJson(Map<String, dynamic> json) {
    return NostrAppAuditEvent(
      appId: json['app_id'] as int,
      origin: Uri.parse(json['origin'] as String),
      userPubkey: json['user_pubkey'] as String,
      method: json['method'] as String,
      eventKind: json['event_kind'] as int?,
      decision: NostrAppAuditDecision.fromWireValue(
        json['decision'] as String,
      ),
      errorCode: json['error_code'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  /// Numeric identifier of the app in the directory.
  final int appId;

  /// The origin URI of the requesting web app.
  final Uri origin;

  /// The hex public key of the user.
  final String userPubkey;

  /// The NIP-07 method name (e.g. `signEvent`).
  final String method;

  /// The Nostr event kind, if applicable.
  final int? eventKind;

  /// The policy decision.
  final NostrAppAuditDecision decision;

  /// An error code when the request was denied.
  final String? errorCode;

  /// When the event was created.
  final DateTime createdAt;

  /// Serializes to JSON (full record).
  Map<String, dynamic> toJson() {
    return {
      'app_id': appId,
      'origin': origin.toString(),
      'user_pubkey': userPubkey,
      'method': method,
      'event_kind': eventKind,
      'decision': decision.wireValue,
      'error_code': errorCode,
      'created_at': createdAt.toUtc().toIso8601String(),
    };
  }

  /// Serializes to JSON for upload (omits user_pubkey and
  /// created_at which are set server-side).
  Map<String, dynamic> toUploadJson() {
    return {
      'app_id': appId,
      'origin': origin.toString(),
      'method': method,
      'event_kind': eventKind,
      'decision': decision.wireValue,
      'error_code': errorCode,
    };
  }

  /// Creates a copy with the given fields replaced.
  NostrAppAuditEvent copyWith({
    int? appId,
    Uri? origin,
    String? userPubkey,
    String? method,
    int? eventKind,
    NostrAppAuditDecision? decision,
    String? errorCode,
    DateTime? createdAt,
  }) {
    return NostrAppAuditEvent(
      appId: appId ?? this.appId,
      origin: origin ?? this.origin,
      userPubkey: userPubkey ?? this.userPubkey,
      method: method ?? this.method,
      eventKind: eventKind ?? this.eventKind,
      decision: decision ?? this.decision,
      errorCode: errorCode ?? this.errorCode,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is NostrAppAuditEvent &&
        other.appId == appId &&
        other.origin == origin &&
        other.userPubkey == userPubkey &&
        other.method == method &&
        other.eventKind == eventKind &&
        other.decision == decision &&
        other.errorCode == errorCode &&
        other.createdAt == createdAt;
  }

  @override
  int get hashCode => Object.hash(
    appId,
    origin,
    userPubkey,
    method,
    eventKind,
    decision,
    errorCode,
    createdAt,
  );
}
