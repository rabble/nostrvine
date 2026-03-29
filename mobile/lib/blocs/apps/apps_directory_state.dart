part of 'apps_directory_cubit.dart';

enum AppsDirectoryStatus { initial, loading, loaded, failure }

class AppsDirectoryState extends Equatable {
  const AppsDirectoryState({
    this.status = AppsDirectoryStatus.initial,
    this.apps = const <NostrAppDirectoryEntry>[],
  });

  final AppsDirectoryStatus status;
  final List<NostrAppDirectoryEntry> apps;

  AppsDirectoryState copyWith({
    AppsDirectoryStatus? status,
    List<NostrAppDirectoryEntry>? apps,
  }) {
    return AppsDirectoryState(
      status: status ?? this.status,
      apps: apps ?? this.apps,
    );
  }

  @override
  List<Object?> get props => [status, apps];
}
