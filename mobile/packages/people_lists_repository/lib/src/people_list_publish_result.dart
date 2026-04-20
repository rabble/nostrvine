// ABOUTME: Publish result vocabulary for PeopleListsRepository operations.
// ABOUTME: Models relay submission outcome without claiming relay OK.

import 'package:equatable/equatable.dart';

/// Outcome of a repository publish or delete operation.
///
/// The repository treats a non-null return from
/// `NostrClient.publishEvent` as relay submission. It does **not** wait for a
/// relay `OK` acknowledgement, so a status of
/// [PeopleListPublishStatus.submitted] does not imply the relay has persisted
/// the event.
enum PeopleListPublishStatus {
  /// The event was signed and submitted to at least one relay socket.
  submitted,

  /// The publish failed or the relay layer returned no event.
  failed,

  /// The operation was a no-op (e.g. removing a pubkey that is not a member).
  noop,
}

/// Value type returned by publish/delete operations on the people-lists
/// repository.
///
/// Carries the [status], the [eventId] of the submitted event when available,
/// and any [error] thrown from the underlying relay client for diagnostics.
class PeopleListPublishResult extends Equatable {
  /// Creates a result describing the publish outcome.
  const PeopleListPublishResult({
    required this.status,
    this.eventId,
    this.error,
  });

  /// Convenience constructor for submitted results.
  const PeopleListPublishResult.submitted({required this.eventId})
    : status = PeopleListPublishStatus.submitted,
      error = null;

  /// Convenience constructor for failed results.
  const PeopleListPublishResult.failed({this.error})
    : status = PeopleListPublishStatus.failed,
      eventId = null;

  /// Convenience constructor for no-op results.
  const PeopleListPublishResult.noop()
    : status = PeopleListPublishStatus.noop,
      eventId = null,
      error = null;

  /// The submission outcome.
  final PeopleListPublishStatus status;

  /// The submitted event ID when [status] is
  /// [PeopleListPublishStatus.submitted], otherwise `null`.
  final String? eventId;

  /// Optional underlying error when [status] is
  /// [PeopleListPublishStatus.failed].
  final Object? error;

  /// Whether the publish reached at least one relay socket.
  bool get submitted => status == PeopleListPublishStatus.submitted;

  @override
  List<Object?> get props => [status, eventId, error];
}
