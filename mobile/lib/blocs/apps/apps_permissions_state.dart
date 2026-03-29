part of 'apps_permissions_cubit.dart';

enum AppsPermissionsStatus { initial, loading, loaded }

class AppsPermissionsState extends Equatable {
  const AppsPermissionsState({
    this.status = AppsPermissionsStatus.initial,
    this.grants = const <NostrAppGrant>[],
  });

  final AppsPermissionsStatus status;
  final List<NostrAppGrant> grants;

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
