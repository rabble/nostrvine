part of 'apps_directory_cubit.dart';

/// Status of the apps directory fetch operation.
enum AppsDirectoryStatus {
  /// No fetch has been attempted yet.
  initial,

  /// A fetch is in progress.
  loading,

  /// Apps have been loaded successfully.
  loaded,

  /// The fetch failed.
  error,
}

/// State for the apps directory cubit.
class AppsDirectoryState extends Equatable {
  /// Creates an [AppsDirectoryState].
  const AppsDirectoryState({
    this.status = AppsDirectoryStatus.initial,
    this.apps = const [],
  });

  /// The current status.
  final AppsDirectoryStatus status;

  /// The loaded apps, empty until [status] is [loaded].
  final List<NostrAppDirectoryEntry> apps;

  /// Returns a copy with the given fields replaced.
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
