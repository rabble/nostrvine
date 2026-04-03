part of 'sandbox_route_cubit.dart';

/// State for the [SandboxRouteCubit].
sealed class SandboxRouteState extends Equatable {
  const SandboxRouteState();
}

/// The entry is being resolved.
class SandboxRouteLoading extends SandboxRouteState {
  /// Creates a loading state.
  const SandboxRouteLoading();

  @override
  List<Object?> get props => [];
}

/// The entry was resolved successfully.
class SandboxRouteResolved extends SandboxRouteState {
  /// Creates a resolved state.
  const SandboxRouteResolved(this.app);

  /// The resolved directory entry.
  final NostrAppDirectoryEntry app;

  @override
  List<Object?> get props => [app];
}

/// The entry was not found.
class SandboxRouteNotFound extends SandboxRouteState {
  /// Creates a not-found state.
  const SandboxRouteNotFound();

  @override
  List<Object?> get props => [];
}
