part of 'apps_permissions_cubit.dart';

/// Status of the permissions list.
enum AppsPermissionsStatus {
  /// No load has been attempted yet.
  initial,

  /// Grants are being loaded.
  loading,

  /// Grants have been loaded.
  loaded,
}

/// State for the permissions cubit.
class AppsPermissionsState extends Equatable {
  /// Creates an [AppsPermissionsState].
  const AppsPermissionsState({
    this.status = AppsPermissionsStatus.initial,
    this.grants = const [],
  });

  /// The current status.
  final AppsPermissionsStatus status;

  /// The loaded grants.
  final List<NostrAppGrant> grants;

  /// Returns a copy with the given fields replaced.
  AppsPermissionsState copyWith({
    AppsPermissionsStatus? status,
    List<NostrAppGrant>? grants,
  }) {
    return AppsPermissionsState(
      status: status ?? this.status,
      grants: grants ?? this.grants,
    );
  }

  @override
  List<Object?> get props => [status, grants];
}
