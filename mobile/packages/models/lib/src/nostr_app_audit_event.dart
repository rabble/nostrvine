import 'package:meta/meta.dart';

enum NostrAppAuditDecision {
  allowed('allowed'),
  denied('denied'),
  promptAllowed('prompt_allowed'),
  promptDenied('prompt_denied'),
  blocked('blocked')
  ;

  const NostrAppAuditDecision(this.wireValue);

  final String wireValue;

  static NostrAppAuditDecision fromWireValue(String value) {
    return NostrAppAuditDecision.values.firstWhere(
      (decision) => decision.wireValue == value,
      orElse: () => throw ArgumentError('Unknown audit decision: $value'),
    );
  }
}

@immutable
class NostrAppAuditEvent {
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

  factory NostrAppAuditEvent.fromJson(Map<String, dynamic> json) {
    return NostrAppAuditEvent(
      appId: json['app_id'] as int,
      origin: Uri.parse(json['origin'] as String),
      userPubkey: json['user_pubkey'] as String,
      method: json['method'] as String,
      eventKind: json['event_kind'] as int?,
      decision: NostrAppAuditDecision.fromWireValue(json['decision'] as String),
      errorCode: json['error_code'] as String?,
      createdAt: DateTime.parse(json['created_at'] as String),
    );
  }

  final int appId;
  final Uri origin;
  final String userPubkey;
  final String method;
  final int? eventKind;
  final NostrAppAuditDecision decision;
  final String? errorCode;
  final DateTime createdAt;

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
